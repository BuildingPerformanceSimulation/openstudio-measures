# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# @author Matt Steen, Ambient Energy
# @author Matthew Dahlhausen, National Renewable Energy Laboratory

# start the measure
class RemoveHVACSystems < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return 'Remove HVAC Systems'
  end

  # human readable description
  def description
    return 'This measure removes HVAC systems from an OpenStudio model.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'The user can optionally selected to remove air loops, plant loops, zone hvac, vrf systems, and curves from the model.  By default all systems except water systems and zone exhaust fans are removed.'
  end

  ##########################################
  # methods copied from openstudio-standards

  # Remove all air loops in model
  def remove_air_loops(model)
    model.getAirLoopHVACs.each(&:remove)
    return model
  end

  # Remove plant loops in model except those used for service hot water
  def remove_plant_loops(model, runner)
    plant_loops = model.getPlantLoops
    plant_loops.each do |plant_loop|
      shw_use = false
      plant_loop.demandComponents.each do |component|
        if component.to_WaterUseConnections.is_initialized or component.to_CoilWaterHeatingDesuperheater.is_initialized
          shw_use = true
          runner.registerInfo("#{plant_loop.name} is used for SHW or refrigeration heat reclaim and will not be removed.")
          break
        end
      end
      plant_loop.remove unless shw_use
    end
    return model
  end

  # Remove all plant loops in model including those used for service hot water
  def remove_all_plant_loops(model)
    model.getPlantLoops.each(&:remove)
    return model
  end

  # Remove VRF units
  def remove_vrf(model)
    model.getAirConditionerVariableRefrigerantFlows.each(&:remove)
    model.getZoneHVACTerminalUnitVariableRefrigerantFlows.each(&:remove)
    return model
  end

  # Remove zone equipment except for exhaust fans
  def remove_zone_equipment(model, runner)
    zone_equipment_removed_count = 0
    model.getThermalZones.each do |zone|
      zone.equipment.each do |equipment|
        if equipment.to_FanZoneExhaust.is_initialized
          runner.registerInfo("#{equipment.name} is a zone exhaust fan and will not be removed.")
        else
          equipment.remove
          zone_equipment_removed_count += 1
        end
      end
    end
    runner.registerInfo("#{zone_equipment_removed_count} zone equipment removed.")
    return model
  end

  # Remove all zone equipment including exhaust fans
  def remove_all_zone_equipment(model, runner)
    zone_equipment_removed_count = 0
    model.getThermalZones.each do |zone|
      zone.equipment.each do |equipment|
        equipment.remove
        zone_equipment_removed_count += 1
      end
    end
    runner.registerInfo("#{zone_equipment_removed_count} zone equipment removed.")
    return model
  end

  # Remove unused performance curves
  def remove_unused_curves(model)
    model.getCurves.each do |curve|
      if curve.directUseCount == 0
        model.removeObject(curve.handle)
      end
    end
    return model
  end

  # Remove HVAC equipment except for service hot water loops and zone exhaust fans
  def remove_HVAC(model, runner)
    remove_air_loops(model)
    remove_plant_loops(model, runner)
    remove_vrf(model)
    remove_zone_equipment(model, runner)
    remove_unused_curves(model)
    return model
  end

  # Remove all HVAC equipment including service hot water loops and zone exhaust fans
  def remove_all_HVAC(model)
    remove_air_loops(model)
    remove_all_plant_loops(model)
    remove_vrf(model)
    remove_all_zone_equipment(model, runner)
    remove_unused_curves(model)
    return model
  end
  ##########################################

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # bool for removing air loops
    remove_air_loops = OpenStudio::Ruleset::OSArgument::makeBoolArgument('remove_air_loops',true)
    remove_air_loops.setDisplayName('Remove Air Loops?:')
    remove_air_loops.setDefaultValue(true)
    args << remove_air_loops

    # bool for removing plant loops
    remove_plant_loops = OpenStudio::Ruleset::OSArgument::makeBoolArgument('remove_plant_loops',true)
    remove_plant_loops.setDisplayName('Remove Plant Loops?:')
    remove_plant_loops.setDefaultValue(true)
    args << remove_plant_loops

    # bool for removing service hot water loops
    remove_shw_loops = OpenStudio::Ruleset::OSArgument::makeBoolArgument('remove_shw_loops',true)
    remove_shw_loops.setDisplayName('Also Remove Service Hot Water Plant Loops?:')
    remove_shw_loops.setDefaultValue(false)
    args << remove_shw_loops

    # bool for removing zone equipment
    remove_zone_equipment = OpenStudio::Ruleset::OSArgument::makeBoolArgument('remove_zone_equipment',true)
    remove_zone_equipment.setDisplayName('Remove Zone Equipment?:')
    remove_zone_equipment.setDefaultValue(true)
    args << remove_zone_equipment

    # bool for removing zone exhaust fans
    remove_zone_exhaust_fans = OpenStudio::Ruleset::OSArgument::makeBoolArgument('remove_zone_exhaust_fans',true)
    remove_zone_exhaust_fans.setDisplayName('Also Zone Exhaust Fans?:')
    remove_zone_exhaust_fans.setDefaultValue(false)
    args << remove_zone_exhaust_fans

    # bool for removing vrf equipment
    remove_vrf = OpenStudio::Ruleset::OSArgument::makeBoolArgument('remove_vrf',true)
    remove_vrf.setDisplayName('Remove VRF?:')
    remove_vrf.setDefaultValue(true)
    args << remove_vrf

    # bool for removing unused curves
    remove_unused_curves = OpenStudio::Ruleset::OSArgument::makeBoolArgument('remove_unused_curves',true)
    remove_unused_curves.setDisplayName('Remove Unused Curves?:')
    remove_unused_curves.setDefaultValue(true)
    args << remove_unused_curves

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
    remove_air_loops_bool = runner.getBoolArgumentValue('remove_air_loops', user_arguments)
    remove_plant_loops_bool = runner.getBoolArgumentValue('remove_plant_loops', user_arguments)
    remove_shw_loops_bool = runner.getBoolArgumentValue('remove_shw_loops', user_arguments)
    remove_zone_equipment_bool = runner.getBoolArgumentValue('remove_zone_equipment', user_arguments)
    remove_zone_exhaust_fans_bool = runner.getBoolArgumentValue('remove_zone_exhaust_fans', user_arguments)
    remove_vrf_bool = runner.getBoolArgumentValue('remove_vrf', user_arguments)
    remove_unused_curves_bool = runner.getBoolArgumentValue('remove_unused_curves', user_arguments)

    # report initial condition
    runner.registerInitialCondition("The building started with #{model.getPlantLoops.size} plant loops and #{model.getAirLoopHVACs.size} air loops.  If zone equipment is present, it will be removed.")

    # remove HVAC equipment according to user inputs
    remove_air_loops(model) if remove_air_loops_bool
    remove_plant_loops(model, runner) if remove_plant_loops_bool && !remove_shw_loops_bool
    remove_all_plant_loops(model) if remove_plant_loops_bool && remove_shw_loops_bool
    remove_zone_equipment(model, runner) if remove_zone_equipment_bool &&! remove_zone_exhaust_fans_bool
    remove_all_zone_equipment(model, runner) if remove_zone_equipment_bool && remove_zone_exhaust_fans_bool
    remove_vrf(model) if remove_vrf_bool
    remove_unused_curves(model) if remove_unused_curves_bool

    # report final condition
    runner.registerFinalCondition("The building finished with #{model.getPlantLoops.size} plant loops and #{model.getAirLoopHVACs.size} air loops.")

    return true
  end
end

# register the measure to be used by the application
RemoveHVACSystems.new.registerWithApplication
