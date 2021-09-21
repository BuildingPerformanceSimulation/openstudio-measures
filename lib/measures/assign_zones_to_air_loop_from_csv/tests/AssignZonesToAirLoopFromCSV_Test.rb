require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class AssignZonesToAirLoopFromCSV_Test < MiniTest::Unit::TestCase
  
  def model_output_path(test_name)
    # always generate test output in specially named 'output' directory so result files are not made part of the measure
    return "#{File.dirname(__FILE__)}/output/#{test_name}.osm"
  end
  
  def test_number_of_arguments_and_argument_names
    # this test ensures that the current test is matched to the measure inputs
    
    # create an instance of the measure
    measure = AssignZonesToAirLoopFromCSV.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    model = translator.loadModel("#{File.dirname(__FILE__)}/office.osm")
    assert((not model.empty?))
    model = model.get

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(4, arguments.size)
    assert_equal("file_path", arguments[0].name)
    assert_equal("default_air_terminal_type", arguments[1].name)
    assert_equal("heating_plant_loop", arguments[2].name)
    assert_equal("cooling_plant_loop", arguments[3].name)
  end
  
  def test_good_uncontrolled
    #this tests good inputs for uncontrolled terminals
    test_name = "test_good_uncontrolled"
    puts "TEST:" + test_name
    
    # create an instance of the measure
    measure = AssignZonesToAirLoopFromCSV.new
    
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
    
    file_path = arguments[0].clone
    assert(file_path.setValue("#{File.dirname(__FILE__)}/ahu_list_example.csv"))
    argument_map["file_path"] = file_path
    
    default_air_terminal_type = arguments[1].clone
    assert(default_air_terminal_type.setValue("AirTerminal:SingleDuct:Uncontrolled"))
    argument_map["default_air_terminal_type"] = default_air_terminal_type
    
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
  
  def test_good_four_pipe_induction
    # this tests good inputs for four-pipe induction terminals
    test_name = "test_good_four_pipe_induction"
    puts "TEST:" + test_name
    
    # create an instance of the measure
    measure = AssignZonesToAirLoopFromCSV.new
    
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
    
    file_path = arguments[0].clone
    assert(file_path.setValue("#{File.dirname(__FILE__)}/ahu_list_example.csv"))
    argument_map["file_path"] = file_path
    
    default_air_terminal_type = arguments[1].clone
    assert(default_air_terminal_type.setValue("AirTerminal:SingleDuct:ConstantVolume:FourPipeInduction"))
    argument_map["default_air_terminal_type"] = default_air_terminal_type
    
    heating_plant_loop = arguments[2].clone
    assert(heating_plant_loop.setValue("Hot Water Loop"))
    argument_map["heating_plant_loop"] = heating_plant_loop

    cooling_plant_loop = arguments[3].clone
    assert(cooling_plant_loop.setValue("Chilled Water Loop"))
    argument_map["cooling_plant_loop"] = cooling_plant_loop
    
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
  
  def test_mislabeled_air_loop
    # this tests a mislabeled air loop in input file
    test_name = "test_mislabeled_air_loop"
    puts "TEST:" + test_name
    
    # create an instance of the measure
    measure = AssignZonesToAirLoopFromCSV.new
    
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
    
    file_path = arguments[0].clone
    assert(file_path.setValue("#{File.dirname(__FILE__)}/ahu_list_example_mislabeled_air_loop.csv"))
    argument_map["file_path"] = file_path
    
    default_air_terminal_type = arguments[1].clone
    assert(default_air_terminal_type.setValue("AirTerminal:SingleDuct:Uncontrolled"))
    argument_map["default_air_terminal_type"] = default_air_terminal_type

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    
    # show the output
    show_output(result)
    
    # assert that it ran correctly
    assert_equal("Fail", result.value.valueName)
    assert(result.warnings.size == 0)
    
    # save the model for testing purposes
    output_file_path = model_output_path(test_name)
    model.save(output_file_path,true)
  end
  
  def test_missing_air_loop
    #  this tests a missing air loop
    test_name = "test_missing_air_loop"
    puts "TEST:" + test_name
    
    # create an instance of the measure
    measure = AssignZonesToAirLoopFromCSV.new
    
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
    
    file_path = arguments[0].clone
    assert(file_path.setValue("#{File.dirname(__FILE__)}/ahu_list_example_missing_air_loop.csv"))
    argument_map["file_path"] = file_path
    
    default_air_terminal_type = arguments[1].clone
    assert(default_air_terminal_type.setValue("AirTerminal:SingleDuct:Uncontrolled"))
    argument_map["default_air_terminal_type"] = default_air_terminal_type

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    
    # show the output
    show_output(result)
    
    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
    assert(result.warnings.size == 1)
    
    # save the model for testing purposes
    output_file_path = model_output_path(test_name)
    model.save(output_file_path,true)
  end
  
  def test_mislabeled_zone
    # this tests a mislabeled zone
    test_name = "test_mislabeled_zone"
    puts "TEST:" + test_name
    
    # create an instance of the measure
    measure = AssignZonesToAirLoopFromCSV.new
    
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
    
    file_path = arguments[0].clone
    assert(file_path.setValue("#{File.dirname(__FILE__)}/ahu_list_example_mislabeled_zone.csv"))
    argument_map["file_path"] = file_path
    
    default_air_terminal_type = arguments[1].clone
    assert(default_air_terminal_type.setValue("AirTerminal:SingleDuct:Uncontrolled"))
    argument_map["default_air_terminal_type"] = default_air_terminal_type

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    
    # show the output
    show_output(result)
    
    # assert that it ran correctly
    assert_equal("Fail", result.value.valueName)
    assert(result.warnings.size == 0)
    
    # save the model for testing purposes
    output_file_path = model_output_path(test_name)
    model.save(output_file_path,true)
  end
  
end