# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class GetLatLongFromGroundExposedFloors < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Get Lat Long from ground exposed floors"
  end

  # human readable description
  def description
    return "This is quick utility to gather geometry needed for geojson"
  end

  # human readable description of modeling approach
  def modeler_description
    return "When have existing OSM wanted to be able to grab geometry from model vs. trying to enter on website. This is useful when there is no built   structures yet to use as reference on the website."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # lat arg
    lat = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("lat", true)
    lat.setDisplayName("Latitude")
    lat.setDefaultValue(39.7392000000)
    args << lat

    # long arg
    lon = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("lon", true)
    lon.setDisplayName("Longitude")
    lon.setDefaultValue(-104.9903000000)
    args << lon

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    lat = runner.getDoubleArgumentValue("lat", user_arguments)
    lon = runner.getDoubleArgumentValue("lon", user_arguments)

    # Identity matrix for setting space origins
    m = OpenStudio::Matrix.new(4,4,0)
    m[0,0] = 1
    m[1,1] = 1
    m[2,2] = 1
    m[3,3] = 1

    # target origin for all spaces
    m[0,3] = 0.0
    m[1,3] = 0.0
    m[2,3] = 0.0

    # todo - bad idea to change model, change this in temp model if necessary
    # space transformation
    model.getSpaces.each do |space|
      space.changeTransformation(OpenStudio::Transformation.new(m))
    end

    # loop through surfaces
    floor_polygons = []
    starting_footprint_area = 0.0
    model.getSurfaces.each do |surface|
      next if not (surface.outsideBoundaryCondition == "Ground" || surface.outsideBoundaryCondition == "OtherSideCoefficients")
      next if not surface.surfaceType == "Floor"
      runner.registerInfo("#{surface.name} is a ground exposed floor")
      starting_footprint_area += surface.grossArea

      # add to polygons
      new_floor_polygon = []
      surface.vertices.each do |vertex|
        new_floor_polygon << OpenStudio::Point3d.new(vertex.x, vertex.y, 0.0)
      end
      floor_polygons << new_floor_polygon

      # loop through vertices
      vertex_array_lat_long = []
      surface.vertices.each do |vertex|
        point_lat_lon = OpenStudio::PointLatLon.new(lat, lon, 0.0)
        vertex_array_lat_long << point_lat_lon.fromLocalCartesian(vertex)
      end

      # if we want to see lat long of space surfaces
      vertex_array_lat_long.each do |i|
        #puts "[#{i.lon},#{i.lat}],"
      end

    end

    # report initial condition of model
    starting_footprint_area_ip =  OpenStudio::toNeatString(OpenStudio::convert(starting_footprint_area,"m^2","ft^2").get,0,true)
    runner.registerInitialCondition("Model has #{floor_polygons.size} ground exposed floor surfaces, with an area of #{starting_footprint_area_ip} (ft^2).")

    # Combine the polygons
    combined_polygons = OpenStudio.joinAll(floor_polygons, 0.01)

    # todo - no error handling for problem geometry like enclosed courtyard

    # note - not setup for non story multipliers on ground floor

    # temp code to work around bug in joinAll
    floor_polygons2 = floor_polygons
    floor_polygons.size.times do |i|
      floor_polygons2 << combined_polygons.first
      combined_polygons = OpenStudio.joinAll(floor_polygons2.rotate(i), 0.01)
    end

    combined_polygons.each do |polygon|

      # make temp surface
      temp_space = OpenStudio::Model::Space.new(model)
      temp_surf = OpenStudio::Model::Surface.new(polygon, model)
      temp_surf.setSpace(temp_space)
      footprint_vertex_array_lat_long = []
      temp_surf.vertices.each do |vertex|
        point_lat_lon = OpenStudio::PointLatLon.new(lat, lon, 0.0)
        point_lat_lon.fromLocalCartesian(vertex)
        footprint_vertex_array_lat_long << point_lat_lon.fromLocalCartesian(vertex)
      end

      geometry_text = []
      footprint_vertex_array_lat_long.each do |i|
        string = "[#{i.lon},#{i.lat}]"
        puts "#{string},"
        geometry_text << string
      end

      # report on resulting polygon
      area_ip =  OpenStudio::toNeatString(OpenStudio::convert(temp_surf.grossArea,"m^2","ft^2").get,0,true)
      runner.registerInfo("Adding surface with area of #{area_ip} (ft^2).")
      runner.registerInfo(geometry_text.join(","))

    end

    # report final condition of model
    runner.registerFinalCondition("Ground exposed floors reduced to #{combined_polygons.size} surfaces.")

    puts model.getBuilding.floorArea

    return true

  end
  
end

# register the measure to be used by the application
GetLatLongFromGroundExposedFloors.new.registerWithApplication
