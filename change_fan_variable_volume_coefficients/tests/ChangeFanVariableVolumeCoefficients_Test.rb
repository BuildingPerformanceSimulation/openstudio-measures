require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

#Goals of testing:
# against various versions of Ruby
# against various versions of OpenStudio
# using combinations of argument values
# against a variety of permutations of input models
# for general runtime errors
# for valid IDF output (may even run EnergyPlus to confirm)
# for reporting measure output quality

class ChangeFanVariableVolumeCoefficients_Test < MiniTest::Unit::TestCase

  def model_with_HVAC_path
    return "#{File.dirname(__FILE__)}/OfficeWithHVAC.osm"
  end

  def model_without_HVAC_path
    return "#{File.dirname(__FILE__)}/OfficeWithoutHVAC.osm"
  end

  def run_dir(test_name)
    # always generate test output in specially named 'output' directory so result files are not made part of the measure
    return "#{File.dirname(__FILE__)}/output/#{test_name}"
  end

  def model_out_path(test_name)
    return "#{run_dir(test_name)}/out.osm"
  end
  
  def test_number_of_arguments_and_argument_names
    #this test ensures that the current test is matched to the measure inputs
    
    # create an instance of the measure
    measure = ChangeFanVariableVolumeCoefficients.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    model = translator.loadModel(model_with_HVAC_path)
    assert((not model.empty?))
    model = model.get

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(2, arguments.size)    
    assert_equal("fan_choice", arguments[0].name)
    assert_equal("coeff_choice", arguments[1].name) 
  end

  def test_all_fans
    #this measure tests a curve applied to all fans
    test_name = "test_all_fans"

    # create an instance of the measure
    measure = ChangeFanVariableVolumeCoefficients.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    model = translator.loadModel(model_with_HVAC_path)
    assert((not model.empty?))
    model = model.get

    # get arguments
    arguments = measure.arguments(model)
    assert_equal(2, arguments.size)
    assert_equal("fan_choice", arguments[0].name)
    assert_equal("coeff_choice", arguments[1].name)

    # set argument values to good values and run the measure on model
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    fan_choice = arguments[0].clone
    assert(fan_choice.setValue("*All Variable Volume Fans*"))
    argument_map["fan_choice"] = fan_choice

    coeff_choice = arguments[1].clone
    assert(coeff_choice.setValue("No SP Reset VSD Fan"))
    argument_map["coeff_choice"] = coeff_choice
    
    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    
    # show the output
    show_output(result)
    
    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
    assert(result.warnings.size == 0)
    
    #save the model for testing purposes
    if !File.exist?(run_dir(test_name))
      FileUtils.mkdir_p(run_dir(test_name))
    end
    assert(File.exist?(run_dir(test_name)))    
    output_file_path = model_out_path(test_name)
    model.save(output_file_path,true)
  end

  def test_no_HVAC
    #this measure tests a curve applied to all fans
    test_name = "test_no_HVAC"

    # create an instance of the measure
    measure = ChangeFanVariableVolumeCoefficients.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    model = translator.loadModel(model_without_HVAC_path)
    assert((not model.empty?))
    model = model.get

    # get arguments
    arguments = measure.arguments(model)
    assert_equal(2, arguments.size)
    assert_equal("fan_choice", arguments[0].name)
    assert_equal("coeff_choice", arguments[1].name)

    # set argument values to good values and run the measure on model
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    fan_choice = arguments[0].clone
    assert(fan_choice.setValue("*All Variable Volume Fans*")) 
    argument_map["fan_choice"] = fan_choice

    coeff_choice = arguments[1].clone
    assert(coeff_choice.setValue("No SP Reset VSD Fan"))
    argument_map["coeff_choice"] = coeff_choice
    
    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    
    # show the output
    show_output(result)
    
    # assert that it ran correctly
    assert_equal("Fail", result.value.valueName)
    assert(result.warnings.size == 0)
    
    #save the model for testing purposes
    if !File.exist?(run_dir(test_name))
      FileUtils.mkdir_p(run_dir(test_name))
    end
    assert(File.exist?(run_dir(test_name)))    
    output_file_path = model_out_path(test_name)
    model.save(output_file_path,true)
  end
  
  def test_single_fan
    #this measure tests a curve applied to all fans
    test_name = "test_single_fan"

    # create an instance of the measure
    measure = ChangeFanVariableVolumeCoefficients.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    model = translator.loadModel(model_with_HVAC_path)
    assert((not model.empty?))
    model = model.get

    # get arguments
    arguments = measure.arguments(model)
    assert_equal(2, arguments.size)
    assert_equal("fan_choice", arguments[0].name)
    assert_equal("coeff_choice", arguments[1].name)

    # set argument values to good values and run the measure on model
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    fan_choice = arguments[0].clone
    assert(fan_choice.setValue("VAV_bot WITH REHEAT Fan"))    
    argument_map["fan_choice"] = fan_choice

    coeff_choice = arguments[1].clone
    assert(coeff_choice.setValue("No SP Reset VSD Fan"))
    argument_map["coeff_choice"] = coeff_choice
    
    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    
    # show the output
    show_output(result)
    
    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
    assert(result.warnings.size == 0)
    
    #save the model for testing purposes
    if !File.exist?(run_dir(test_name))
      FileUtils.mkdir_p(run_dir(test_name))
    end
    assert(File.exist?(run_dir(test_name)))    
    output_file_path = model_out_path(test_name)
    model.save(output_file_path,true)
  end
end