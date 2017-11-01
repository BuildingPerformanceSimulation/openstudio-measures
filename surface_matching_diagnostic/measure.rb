#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#start the measure
class SurfaceMatchingDiagnostic < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Surface Matching Diagnostic"
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # bool for removing duplicate points in a surface
    remove_duplicate_vertices = OpenStudio::Ruleset::OSArgument::makeBoolArgument("remove_duplicate_vertices",true)
    remove_duplicate_vertices.setDisplayName("Remove Duplicate Vertices in the Same Surface")
    remove_duplicate_vertices.setDefaultValue(true)
    args << remove_duplicate_vertices

    # bool for removing collinear points in a surface
    remove_collinear_vertices = OpenStudio::Ruleset::OSArgument::makeBoolArgument("remove_collinear_vertices",true)
    remove_collinear_vertices.setDisplayName("Remove Collinear Vertices in the Same Surface.")
    remove_collinear_vertices.setDefaultValue(true)
    args << remove_collinear_vertices

    # bool for removing duplicate surfaces in a space (should be done after remove duplicate and collinear points)
    remove_duplicate_surfaces = OpenStudio::Ruleset::OSArgument::makeBoolArgument("remove_duplicate_surfaces",true)
    remove_duplicate_surfaces.setDisplayName("Remove Duplicate Surfaces")
    remove_duplicate_surfaces.setDefaultValue(true)
    args << remove_duplicate_surfaces

    #make an argument for intersect surfaces
    intersect_surfaces = OpenStudio::Ruleset::OSArgument::makeBoolArgument("intersect_surfaces",true)
    intersect_surfaces.setDisplayName("Intersect Surfaces")
    intersect_surfaces.setDefaultValue(true)
    args << intersect_surfaces

    #make an argument for match surfaces
    match_surfaces = OpenStudio::Ruleset::OSArgument::makeBoolArgument("match_surfaces",true)
    match_surfaces.setDisplayName("Match Surfaces")
    match_surfaces.setDefaultValue(true)
    args << match_surfaces

    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #assign the user inputs to variables
    remove_duplicate_vertices = runner.getBoolArgumentValue("remove_duplicate_vertices",user_arguments)
    remove_collinear_vertices = runner.getBoolArgumentValue("remove_collinear_vertices",user_arguments)
    remove_duplicate_surfaces = runner.getBoolArgumentValue("remove_duplicate_surfaces",user_arguments)
    intersect_surfaces = runner.getBoolArgumentValue("intersect_surfaces",user_arguments)
    match_surfaces = runner.getBoolArgumentValue("match_surfaces",user_arguments)

    # matched surface counter
    initialMatchedSurfaceCounter = 0
    surfaces = model.getSurfaces
    surfaces.each do |surface|
      if surface.outsideBoundaryCondition == "Surface"
        next if not surface.adjacentSurface.is_initialized # don't count as matched if boundary condition is right but no matched object
        initialMatchedSurfaceCounter += 1
      end
    end

    #reporting initial condition of model
    runner.registerInitialCondition("The initial model has #{initialMatchedSurfaceCounter} matched surfaces.")

    # removing duplicate points in a surface
    if remove_duplicate_vertices
      model.getPlanarSurfaces.each do |surface|
        array = []
        vertices = surface.vertices
        vertices.each do |vertex|
          if array.include?(vertex)
            # create a new set of vertices
            new_vertices = OpenStudio::Point3dVector.new
            array_b = []
            surface.vertices.each do |vertex_b|
              next if array_b.include?(vertex_b)
              new_vertices << vertex_b
              array_b << vertex_b
            end
            surface.setVertices(new_vertices)
            num_removed = vertices.size - surface.vertices.size
            runner.registerWarning("#{surface.name} has duplicate vertices. Started with #{vertices.size} verticies, removed #{num_removed}.")
          else
            array << vertex
          end
        end
      end
    end

    # remove collinear points in a surface
    if remove_collinear_vertices
      model.getPlanarSurfaces.each do |surface|
        new_vertices = OpenStudio.removeCollinear(surface.vertices)
        starting_count = surface.vertices.size
        final_count = new_vertices.size
        if final_count < starting_count
          runner.registerWarning("Removing #{starting_count - final_count} colliner vertices from #{surface.name}.")
          surface.setVertices(new_vertices)
        end
      end
    end

    # remove duplicate surfaces in a space (should be done after remove duplicate and collinear points)
    if remove_duplicate_surfaces
      model.getSpaces.each do |space|

        # secondary array to compare against
        surfaces_b = space.surfaces.sort

        space.surfaces.sort.each do |surface_a|

          # delete from secondary array
          surfaces_b.delete(surface_a)

          surfaces_b.each do |surface_b|
            next if surface_a == surface_b # dont' test against same surface
            if surface_a.equalVertices(surface_b)
              runner.registerWarning("#{surface_a.name} and #{surface_b.name} in #{space.name} have duplicate geometry, removing #{surface_b.name}.")
              surface_b.remove
            elsif surface_a.reverseEqualVertices(surface_b)
              # todo - add logic to determine which face naormal is reversed and which is correct
              runner.registerWarning("#{surface_a.name} and #{surface_b.name} in #{space.name} have reversed geometry, removing #{surface_b.name}.")
              surface_b.remove
            end

          end

        end
      end
    end

    # get starting time
    starting_time =  Time.now
    counter = 0

    # secondary array of spaces that we can remove items from once they have gone through in primary loop
    spaces_b = model.getSpaces.sort

    # looping through vector of each space
    model.getSpaces.sort.each do |space_a|

      runner.registerInfo("Intersecting and matching surfaces for #{space_a.name}.")

      # delete from secondary array
      spaces_b.delete(space_a)

      # todo - update this to remove spaces already tested from space_a from the second loop, this will cut number of combinations in half.
      spaces_b.each do |space_b|

=begin
        # special use case ot allow skipping of know bad combinations
        if space_a.name.to_s.include?("TZ45-3") && space.name.to_s.include?("TZ46-101")
          # for whatever reason ruby hangs here and won't abort or exit
          puts "skipping #{space_a.name} and #{space.name}"
        elsif space_a.name.to_s.include?("TZ46-54") && space.name.to_s.include?("TZ47-5002")
          # [BUG] Segmentation fault at 0x00000000000008
          puts "skipping #{space_a.name} and #{space.name}"
        else
          # intersect and match
        end
=end

        #runner.registerInfo("Intersecting and matching surfaces between #{space_a.name} and #{space.name}")
        spaces = OpenStudio::Model::SpaceVector.new
        spaces << space_a
        spaces << space_b

        if intersect_surfaces then OpenStudio::Model.intersectSurfaces(spaces) end
        if match_surfaces then OpenStudio::Model.matchSurfaces(spaces) end

        # reset and log
        spaces = nil
        current_time = Time.now
        puts "#{(current_time-starting_time)} Duration for last step, #{counter}"
        starting_time = current_time
        counter = counter + 1
      end
    end

    # matched surface counter
    finalMatchedSurfaceCounter = 0
    surfaces.each do |surface|
      if surface.outsideBoundaryCondition == "Surface"
        finalMatchedSurfaceCounter += 1
      end
    end

    #reporting final condition of model
    runner.registerFinalCondition("The final model has #{finalMatchedSurfaceCounter} matched surfaces.")

    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
SurfaceMatchingDiagnostic.new.registerWithApplication