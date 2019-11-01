# dependencies
require 'openstudio-standards'

class IdealAirLoadsZoneHVAC < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return 'Ideal Air Loads Zone HVAC'
  end

  # human readable description
  def description
    return 'This OpenStudio measure will replace the existing HVAC system with ideal air loads objects for each conditioned zone and allow the user to specify input fields including availability schedules, humidity controls, outdoor air ventilation, demand controlled ventilation, economizer operation, and heat recovery.  The measure optionally creates custom meter and output meter objects that sum all ideal loads output variables for further analysis.'
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure creates ZoneHVACIdealLoadsAirSystem objects for each conditioned zone using the model_add_ideal_air_loads method in the openstudio-standards gem.  If the 'Include Outdoor Air Ventilation?' option is set to false, the measure will remove all Design Specification Outdoor Air objects in the model so that they don't get written to the ideal loads objects during forward translation."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make choice argument for availability_schedule
    schedule_choices = OpenStudio::StringVector.new
    schedule_choices << 'Default Always On'
    model.getSchedules.each do |sch|
      sch_type = sch.scheduleTypeLimits
      if sch_type.is_initialized
        sch_type = sch_type.get
        if sch_type.unitType.downcase == 'availability'
          schedule_choices << sch.name.to_s
        end
      end
    end

    # argument for system availability schedule
    availability_schedule = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('availability_schedule', schedule_choices, true)
    availability_schedule.setDisplayName('System Availability Schedule:')
    availability_schedule.setDefaultValue('Default Always On')
    args << availability_schedule

    # argument for heating availability schedule
    heating_availability_schedule = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('heating_availability_schedule', schedule_choices, true)
    heating_availability_schedule.setDisplayName('Heating Availability Schedule:')
    heating_availability_schedule.setDefaultValue('Default Always On')
    args << heating_availability_schedule

    # argument for cooling availability schedule
    cooling_availability_schedule = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('cooling_availability_schedule', schedule_choices, true)
    cooling_availability_schedule.setDisplayName('Cooling Availability Schedule:')
    cooling_availability_schedule.setDefaultValue('Default Always On')
    args << cooling_availability_schedule

    # argument for Heating Limit Type
    choices = OpenStudio::StringVector.new
    choices << 'NoLimit'
    choices << 'LimitFlowRate'
    choices << 'LimitCapacity'
    choices << 'LimitFlowRateAndCapacity'
    heating_limit_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('heating_limit_type', choices, true)
    heating_limit_type.setDisplayName('Heating Limit Type:')
    heating_limit_type.setDefaultValue('NoLimit')
    args << heating_limit_type

    # argument for Cooling Limit Type
    choices = OpenStudio::StringVector.new
    choices << 'NoLimit'
    choices << 'LimitFlowRate'
    choices << 'LimitCapacity'
    choices << 'LimitFlowRateAndCapacity'
    cooling_limit_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('cooling_limit_type', choices, true)
    cooling_limit_type.setDisplayName('Cooling Limit Type:')
    cooling_limit_type.setDefaultValue('NoLimit')
    args << cooling_limit_type

    # argument for Dehumidification Control Type
    choices = OpenStudio::StringVector.new
    choices << 'None'
    choices << 'ConstantSensibleHeatRatio'
    choices << 'Humidistat'
    choices << 'ConstantSupplyHumidityRatio'
    dehumid_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('dehumid_type', choices, true)
    dehumid_type.setDisplayName('Dehumidification Control:')
    dehumid_type.setDefaultValue('ConstantSensibleHeatRatio')
    args << dehumid_type

    # argument for Cooling Sensible Heat Ratio
    cooling_sensible_heat_ratio = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('cooling_sensible_heat_ratio', true)
    cooling_sensible_heat_ratio.setDisplayName('Cooling Sensible Heat Ratio')
    cooling_sensible_heat_ratio.setDefaultValue(0.7)
    args << cooling_sensible_heat_ratio

    # argument for Humidification Control Type
    choices = OpenStudio::StringVector.new
    choices << 'None'
    choices << 'Humidistat'
    choices << 'ConstantSupplyHumidityRatio'
    humid_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('humid_type', choices, true)
    humid_type.setDisplayName('Humidification Control:')
    humid_type.setDefaultValue('None')
    args << humid_type

    # argument for Design Specification Outdoor Air
    include_outdoor_air = OpenStudio::Ruleset::OSArgument::makeBoolArgument('include_outdoor_air', true)
    include_outdoor_air.setDisplayName('Include Outdoor Air Ventilation?:')
    include_outdoor_air.setDefaultValue(true)
    args << include_outdoor_air

    # argument for Demand Controlled Ventilation
    enable_dcv = OpenStudio::Ruleset::OSArgument::makeBoolArgument('enable_dcv', true)
    enable_dcv.setDisplayName('Enable Demand Controlled Ventilation?:')
    enable_dcv.setDefaultValue(false)
    args << enable_dcv

    # argument for Economizer Type
    choices = OpenStudio::StringVector.new
    choices << 'NoEconomizer'
    choices << 'DifferentialDryBulb'
    choices << 'DifferentialEnthalpy'
    economizer_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('economizer_type', choices, true)
    economizer_type.setDisplayName('Economizer Type (Requires a Flow Rate Cooling Limit Type and Outdoor Air):')
    economizer_type.setDefaultValue('NoEconomizer')
    args << economizer_type

    # argument for Heat Recovery Type
    choices = OpenStudio::StringVector.new
    choices << 'None'
    choices << 'Sensible'
    choices << 'Enthalpy'
    heat_recovery_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('heat_recovery_type', choices, true)
    heat_recovery_type.setDisplayName('Heat Recovery Type (Requires Outdoor Air):')
    heat_recovery_type.setDefaultValue('None')
    args << heat_recovery_type

    # argument for Heat Recovery Sensible Effectiveness
    sensible_effectiveness = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('sensible_effectiveness', true)
    sensible_effectiveness.setDisplayName('Heat Recovery Sensible Effectiveness')
    sensible_effectiveness.setDefaultValue(0.7)
    args << sensible_effectiveness

    # argument for Heat Recovery Latent Effectiveness
    latent_effectiveness = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('latent_effectiveness', true)
    latent_effectiveness.setDisplayName('Heat Recovery Latent Effectiveness')
    latent_effectiveness.setDefaultValue(0.65)
    args << latent_effectiveness

    # add output meter
    add_meters = OpenStudio::Ruleset::OSArgument.makeBoolArgument('add_meters',true)
    add_meters.setDisplayName('Add Meter:Custom and Output:Meter objects to sum ZoneHVAC:IdealLoadsAirSystem variables?')
    add_meters.setDefaultValue(true)
    args << add_meters

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    availability_schedule = runner.getStringArgumentValue('availability_schedule', user_arguments)
    availability_schedule = nil if availability_schedule == 'Default Always On'
    heating_availability_schedule = runner.getStringArgumentValue('heating_availability_schedule', user_arguments)
    heating_availability_schedule = nil  if heating_availability_schedule == 'Default Always On'
    cooling_availability_schedule = runner.getStringArgumentValue('cooling_availability_schedule', user_arguments)
    cooling_availability_schedule = nil  if cooling_availability_schedule == 'Default Always On'
    heating_limit_type = runner.getStringArgumentValue('heating_limit_type', user_arguments)
    cooling_limit_type = runner.getStringArgumentValue('cooling_limit_type', user_arguments)
    dehumid_type = runner.getStringArgumentValue('dehumid_type', user_arguments)
    cooling_sensible_heat_ratio = runner.getDoubleArgumentValue('cooling_sensible_heat_ratio', user_arguments)
    humid_type = runner.getStringArgumentValue('humid_type', user_arguments)
    include_outdoor_air = runner.getBoolArgumentValue('include_outdoor_air', user_arguments)
    enable_dcv = runner.getBoolArgumentValue('enable_dcv', user_arguments)
    economizer_type = runner.getStringArgumentValue('economizer_type', user_arguments)
    heat_recovery_type = runner.getStringArgumentValue('heat_recovery_type', user_arguments)
    sensible_effectiveness = runner.getDoubleArgumentValue('sensible_effectiveness', user_arguments)
    latent_effectiveness = runner.getDoubleArgumentValue('latent_effectiveness', user_arguments)
    add_meters = runner.getBoolArgumentValue('add_meters', user_arguments)

    # check which zone already include ideal air loads 
    existing_ideal_loads = model.getZoneHVACIdealLoadsAirSystems
    runner.registerInitialCondition("The model has #{existing_ideal_loads.size} ideal air loads objects.")

    # dummy standard to access methods in openstudio-standards
    std = Standard.build('90.1-2013')

    # remove existing HVAC
    runner.registerInfo('Removing existing HVAC systems from the model')
    std.remove_HVAC(model)

    # add zone hvac ideal load air system objects
    conditioned_zones = []
    model.getThermalZones.each do |zone|
      next if std.thermal_zone_plenum?(zone)
      next if !std.thermal_zone_heated?(zone) && !std.thermal_zone_cooled?(zone)
      conditioned_zones << zone
    end
    ideal_loads_objects = std.model_add_ideal_air_loads(model,
                                                        conditioned_zones,
                                                        hvac_op_sch: availability_schedule,
                                                        heat_avail_sch: heating_availability_schedule,
                                                        cool_avail_sch: cooling_availability_schedule,
                                                        heat_limit_type: heating_limit_type,
                                                        cool_limit_type: cooling_limit_type,
                                                        dehumid_limit_type: dehumid_type,
                                                        cool_sensible_heat_ratio: cooling_sensible_heat_ratio,
                                                        humid_ctrl_type: humid_type,
                                                        include_outdoor_air: include_outdoor_air,
                                                        enable_dcv: enable_dcv,
                                                        econo_ctrl_mthd: economizer_type,
                                                        heat_recovery_type: heat_recovery_type,
                                                        heat_recovery_sensible_eff: sensible_effectiveness,
                                                        heat_recovery_latent_eff: latent_effectiveness,
                                                        add_output_meters: add_meters)

    # validity checks
    unless ideal_loads_objects
      runner.registerError('Failure in creating ideal loads objects.  See logs from [openstudio.model.Model]. Likely cause is an invalid schedule input or schedule removed from by another measure.')
      return false
    end
    if include_outdoor_air
      ideal_load_objects_with_oa = ideal_loads_objects.select { |obj| obj.designSpecificationOutdoorAirObject.is_initialized }
      if ideal_load_objects_with_oa.empty?
        runner.registerError('Outdoor air ventilation requested, but ideal loads objects are missing design outdoor air specification objects.  See logs from [openstudio.model.Model].  Likely cause is spaces or space types missing design specification outdoor air objects.')
        return false
      elsif ideal_load_objects_with_oa.size < ideal_loads_objects.size
        runner.registerWarning('Outdoor air ventilation requested, but some ideal loads objects are missing design outdoor air specification objects.  See logs from [openstudio.model.Model].  Likely cause is a space or space missing a design specification outdoor air objects.  This could be intentional.')
      end
    else
      # remove design specification outdoor air objects
      runner.registerWarning('No outdoor air ventilation requested; removing Design Specification Outdoor Air objects from model.')
      model.getDesignSpecificationOutdoorAirs.each(&:remove)
    end

    runner.registerFinalCondition("The model has #{ideal_loads_objects.size} ideal air loads objects.")

    return true
  end
end

# register the measure to be used by the application
IdealAirLoadsZoneHVAC.new.registerWithApplication