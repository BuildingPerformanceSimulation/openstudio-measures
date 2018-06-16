# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require 'openstudio'
require 'csv'

# start the measure
class MeterCustom < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return "Custom Meter"
  end

  # human readable description
  def description
    return "This measure creates a Custom Meter to combine output variables and meters from a user-defined .csv file.  This is helpful for combining energy use by floor, by space type, or for specific zones. You can easily create this grouping by generating the SpaceTypeReport, then filtering and copying the zones you want to group together. An example .csv file is included in the resources folder for this measure. The measure optionally outputs the custom meter."
  end
  
  # human readable description of modeling approach
  def modeler_description
    return "This measure creates a Meter:Custom object based on a user-defined .csv file and optionally adds an Output:Meter for the custom meter to save the values to the .eio and .mtr files.  Common errors: (1) Using space names instead of thermal zone names as key variables, (2) not specifying the Zone variable, e.g. Lights Electric Energy vs. Zone Lights Electric Energy, (3) Requesting a variable or meter that is not there.  E.g., if a zone has no electric equipment, you cannot request a Zone Electric Equipment Electric Energy variable."
  end
  
  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make string argument for meter name
    custom_meter_name = OpenStudio::Ruleset::OSArgument::makeStringArgument("custom_meter_name", true)
    custom_meter_name.setDisplayName("Name of Custom Meter:")
    custom_meter_name.setDefaultValue("custom meter name")
    args << custom_meter_name

    #make choice argument for fuel type
    choices = OpenStudio::StringVector.new
    choices << "Electricity"
    choices << "NaturalGas"
    choices << "PropaneGas"
    choices << "FuelOil#1"
    choices << "FuelOil21"
    choices << "Coal"
    choices << "Diesel"
    choices << "Water"
    choices << "Generic"
    choices << "OtherFuel1"
    choices << "OtherFuel2"
    fuel_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("fuel_type", choices, true)
    fuel_type.setDisplayName("Fuel Type:")
    fuel_type.setDefaultValue("Electricity")
    args << fuel_type

    #file path to csv detailing what is on the meter
    file_path = OpenStudio::Ruleset::OSArgument.makeStringArgument("file_path", true)
    file_path.setDisplayName("Enter the path to the file:")
    file_path.setDescription("Example: 'C:\\MyProject\\custom_meter_assignment.csv'")
    args << file_path
    
    add_output_meter = OpenStudio::Ruleset::OSArgument.makeBoolArgument("add_output_meter",true)
    add_output_meter.setDisplayName("Include associated Output:Meter object?")
    add_output_meter.setDefaultValue(true)
    args << add_output_meter
    
    reporting_frequency_chs = OpenStudio::StringVector.new
    reporting_frequency_chs << "detailed"
    reporting_frequency_chs << "timestep"
    reporting_frequency_chs << "hourly"
    reporting_frequency_chs << "daily"
    reporting_frequency_chs << "monthly"
    reporting_frequency = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("reporting_frequency", reporting_frequency_chs, true)
    reporting_frequency.setDisplayName("Select reporting frequency for Output:Meter object:")
    reporting_frequency.setDefaultValue("hourly")
    args << reporting_frequency

    return args
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

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)
    
    # use the built-in error checking 
    if not runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end
    
    #assign the user inputs to variables
    custom_meter_name = runner.getStringArgumentValue("custom_meter_name",user_arguments)
    fuel_type = runner.getStringArgumentValue("fuel_type",user_arguments)
    file_path = runner.getStringArgumentValue("file_path",user_arguments)
    add_output_meter = runner.getBoolArgumentValue("add_output_meter",user_arguments)
    reporting_frequency = runner.getStringArgumentValue("reporting_frequency",user_arguments)
    
    # check the file path for reasonableness
    if file_path.empty?
      runner.registerError("Empty path was entered.")
      return false
    end
    
    runner.registerWarning("Looking for file at file_path 1: #{file_path})")
    # Strip out the potential leading and trailing quotes  
    file_path.gsub!('"','')
    
    meter_definition = "Meter:Custom," + custom_meter_name + "," + fuel_type
    runner.registerWarning("Looking for file at file_path 2: #{file_path})")
    
    
    # build up meter definition
    if !File.exist? file_path
      runner.registerError("The file at path #{file_path} doesn't exist.")
      return false
    else
      raw_data =  CSV.table(file_path)
      # Transform to array of hashes
      variables = raw_data.map { |row| row.to_hash }
      variables.each do |var|
        key_name = var[:key_name]
        output_variable_or_meter_name = var[:output_variable_or_meter_name]
        meter_definition = meter_definition + "," + "#{key_name}" + "," + "#{output_variable_or_meter_name}"
      end
    end
    
    meter_definition = meter_definition + ";"    
    runner.registerInfo("This is the custom meter definition: #{meter_definition}")
    
    num_added = 0
    idf_object = OpenStudio::IdfObject::load(meter_definition)
    idf_object = idf_object.get    
    num_added += add_object(runner, workspace, idf_object)
    
    if add_output_meter
      output_meter_definition = "Output:Meter," + custom_meter_name + "," + reporting_frequency + ";"
      idf_object = OpenStudio::IdfObject::load(output_meter_definition)
      idf_object = idf_object.get    
      num_added += add_object(runner, workspace, idf_object)
      runner.registerFinalCondition("Added #{num_added} meter:custom and output:meter objects.")
    else
      runner.registerFinalCondition("Added #{num_added} custom meter objects.")
    end   

    return true
 
  end 

end 

# register the measure to be used by the application
MeterCustom.new.registerWithApplication