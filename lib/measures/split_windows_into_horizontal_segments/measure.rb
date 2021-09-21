# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class SplitWindowsIntoHorizontalSegments < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Split Windows Into Horizontal Segments'
  end

  # human readable description
  def description
    return 'This will replace all exterior rectangular windows with a series of stacked horizontal segments of the same area. The number of segments is determined by a user argument. Note that the resulting windows are adjacent and may result in odd behavior in various interfaces that expect sub surfaces to have small gap between them.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'This can be modifed to alter a sub-set of the windows by filtering by sub urface type, construction, name, or orientation. '
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # the number of horizontal segments
    segments = OpenStudio::Measure::OSArgument.makeIntegerArgument('segments', true)
    segments.setDisplayName('Number of Horizontal Segments')
    segments.setDescription('This will split existing rectangular exterior windows into specified number of equal horizontal segments.')
    segments.setDefaultValue(4)
    args << segments

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
    segments = runner.getIntegerArgumentValue('segments', user_arguments)

    # check the space_name for reasonableness
    if segments < 1
      runner.registerError('Please specify a positive integer for number of segments.')
      return false
    end

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.getSubSurfaces.size} sub surfaces.")

    # loop through sub-surfaces
    model.getSubSurfaces.each do |ss|

      # only split if exterior
      next if not ss.outsideBoundaryCondition == "Outdoors"

      # see if surface is rectangular (only checking non rotated on vertical wall)
      x_vals = []
      y_vals = []
      z_vals = []
      vertices = ss.vertices
      vertices.each do |vertex|
        # initialize new vertex to old vertex
        # rounding values to address tolerance issue 10 digits digits in
        x_vals <<  vertex.x.round(8)
        y_vals << vertex.y.round(8)
        z_vals << vertex.z.round(8)
      end
      next if not x_vals.uniq.size <= 2 && y_vals.uniq.size <= 2 && z_vals.uniq.size <= 2 && x_vals.size == 4

      # store initial min and max z and height
      z_min = z_vals.min
      z_max = z_vals.max
      orig_height = z_max - z_min
      segment_height = orig_height/segments.to_f

      # modify window height
      new_vertices = OpenStudio::Point3dVector.new
      vertices.each do |vertex|
        x = vertex.x
        y = vertex.y
        if vertex.z == z_min
          z = vertex.z
        else
          z = z_min + segment_height
        end
        new_vertices << OpenStudio::Point3d.new(x, y, z)
      end
      ss.setVertices(new_vertices)

      # clone and move copies of window
      (segments -1).times do |i|
        new_segment = ss.clone(model).to_SubSurface.get
        new_segment.setName("#{ss.name} seg #{i+2}")

        # move cloned surface up
        seg_vertices = OpenStudio::Point3dVector.new
        vertices.each do |vertex|
          x = vertex.x
          y = vertex.y
          if vertex.z == z_min
            z = vertex.z + segment_height * (i + 1)
          else
            z = z_min + segment_height * (i + 2)
          end
          seg_vertices << OpenStudio::Point3d.new(x, y, z)
        end
        new_segment.setVertices(seg_vertices)
      end

    end

    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.getSubSurfaces.size} sub sufaces.")

    return true
  end
end

# register the measure to be used by the application
SplitWindowsIntoHorizontalSegments.new.registerWithApplication
