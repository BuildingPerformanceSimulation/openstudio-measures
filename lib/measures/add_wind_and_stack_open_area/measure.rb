class AddWindAndStackOpenArea < OpenStudio::Measure::ModelMeasure

  # define the name that a user will see
  def name
    return "Add Wind and Stack Open Area"
  end

  # human readable description
  def description
    return "This measure models natural ventilation to thermal zones with operable casement type windows.  It is not intended to model natural ventilation that relies on interzone, stack driven air transfer."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure adds ZoneVentilation:WindandStackOpenArea objects to a zone for each window of a specified operable window construction.  The user can specify values for minimum and maximum zone and outdoor air temperatures and wind speed that set limits on when the ventilation is active. The airflow rate is the quadrature sum of wind driven and stack effect driven air flow.  Airflow driven by wind is a function of opening effectiveness, area, scheduled open area fraction, and wind speed.  Airflow driven by the stack effect is a function of the discharge coefficient, area, scheduled open area fraction, and height difference to the neutral pressure level.  This measure takes the height difference as one quarter the window height, and as such is only intended to model natural ventilation in single zones where a few large operable casement type windows or doors account for the majority of operable area.  It is not intended to model natural ventilation that relies on interzone, stack driven air transfer where ventilation flow through a opening is unidirectional."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # select constructions
    # filter to only fenestration constructions
    construction_handles = OpenStudio::StringVector.new
    construction_display_names = OpenStudio::StringVector.new
    model.getConstructions.each do |construction|
      next unless construction.isFenestration
      construction_handles << construction.handle.to_s
      construction_display_names << construction.name.to_s
    end
    construction_handles << model.getBuilding.handle.to_s
    construction_display_names << '*All Operable Windows*'

    # argument for operable window construction
    construction = OpenStudio::Measure::OSArgument::makeChoiceArgument('construction', construction_handles, construction_display_names, false)
    construction.setDisplayName('Specific Window Construction for Operable Windows:')
    construction.setDefaultValue('*All Operable Windows*')
    args << construction

    # make choice argument for fractional schedules
    frac_sch_handles = OpenStudio::StringVector.new
    frac_sch_display_names = OpenStudio::StringVector.new
    model.getSchedules.each do |sch|
      sch_type_limits = sch.scheduleTypeLimits.is_initialized ? sch.scheduleTypeLimits.get : nil
      next if sch_type_limits.nil?
      next unless sch_type_limits.name.to_s.downcase == 'fractional'

      frac_sch_handles << sch.handle.to_s
      frac_sch_display_names << sch.name.to_s
    end
    frac_sch_handles << model.getBuilding.handle.to_s
    frac_sch_display_names<< 'Default 0.5 Open Fractional Schedule'

    # make an argument for open area fraction
    open_area_fraction_schedule = OpenStudio::Measure::OSArgument::makeChoiceArgument('open_area_fraction_schedule', frac_sch_handles, frac_sch_display_names, false)
    open_area_fraction_schedule.setDisplayName('Open Area Fraction Schedule (must have fractional schedule type limits)')
    open_area_fraction_schedule.setDescription('A typical operable window does not open fully. The actual opening area in a zone is the product of the area of operable windows and the open area fraction schedule. Default 50% open.')
    open_area_fraction_schedule.setDefaultValue('Default 0.5 Open Fractional Schedule')
    args << open_area_fraction_schedule

    # make an argument for min indoor temp
    min_indoor_temp = OpenStudio::Measure::OSArgument::makeDoubleArgument('min_indoor_temp', true)
    min_indoor_temp.setDisplayName('Minimum Indoor Temperature (degC)')
    min_indoor_temp.setDescription('The indoor temperature below which ventilation is shutoff.')
    min_indoor_temp.setDefaultValue(21.67)
    args << min_indoor_temp

    # make choice argument for temperature schedules
    temp_sch_handles = OpenStudio::StringVector.new
    temp_sch_display_names = OpenStudio::StringVector.new
    model.getSchedules.each do |sch|
      sch_type_limits = sch.scheduleTypeLimits.is_initialized ? sch.scheduleTypeLimits.get : nil
      next if sch_type_limits.nil?
      next unless sch_type_limits.name.to_s.downcase == 'temperature'

      temp_sch_handles << sch.handle.to_s
      temp_sch_display_names << sch.name.to_s
    end
    temp_sch_handles << model.getBuilding.handle.to_s
    temp_sch_display_names << 'NA'

    # make an argument for minimum indoor temperature schedule
    min_indoor_temp_schedule = OpenStudio::Measure::OSArgument::makeChoiceArgument('min_indoor_temp_schedule', temp_sch_handles, temp_sch_display_names, true)
    min_indoor_temp_schedule.setDisplayName('Minimum Indoor Temperature Schedule')
    min_indoor_temp_schedule.setDescription('The indoor temperature below which ventilation is shutoff. If specified, this will be used instead of the Minimum Indoor Temperature field above.')
    min_indoor_temp_schedule.setDefaultValue('NA')
    args << min_indoor_temp_schedule

    # make an argument for maximum indoor temperature
    max_indoor_temp = OpenStudio::Measure::OSArgument::makeDoubleArgument('max_indoor_temp', true)
    max_indoor_temp.setDisplayName('Maximum Indoor Temperature (degC)')
    max_indoor_temp.setDescription('The indoor temperature above which ventilation is shutoff.')
    max_indoor_temp.setDefaultValue(40.0)
    args << max_indoor_temp

    # make an argument for maximum indoor temperature schedule
    max_indoor_temp_schedule = OpenStudio::Measure::OSArgument::makeChoiceArgument('max_indoor_temp_schedule', temp_sch_handles, temp_sch_display_names, true)
    max_indoor_temp_schedule.setDisplayName('Maximum Indoor Temperature Schedule')
    max_indoor_temp_schedule.setDescription('The indoor temperature above which ventilation is shutoff. If specified, this will be used instead of the Maximum Indoor Temperature field above.')
    max_indoor_temp_schedule.setDefaultValue('NA')
    args << max_indoor_temp_schedule

    # make an argument for delta temperature
    delta_temp = OpenStudio::Measure::OSArgument::makeDoubleArgument('delta_temp', true)
    delta_temp.setDisplayName('Maximum Indoor-Outdoor Temperature Difference (degC)')
    delta_temp.setDescription('This is the temperature difference between the indoor and outdoor air dry-bulb temperatures below which ventilation is shutoff.  For example, a delta temperature of 3 degC means ventilation is available if the outside air temperature is at least 3 degC cooler than the zone air temperature. Values can be negative.')
    delta_temp.setDefaultValue(3.0)
    args << delta_temp

    # make an argument for delta temperature schedule
    delta_temp_schedule = OpenStudio::Measure::OSArgument::makeChoiceArgument('delta_temp_schedule', temp_sch_handles, temp_sch_display_names, true)
    delta_temp_schedule.setDisplayName('Maximum Indoor-Outdoor Temperature Difference Schedule')
    delta_temp_schedule.setDescription('This is the temperature difference between the indoor and outdoor air dry-bulb temperatures below which ventilation is shutoff. If specified, this will be used instead of the Maximum Indoor-Outdoor Temperature Difference field above.')
    delta_temp_schedule.setDefaultValue('NA')
    args << delta_temp_schedule

    # make an argument for minimum outdoor temperature
    min_outdoor_temp = OpenStudio::Measure::OSArgument::makeDoubleArgument('min_outdoor_temp', true)
    min_outdoor_temp.setDisplayName('Minimum Outdoor Temperature (degC)')
    min_outdoor_temp.setDescription('The outdoor temperature below which ventilation is shut off.')
    min_outdoor_temp.setDefaultValue(18.3333)
    args << min_outdoor_temp

    # make an argument for minimum outdoor temperature schedule
    min_outdoor_temp_schedule = OpenStudio::Measure::OSArgument::makeChoiceArgument('min_outdoor_temp_schedule', temp_sch_handles, temp_sch_display_names, true)
    min_outdoor_temp_schedule.setDisplayName('Minimum Outdoor Temperature Schedule')
    min_outdoor_temp_schedule.setDescription('The outdoor temperature below which ventilation is shut off. If specified, this will be used instead of the Minimum Outdoor Temperature field above.')
    min_outdoor_temp_schedule.setDefaultValue('NA')
    args << min_outdoor_temp_schedule

    # make an argument for maximum outdoor temperature
    max_outdoor_temp = OpenStudio::Measure::OSArgument::makeDoubleArgument('max_outdoor_temp', true)
    max_outdoor_temp.setDisplayName('Maximum Outdoor Temperature (degC)')
    max_outdoor_temp.setDescription('The outdoor temperature above which ventilation is shut off.')
    max_outdoor_temp.setDefaultValue(25.5556)
    args << max_outdoor_temp

    # make an argument for maximum outdoor temperature schedule
    max_outdoor_temp_schedule = OpenStudio::Measure::OSArgument::makeChoiceArgument('max_outdoor_temp_schedule', temp_sch_handles, temp_sch_display_names, true)
    max_outdoor_temp_schedule.setDisplayName('Maximum Outdoor Temperature Schedule')
    max_outdoor_temp_schedule.setDescription('The outdoor temperature above which ventilation is shut off. If specified, this will be used instead of the Maximum Outdoor Temperature field above.')
    max_outdoor_temp_schedule.setDefaultValue('NA')
    args << max_outdoor_temp_schedule

    # make an argument for maximum wind speed
    max_wind_speed = OpenStudio::Measure::OSArgument::makeDoubleArgument('max_wind_speed', true)
    max_wind_speed.setDisplayName('Maximum Wind Speed (m/s)')
    max_wind_speed.setDescription('This is the wind speed above which ventilation is shut off.  The default values assume windows are closed when wind is above a gentle breeze to avoid blowing around papers in the space.')
    max_wind_speed.setDefaultValue(5.4)
    args << max_wind_speed

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # assign the user inputs to variables
    construction = runner.getOptionalWorkspaceObjectChoiceValue('construction', user_arguments, model)
    open_area_fraction_schedule = runner.getOptionalWorkspaceObjectChoiceValue('open_area_fraction_schedule', user_arguments, model)
    min_indoor_temp = runner.getDoubleArgumentValue('min_indoor_temp', user_arguments)
    min_indoor_temp_schedule = runner.getOptionalWorkspaceObjectChoiceValue('min_indoor_temp_schedule', user_arguments, model)
    max_indoor_temp = runner.getDoubleArgumentValue('max_indoor_temp', user_arguments)
    max_indoor_temp_schedule = runner.getOptionalWorkspaceObjectChoiceValue('max_indoor_temp_schedule', user_arguments, model)
    delta_temp = runner.getDoubleArgumentValue('delta_temp', user_arguments)
    delta_temp_schedule = runner.getOptionalWorkspaceObjectChoiceValue('delta_temp_schedule', user_arguments, model)
    min_outdoor_temp = runner.getDoubleArgumentValue('min_outdoor_temp', user_arguments)
    min_outdoor_temp_schedule = runner.getOptionalWorkspaceObjectChoiceValue('min_outdoor_temp_schedule', user_arguments, model)
    max_outdoor_temp = runner.getDoubleArgumentValue('max_outdoor_temp', user_arguments)
    max_outdoor_temp_schedule = runner.getOptionalWorkspaceObjectChoiceValue('max_outdoor_temp_schedule', user_arguments, model)
    max_wind_speed = runner.getDoubleArgumentValue('max_wind_speed', user_arguments)

    # check for construction for reasonableness
    if construction.empty?
      handle = runner.getStringArgumentValue('construction', user_arguments)
      if handle.empty?
        runner.registerError('No operable window construction selected.')
      else
        runner.registerError("The selected construction with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if !construction.get.to_Construction.empty?
        construction = construction.get.to_Construction.get
        
        # check if construction isn't used
        matching_stds_info = 0.0
        model.getStandardsInformationConstructions.each do |stds_info|
          matching_stds_info += 1.0 if construction.name.to_s.downcase == stds_info.construction.name.to_s.downcase
        end
        if (construction.directUseCount - matching_stds_info) <= 0
          runner.registerAsNotApplicable("Construction #{construction.name} is not used for any operable windows in the model.  This measure will have no effect.")
        end
      elsif !construction.get.to_Building.empty?
        # apply to all operable windows
        construction = nil
      else
        runner.registerError("Construction argument not showing up as a Construction object.")
        return false
      end
    end

    # check open area schedule for reasonableness
    if open_area_fraction_schedule.empty?
      handle = runner.getStringArgumentValue('open_area_fraction_schedule', user_arguments)
      if handle.empty?
        runner.registerError('No open area fraction schedule selected.')
      else
        runner.registerError("The selected open area fraction schedule with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if !open_area_fraction_schedule.get.to_Schedule.empty?
        open_area_fraction_schedule = open_area_fraction_schedule.get.to_Schedule.get
      elsif !open_area_fraction_schedule.get.to_Building.empty?
        # use default
        existing_schedule = model.getScheduleByName('Default 0.5 Open Fractional Schedule')
        if existing_schedule.is_initialized
          open_area_fraction_schedule = existing_schedule
        else
          open_area_fraction_schedule = OpenStudio::Model::ScheduleCompact.new(model, 0.5)
          open_area_fraction_schedule.setName('Default 0.5 Open Fractional Schedule')
        end
      else
        runner.registerError("Open Area Fraction Schedule argument not showing up as a Schedule object.")
        return false
      end
    end

    # check temperature schedules for reasonableness
    if min_indoor_temp_schedule.empty?
      handle = runner.getStringArgumentValue('min_indoor_temp_schedule', user_arguments)
      if handle.empty?
        runner.registerError('No Minimum Indoor Temperature Schedule selected.')
      else
        runner.registerError("The selected Minimum Indoor Temperature Schedule with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if !min_indoor_temp_schedule.get.to_Schedule.empty?
        min_indoor_temp_schedule = min_indoor_temp_schedule.get.to_Schedule.get
      elsif !min_indoor_temp_schedule.get.to_Building.empty?
        min_indoor_temp_schedule = nil
      else
        runner.registerError("Minimum Indoor Temperature Schedule argument not showing up as a Schedule object.")
        return false
      end
    end

    if max_indoor_temp_schedule.empty?
      handle = runner.getStringArgumentValue('max_indoor_temp_schedule', user_arguments)
      if handle.empty?
        runner.registerError('No Maximum Indoor Temperature Schedule selected.')
      else
        runner.registerError("The selected Maximum Indoor Temperature Schedule with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if !max_indoor_temp_schedule.get.to_Schedule.empty?
        max_indoor_temp_schedule = max_indoor_temp_schedule.get.to_Schedule.get
      elsif !max_indoor_temp_schedule.get.to_Building.empty?
        max_indoor_temp_schedule = nil
      else
        runner.registerError("Maximum Indoor Temperature Schedule argument not showing up as a Schedule object.")
        return false
      end
    end

    if delta_temp_schedule.empty?
      handle = runner.getStringArgumentValue('delta_temp_schedule', user_arguments)
      if handle.empty?
        runner.registerError('No Maximum Indoor-Outdoor Temperature Difference Schedule selected.')
      else
        runner.registerError("The selected Maximum Indoor-Outdoor Temperature Difference Schedule with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if !delta_temp_schedule.get.to_Schedule.empty?
        delta_temp_schedule = delta_temp_schedule.get.to_Schedule.get
      elsif !delta_temp_schedule.get.to_Building.empty?
        delta_temp_schedule = nil
      else
        runner.registerError("Maximum Indoor-Outdoor Temperature Difference Schedule argument not showing up as a Schedule object.")
        return false
      end
    end

    if min_outdoor_temp_schedule.empty?
      handle = runner.getStringArgumentValue('min_outdoor_temp_schedule', user_arguments)
      if handle.empty?
        runner.registerError('No Minimum Outdoor Temperature Schedule selected.')
      else
        runner.registerError("The selected Minimum Outdoor Temperature Schedule with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if !min_outdoor_temp_schedule.get.to_Schedule.empty?
        min_outdoor_temp_schedule = min_outdoor_temp_schedule.get.to_Schedule.get
      elsif !min_outdoor_temp_schedule.get.to_Building.empty?
        min_outdoor_temp_schedule = nil
      else
        runner.registerError("Minimum Outdoor Temperature Schedule argument not showing up as a Schedule object.")
        return false
      end
    end

    if max_outdoor_temp_schedule.empty?
      handle = runner.getStringArgumentValue('max_outdoor_temp_schedule', user_arguments)
      if handle.empty?
        runner.registerError('No Maximum Outdoor Temperature Schedule selected.')
      else
        runner.registerError("The selected Maximum Outdoor Temperature Schedule with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if !max_outdoor_temp_schedule.get.to_Schedule.empty?
        max_outdoor_temp_schedule = max_outdoor_temp_schedule.get.to_Schedule.get
      elsif !max_outdoor_temp_schedule.get.to_Building.empty?
        max_outdoor_temp_schedule = nil
      else
        runner.registerError("Maximum Outdoor Temperature Schedule argument not showing up as a Schedule object.")
        return false
      end
    end

    # check temperature variables for reasonableness
    temp_var_names = []
    temp_var_names << {'name' => 'Minimum Indoor Temperature', 'value' => min_indoor_temp}
    temp_var_names << {'name' => 'Maximum Indoor Temperature', 'value' => max_indoor_temp}
    temp_var_names << {'name' => 'Maximum Indoor-Outdoor Temperature Difference', 'value' => delta_temp}
    temp_var_names << {'name' => 'Minimum Outdoor Temperature', 'value' => min_outdoor_temp}
    temp_var_names << {'name' => 'Maximum Outdoor Temperature', 'value' => max_outdoor_temp}
    temp_var_names.each do |temp_var|
      if temp_var['value'] < -100.0
        runner.registerError("Please enter a value greater than -100.0 degC for #{temp_var['name']}.")
        return false
      elsif temp_var['value'] > 100.0
        runner.registerError("Please enter a value less than 100.0 degC for #{temp_var['name']}.")
        return false
      end
    end

    # check value for reasonableness
    if max_wind_speed < 0.0
      runner.registerError('Please enter a non-negative value for maximum wind speed.')
      return false
    end

    runner.registerInitialCondition("Model contains #{model.getZoneVentilationWindandStackOpenAreas.size} ZoneVentilation:WindandStackOpenArea objects.")

    # loop through fenestrations finding exterior windows  
    model.getSubSurfaces.each do |sub_surface|
      next unless sub_surface.outsideBoundaryCondition == 'Outdoors'
      next unless sub_surface.subSurfaceType == 'OperableWindow'

      # skip sub surface if sub surface construction does not match operable window construction if provided
      unless construction.nil?
        sub_surface_construction = sub_surface.construction
        unless sub_surface_construction.is_initialized
          runner.registerWarning("Sub surface construction not specified for #{sub_surface.name}; will not apply ventilation to window.")
          next
        end
        sub_surface_construction = sub_surface.construction.get

        unless sub_surface_construction.name.to_s == construction.name.to_s
          next
        end
      end

      # get sub surface thermal zone
      sub_surface_space = sub_surface.space
      unless sub_surface_space.is_initialized
        runner.registerError("No space defined for sub surface #{sub_surface.name}")
      end
      sub_surface_space = sub_surface.space.get
      sub_surface_zone = sub_surface_space.thermalZone
      unless sub_surface_space.thermalZone.is_initialized
        runner.registerError("No thermal zone defined for space #{sub_surface_space.name} with sub surface #{sub_surface.name}")
      end
      sub_surface_zone = sub_surface_space.thermalZone.get
     
      # calculate the height_difference at one quarter the window height. Assuming a casement type window or any type of door with the neutral pressure level (NPL) assumed to be 1/2 the window height and the midpoint of the lower opening (MP) being one half of the height between the bottom of the window and the NPL.
      z_values = []
      sub_surface.vertices.each { |v| z_values << v.z }
      height_difference = (z_values.max - z_values.min) / 4.0

      # determine outward normal angle
      absolute_azimuth = OpenStudio.convert(sub_surface.azimuth, 'rad', 'deg').get + sub_surface.surface.get.space.get.directionofRelativeNorth + model.getBuilding.northAxis

      # add ZoneVentilationWindStackOpenArea object
      vent_obj = OpenStudio::Model::ZoneVentilationWindandStackOpenArea.new(model)
      vent_obj.setName("#{sub_surface.name}_WindandStackOpenArea")
      vent_obj.addToThermalZone(sub_surface_zone)
      vent_obj.setOpeningArea(sub_surface.grossArea)
      vent_obj.setOpeningAreaFractionSchedule(open_area_fraction_schedule)
      vent_obj.autocalculateOpeningEffectiveness
      vent_obj.setEffectiveAngle(absolute_azimuth)
      vent_obj.setHeightDifference(height_difference)
      vent_obj.autocalculateDischargeCoefficientforOpening
      if min_indoor_temp_schedule.nil?
        vent_obj.setMinimumIndoorTemperature(min_indoor_temp)
      else
        vent_obj.setMinimumIndoorTemperatureSchedule(min_indoor_temp_schedule)
      end
      if max_indoor_temp_schedule.nil?
        vent_obj.setMaximumIndoorTemperature(max_indoor_temp)
      else
        vent_obj.setMaximumIndoorTemperatureSchedule(max_indoor_temp_schedule)
      end
      if delta_temp_schedule.nil?
        vent_obj.setDeltaTemperature(delta_temp)
      else
        vent_obj.setDeltaTemperatureSchedule(delta_temp_schedule)
      end
      if min_outdoor_temp_schedule.nil?
        vent_obj.setMinimumOutdoorTemperature(min_outdoor_temp)
      else
        vent_obj.setMinimumOutdoorTemperatureSchedule(min_outdoor_temp_schedule)
      end
      if max_outdoor_temp_schedule.nil?
        vent_obj.setMaximumOutdoorTemperature(max_outdoor_temp)
      else
        vent_obj.setMaximumOutdoorTemperatureSchedule(max_outdoor_temp_schedule)
      end
      vent_obj.setMaximumWindSpeed(max_wind_speed)
    end

    runner.registerFinalCondition("Added #{model.getZoneVentilationWindandStackOpenAreas.size} ZoneVentilation:WindandStackOpenArea objects.")

    return true
  end

end

AddWindAndStackOpenArea.new.registerWithApplication
