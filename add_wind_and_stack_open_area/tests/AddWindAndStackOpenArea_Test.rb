require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class AddWindAndStackOpenArea_Test < MiniTest::Unit::TestCase

  def workspace_out_path(test_name)
    # always generate test output in specially named 'output' directory so result files are not made part of the measure
    return "#{File.dirname(__FILE__)}/output/#{test_name}.idf"
  end
  
  def test_number_of_arguments_and_argument_names
    # this test ensures that the current test is matched to the measure inputs
    
    # create an instance of the measure
    measure = AddWindAndStackOpenArea.new
    
    #load the example workspace
    workspace = OpenStudio::Workspace.new
    
    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(workspace)
    assert_equal(8, arguments.size)
    assert_equal("construction", arguments[0].name)
    assert_equal("open_area_fraction_schedule", arguments[1].name)
    assert_equal("min_indoor_temp", arguments[2].name)
    assert_equal("max_indoor_temp", arguments[3].name)
    assert_equal("delta_temp", arguments[4].name)
    assert_equal("min_outdoor_temp", arguments[5].name)
    assert_equal("max_outdoor_temp", arguments[6].name)
    assert_equal("max_wind_speed", arguments[7].name)    
  end

  def test_good_inputs
    # this tests good input values
    test_name = "test_good_inputs"
    
    # create an instance of the measure
    measure = AddWindAndStackOpenArea.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/Office.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)
    
    # set argument values to good values
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    
    construction = arguments[0].clone
    assert(construction.setValue("U 0.62 SHGC 0.25 Dbl Ref-C-H Clr 6mm/6mm Air 2"))
    argument_map["construction"] = construction

    open_area_fraction_schedule = arguments[1].clone
    assert(open_area_fraction_schedule.setValue("Wind Stack Open Area Fraction Schedule"))
    argument_map["open_area_fraction_schedule"] = open_area_fraction_schedule

    min_indoor_temp = arguments[2].clone
    assert(min_indoor_temp.setValue(10.0))
    argument_map["min_indoor_temp"] = min_indoor_temp
    
    max_indoor_temp = arguments[3].clone
    assert(max_indoor_temp.setValue(60.0))
    argument_map["max_indoor_temp"] = max_indoor_temp
    
    delta_temp = arguments[4].clone
    assert(delta_temp.setValue(0.0))
    argument_map["delta_temp"] = delta_temp
    
    min_outdoor_temp = arguments[5].clone
    assert(min_outdoor_temp.setValue(18.3333))
    argument_map["min_outdoor_temp"] = min_outdoor_temp

    max_outdoor_temp = arguments[6].clone
    assert(max_outdoor_temp.setValue(25.5556))
    argument_map["max_outdoor_temp"] = max_outdoor_temp
    
    max_wind_speed = arguments[7].clone
    assert(max_wind_speed.setValue(5.4))
    argument_map["max_wind_speed"] = max_wind_speed
    
    # run the measure
    measure.run(workspace, runner, argument_map)
    result = runner.result
    
    # show the output
    show_output(result)
    
    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
    assert(result.warnings.size == 0)
    
    #save the workspace for testing purposes
    if !File.exist?("#{File.dirname(__FILE__)}/output")
      FileUtils.mkdir_p("#{File.dirname(__FILE__)}/output")
    end
    output_file_path = workspace_out_path(test_name)
    workspace.save(output_file_path,true)
  end

  def test_bad_temps
    # this tests bad temperatures
    test_name = "test_bad_temps"
    
    # create an instance of the measure
    measure = AddWindAndStackOpenArea.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/Office.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)
    
    # set argument values to good values
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    
    construction = arguments[0].clone
    assert(construction.setValue("U 0.62 SHGC 0.25 Dbl Ref-C-H Clr 6mm/6mm Air 2"))
    argument_map["construction"] = construction

    open_area_fraction_schedule = arguments[1].clone
    assert(open_area_fraction_schedule.setValue("Wind Stack Open Area Fraction Schedule"))
    argument_map["open_area_fraction_schedule"] = open_area_fraction_schedule

    min_indoor_temp = arguments[2].clone
    assert(min_indoor_temp.setValue(-110.0))
    argument_map["min_indoor_temp"] = min_indoor_temp
    
    max_indoor_temp = arguments[3].clone
    assert(max_indoor_temp.setValue(60.0))
    argument_map["max_indoor_temp"] = max_indoor_temp
    
    delta_temp = arguments[4].clone
    assert(delta_temp.setValue(0.0))
    argument_map["delta_temp"] = delta_temp
    
    min_outdoor_temp = arguments[5].clone
    assert(min_outdoor_temp.setValue(18.3333))
    argument_map["min_outdoor_temp"] = min_outdoor_temp

    max_outdoor_temp = arguments[6].clone
    assert(max_outdoor_temp.setValue(25.5556))
    argument_map["max_outdoor_temp"] = max_outdoor_temp
    
    max_wind_speed = arguments[7].clone
    assert(max_wind_speed.setValue(5.4))
    argument_map["max_wind_speed"] = max_wind_speed
    
    # run the measure
    measure.run(workspace, runner, argument_map)
    result = runner.result
    
    # show the output
    show_output(result)
    
    # assert that it ran correctly
    assert_equal("Fail", result.value.valueName)
    assert(result.warnings.size == 0)
  end
  
  def test_bad_construction
    # this tests an incorrect construction 
    test_name = "test_bad_construction"
    
    # create an instance of the measure
    measure = AddWindAndStackOpenArea.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/Office.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)
    
    # set argument values to good values
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    
    construction = arguments[0].clone
    assert(construction.setValue("U 0.62 SHGC 0.25 Dbl Ref-C-H Clr 6mm/6mm Air 3"))
    argument_map["construction"] = construction

    open_area_fraction_schedule = arguments[1].clone
    assert(open_area_fraction_schedule.setValue("Wind Stack Open Area Fraction Schedule"))
    argument_map["open_area_fraction_schedule"] = open_area_fraction_schedule

    min_indoor_temp = arguments[2].clone
    assert(min_indoor_temp.setValue(10.0))
    argument_map["min_indoor_temp"] = min_indoor_temp
    
    max_indoor_temp = arguments[3].clone
    assert(max_indoor_temp.setValue(60.0))
    argument_map["max_indoor_temp"] = max_indoor_temp
    
    delta_temp = arguments[4].clone
    assert(delta_temp.setValue(0.0))
    argument_map["delta_temp"] = delta_temp
    
    min_outdoor_temp = arguments[5].clone
    assert(min_outdoor_temp.setValue(18.3333))
    argument_map["min_outdoor_temp"] = min_outdoor_temp

    max_outdoor_temp = arguments[6].clone
    assert(max_outdoor_temp.setValue(25.5556))
    argument_map["max_outdoor_temp"] = max_outdoor_temp
    
    max_wind_speed = arguments[7].clone
    assert(max_wind_speed.setValue(5.4))
    argument_map["max_wind_speed"] = max_wind_speed
    
    # run the measure
    measure.run(workspace, runner, argument_map)
    result = runner.result
    
    # show the output
    show_output(result)
    
    # assert that it ran correctly
    assert_equal("Fail", result.value.valueName)
    assert(result.warnings.size == 0)
  end
  
end