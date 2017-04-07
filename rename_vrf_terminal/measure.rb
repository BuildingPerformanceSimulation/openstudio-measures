# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class RenameVRFTerminal < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Rename VRF Terminal"
  end

  # human readable description
  def description
    return "New new is combination of VRF system name and thermal zone name. This doesn't change the performance of the system in any way, just the name of VRF terminal objects"
  end

  # human readable description of modeling approach
  def modeler_description
    return "Could add argumntes to provide more control at later date."
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
    runner.registerInitialCondition("The building started with #{model.getZoneHVACTerminalUnitVariableRefrigerantFlows.size} VRF terminals.")

    # loop through VRF systems
    model.getAirConditionerVariableRefrigerantFlows.each do |vrf_sys|

      # loop through current terminals on system
      vrf_sys.terminals.each do |terminal|

        # get thermal zone name if assigned
        if terminal.thermalZone.is_initialized
          thermal_zone_name = terminal.thermalZone.get.name
        else
          thermal_zone_name = ""
        end

        # rename terminal
        orig_name = terminal.name
        target_name = "#{vrf_sys.name} - #{thermal_zone_name}"
        terminal.setName(target_name)
        runner.registerInfo("Renamed #{orig_name} to #{target_name}")

      end
    end

    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.getZoneHVACTerminalUnitVariableRefrigerantFlows.size} VRF terminals.")

    return true

  end
  
end

# register the measure to be used by the application
RenameVRFTerminal.new.registerWithApplication
