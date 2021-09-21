require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class AddHourlyMeters_Test < MiniTest::Unit::TestCase

  def test_number_of_arguments_and_argument_names
    # this test ensures that the current test is matched to the measure inputs
    
    # create an instance of the measure
    measure = AddHourlyMeters.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(0, arguments.size)
  end

  def test_run
    # create an instance of the measure
    measure = AddHourlyMeters.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # set arguments and run the measure
    arguments = measure.arguments(model)    
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 0)
  end

  def test_with_existing_meter
    # create an instance of the measure
    measure = AddHourlyMeters.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # make an empty model
    model = OpenStudio::Model::Model.new
    
    #make an existing meter
    meter = OpenStudio::Model::OutputMeter.new(model)
    meter.setName("Electricity:Facility")
    meter.setReportingFrequency("Timestep")

    # set arguments and run the measure
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 1)
  end
  
end
