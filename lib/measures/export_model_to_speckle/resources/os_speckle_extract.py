"""Extract an OpenStudio model into a plain-JSON "Speckle payload".

This module depends only on the ``openstudio`` Python bindings (available inside
every OpenStudio measure). It never imports specklepy, so the extraction step works
even when specklepy is not installed. ``speckle_publisher.py`` turns the payload
into a Speckle bundle and publishes it.

Payload layout (all lengths in metres, site coordinates incl. north axis):

    {
      "schema": "os-speckle-payload/1",
      "units": "m",
      "producer": {"slug": "openstudio", "version": "3.11.0"},
      "model_name": "...",
      "model_properties": {"Building.Name": "...", ...},
      "levels":  [{"key", "name", "elevation"}],
      "groups":  [{"key", "name", "subtype"}],          # thermal zones, air loops
      "materials": [{"key", "name", "argb", "opacity"}],
      "objects": [{
          "id", "name", "category", "collection": [...path],
          "level", "room", "host", "groups": [...], "systems": [...],
          "material", "properties": {...nested...},
          "mesh": {"vertices": [...], "faces": [...]} | null
      }],
      "scene_views": [{"name", "default", "keys": [["rel", 10] | ["eav", "path"]]}]
    }
"""

from __future__ import annotations

import math

import openstudio

PAYLOAD_SCHEMA = "os-speckle-payload/1"

# Colours roughly follow the OpenStudio SketchUp plugin / OS App "render by surface type".
SURFACE_TYPE_COLORS = {
    "Floor": ((128, 128, 128), 1.0),
    "Wall": ((204, 178, 102), 1.0),
    "RoofCeiling": ((153, 76, 76), 1.0),
    "FixedWindow": ((102, 178, 204), 0.45),
    "OperableWindow": ((102, 178, 204), 0.45),
    "GlassDoor": ((102, 178, 204), 0.45),
    "Skylight": ((102, 178, 204), 0.45),
    "TubularDaylightDome": ((102, 178, 204), 0.45),
    "TubularDaylightDiffuser": ((102, 178, 204), 0.45),
    "Door": ((153, 133, 76), 1.0),
    "OverheadDoor": ((153, 133, 76), 1.0),
    "SiteShading": ((75, 124, 149), 0.8),
    "BuildingShading": ((113, 76, 153), 0.8),
    "SpaceShading": ((76, 110, 178), 0.8),
    "InteriorPartitionSurface": ((158, 188, 143), 0.8),
}

BOUNDARY_COLORS = {
    "Outdoors": ((163, 204, 204), 1.0),
    "Ground": ((204, 183, 122), 1.0),
    "Surface": ((0, 153, 0), 1.0),
    "Adiabatic": ((255, 101, 178), 1.0),
    "Foundation": ((117, 30, 122), 1.0),
    "OtherSideCoefficients": ((63, 63, 63), 1.0),
    "OtherSideConditionsModel": ((153, 0, 76), 1.0),
}

COLOR_BY_CHOICES = ["Surface Type", "Boundary Condition", "Thermal Zone", "Space Type", "Construction"]

M2 = "m²"


# ───────────────────────────── small helpers ─────────────────────────────────


def _opt(o):
    """Unwrap an OpenStudio boost::optional (None if empty)."""
    if o is None:
        return None
    if hasattr(o, "is_initialized"):
        return o.get() if o.is_initialized() else None
    return o


def _name(obj) -> str | None:
    if obj is None:
        return None
    n = _opt(obj.name())
    return str(n) if n is not None else None


def _handle(obj) -> str:
    return str(obj.handle()).strip("{}")


def _q(name: str, value, units: str | None = None) -> dict | None:
    """Speckle 'parameter' pattern -> one property row carrying units."""
    if value is None:
        return None
    if isinstance(value, float):
        if not math.isfinite(value):
            return None
        value = round(value, 6)
    d = {"name": name, "value": value}
    if units:
        d["units"] = units
    return d


def _clean(d: dict) -> dict:
    """Drop None values recursively so the property tree stays tidy."""
    out = {}
    for k, v in d.items():
        if isinstance(v, dict) and not ("name" in v and "value" in v):
            v = _clean(v)
            if not v:
                continue
        if v is None:
            continue
        out[k] = v
    return out


def _argb(rgb, alpha=255) -> int:
    r, g, b = rgb
    return (int(alpha) << 24) | (int(r) << 16) | (int(g) << 8) | int(b)


# Distinct, mid-saturation colours for objects that have no OpenStudio RenderingColor.
_AUTO_PALETTE = [
    (31, 119, 180), (255, 127, 14), (44, 160, 44), (214, 39, 40), (148, 103, 189),
    (140, 86, 75), (227, 119, 194), (127, 127, 127), (188, 189, 34), (23, 190, 207),
    (174, 199, 232), (255, 187, 120), (152, 223, 138), (255, 152, 150), (197, 176, 213),
    (196, 156, 148), (247, 182, 210), (219, 219, 141), (158, 218, 229), (57, 59, 121),
]


def _auto_rgb(label: str):
    """Stable colour from a name (same name -> same colour on every run)."""
    import zlib

    return _AUTO_PALETTE[zlib.crc32((label or "").encode("utf-8")) % len(_AUTO_PALETTE)]


def _rendering_rgb(obj):
    """RGB tuple from an object's RenderingColor, if it has one."""
    if obj is None or not hasattr(obj, "renderingColor"):
        return None
    rc = _opt(obj.renderingColor())
    if rc is None:
        return None
    return (rc.renderingRedValue(), rc.renderingGreenValue(), rc.renderingBlueValue())


def _all(model, cls: str):
    """model.getXs() with fallbacks: some OpenStudio builds (e.g. the macOS CLI's
    embedded Python) don't attach every getter to Model."""
    plural = f"get{cls}s"
    fn = getattr(model, plural, None)
    if fn is not None:
        return list(fn())
    fn = getattr(openstudio.model, plural, None)
    if fn is not None:
        return list(fn(model))
    return _by_type(model, cls)


def _by_type(model, cls: str):
    """Last-resort lookup by IDD type, cast with the generic to_<Class>()."""
    idd = openstudio.IddObjectType(f"OS:{cls}")
    out = []
    for o in model.getObjectsByType(idd):
        cast = _opt(getattr(o, f"to_{cls}")())
        if cast is not None:
            out.append(cast)
    return out


def _unique(model, cls: str):
    """model.getBuilding()/getSite()/... with the same fallbacks as _all."""
    fn = getattr(model, f"get{cls}", None)
    if fn is not None:
        return fn()
    fn = getattr(openstudio.model, f"get{cls}", None)
    if fn is not None:
        return fn(model)
    found = _by_type(model, cls)
    return found[0] if found else None  # never create objects: the model stays untouched


def _deg(rad) -> float:
    return math.degrees(rad)


# ───────────────────────────── geometry ──────────────────────────────────────


def _triangulate(vertices, holes, transformation):
    """Triangulate a planar polygon (with optional holes) and return a Speckle mesh
    dict in site coordinates. Mirrors OpenStudio's ThreeJS translator."""
    verts = list(vertices)
    if len(verts) < 3:
        return None
    try:
        align = openstudio.Transformation.alignFace(vertices)
        inv = align.inverse()
        face = openstudio.reverse(inv * vertices)
        hole_vec = openstudio.Point3dVectorVector()
        for h in holes:
            hole_vec.append(openstudio.reverse(inv * h))
        tris = openstudio.computeTriangulation(face, hole_vec)
        if len(tris) == 0 and len(holes) > 0:
            # triangulation with holes can fail on bad sub-surface geometry; fall back
            tris = openstudio.computeTriangulation(face, openstudio.Point3dVectorVector())
        world = transformation * align
        tri_pts = [list(world * openstudio.reverse(t)) for t in tris]
    except Exception:
        tri_pts = []

    if not tri_pts:
        # simple fan triangulation as a last resort (fine for convex polygons)
        pts = list(transformation * vertices)
        tri_pts = [[pts[0], pts[i], pts[i + 1]] for i in range(1, len(pts) - 1)]

    flat, faces, index = [], [], {}
    for tri in tri_pts:
        if len(tri) != 3:
            continue
        ids = []
        for p in tri:
            key = (round(p.x(), 6), round(p.y(), 6), round(p.z(), 6))
            if key not in index:
                index[key] = len(index)
                flat.extend(key)
            ids.append(index[key])
        if len(set(ids)) == 3:
            faces.extend([3, *ids])
    if not faces:
        return None
    return {"vertices": flat, "faces": faces}


# ───────────────────────────── extractor ─────────────────────────────────────


class _Extractor:
    def __init__(self, model, color_by="Surface Type", include_shading=True,
                 include_partitions=True, include_spaces=True):
        self.m = model
        self.color_by = color_by if color_by in COLOR_BY_CHOICES else "Surface Type"
        self.include_shading = include_shading
        self.include_partitions = include_partitions
        self.include_spaces = include_spaces
        self.objects: list[dict] = []
        self.levels: dict[str, dict] = {}
        self.groups: dict[str, dict] = {}
        self.materials: dict[str, dict] = {}
        self.space_cache: dict[str, dict] = {}
        self.warnings: list[str] = []
        self.building = _unique(model, "Building")

    # ── materials / colours ────────────────────────────────────────────────

    def _material(self, key: str, rgb, opacity: float, label: str) -> str:
        if key not in self.materials:
            self.materials[key] = {
                "key": key,
                "name": label,
                "argb": _argb(rgb),
                "opacity": float(opacity),
            }
        return key

    def _pick_material(self, kind: str, surface_type: str, boundary: str | None,
                       zone, space_type, construction) -> str:
        default_rgb, default_op = SURFACE_TYPE_COLORS.get(surface_type, ((200, 200, 200), 1.0))
        is_glazing = default_op < 0.5
        mode = self.color_by
        if mode == "Boundary Condition" and boundary and kind != "SubSurface":
            rgb, op = BOUNDARY_COLORS.get(boundary, ((200, 200, 200), 1.0))
            return self._material(f"bc:{boundary}", rgb, op, f"Boundary: {boundary}")
        if mode in ("Thermal Zone", "Space Type", "Construction") and kind in ("Surface", "SubSurface"):
            src = {"Thermal Zone": zone, "Space Type": space_type, "Construction": construction}[mode]
            rgb = _rendering_rgb(src)
            if rgb is None and src is not None:
                # e.g. a building-default space type created by a script: no
                # RenderingColor object, but it should still get its own colour
                rgb = _auto_rgb(_name(src))
            if rgb is not None:
                op = default_op if is_glazing else 1.0
                key = f"{mode}:{_name(src)}:{'glz' if is_glazing else 'opq'}"
                return self._material(key, rgb, op, f"{mode}: {_name(src)}")
        return self._material(f"type:{surface_type}", default_rgb, default_op, surface_type)

    # ── context objects ────────────────────────────────────────────────────

    def _level(self, story) -> str | None:
        if story is None:
            return None
        key = _handle(story)
        if key not in self.levels:
            z = _opt(story.nominalZCoordinate())
            self.levels[key] = {
                "key": key,
                "name": _name(story),
                "elevation": float(z) if z is not None else 0.0,
            }
        return key

    def _group(self, obj, subtype: str) -> str:
        key = f"{subtype}:{_handle(obj)}"
        if key not in self.groups:
            self.groups[key] = {"key": key, "name": _name(obj), "subtype": subtype}
        return key

    def _space_info(self, space) -> dict:
        """Space / zone / story context shared by every surface in the space."""
        if space is None:
            return {"props": {}, "collection": ["Unassigned"], "level": None,
                    "zone": None, "space_type": None, "groups": [], "systems": [],
                    "id": None, "transform": openstudio.Transformation()}
        h = _handle(space)
        if h in self.space_cache:
            return self.space_cache[h]

        story = _opt(space.buildingStory())
        zone = _opt(space.thermalZone())
        stype = _opt(space.spaceType())
        groups, systems, air_loops, zone_equipment = [], [], [], []
        zone_props = None
        if zone is not None:
            groups.append(self._group(zone, "Thermal Zone"))
            for loop in zone.airLoopHVACs():
                air_loops.append(_name(loop))
                systems.append(self._group(loop, "Air Loop"))
            zone_equipment = [_name(e) for e in zone.equipment()]
            tstat = _opt(zone.thermostatSetpointDualSetpoint())
            heat = _opt(tstat.heatingSetpointTemperatureSchedule()) if tstat else None
            cool = _opt(tstat.coolingSetpointTemperatureSchedule()) if tstat else None
            zone_props = {
                "Name": _name(zone),
                "Multiplier": zone.multiplier(),
                "Has Thermostat": tstat is not None,
                "Has HVAC": bool(air_loops or zone_equipment),
                "Air Loops": ", ".join(air_loops) if air_loops else None,
                "Zone Equipment": ", ".join(zone_equipment) if zone_equipment else None,
                "Heating Setpoint Schedule": _name(heat),
                "Cooling Setpoint Schedule": _name(cool),
                "Floor Area": _q("Floor Area", zone.floorArea(), M2),
            }

        std_type = _opt(stype.standardsSpaceType()) if stype else None
        std_bldg = _opt(stype.standardsBuildingType()) if stype else None
        oa = _opt(space.designSpecificationOutdoorAir())
        space_props = {
            "Name": _name(space),
            "Space Type": _name(stype),
            "Space Type Source": (None if stype is None else
                                  ("Building default" if space.isSpaceTypeDefaulted() else "Space")),
            "Standards Building Type": std_bldg,
            "Standards Space Type": std_type,
            "Building Story": _name(story),
            "Thermal Zone": _name(zone),
            "Part of Total Floor Area": bool(space.partofTotalFloorArea()),
            "Floor Area": _q("Floor Area", space.floorArea(), M2),
            "Volume": _q("Volume", space.volume(), "m³"),
            "Exterior Wall Area": _q("Exterior Wall Area", space.exteriorWallArea(), M2),
            "People Density": _q("People Density", space.peoplePerFloorArea(), "people/m²"),
            "Lighting Power Density": _q("Lighting Power Density", space.lightingPowerPerFloorArea(), "W/m²"),
            "Electric Equipment Power Density": _q("Electric Equipment Power Density",
                                                   space.electricEquipmentPowerPerFloorArea(), "W/m²"),
            "Gas Equipment Power Density": _q("Gas Equipment Power Density",
                                              space.gasEquipmentPowerPerFloorArea(), "W/m²"),
            "Infiltration ACH": _q("Infiltration ACH", space.infiltrationDesignAirChangesPerHour(), "1/h"),
            "Infiltration per Exterior Area": _q("Infiltration per Exterior Area",
                                                 space.infiltrationDesignFlowPerExteriorSurfaceArea(), "m³/s·m²"),
            "Outdoor Air Spec": _name(oa),
            "Outdoor Air per Person": _q("Outdoor Air per Person",
                                         oa.outdoorAirFlowperPerson() if oa else None, "m³/s·person"),
            "Outdoor Air per Floor Area": _q("Outdoor Air per Floor Area",
                                             oa.outdoorAirFlowperFloorArea() if oa else None, "m³/s·m²"),
        }
        props = {"Space": _clean(space_props)}
        if zone_props:
            props["Thermal Zone"] = _clean(zone_props)
        if story is not None:
            props["Building Story"] = _clean({
                "Name": _name(story),
                "Nominal Z": _q("Nominal Z", _opt(story.nominalZCoordinate()), "m"),
                "Floor to Floor Height": _q("Floor to Floor Height",
                                            _opt(story.nominalFloortoFloorHeight()), "m"),
            })

        info = {
            "id": h,
            "props": props,
            "collection": [_name(story) or "No Story", _name(space)],
            "level": self._level(story),
            "zone": zone,
            "space_type": stype,
            "groups": groups,
            "systems": systems,
            "transform": space.siteTransformation(),
        }
        self.space_cache[h] = info

        if self.include_spaces:
            self.objects.append({
                "id": h,
                "name": _name(space),
                "category": "Space",
                "collection": info["collection"],
                "level": info["level"],
                "room": None,
                "host": None,
                "groups": groups,
                "systems": systems,
                "material": None,
                "properties": _clean({
                    "OpenStudio": {"Object Type": "OS:Space", "Handle": h},
                    **props,
                }),
                "mesh": None,
            })
        return info

    # ── constructions ──────────────────────────────────────────────────────

    def _construction_props(self, planar) -> tuple[dict, object]:
        c = _opt(planar.construction())
        if c is None:
            return {"Name": None}, None
        props = {
            "Name": _name(c),
            "Defaulted": bool(planar.isConstructionDefaulted()) if hasattr(planar, "isConstructionDefaulted") else None,
            "Type": c.iddObjectType().valueDescription(),
        }
        lc = _opt(c.to_LayeredConstruction())
        if lc is not None:
            layers = [_name(m) for m in lc.layers()]
            props["Layers"] = " | ".join([n for n in layers if n])
            props["Layer Count"] = len(layers)
            if lc.isFenestration() and len(lc.layers()) == 1:
                sg = _opt(lc.layers()[0].to_SimpleGlazing())
                if sg is not None:
                    props["SHGC"] = _q("SHGC", sg.solarHeatGainCoefficient())
                    props["Glazing U-Factor"] = _q("Glazing U-Factor", sg.uFactor(), "W/m²·K")
                    vt = _opt(sg.visibleTransmittance())
                    props["Visible Transmittance"] = _q("Visible Transmittance", vt)
        if hasattr(planar, "uFactor"):
            u = _opt(planar.uFactor())
            if u is not None and u > 0:
                props["U-Factor"] = _q("U-Factor", u, "W/m²·K")
                props["R-Value"] = _q("R-Value", 1.0 / u, "m²·K/W")
        return props, c

    # ── surfaces ───────────────────────────────────────────────────────────

    def surfaces(self):
        for s in sorted(_all(self.m, "Surface"), key=lambda x: _name(x) or ""):
            try:
                self._surface(s)
            except Exception as err:
                self.warnings.append(f"Skipped surface '{_name(s)}': {err}")

    def _surface(self, s):
        space = _opt(s.space())
        info = self._space_info(space)
        subs = list(s.subSurfaces())
        holes = [sub.vertices() for sub in subs]
        mesh = _triangulate(s.vertices(), holes, info["transform"])
        if mesh is None:
            self.warnings.append(f"Could not triangulate surface '{_name(s)}'.")
        stype = s.surfaceType()
        bc = s.outsideBoundaryCondition()
        adj = _opt(s.adjacentSurface())
        cprops, construction = self._construction_props(s)
        wwr = s.windowToWallRatio() if stype == "Wall" else None
        h = _handle(s)
        props = {
            "OpenStudio": {"Object Type": "OS:Surface", "Handle": h},
            "Surface": {
                "Name": _name(s),
                "Surface Type": stype,
                "Outside Boundary Condition": bc,
                "Outside Boundary Condition Object": _name(adj),
                "Sun Exposure": s.sunExposure(),
                "Wind Exposure": s.windExposure(),
                "Gross Area": _q("Gross Area", s.grossArea(), M2),
                "Net Area": _q("Net Area", s.netArea(), M2),
                "Azimuth": _q("Azimuth", _deg(s.azimuth()), "deg"),
                "Tilt": _q("Tilt", _deg(s.tilt()), "deg"),
                "Window to Wall Ratio": _q("Window to Wall Ratio", wwr),
                "Sub-Surface Count": len(subs),
            },
            "Construction": cprops,
            **info["props"],
        }
        self.objects.append({
            "id": h,
            "name": _name(s),
            "category": "Surface",
            "collection": info["collection"],
            "level": info["level"],
            "room": info["id"] if self.include_spaces else None,
            "host": None,
            "groups": info["groups"],
            "systems": [],
            "material": self._pick_material("Surface", stype, bc, info["zone"],
                                            info["space_type"], construction),
            "properties": _clean(props),
            "mesh": mesh,
        })

        for sub in subs:
            try:
                self._subsurface(sub, s, info)
            except Exception as err:
                self.warnings.append(f"Skipped sub-surface '{_name(sub)}': {err}")

    def _subsurface(self, sub, parent, info):
        mesh = _triangulate(sub.vertices(), [], info["transform"])
        stype = sub.subSurfaceType()
        cprops, construction = self._construction_props(sub)
        h = _handle(sub)
        props = {
            "OpenStudio": {"Object Type": "OS:SubSurface", "Handle": h},
            "Sub Surface": {
                "Name": _name(sub),
                "Sub Surface Type": stype,
                "Parent Surface": _name(parent),
                "Outside Boundary Condition": parent.outsideBoundaryCondition(),
                "Multiplier": sub.multiplier(),
                "Gross Area": _q("Gross Area", sub.grossArea(), M2),
                "Azimuth": _q("Azimuth", _deg(sub.azimuth()), "deg"),
                "Tilt": _q("Tilt", _deg(sub.tilt()), "deg"),
                "Shading Control": ", ".join(_name(c) for c in sub.shadingControls())
                if hasattr(sub, "shadingControls") and len(sub.shadingControls()) else None,
            },
            "Construction": cprops,
            **info["props"],
        }
        self.objects.append({
            "id": h,
            "name": _name(sub),
            "category": "SubSurface",
            "collection": info["collection"],
            "level": info["level"],
            "room": info["id"] if self.include_spaces else None,
            "host": _handle(parent),
            "groups": info["groups"],
            "systems": [],
            "material": self._pick_material("SubSurface", stype, None, info["zone"],
                                            info["space_type"], construction),
            "properties": _clean(props),
            "mesh": mesh,
        })

    # ── shading & partitions ───────────────────────────────────────────────

    def shading(self):
        if not self.include_shading:
            return
        for grp in _all(self.m, "ShadingSurfaceGroup"):
            gtype = grp.shadingSurfaceType()  # Site | Building | Space
            space = _opt(grp.space())
            info = self._space_info(space) if space is not None else None
            transform = grp.siteTransformation()
            category = f"{gtype}Shading"
            for sh in grp.shadingSurfaces():
                mesh = _triangulate(sh.vertices(), [], transform)
                cprops, construction = self._construction_props(sh)
                sched = _opt(sh.transmittanceSchedule())
                h = _handle(sh)
                props = {
                    "OpenStudio": {"Object Type": "OS:ShadingSurface", "Handle": h},
                    "Shading Surface": {
                        "Name": _name(sh),
                        "Shading Type": gtype,
                        "Shading Group": _name(grp),
                        "Gross Area": _q("Gross Area", sh.grossArea(), M2),
                        "Transmittance Schedule": _name(sched),
                    },
                    "Construction": cprops,
                }
                if info:
                    props.update(info["props"])
                self.objects.append({
                    "id": h,
                    "name": _name(sh),
                    "category": "ShadingSurface",
                    "collection": ["Shading", f"{gtype} Shading", _name(grp) or "Group"],
                    "level": info["level"] if info else None,
                    "room": None,
                    "host": None,
                    "groups": [],
                    "systems": [],
                    "material": self._pick_material("Shading", category, None, None, None, construction),
                    "properties": _clean(props),
                    "mesh": mesh,
                })

    def partitions(self):
        if not self.include_partitions:
            return
        for grp in _all(self.m, "InteriorPartitionSurfaceGroup"):
            space = _opt(grp.space())
            info = self._space_info(space)
            transform = grp.siteTransformation()
            for ip in grp.interiorPartitionSurfaces():
                mesh = _triangulate(ip.vertices(), [], transform)
                cprops, construction = self._construction_props(ip)
                h = _handle(ip)
                props = {
                    "OpenStudio": {"Object Type": "OS:InteriorPartitionSurface", "Handle": h},
                    "Interior Partition": {
                        "Name": _name(ip),
                        "Group": _name(grp),
                        "Gross Area": _q("Gross Area", ip.grossArea(), M2),
                        "Converted to Internal Mass": bool(ip.converttoInternalMass()),
                    },
                    "Construction": cprops,
                    **info["props"],
                }
                self.objects.append({
                    "id": h,
                    "name": _name(ip),
                    "category": "InteriorPartitionSurface",
                    "collection": info["collection"] + ["Interior Partitions"],
                    "level": info["level"],
                    "room": info["id"] if self.include_spaces else None,
                    "host": None,
                    "groups": info["groups"],
                    "systems": [],
                    "material": self._pick_material("Partition", "InteriorPartitionSurface", None,
                                                    info["zone"], info["space_type"], construction),
                    "properties": _clean(props),
                    "mesh": mesh,
                })

    # ── model-level properties ─────────────────────────────────────────────

    def model_properties(self) -> dict:
        b = self.building
        site = _unique(self.m, "Site")
        getters = [
            ("OpenStudio.Version", lambda: openstudio.openStudioLongVersion()),
            ("Building.Name", lambda: _name(b)),
            ("Building.Floor Area (m²)", lambda: b.floorArea()),
            ("Building.Conditioned Floor Area (m²)", lambda: _opt(b.conditionedFloorArea())),
            ("Building.Exterior Surface Area (m²)", lambda: b.exteriorSurfaceArea()),
            ("Building.Exterior Wall Area (m²)", lambda: b.exteriorWallArea()),
            ("Building.North Axis (deg)", lambda: b.northAxis()),
            ("Building.Standards Building Type", lambda: _opt(b.standardsBuildingType())),
            ("Building.Standards Template", lambda: _opt(b.standardsTemplate())),
            ("Building.Number of Stories", lambda: _opt(b.standardsNumberOfStories())),
            ("Building.Space Count", lambda: len(_all(self.m, "Space"))),
            ("Building.Thermal Zone Count", lambda: len(_all(self.m, "ThermalZone"))),
            ("Site.Name", lambda: _name(site)),
            ("Site.Latitude", lambda: site.latitude()),
            ("Site.Longitude", lambda: site.longitude()),
            ("Site.Elevation (m)", lambda: site.elevation()),
            ("Site.Time Zone", lambda: site.timeZone()),
        ]
        props = {}
        for key, get in getters:
            try:
                props[key] = get()
            except Exception:  # missing object / API difference: just skip the field
                pass
        try:
            wf = _opt(self.m.weatherFile())
            if wf is not None:
                props["Weather.City"] = wf.city()
                props["Weather.WMO"] = _opt(wf.wMONumber())
                url = _opt(wf.url())
                props["Weather.File"] = str(url) if url is not None else None
        except Exception as err:
            self.warnings.append(f"Weather file info skipped: {err}")
        try:
            czs = _unique(self.m, "ClimateZones")
            for cz in (czs.climateZones() if czs is not None else []):
                if cz.value():
                    props["Climate Zone"] = f"{cz.institution()} {cz.value()}"
                    break
        except Exception as err:
            self.warnings.append(f"Climate zone info skipped: {err}")
        out = {}
        for k, v in props.items():
            if v is None:
                continue
            if isinstance(v, float):
                if not math.isfinite(v):
                    continue
                v = round(v, 6)
            out[k] = v
        return out

    def run(self) -> dict:
        self.surfaces()
        self.partitions()
        self.shading()
        # spaces with no surfaces still get an object (useful for space-type audits)
        for sp in _all(self.m, "Space"):
            self._space_info(sp)

        scene_views = [
            {"name": "By Story / Space", "default": True, "keys": [["rel", 10]]},
            {"name": "By Thermal Zone", "default": False,
             "keys": [["eav", "properties.Thermal Zone.Name"]]},
            {"name": "By Surface Type", "default": False,
             "keys": [["eav", "properties.Surface.Surface Type"]]},
            {"name": "By Boundary Condition", "default": False,
             "keys": [["eav", "properties.Surface.Outside Boundary Condition"]]},
            {"name": "By Construction", "default": False,
             "keys": [["eav", "properties.Construction.Name"]]},
        ]
        return {
            "schema": PAYLOAD_SCHEMA,
            "units": "m",
            "producer": {"slug": "openstudio", "version": openstudio.openStudioVersion()},
            "model_name": _name(self.building) or "OpenStudio Model",
            "model_properties": self.model_properties(),
            "levels": list(self.levels.values()),
            "groups": list(self.groups.values()),
            "materials": list(self.materials.values()),
            "objects": self.objects,
            "scene_views": scene_views,
            "warnings": self.warnings,
        }


def extract_payload(model, color_by="Surface Type", include_shading=True,
                    include_partitions=True, include_spaces=True) -> dict:
    """Build the JSON-serialisable Speckle payload for an OpenStudio model."""
    return _Extractor(model, color_by, include_shading, include_partitions,
                      include_spaces).run()


def summarize(payload: dict) -> dict:
    counts: dict[str, int] = {}
    for o in payload["objects"]:
        counts[o["category"]] = counts.get(o["category"], 0) + 1
    return counts
