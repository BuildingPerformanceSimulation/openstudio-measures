# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# @author Matt Steen, Ambient Energy

# start the measure
class RemoveHVACSystems < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Remove HVAC Systems"
  end

  # human readable description
  def description
    return "TODO"
  end

  # human readable description of modeling approach
  def modeler_description
    return "TODO"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #TODO add bools for SHW, EFs, etc.
    

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

    # check the space_name for reasonableness

    # get model objects 
    air_loops = model.getAirLoopHVACs
    plant_loops = model.getPlantLoops
    zones = model.getThermalZones

    # initial condition
    runner.registerInfo("Initial Condition: #{plant_loops.size} Plant Loops")
    runner.registerInfo("Initial Condition: #{air_loops.size} Air Loops")
    runner.registerInfo("If zone equipment is present, it will be removed")
    
    # variables
    zone_equipment_count = 0
    
    # do stuff
    plant_loops.each do |plant_loop|
      plant_loop.remove
    end

    air_loops.each do |air_loop|
      air_loop.remove
    end

    zones.each do |zone|

      zone.equipment.each do |zone_equipment|
        zone_equipment.remove
        zone_equipment_count += 1
      end

    end

    # final condition
    runner.registerInfo("Final Condition: #{model.getPlantLoops.size} Plant Loops")
    runner.registerInfo("Final Condition: #{model.getAirLoopHVACs.size} Air Loops")
    runner.registerInfo("Final Condition: #{zone_equipment_count} Zone Equipment Removed")

    return true

  end
  
end

# register the measure to be used by the application
RemoveHVACSystems.new.registerWithApplication
