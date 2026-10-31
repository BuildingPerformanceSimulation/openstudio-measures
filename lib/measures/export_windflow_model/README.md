

###### (Automatically generated documentation)

# Export Windflow Model

## Description
Writes the model's geometry as a WindFlow model (.windflow.json) so its natural ventilation can be studied in WindFlow (https://github.com/Bijaykars/Windflow). Spaces become rooms, building stories become storeys, walls, floors, roofs and shading become solid obstacles, and windows and doors become openings. Operable windows are open; fixed windows and doors are closed unless the arguments say otherwise. The OpenStudio model is not changed.

## Modeler Description
Coordinates are OpenStudio building coordinates (m); NorthDeg = -Building North Axis. Each planar surface becomes a prism centred on its plane, as thick as the sum of its construction's layers (default thickness when unknown); air-boundary constructions are skipped and matched interior pairs are written once. Sub-surfaces in vertical walls become WindFlow openings (an oriented box: centroid on the wall plane, horizontal outward normal, in-plane bounding width and height, depth = host thickness). Skylights and sub-surfaces in sloped surfaces are left out with a warning. A window is open when it is an OperableWindow, when treat_all_windows_operable is true, or when it has an AirflowNetwork simple or detailed opening; doors (Door, GlassDoor, OverheadDoor) are open when treat_doors_as_openings is true or they have an AirflowNetwork opening (no door swing is modelled). An AirflowNetwork simple opening's discharge coefficient is passed through, and an opening factor below 1 narrows the opening about its centre. Rooms are each space's floor polygons in plan with ZMin at the floor and ZMax at the space's highest vertex. Infiltration is not exported: WindFlow treats closed openings as sealed.

## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### WindFlow model file
Where to write the .windflow.json file. A relative path is relative to the measure's run directory (in an OSW run, run/<step>/).
**Name:** output_path,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false


### Treat all windows as operable
When true, every window (FixedWindow as well as OperableWindow) is exported open. When false, only OperableWindow sub-surfaces (and windows with an AirflowNetwork opening) are open. Closed windows can still be opened in WindFlow.
**Name:** treat_all_windows_operable,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false


### Treat doors as openings
When true, every door (Door, GlassDoor, OverheadDoor, exterior and interior) is exported as an open opening the size of the door; door swing is not modelled. When false, doors are exported closed (they can still be opened in WindFlow).
**Name:** treat_doors_as_openings,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false


### Default surface thickness (m)
Thickness used for a surface whose construction has no layers with thickness (or an implausible total, under 0.01 m or over 2 m). WindFlow needs solid walls; OpenStudio surfaces have none.
**Name:** default_wall_thickness,
**Type:** Double,
**Units:** ,
**Required:** true,
**Model Dependent:** false


### Include shading surfaces
When true, site, building and space shading surfaces are exported as thin obstacles that block the wind.
**Name:** include_shading,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false


### Shading surface thickness (m)
Thickness given to shading surfaces when they are exported.
**Name:** shading_thickness,
**Type:** Double,
**Units:** ,
**Required:** true,
**Model Dependent:** false






