# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class ReportEffectiveNumberOfSpacesAndAvgSpaceSizePerSpaceType < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Report Effective Number of Spaces and Avg Space Size per space type"
  end

  # human readable description
  def description
    return "Quick measure to report the effective number of spaces, along with average and total floor area for each space type.."
  end

  # human readable description of modeling approach
  def modeler_description
    return "The difference between actual spaces and effective spaces takes into account the zone multipliers. The goal was to get average floor area assuming that each space represents a room vs. a collection of rooms. This was used to help determine average space sizes of different space types from the prototype buildings. In some cases I had to manaually adjust for where a space didn't map to a single room."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)


    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.getSpaces.size} spaces.")

    model.getSpaceTypes.each do |space_type|
    	count = 0
    	space_type.spaces.each do |space|
			count += space.multiplier
    	end

	avg_si = space_type.floorArea/count.to_f
	avg_ip = OpenStudio::convert(avg_si,'m^2','ft^2').get.round(2)
	total_ip = OpenStudio::convert(space_type.floorArea,'m^2','ft^2').get.round(2)

	runner.registerInfo("#{space_type.name} has #{count} spaces, with average area of #{avg_ip} ft^2. Total is #{total_ip}")

	end

    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.getSpaces.size} spaces.")

    return true

  end
  
end

# register the measure to be used by the application
ReportEffectiveNumberOfSpacesAndAvgSpaceSizePerSpaceType.new.registerWithApplication
