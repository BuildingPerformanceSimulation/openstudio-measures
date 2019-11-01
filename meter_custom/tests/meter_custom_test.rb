require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'

class MeterCustom_Test < Minitest::Test

  def test_number_of_arguments_and_argument_names
    puts 'test_number_of_arguments_and_argument_names'
    # create an instance of the measure
    measure = MeterCustom.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments
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
    arguments = measure.arguments

    # set file path argument
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)
    file_path = arguments[2].clone
    assert(file_path.setValue("#{File.dirname(__FILE__)}/example_file.csv"))
    argument_map['file_path'] = file_path

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
    arguments = measure.arguments

    # set file path argument
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)
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
