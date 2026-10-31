class ExportWindflowModel < OpenStudio::Measure::ModelMeasure
  def name
    return "Export Windflow Model"
  end

  def description
    return "Writes the model's geometry as a WindFlow model (.windflow.json) so its natural ventilation can be studied in WindFlow (https://github.com/Bijaykars/Windflow). Spaces become rooms, building stories become storeys, walls, floors, roofs and shading become solid obstacles, and windows and doors become openings. Operable windows are open; fixed windows and doors are closed unless the arguments say otherwise. The OpenStudio model is not changed."
  end

  def modeler_description
    return "Coordinates are OpenStudio building coordinates (m); NorthDeg = -Building North Axis. Each planar surface becomes a prism centred on its plane, as thick as the sum of its construction's layers (default thickness when unknown); air-boundary constructions are skipped and matched interior pairs are written once. Sub-surfaces in vertical walls become WindFlow openings (an oriented box: centroid on the wall plane, horizontal outward normal, in-plane bounding width and height, depth = host thickness). Skylights and sub-surfaces in sloped surfaces are left out with a warning. A window is open when it is an OperableWindow, when treat_all_windows_operable is true, or when it has an AirflowNetwork simple or detailed opening; doors (Door, GlassDoor, OverheadDoor) are open when treat_doors_as_openings is true or they have an AirflowNetwork opening (no door swing is modelled). An AirflowNetwork simple opening's discharge coefficient is passed through, and an opening factor below 1 narrows the opening about its centre. Rooms are each space's floor polygons in plan with ZMin at the floor and ZMax at the space's highest vertex. Infiltration is not exported: WindFlow treats closed openings as sealed."
  end

  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new
    output_path = OpenStudio::Measure::OSArgument.makeStringArgument("output_path", true)
    output_path.setDisplayName("WindFlow model file")
    output_path.setDescription("Where to write the .windflow.json file. A relative path is relative to the measure's run directory (in an OSW run, run/<step>/).")
    output_path.setDefaultValue("windflow_model.windflow.json")
    args << output_path
    treat_all_windows_operable = OpenStudio::Measure::OSArgument.makeBoolArgument("treat_all_windows_operable", true)
    treat_all_windows_operable.setDisplayName("Treat all windows as operable")
    treat_all_windows_operable.setDescription("When true, every window (FixedWindow as well as OperableWindow) is exported open. When false, only OperableWindow sub-surfaces (and windows with an AirflowNetwork opening) are open. Closed windows can still be opened in WindFlow.")
    treat_all_windows_operable.setDefaultValue(false)
    args << treat_all_windows_operable
    treat_doors_as_openings = OpenStudio::Measure::OSArgument.makeBoolArgument("treat_doors_as_openings", true)
    treat_doors_as_openings.setDisplayName("Treat doors as openings")
    treat_doors_as_openings.setDescription("When true, every door (Door, GlassDoor, OverheadDoor, exterior and interior) is exported as an open opening the size of the door; door swing is not modelled. When false, doors are exported closed (they can still be opened in WindFlow).")
    treat_doors_as_openings.setDefaultValue(false)
    args << treat_doors_as_openings
    default_wall_thickness = OpenStudio::Measure::OSArgument.makeDoubleArgument("default_wall_thickness", true)
    default_wall_thickness.setDisplayName("Default surface thickness (m)")
    default_wall_thickness.setDescription("Thickness used for a surface whose construction has no layers with thickness (or an implausible total, under 0.01 m or over 2 m). WindFlow needs solid walls; OpenStudio surfaces have none.")
    default_wall_thickness.setDefaultValue(0.2)
    args << default_wall_thickness
    include_shading = OpenStudio::Measure::OSArgument.makeBoolArgument("include_shading", true)
    include_shading.setDisplayName("Include shading surfaces")
    include_shading.setDescription("When true, site, building and space shading surfaces are exported as thin obstacles that block the wind.")
    include_shading.setDefaultValue(true)
    args << include_shading
    shading_thickness = OpenStudio::Measure::OSArgument.makeDoubleArgument("shading_thickness", true)
    shading_thickness.setDisplayName("Shading surface thickness (m)")
    shading_thickness.setDescription("Thickness given to shading surfaces when they are exported.")
    shading_thickness.setDefaultValue(0.05)
    args << shading_thickness
    return args
  end

  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    output_path = runner.getStringArgumentValue("output_path", user_arguments)
    treat_all_windows_operable = runner.getBoolArgumentValue("treat_all_windows_operable", user_arguments)
    treat_doors_as_openings = runner.getBoolArgumentValue("treat_doors_as_openings", user_arguments)
    default_wall_thickness = runner.getDoubleArgumentValue("default_wall_thickness", user_arguments)
    include_shading = runner.getBoolArgumentValue("include_shading", user_arguments)
    shading_thickness = runner.getDoubleArgumentValue("shading_thickness", user_arguments)
    # --- begin user logic ---
    require 'json'

    # Writes a WindFlow model (.windflow.json, the BuildingModel schema in WindFlow.Core/Simulation.cs) from this model.
    # The OpenStudio model itself is not changed. Coordinates are OpenStudio building coordinates (m); true north is
    # carried in NorthDeg. Surfaces have no thickness in OpenStudio, so each one becomes a solid slab centred on its
    # plane, as thick as its construction; openings sit mid-wall in those slabs and WindFlow carves the open ones.
    warnings = []
    warn = lambda do |msg|
      warnings << msg
      runner.registerWarning(msg)
    end

    rnd = lambda { |x| x.to_f.round(4) }
    vec3 = lambda { |x, y, z| { 'X' => rnd.call(x), 'Y' => rnd.call(y), 'Z' => rnd.call(z) } }
    pt = lambda { |p| vec3.call(p.x, p.y, p.z) }
    plain_id = lambda { |obj| obj.handle.to_s.delete('{}') }

    # Construction thickness (m): the sum of its layers; the default when unknown, massless or implausible.
    thickness_of = lambda do |planar|
      t = 0.0
      c = planar.construction
      if c.is_initialized && c.get.to_LayeredConstruction.is_initialized
        c.get.to_LayeredConstruction.get.layers.each { |layer| t += layer.thickness }
      end
      (t < 0.01 || t > 2.0) ? default_wall_thickness : t
    end

    is_air_boundary = lambda do |planar|
      c = planar.construction
      c.is_initialized && c.get.to_ConstructionAirBoundary.is_initialized
    end

    # A planar polygon (building coordinates) thickened to a prism, as a triangle soup.
    prism = lambda do |id, pts, thickness|
      normal = OpenStudio.getOutwardNormal(pts)
      return nil unless normal.is_initialized
      n = normal.get
      h = thickness / 2.0
      top = pts.map { |p| OpenStudio::Point3d.new(p.x + n.x * h, p.y + n.y * h, p.z + n.z * h) }
      bot = pts.map { |p| OpenStudio::Point3d.new(p.x - n.x * h, p.y - n.y * h, p.z - n.z * h) }
      verts = []
      tri = lambda { |a, b, c| verts.push(a, b, c) }

      # caps: triangulate in the face's own plane, fan as a fallback
      align = OpenStudio::Transformation.alignFace(pts)
      local = align.inverse * pts
      tris = OpenStudio.computeTriangulation(local, OpenStudio::Point3dVectorVector.new).to_a.map(&:to_a)
      if tris.empty?
        (1...(pts.size - 1)).each { |i| tris << [local[0], local[i], local[i + 1]] }
      end
      tris.each do |t|
        world = t.map { |p| align * p }
        off_top = world.map { |p| OpenStudio::Point3d.new(p.x + n.x * h, p.y + n.y * h, p.z + n.z * h) }
        off_bot = world.map { |p| OpenStudio::Point3d.new(p.x - n.x * h, p.y - n.y * h, p.z - n.z * h) }
        tri.call(*off_top)
        tri.call(off_bot[0], off_bot[2], off_bot[1])
      end
      # sides
      pts.size.times do |i|
        j = (i + 1) % pts.size
        tri.call(bot[i], bot[j], top[j])
        tri.call(bot[i], top[j], top[i])
      end
      { 'Id' => id, 'Furniture' => false, 'Vertices' => verts.map { |p| pt.call(p) }, 'Indices' => (0...verts.size).to_a }
    end

    building = model.getBuilding
    runner.registerInitialCondition("#{model.getSpaces.size} spaces, #{model.getSurfaces.size} surfaces, #{model.getSubSurfaces.size} sub-surfaces.")

    # ---- storeys ----
    space_z = {}   # space handle -> [zmin, zmax] in building coordinates
    model.getSpaces.each do |sp|
      zs = []
      sp.surfaces.each { |s| (sp.buildingTransformation * s.vertices).each { |p| zs << p.z } }
      space_z[sp.handle.to_s] = zs.empty? ? nil : [zs.min, zs.max]
    end

    storeys = []
    story_name = {}   # space handle -> storey name
    stories = model.getBuildingStorys.sort_by { |st| st.nominalZCoordinate.is_initialized ? st.nominalZCoordinate.get : 0.0 }
    unassigned = model.getSpaces.select { |sp| sp.buildingStory.empty? }
    groups = stories.map { |st| [st.name.to_s, st, st.spaces] }
    groups << ['Unassigned', nil, unassigned] unless unassigned.empty?
    warn.call("#{unassigned.size} space(s) have no building story; they are on a storey called 'Unassigned'.") unless unassigned.empty?
    groups.each do |name, st, spaces|
      ranges = spaces.map { |sp| space_z[sp.handle.to_s] }.compact
      next if ranges.empty? && st.nil?
      zmin = ranges.empty? ? 0.0 : ranges.map(&:first).min
      zmax = ranges.empty? ? zmin : ranges.map(&:last).max
      elev = (st && st.nominalZCoordinate.is_initialized) ? st.nominalZCoordinate.get : zmin
      height = (st && st.nominalFloortoFloorHeight.is_initialized) ? st.nominalFloortoFloorHeight.get : (zmax - zmin)
      storeys << { 'Id' => name, 'Name' => name, 'Elevation' => rnd.call(elev), 'Height' => rnd.call([height, 0.0].max), 'Analysed' => true }
      spaces.each { |sp| story_name[sp.handle.to_s] = name }
    end
    storeys.sort_by! { |s| s['Elevation'] }

    # ---- obstacles: walls, floors, roofs (and shading) ----
    obstacles = []
    skipped_air = 0
    model.getSurfaces.sort_by { |s| s.name.to_s }.each do |s|
      sp = s.space
      next if sp.empty?
      if is_air_boundary.call(s)
        skipped_air += 1
        next
      end
      adj = s.adjacentSurface
      next if adj.is_initialized && adj.get.handle.to_s < s.handle.to_s   # a matched pair is one wall
      pts = sp.get.buildingTransformation * s.vertices
      m = prism.call(s.name.to_s, pts, thickness_of.call(s))
      m ? obstacles << m : warn.call("Surface '#{s.name}' has no valid outward normal; it was left out.")
    end
    runner.registerInfo("#{skipped_air} air-boundary surface(s) were left out (air passes through them).") if skipped_air > 0

    if include_shading
      model.getShadingSurfaces.sort_by { |s| s.name.to_s }.each do |s|
        grp = s.shadingSurfaceGroup
        next if grp.empty?
        pts = grp.get.buildingTransformation * s.vertices
        m = prism.call(s.name.to_s, pts, shading_thickness)
        obstacles << m if m
      end
    end

    # ---- openings ----
    openings = []
    counts = Hash.new(0)
    model.getSubSurfaces.sort_by { |ss| ss.name.to_s }.each do |ss|
      sp = ss.space
      surf = ss.surface
      next if sp.empty? || surf.empty?
      adj = ss.adjacentSubSurface
      next if adj.is_initialized && adj.get.handle.to_s < ss.handle.to_s   # a matched pair is one opening
      type = ss.subSurfaceType
      kind = case type
             when 'FixedWindow', 'OperableWindow' then 0
             when 'Door', 'GlassDoor', 'OverheadDoor' then 1
             end
      if kind.nil?
        warn.call("#{type} '#{ss.name}' was left out: WindFlow openings are in walls, so its roof or ceiling stays closed.")
        next
      end
      pts = sp.get.buildingTransformation * ss.vertices
      normal = OpenStudio.getOutwardNormal(pts)
      unless normal.is_initialized
        warn.call("#{type} '#{ss.name}' has no valid outward normal; it was left out.")
        next
      end
      n = normal.get
      hl = Math.sqrt(n.x**2 + n.y**2)
      if hl < 0.95
        warn.call("#{type} '#{ss.name}' is not in a vertical wall (tilt #{(Math.asin([n.z.abs, 1.0].min) * 180 / Math::PI).round} deg from vertical); it was left out and its host stays closed.")
        next
      end
      hx = n.x / hl
      hy = n.y / hl
      ux = -hy
      uy = hx
      us = pts.map { |p| p.x * ux + p.y * uy }
      zs = pts.map(&:z)
      width = us.max - us.min
      height = zs.max - zs.min
      c = OpenStudio.getCentroid(pts)
      next if c.empty? || width < 1e-3 || height < 1e-3
      c = c.get
      d = c.x * hx + c.y * hy        # the plane's offset along the normal
      umid = (us.max + us.min) / 2.0
      area = ss.grossArea
      if area < 0.9 * width * height
        warn.call("#{type} '#{ss.name}' is not rectangular (#{(100 * area / (width * height)).round} % of its bounding box); WindFlow uses the bounding box.")
      end

      # open / closed, and the airflow-network opening if there is one
      afn_open = false
      cd = nil
      factor = 1.0
      afn = ss.airflowNetworkSurface
      if afn.is_initialized
        comp = afn.get.leakageComponent
        if comp.is_initialized
          so = comp.get.to_AirflowNetworkSimpleOpening
          dop = comp.get.to_AirflowNetworkDetailedOpening
          afn_open = so.is_initialized || dop.is_initialized
          cd = so.get.dischargeCoefficient if so.is_initialized
        end
        factor = afn.get.windowDoorOpeningFactorOrCrackFactor if afn_open
      end
      is_open = if kind == 0
                  type == 'OperableWindow' || treat_all_windows_operable || afn_open
                else
                  treat_doors_as_openings || afn_open
                end
      # an airflow-network opening factor below 1 opens part of the sash: narrow it about its centre
      if is_open && factor > 0.0 && factor < 1.0
        width *= factor
        warn.call("#{type} '#{ss.name}': airflow-network opening factor #{factor.round(2)}, so it is open #{(width).round(2)} m wide.") if width < 0.1
      end

      counts["#{type}#{is_open ? ' open' : ' closed'}"] += 1
      openings << {
        'Id' => plain_id.call(ss), 'Name' => ss.name.to_s, 'Level' => story_name[sp.get.handle.to_s] || '',
        'Kind' => kind, 'IsOpen' => is_open,
        'Center' => vec3.call(ux * umid + hx * d, uy * umid + hy * d, (zs.max + zs.min) / 2.0),
        'Normal' => vec3.call(hx, hy, 0.0),
        'Width' => rnd.call(width), 'Height' => rnd.call(height), 'Depth' => rnd.call(thickness_of.call(surf.get)),
        'SideA' => 0, 'SideB' => 0, 'DischargeCoefficient' => cd.nil? ? nil : rnd.call(cd)
      }
    end

    # ---- rooms: each space's floor polygons in plan ----
    rooms = []
    model.getSpaces.sort_by { |sp| sp.name.to_s }.each do |sp|
      floors = sp.surfaces.select { |s| s.surfaceType == 'Floor' }
      zr = space_z[sp.handle.to_s]
      if floors.empty? || zr.nil?
        warn.call("Space '#{sp.name}' has no floor surface; it has no room in WindFlow.")
        next
      end
      tf = sp.buildingTransformation
      loops = floors.map { |s| (tf * s.vertices).map { |p| { 'X' => rnd.call(p.x), 'Y' => rnd.call(p.y) } } }
      floor_z = floors.map { |s| (tf * s.vertices).map(&:z).min }.min
      rooms << {
        'Id' => plain_id.call(sp), 'Name' => sp.name.to_s, 'Level' => story_name[sp.handle.to_s] || '',
        'Loops' => loops, 'ZMin' => rnd.call(floor_z), 'ZMax' => rnd.call(zr[1]),
        'Occupants' => sp.numberOfPeople.round, 'VoxelDerived' => false, 'DetectedVolume' => 0
      }
    end

    if obstacles.empty?
      runner.registerError('The model has no surfaces in spaces, so there is no geometry for WindFlow.')
      return false
    end

    # EnergyPlus North Axis turns the building +Y clockwise from true north, so true north is that far anticlockwise of +Y.
    north_deg = ((-building.northAxis) % 360.0) + 0.0
    ground_z = storeys.empty? ? 0.0 : storeys.first['Elevation']
    wf = {
      'Name' => building.name.to_s, 'NorthDeg' => rnd.call(north_deg), 'GroundZ' => rnd.call(ground_z),
      'Storeys' => storeys, 'Obstacles' => obstacles, 'Openings' => openings, 'Rooms' => rooms,
      'Sources' => [], 'Env' => { 'OutdoorTemperature' => 20, 'IndoorTemperature' => 22, 'RelativeHumidity' => 50, 'OutdoorCo2' => 420 },
      'Heat' => [], 'Contaminants' => [], 'Warnings' => warnings
    }

    path = File.expand_path(output_path.to_s.strip.empty? ? 'windflow_model.windflow.json' : output_path.to_s.strip)
    File.write(path, JSON.generate(wf))
    runner.registerValue('windflow_openings_open', openings.count { |o| o['IsOpen'] })
    runner.registerValue('windflow_openings_closed', openings.count { |o| !o['IsOpen'] })
    runner.registerInfo("Openings: #{counts.sort.map { |k, v| "#{v} #{k}" }.join(', ')}.") unless counts.empty?
    runner.registerFinalCondition("Wrote #{path}: #{storeys.size} storeys, #{rooms.size} rooms, #{obstacles.size} obstacles, #{openings.size} openings (#{openings.count { |o| o['IsOpen'] }} open). The OpenStudio model was not changed.")
    # --- end user logic ---
    return true
  end
end

ExportWindflowModel.new.registerWithApplication
