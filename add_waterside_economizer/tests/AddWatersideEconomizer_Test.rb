require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class AddWatersideEconomizer_Test < MiniTest::Unit::TestCase  
  
  def model_output_path(test_name)
    # always generate test output in specially named 'output' directory so result files are not made part of the measure
    return "#{File.dirname(__FILE__)}/output/#{test_name}.osm"
  end
  
  def test_number_of_arguments_and_argument_names
    #this test ensures that the current test is matched to the measure inputs
    
    # create an instance of the measure
    measure = AddWatersideEconomizer.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    model = translator.loadModel("#{File.dirname(__FILE__)}/office.osm")
    assert((not model.empty?))
    model = model.get

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(2, arguments.size)
    assert_equal("condenser_water_loop", arguments[0].name)
    assert_equal("chilled_water_loop", arguments[1].name)
  end
  
  def test_good_arguments
    #this measure tests a curve applied to all fans
    test_name = "test_good_arguments"
    puts "TEST:" + test_name
    
    # create an instance of the measure
    measure = AddWatersideEconomizer.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    model = translator.loadModel("#{File.dirname(__FILE__)}/office.osm")
    assert((not model.empty?))
    model = model.get
    
    # set argument values to good values and run the measure on model
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    
    condenser_water_loop = arguments[0].clone
    assert(condenser_water_loop.setValue("Condenser Water Loop"))
    argument_map["condenser_water_loop"] = condenser_water_loop

    chilled_water_loop = arguments[1].clone
    assert(chilled_water_loop.setValue("Chilled Water Loop"))
    argument_map["chilled_water_loop"] = chilled_water_loop
    
    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    
    # show the output
    show_output(result)
    
    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
    assert(result.warnings.size == 0)
    
    #save the model for testing purposes
    output_file_path = model_output_path(test_name)
    model.save(output_file_path,true)
  end
  
end