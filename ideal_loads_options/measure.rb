# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require 'openstudio'

# start the measure
class IdealLoadsOptions < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return "Ideal Loads Options"
  end

  # human readable description
  def description
    return "This measure allows the user to edit ideal air loads fields including availability schedules, maximum and minimum supply air temperatures, humidity ratios and flow rates, humidity control, outdoor air requirements, demand controlled ventilation, economizer operation, and heat recovery."
  end
  
  # human readable description of modeling approach
  def modeler_description
    return "This measure assigns fields to all IdealLoadsAirSystem objects."
  end

  def getScheduleLimitType(workspace,schedule)
    sch_type_limits_name = schedule.getString(1).to_s
    if sch_type_limits_name == ""
      return ""
    else
      sch_type_limits = workspace.getObjectsByTypeAndName("ScheduleTypeLimits".to_IddObjectType,sch_type_limits_name)
      sch_type = sch_type_limits[0].getString(4).to_s
      if sch_type != ""
        return sch_type
      else
        return ""
      end
    end
  end

  def filterSchedulesByLimitType(workspace, schedules, limit_type)
    filtered_schedules = []
    
    schedules.each do |sch|
      sch_typ = getScheduleLimitType(workspace,sch)
      if  (sch_typ == limit_type)
        filtered_schedules << sch.getString(0).to_s
      end
    end
    
    return filtered_schedules
  end  

  # check to see if we have an exact match for this object already
  def check_for_object(runner, workspace, idf_object, idd_object_type)
    workspace.getObjectsByType(idd_object_type).each do |object|
      # all of these objects fields are data fields
      if idf_object.dataFieldsEqual(object)
        return true
      end
    end
    return false
  end
  
  # merge all summary reports that are not in the current workspace
  def merge_output_table_summary_reports(current_object, new_object)
  
    current_fields = []
    current_object.extensibleGroups.each do |current_extensible_group|
      current_fields << current_extensible_group.getString(0).to_s
    end
        
    fields_to_add = []
    new_object.extensibleGroups.each do |new_extensible_group|
      field = new_extensible_group.getString(0).to_s
      if !current_fields.include?(field)
        current_fields << field
        fields_to_add << field
      end
    end
    
    if !fields_to_add.empty?
      fields_to_add.each do |field|
        values = OpenStudio::StringVector.new
        values << field
        current_object.pushExtensibleGroup(values)
      end
      return true
    end
    
    return false
  end
  
  # examines object and determines whether or not to add it to the workspace
  def add_object(runner, workspace, idf_object)

    num_added = 0
    idd_object = idf_object.iddObject
   
    allowed_objects = []
    allowed_objects << "Output:Surfaces:List"
    allowed_objects << "Output:Surfaces:Drawing"
    allowed_objects << "Output:Schedules"
    allowed_objects << "Output:Constructions"
    allowed_objects << "Output:Table:TimeBins"
    allowed_objects << "Output:Table:Monthly"
    allowed_objects << "Output:Variable"
    allowed_objects << "Output:Meter"
    allowed_objects << "Output:Meter:MeterFileOnly"
    allowed_objects << "Output:Meter:Cumulative"
    allowed_objects << "Output:Meter:Cumulative:MeterFileOnly"
    allowed_objects << "Meter:Custom"
    allowed_objects << "Meter:CustomDecrement"
    
    if allowed_objects.include?(idd_object.name)
      if !check_for_object(runner, workspace, idf_object, idd_object.type)
        runner.registerInfo("Adding idf object #{idf_object.to_s.strip}")
        workspace.addObject(idf_object)
        num_added += 1
      else
        runner.registerInfo("Workspace already includes #{idf_object.to_s.strip}")
      end
    end
    
    allowed_unique_objects = []
    #allowed_unique_objects << "Output:EnergyManagementSystem" # TODO: have to merge
    #allowed_unique_objects << "OutputControl:SurfaceColorScheme" # TODO: have to merge
    allowed_unique_objects << "Output:Table:SummaryReports" # TODO: have to merge
    # OutputControl:Table:Style # not allowed
    # OutputControl:ReportingTolerances # not allowed
    # Output:SQLite # not allowed
   
    if allowed_unique_objects.include?(idf_object.iddObject.name)
      if idf_object.iddObject.name == "Output:Table:SummaryReports"
        summary_reports = workspace.getObjectsByType(idf_object.iddObject.type)
        if summary_reports.empty?
          runner.registerInfo("Adding idf object #{idf_object.to_s.strip}")
          workspace.addObject(idf_object)
          num_added += 1
        elsif merge_output_table_summary_reports(summary_reports[0], idf_object)
          runner.registerInfo("Merged idf object #{idf_object.to_s.strip}")     
        else
          runner.registerInfo("Workspace already includes #{idf_object.to_s.strip}")
        end
      end
    end
    
    return num_added
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    #make choice argument for availability_schedule
    sch_choices = OpenStudio::StringVector.new
    sch_compacts = workspace.getObjectsByType("Schedule:Compact".to_IddObjectType)
    sch_constants = workspace.getObjectsByType("Schedule:Constant".to_IddObjectType)
    sch_years = workspace.getObjectsByType("Schedule:Year".to_IddObjectType)
    sch_files = workspace.getObjectsByType("Schedule:File".to_IddObjectType)
    sch_compacts.each do |sch|
      if getScheduleLimitType(workspace,sch) == "availability"
        sch_choices << sch.getString(0).to_s
      end
    end
    sch_constants.each do |sch|
      if getScheduleLimitType(workspace,sch) == "availability"
        sch_choices << sch.getString(0).to_s
      end
    end    
    sch_years.each do |sch|
      if getScheduleLimitType(workspace,sch) == "availability"
        sch_choices << sch.getString(0).to_s
      end
    end
    sch_files.each do |sch|
      if getScheduleLimitType(workspace,sch) == "availability"
        sch_choices << sch.getString(0).to_s
      end
    end
    
    #argument for system availability schedule
    availability_schedule = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("availability_schedule", sch_choices, true)
    availability_schedule.setDisplayName("System Availability Schedule:")
    args << availability_schedule

    #argument for heating availability schedule
    heating_availability_schedule = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("heating_availability_schedule", sch_choices, true)
    heating_availability_schedule.setDisplayName("Heating Availability Schedule:")
    args << heating_availability_schedule
    
    #argument for cooling availability schedule
    cooling_availability_schedule = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("cooling_availability_schedule", sch_choices, true)
    cooling_availability_schedule.setDisplayName("Cooling Availability Schedule:")
    args << cooling_availability_schedule

    #argument for Heating Limit Type
    choices = OpenStudio::StringVector.new
    choices << "NoLimit"
    choices << "LimitFlowRate"
    choices << "LimitCapacity"
    choices << "LimitFlowRateAndCapacity"
    heating_limit_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("heating_limit_type", choices, true)
    heating_limit_type.setDisplayName("Heating Limit Type:")
    heating_limit_type.setDefaultValue("NoLimit")
    args << heating_limit_type

    #argument for Cooling Limit Type
    choices = OpenStudio::StringVector.new
    choices << "NoLimit"
    choices << "LimitFlowRate"
    choices << "LimitCapacity"
    choices << "LimitFlowRateAndCapacity"
    cooling_limit_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("cooling_limit_type", choices, true)
    cooling_limit_type.setDisplayName("Cooling Limit Type:")
    cooling_limit_type.setDefaultValue("NoLimit")
    args << cooling_limit_type
    
    #argument for Dehumidification Control Type
    choices = OpenStudio::StringVector.new
    choices << "None"
    choices << "ConstantSensibleHeatRatio"
    choices << "Humidistat"
    choices << "ConstantSupplyHumidityRatio"
    dehumid_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("dehumid_type", choices, true)
    dehumid_type.setDisplayName("Dehumidification Control:")
    dehumid_type.setDefaultValue("ConstantSensibleHeatRatio")
    args << dehumid_type

    #argument for Cooling Sensible Heat Ratio
    cooling_sensible_heat_ratio = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("cooling_sensible_heat_ratio", true)
    cooling_sensible_heat_ratio.setDisplayName("Cooling Sensible Heat Ratio")
    cooling_sensible_heat_ratio.setDefaultValue(0.7)
    args << cooling_sensible_heat_ratio
    
    #argument for Humidification Control Type
    choices = OpenStudio::StringVector.new
    choices << "None"
    choices << "Humidistat"
    choices << "ConstantSupplyHumidityRatio"
    humid_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("humid_type", choices, true)
    humid_type.setDisplayName("Humidification Control:")
    humid_type.setDefaultValue("None")
    args << humid_type

    #argument for Design Specification Outdoor Air
    choices = OpenStudio::StringVector.new
    choices << "None"
    choices << "Use Individual Zone Design Outdoor Air"
    oa_spec = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("oa_spec", choices, true)
    oa_spec.setDisplayName("Outdoor Air Specification:")
    oa_spec.setDefaultValue("Use Individual Zone Design Outdoor Air")
    args << oa_spec
    
    #argument for Demand Controlled Ventilation
    choices = OpenStudio::StringVector.new
    choices << "None"
    choices << "OccupancySchedule"
    #choices << "CO2Setpoint" #requires ZoneControl:ContaminantController object
    dcv_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("dcv_type", choices, true)
    dcv_type.setDisplayName("Demand Controlled Ventilation:")
    dcv_type.setDefaultValue("None")
    args << dcv_type

    #argument for Economizer Type
    choices = OpenStudio::StringVector.new
    choices << "NoEconomizer"
    choices << "DifferentialDryBulb"
    choices << "DifferentialEnthalpy"
    economizer_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("economizer_type", choices, true)
    economizer_type.setDisplayName("Economizer Type (Requires a Flow Rate Cooling Limit Type and Outdoor Air):")
    economizer_type.setDefaultValue("NoEconomizer")
    args << economizer_type
    
    #argument for Heat Recovery Type
    choices = OpenStudio::StringVector.new
    choices << "None"
    choices << "Sensible"
    choices << "Enthalpy"
    heat_recovery_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("heat_recovery_type", choices, true)
    heat_recovery_type.setDisplayName("Heat Recovery Type (Requires Outdoor Air):")
    heat_recovery_type.setDefaultValue("None")
    args << heat_recovery_type
    
    #argument for Heat Recovery Sensible Effectiveness
    sensible_effectiveness = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("sensible_effectiveness", true)
    sensible_effectiveness.setDisplayName("Heat Recovery Sensible Effectiveness")
    sensible_effectiveness.setDefaultValue(0.7)
    args << sensible_effectiveness
    
    #argument for Heat Recovery Latent Effectiveness
	  latent_effectiveness = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("latent_effectiveness", true)
    latent_effectiveness.setDisplayName("Heat Recovery Latent Effectiveness")
    latent_effectiveness.setDefaultValue(0.65)
    args << latent_effectiveness
    
    #add output meter
    add_meters = OpenStudio::Ruleset::OSArgument.makeBoolArgument("add_meters",true)
    add_meters.setDisplayName("Add Meter:Custom and Output:Meter objects to sum ZoneHVAC:IdealLoadsAirSystem variables?")
    add_meters.setDefaultValue(true)
    args << add_meters

    return args
  end

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)
    
    # use the built-in error checking 
    if not runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end

    #default is OpenStudio version >= 2.0, set to OSv1 for OpenStudio version <=1.14
    # version = "OSv1"
    version = "OSv2"
    
    #assign the user inputs to variables
    availability_schedule = runner.getStringArgumentValue("availability_schedule",user_arguments)
    heating_availability_schedule = runner.getStringArgumentValue("heating_availability_schedule",user_arguments)
    cooling_availability_schedule = runner.getStringArgumentValue("cooling_availability_schedule",user_arguments)
    heating_limit_type = runner.getStringArgumentValue("heating_limit_type",user_arguments)
    cooling_limit_type = runner.getStringArgumentValue("cooling_limit_type",user_arguments)
    dehumid_type = runner.getStringArgumentValue("dehumid_type",user_arguments)
    cooling_sensible_heat_ratio = runner.getDoubleArgumentValue("cooling_sensible_heat_ratio",user_arguments)
    humid_type = runner.getStringArgumentValue("humid_type",user_arguments)
    oa_spec = runner.getStringArgumentValue("oa_spec",user_arguments)
    dcv_type = runner.getStringArgumentValue("dcv_type",user_arguments)
    economizer_type = runner.getStringArgumentValue("economizer_type",user_arguments)
    heat_recovery_type = runner.getStringArgumentValue("heat_recovery_type",user_arguments)
    sensible_effectiveness = runner.getDoubleArgumentValue("sensible_effectiveness",user_arguments)
    latent_effectiveness = runner.getDoubleArgumentValue("latent_effectiveness",user_arguments)
    add_meters = runner.getBoolArgumentValue("add_meters",user_arguments)
    
    #get ideal air loads objects
    if version == "OSv1" #OS v1 ZoneHVAC:IdealLoadsAirSystem
      ideal_loads_objects = workspace.getObjectsByType("ZoneHVAC:IdealLoadsAirSystem".to_IddObjectType)
    else #OS v2 HVACTemplate:Zone:IdealLoadsAirSystem
      ideal_loads_objects = workspace.getObjectsByType("HVACTemplate:Zone:IdealLoadsAirSystem".to_IddObjectType)
    end
    runner.registerInitialCondition("The model has #{ideal_loads_objects.length} ideal air loads objects.")
    
    equipment_connection_objects = workspace.getObjectsByType("ZoneHVAC:EquipmentConnections".to_IddObjectType)
    zone_sizing_objects = workspace.getObjectsByType("Sizing:Zone".to_IddObjectType)

    num_set = 0
    ideal_loads_objects.each do |ideal_loads_object|
      
      if version == "OSv1" #OS v1 ZoneHVAC:IdealLoadsAirSystem
        ideal_loads_object.setString(1,availability_schedule)
        ideal_loads_object.setString(8,heating_limit_type)
        ideal_loads_object.setString(11,cooling_limit_type)
        ideal_loads_object.setString(14,heating_availability_schedule)
        ideal_loads_object.setString(15,cooling_availability_schedule)
        ideal_loads_object.setString(16,dehumid_type)
        ideal_loads_object.setDouble(17,cooling_sensible_heat_ratio)
        ideal_loads_object.setString(18,humid_type)
      else #OS v2 HVACTemplate:Zone:IdealLoadsAirSystem
        ideal_loads_object.setString(2,availability_schedule)
        ideal_loads_object.setString(7,heating_limit_type)
        ideal_loads_object.setString(10,cooling_limit_type)
        ideal_loads_object.setString(13,heating_availability_schedule)
        ideal_loads_object.setString(14,cooling_availability_schedule)
        ideal_loads_object.setString(15,dehumid_type)
        ideal_loads_object.setDouble(16,cooling_sensible_heat_ratio)
        ideal_loads_object.setString(18,humid_type)
      end
      
      if oa_spec == "Use Individual Zone Design Outdoor Air"
      
        #get design specification outdoor air object name for this zone
        design_spec_oa_name = ""
        
        if version == "OSv1" #OS v1 ZoneHVAC:IdealLoadsAirSystem
          zone_supply_node_name = ideal_loads_object.getString(2)
          zone_name = ""
          equipment_connection_objects.each do |obj|    
            if obj.getString(2).to_s == zone_supply_node_name.to_s
              zone_name = obj.getString(0).to_s
              break;
            end
          end
        else #OS v2 HVACTemplate:Zone:IdealLoadsAirSystem
          zone_name = ideal_loads_object.getString(0).to_s
        end
           
        if zone_name == ""
          if version == "OSv1" #OS v1 ZoneHVAC:IdealLoadsAirSystem
            runner.registerError("Unable to find zone for ideal air loads system. Check ZoneHVAC:IdealLoadsAirSystem supply node fields.")
          else #OS v2 HVACTemplate:Zone:IdealLoadsAirSystem
            runner.registerError("Unable to find zone for ideal air loads system. Check HVACTemplate:Zone:IdealLoadsAirSystem supply node fields.")
          end
          return false
        else
          zone_sizing_objects.each do |obj|
            if obj.getString(0).to_s == zone_name.to_s
              design_spec_oa_name = obj.getString(9).to_s
              break;
            end
          end
        end
				
        if design_spec_oa_name == ""
          runner.registerError("Unable to find design specification outdoor air for zone #{zone_name}.  Please specify a design specification outdoor air object for the zone, or select None for Outdoor Air Specification.")
          return false
        else
          if version == "OSv1" #OS v1 ZoneHVAC:IdealLoadsAirSystem
            ideal_loads_object.setString(19,design_spec_oa_name)          
          else #OS v2 HVACTemplate:Zone:IdealLoadsAirSystem
            ideal_loads_object.setString(20,"DetailedSpecification")
				    ideal_loads_object.setString(24,design_spec_oa_name)
          end
        end
      end

      #set remaining fields
      if version == "OSv1" #OS v1 ZoneHVAC:IdealLoadsAirSystem
        ideal_loads_object.setString(21,dcv_type)
        ideal_loads_object.setString(22,economizer_type)
        ideal_loads_object.setString(23,heat_recovery_type)
        ideal_loads_object.setDouble(24,sensible_effectiveness)
        ideal_loads_object.setDouble(25,latent_effectiveness)
      else #OS v2 HVACTemplate:Zone:IdealLoadsAirSystem
        ideal_loads_object.setString(25,dcv_type)
        ideal_loads_object.setString(26,economizer_type)
        ideal_loads_object.setString(27,heat_recovery_type)
        ideal_loads_object.setDouble(28,sensible_effectiveness)
        ideal_loads_object.setDouble(29,latent_effectiveness)
      end
      num_set += 1
    end
    
    if add_meters
      #ideal air loads system variables to include
      ideal_air_loads_system_variables = ["Zone Ideal Loads Supply Air Sensible Heating Energy","Zone Ideal Loads Supply Air Latent Heating Energy","Zone Ideal Loads Supply Air Total Heating Energy","Zone Ideal Loads Supply Air Sensible Cooling Energy","Zone Ideal Loads Supply Air Latent Cooling Energy","Zone Ideal Loads Supply Air Total Cooling Energy","Zone Ideal Loads Zone Sensible Heating Energy","Zone Ideal Loads Zone Latent Heating Energy","Zone Ideal Loads Zone Total Heating Energy","Zone Ideal Loads Zone Sensible Cooling Energy","Zone Ideal Loads Zone Latent Cooling Energy","Zone Ideal Loads Zone Total Cooling Energy","Zone Ideal Loads Outdoor Air Sensible Heating Energy","Zone Ideal Loads Outdoor Air Latent Heating Energy","Zone Ideal Loads Outdoor Air Total Heating Energy","Zone Ideal Loads Outdoor Air Sensible Cooling Energy","Zone Ideal Loads Outdoor Air Latent Cooling Energy","Zone Ideal Loads Outdoor Air Total Cooling Energy","Zone Ideal Loads Heat Recovery Sensible Heating Energy","Zone Ideal Loads Heat Recovery Latent Heating Energy","Zone Ideal Loads Heat Recovery Total Heating Energy","Zone Ideal Loads Heat Recovery Sensible Cooling Energy","Zone Ideal Loads Heat Recovery Latent Cooling Energy","Zone Ideal Loads Heat Recovery Total Cooling Energy"]
      
      ideal_loads_names = []
      ideal_loads_objects.each do |object|
        if version == "OSv1" #OS v1 ZoneHVAC:IdealLoadsAirSystem
          if not object.name.empty?
            ideal_loads_names << object.name.get.to_s
          else
            runner.registerError("A ZoneHVAC:IdealLoadsAirSystem object did not have a name. Cannot specify meter.")
          end
        else #OS v2 HVACTemplate:Zone:IdealLoadsAirSystem
          zone_name = object.getString(0).to_s
          if not zone_name.empty?
            ideal_loads_names << "#{zone_name} Ideal Loads Air System"
          else
            runner.registerError("A HVACTemplate:Zone:IdealLoadsAirSystem object did not have a zone name. Cannot specify meter.")
          end
        end
      end
      
      meters_added = 0
      outputs_added = 0      
      ideal_air_loads_system_variables.each do |variable|        
        #create meter definition for variable
        meter_definition = "Meter:Custom," + "Sum #{variable}" + "," + "Generic"        
        ideal_loads_names.each do |name|
          meter_definition = meter_definition + "," + name + "," + variable
        end
        meter_definition = meter_definition + ";"

        #add meter:custom to idf        
        idf_object = OpenStudio::IdfObject::load(meter_definition)
        idf_object = idf_object.get    
        meters_added += add_object(runner, workspace, idf_object)

        #add output meter
        output_meter_definition = "Output:Meter," + "Sum #{variable}" + "," + "hourly" + ";"
        idf_object = OpenStudio::IdfObject::load(output_meter_definition)
        idf_object = idf_object.get    
        outputs_added += add_object(runner, workspace, idf_object)        
      end

      runner.registerInfo("Added #{meters_added} meter:custom and #{outputs_added} output:meter objects.")
    end

    if version == "OSv1" #OS v1 ZoneHVAC:IdealLoadsAirSystem
      runner.registerFinalCondition("Set availability schedules to #{availability_schedule} for #{num_set} ZoneHVAC:IdealLoadsAirSystem objects.")    
    else #OS v2 HVACTemplate:Zone:IdealLoadsAirSystem
      runner.registerFinalCondition("Set availability schedules to #{availability_schedule} for #{num_set} HVACTemplate:Zone:IdealLoadsAirSystem objects.")
    end

    return true

  end

end

# register the measure to be used by the application
IdealLoadsOptions.new.registerWithApplication