require 'openstudio'
require 'csv'

# start the measure
class MeterCustom < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    return 'Meter Custom'
  end

  # human readable description
  def description
    return 'This measure creates a Custom Meter to combine output variables and meters from a user-defined .csv file. This is helpful for combining energy use by floor, by space type, or for specific zones. You can easily create this grouping by generating the SpaceTypeReport, then filtering and copying the zones you want to group together. An example .csv file is included in the resources folder for this measure. The measure optionally outputs the custom meter.  An example file is included in the tests directory of this measure.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'This measure creates a Meter:Custom object based on a user-defined .csv file and optionally adds an Output:Meter for the custom meter to save the values to the .eio and .mtr files. Common errors include (1) using space names instead of thermal zone names as key variables, (2) not specifying the Zone variable, e.g. Lights Electric Energy vs. Zone Lights Electric Energy, (3) combining different fuel types on the same meter, and (4) Requesting a variable or meter that is not there, e.g., if a zone has no electric equipment, you cannot request a Zone Electric Equipment Electric Energy variable.'
  end

  # define the arguments that the user will input
  def arguments
    args = OpenStudio::Measure::OSArgumentVector.new

    # make string argument for meter name
    custom_meter_name = OpenStudio::Measure::OSArgument.makeStringArgument('custom_meter_name', true)
    custom_meter_name.setDisplayName('Name of Custom Meter:')
    custom_meter_name.setDefaultValue('custom_meter_name')
    args << custom_meter_name

    # make choice argument for fuel type
    choices = OpenStudio::StringVector.new
    choices << 'Electricity'
    choices << 'NaturalGas'
    choices << 'PropaneGas'
    choices << 'FuelOil#1'
    choices << 'FuelOil21'
    choices << 'Coal'
    choices << 'Diesel'
    choices << 'Water'
    choices << 'Generic'
    choices << 'OtherFuel1'
    choices << 'OtherFuel2'
    fuel_type = OpenStudio::Measure::OSArgument::makeChoiceArgument('fuel_type', choices, true)
    fuel_type.setDisplayName('Fuel Type:')
    fuel_type.setDefaultValue('Electricity')
    args << fuel_type

    # file path to csv detailing what is on the meter
    file_path = OpenStudio::Measure::OSArgument.makeStringArgument('file_path', true)
    file_path.setDisplayName('Enter the path to the file:')
    file_path.setDefaultValue("'C:\\MyProject\\custom_meter_assignment.csv'")
    args << file_path

    add_output_meter = OpenStudio::Measure::OSArgument.makeBoolArgument('add_output_meter',true)
    add_output_meter.setDisplayName('Include associated Output:Meter object?')
    add_output_meter.setDefaultValue(true)
    args << add_output_meter

    reporting_frequency_chs = OpenStudio::StringVector.new
    reporting_frequency_chs << 'detailed'
    reporting_frequency_chs << 'timestep'
    reporting_frequency_chs << 'hourly'
    reporting_frequency_chs << 'daily'
    reporting_frequency_chs << 'monthly'
    reporting_frequency = OpenStudio::Measure::OSArgument::makeChoiceArgument('reporting_frequency', reporting_frequency_chs, true)
    reporting_frequency.setDisplayName('Select reporting frequency for Output:Meter object:')
    reporting_frequency.setDefaultValue('hourly')
    args << reporting_frequency

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking 
    unless runner.validateUserArguments(arguments, user_arguments)
      return false
    end

    # assign the user inputs to variables
    custom_meter_name = runner.getStringArgumentValue('custom_meter_name', user_arguments)
    fuel_type = runner.getStringArgumentValue('fuel_type', user_arguments)
    file_path = runner.getStringArgumentValue('file_path', user_arguments)
    add_output_meter = runner.getBoolArgumentValue('add_output_meter', user_arguments)
    reporting_frequency = runner.getStringArgumentValue('reporting_frequency', user_arguments)

    # check the file path for reasonableness
    if file_path.empty?
      runner.registerError('Empty path was entered.')
      return false
    end

    # strip out the potential leading and trailing quotes
    file_path = file_path.gsub('"', '')

    # check for and read in file
    unless File.exist?(file_path)
      runner.registerError("No file found at file path '#{file_path}'")
      return false
    end

    # read in csv and transform to an array of hashes
    runner.registerInfo("Reading file at file path '#{file_path}'")
    raw_data =  CSV.table(file_path)
    variables = raw_data.map { |row| row.to_hash }
    if variables.empty?
      runner.registerError("File at file path '#{file_path}' is empty")
      return false
    end

    # build up meter definition
    runner.registerInfo("Creating custom meter: '#{custom_meter_name}'")
    meter_custom = OpenStudio::Model::MeterCustom.new(model)
    meter_custom.setName(custom_meter_name)
    meter_custom.setFuelType(fuel_type)
    variables.each do |var|
      meter_custom.addKeyVarGroup(var[:key_name], var[:output_variable_or_meter_name])
    end

    # add output meter
    if add_output_meter
      output_meter = OpenStudio::Model::OutputMeter.new(model)
      output_meter.setName(custom_meter_name)
      output_meter.setReportingFrequency(reporting_frequency)
      runner.registerInfo("Adding meter for '#{meter_custom.name}' reporting #{reporting_frequency}")
    end

    # reporting final condition
    runner.registerFinalCondition("Added a custom meter object with #{meter_custom.numKeyVarGroups} key-variable groups.")

    return true
  end
end

# register the measure to be used by the application
MeterCustom.new.registerWithApplication