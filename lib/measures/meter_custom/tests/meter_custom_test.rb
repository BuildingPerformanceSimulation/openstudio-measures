require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'

class MeterCustom_Test < Minitest::Test

  def test_number_of_arguments_and_argument_names
    puts 'test_number_of_arguments_and_argument_names'
    # create an instance of the measure
    measure = MeterCustom.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(5, arguments.size)
    assert_equal('custom_meter_name', arguments[0].name)
    assert_equal('fuel_type', arguments[1].name)
    assert_equal('file_path', arguments[2].name)
    assert_equal('add_output_meter', arguments[3].name)
    assert_equal('reporting_frequency', arguments[4].name)
  end

  def test_example_csv_file
    puts 'test_example_csv_file'
    assert(File.exist?("#{File.dirname(__FILE__)}/example_file.csv"))

    # create an instance of the measure
    measure = MeterCustom.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    # set arguments
    custom_meter_name = arguments[0].clone
    assert(custom_meter_name.setValue('test_name'))
    argument_map['custom_meter_name'] = custom_meter_name

    fuel_type = arguments[1].clone
    assert(fuel_type.setValue('Electricity'))
    argument_map['fuel_type'] = fuel_type

    file_path = arguments[2].clone
    assert(file_path.setValue("#{File.dirname(__FILE__)}/example_file.csv"))
    argument_map['file_path'] = file_path

    add_output_meter = arguments[3].clone
    assert(add_output_meter.setValue(true))
    argument_map['add_output_meter'] = add_output_meter

    reporting_frequency = arguments[4].clone
    assert(reporting_frequency.setValue('hourly'))
    argument_map['reporting_frequency'] = reporting_frequency

    # run the measure and show the output
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert_equal('Success', result.value.valueName)
  end

  def test_bad_path
    puts 'test_bad_path'

    # create an instance of the measure
    measure = MeterCustom.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    # set file path argument
    file_path = arguments[2].clone
    assert(file_path.setValue("#{File.dirname(__FILE__)}/does_not_exist.csv"))
    argument_map['file_path'] = file_path

    # run the measure and show the output
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert_equal('Fail', result.value.valueName)
  end
end
