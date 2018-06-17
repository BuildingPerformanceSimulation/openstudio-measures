require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class SwapConstructionInConstructionSet_Test < MiniTest::Unit::TestCase 

  def model_output_path(test_name)
    # always generate test output in specially named 'output' directory so result files are not made part of the measure
    return "#{File.dirname(__FILE__)}/output/#{test_name}.osm"
  end
  
  def test_number_of_arguments_and_argument_names
    # this test ensures that the current test is matched to the measure inputs

    # create an instance of the measure
    measure = SwapConstructionInConstructionSet.new
    
    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(2, arguments.size)
    assert_equal("old_construction", arguments[0].name)
    assert_equal("new_construction", arguments[1].name)
  end

  def test_good_wall_construction_swap
    # this tests swapping a default wall construction
    test_name = "test_good_wall_construction_swap"
    puts "TEST:" + test_name
    
    # create an instance of the measure
    measure = SwapConstructionInConstructionSet.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/office.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values and run the measure
    arguments = measure.arguments(model)

    # set argument values to good values and run the measure
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    old_construction = arguments[0].clone
    assert(old_construction.setValue("Typical Insulated Exterior Mass Wall R-3.45"))
    argument_map["old_construction"] = old_construction

    new_construction = arguments[1].clone
    assert(new_construction.setValue("ASHRAE 189.1-2009 ExtWall Mass ClimateZone 3"))
    argument_map["new_construction"] = new_construction
    
    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    
    # show the output
    show_output(result)
    
    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
    assert(result.warnings.size == 0)
    
    # save the model for testing purposes
    output_file_path = model_output_path(test_name)
    model.save(output_file_path,true)
  end
  
  def test_good_window_construction_swap
    # this tests swapping a default window construction
    test_name = "test_good_window_construction_swap"
    puts "TEST:" + test_name
    
    # create an instance of the measure
    measure = SwapConstructionInConstructionSet.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/office.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values and run the measure
    arguments = measure.arguments(model)

    # set argument values to good values and run the measure
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    old_construction = arguments[0].clone
    assert(old_construction.setValue("U 0.72 SHGC 0.25 Simple Glazing Window"))
    argument_map["old_construction"] = old_construction

    new_construction = arguments[1].clone
    assert(new_construction.setValue("ASHRAE 189.1-2009 ExtWindow ClimateZone 3"))
    argument_map["new_construction"] = new_construction
    
    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    
    # show the output
    show_output(result)
    
    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
    assert(result.warnings.size == 0)
    
    # save the model for testing purposes
    output_file_path = model_output_path(test_name)
    model.save(output_file_path,true)
  end
  
  def test_construction_of_wrong_type
    # this tests a new construction of the wrong type
    test_name = "test_construction_of_wrong_type"
    puts "TEST:" + test_name
    
    # create an instance of the measure
    measure = SwapConstructionInConstructionSet.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/office.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values and run the measure
    arguments = measure.arguments(model)

    # set argument values to good values and run the measure
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    old_construction = arguments[0].clone
    assert(old_construction.setValue("Typical Insulated Exterior Mass Wall R-3.45"))
    argument_map["old_construction"] = old_construction

    new_construction = arguments[1].clone
    assert(new_construction.setValue("ASHRAE 189.1-2009 ExtWindow ClimateZone 3"))
    argument_map["new_construction"] = new_construction
    
    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    
    # show the output
    show_output(result)
    
    # assert that it ran correctly
    #assert_equal("Fail", result.value.valueName)
    #assert(result.errors.size == 1)
    
    # save the model for testing purposes
    output_file_path = model_output_path(test_name)
    model.save(output_file_path,true)
  end

end
