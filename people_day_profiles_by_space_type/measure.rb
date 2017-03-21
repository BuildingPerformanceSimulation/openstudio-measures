# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class PeopleDayProfilesBySpaceType < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "People Day Profiles by Space Type"
  end

  # human readable description
  def description
    return "Creates a stacked bar plot of the number of the poeple in the building throughout the day, for slected days."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This will register as not applicatlbe if any schedules used for people are not ruleset schedules. This operates in input data not, sql results. First pass will just look at default profiles, future version can find unique profile combinations and plot them each."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.getSpaces.size} spaces.")

    # hash to store running totals by space type
    # todo - will this be a space in some cases, in which case I need to get the space type for the space. I don't want the space in the hash
    space_types = {} # for each space type have one values has

    # frequency in timesteps per 24 hours
    frequency = 24

    # loop through people objects
    model.getPeoples.each do |people_inst|
      next if not people_inst.spaceType.is_initialized
      next if people_inst.spaceType.get.floorArea == 0.0
      space_type = people_inst.spaceType.get
      num_people = people_inst.getNumberOfPeople(people_inst.spaceType.get.floorArea)
      puts "#{people_inst.name} has #{num_people} people."
      if people_inst.numberofPeopleSchedule.is_initialized
        schedule = people_inst.numberofPeopleSchedule.get
        if schedule.to_ScheduleRuleset.is_initialized
          schedule = schedule.to_ScheduleRuleset.get
          puts "Schedule is #{schedule.name}"
          profile = schedule.defaultDaySchedule
          values = {} # key is hours value is fractional value
          frequency.times do |i|

              fractional_hours = i / 1.0

              hr = fractional_hours.truncate
              min = ((fractional_hours - fractional_hours.truncate) * 60.0).truncate

              time = OpenStudio::Time.new(0, hr, min, 0)
              values[fractional_hours.round(2)] = profile.getValue(time)

          end

          # populate space type hash
          if space_types.has_key?(nil) # todo - update this

        else
          runner.registerWarning("Skipping #{people_inst.name}, it doesn't have a ruleset schedule assigned, can't calculate values.")
        end
      else
        runner.registerWarning("Skipping #{people_inst.name}, it doesn't have a schedule assigned, can't calculate values.")
      end
    end

    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.getSpaces.size} spaces.")

    return true

  end
  
end

# register the measure to be used by the application
PeopleDayProfilesBySpaceType.new.registerWithApplication
