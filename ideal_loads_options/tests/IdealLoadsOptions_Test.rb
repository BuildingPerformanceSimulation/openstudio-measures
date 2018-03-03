require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class IdealLoadsOptions_Test < MiniTest::Unit::TestCase

  def workspace_out_path(test_name)
    # always generate test output in specially named 'output' directory so result files are not made part of the measure
    return "#{File.dirname(__FILE__)}/output/#{test_name}.idf"
  end

  def test_number_of_arguments_and_argument_names
    #this test ensures that the current test is matched to the measure inputs
    
    # create an instance of the measure
    measure = IdealLoadsOptions.new

    #load the example workspace
    workspace = OpenStudio::Workspace.new
    
    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(workspace)
    assert_equal(15, arguments.size)
    assert_equal("availability_schedule", arguments[0].name)
    assert_equal("heating_availability_schedule", arguments[1].name)
    assert_equal("cooling_availability_schedule", arguments[2].name)
    assert_equal("heating_limit_type", arguments[3].name)
    assert_equal("cooling_limit_type", arguments[4].name)
    assert_equal("dehumid_type", arguments[5].name)
    assert_equal("cooling_sensible_heat_ratio", arguments[6].name)
    assert_equal("humid_type", arguments[7].name)
    assert_equal("oa_spec", arguments[8].name)
    assert_equal("dcv_type", arguments[9].name)
    assert_equal("economizer_type", arguments[10].name)
    assert_equal("heat_recovery_type", arguments[11].name)
    assert_equal("sensible_effectiveness", arguments[12].name)
    assert_equal("latent_effectiveness", arguments[13].name)
    assert_equal("add_meters", arguments[14].name)
  end

  def test_good_inputs
    #this measure tests a curve applied to all fans
    test_name = "test_good_inputs"

    # create an instance of the measure
    measure = IdealLoadsOptions.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/test_v2.4_office_ideal.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)
    
    # set argument values to good values
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    
    availability_schedule = arguments[0].clone
    assert(availability_schedule.setValue("Always On Discrete"))
    argument_map["availability_schedule"] = availability_schedule

    heating_availability_schedule = arguments[1].clone
    assert(heating_availability_schedule.setValue("Always On Discrete"))
    argument_map["heating_availability_schedule"] = heating_availability_schedule
    
    cooling_availability_schedule = arguments[2].clone
    assert(cooling_availability_schedule.setValue("Always On Discrete"))
    argument_map["cooling_availability_schedule"] = cooling_availability_schedule
    
    heating_limit_type = arguments[3].clone
    assert(heating_limit_type.setValue("NoLimit"))
    argument_map["heating_limit_type"] = heating_limit_type

    cooling_limit_type = arguments[4].clone
    assert(cooling_limit_type.setValue("NoLimit"))
    argument_map["cooling_limit_type"] = cooling_limit_type
    
    dehumid_type = arguments[5].clone
    assert(dehumid_type.setValue("ConstantSensibleHeatRatio"))
    argument_map["dehumid_type"] = dehumid_type
    
    cooling_sensible_heat_ratio = arguments[6].clone
    assert(cooling_sensible_heat_ratio.setValue(0.7))
    argument_map["cooling_sensible_heat_ratio"] = cooling_sensible_heat_ratio
    
    humid_type = arguments[7].clone
    assert(humid_type.setValue("None"))
    argument_map["humid_type"] = humid_type

    oa_spec = arguments[8].clone
    assert(oa_spec.setValue("Use Individual Zone Design Outdoor Air"))
    argument_map["oa_spec"] = oa_spec
        
    dcv_type = arguments[9].clone
    assert(dcv_type.setValue("OccupancySchedule"))
    argument_map["dcv_type"] = dcv_type

    economizer_type = arguments[10].clone
    assert(economizer_type.setValue("DifferentialDryBulb"))
    argument_map["economizer_type"] = economizer_type
    
    heat_recovery_type = arguments[11].clone
    assert(heat_recovery_type.setValue("Sensible"))
    argument_map["heat_recovery_type"] = heat_recovery_type
    
    sensible_effectiveness = arguments[12].clone
    assert(sensible_effectiveness.setValue(0.7))
    argument_map["sensible_effectiveness"] = sensible_effectiveness
    
    latent_effectiveness = arguments[13].clone
    assert(latent_effectiveness.setValue(0.65))
    argument_map["latent_effectiveness"] = latent_effectiveness
    
    add_meters = arguments[14].clone
    assert(add_meters.setValue(true))
    argument_map["add_meters"] = add_meters
    
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

  def test_bad_oa_input
    #this measure tests a curve applied to all fans
    test_name = "test_bad_oa_input"

    # create an instance of the measure
    measure = IdealLoadsOptions.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/test_v2.4_office_ideal_nodesignOA.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)
    
    # set argument values to good values
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    
    availability_schedule = arguments[0].clone
    assert(availability_schedule.setValue("Always On Discrete"))
    argument_map["availability_schedule"] = availability_schedule

    heating_availability_schedule = arguments[1].clone
    assert(heating_availability_schedule.setValue("Always On Discrete"))
    argument_map["heating_availability_schedule"] = heating_availability_schedule
    
    cooling_availability_schedule = arguments[2].clone
    assert(cooling_availability_schedule.setValue("Always On Discrete"))
    argument_map["cooling_availability_schedule"] = cooling_availability_schedule
    
    heating_limit_type = arguments[3].clone
    assert(heating_limit_type.setValue("NoLimit"))
    argument_map["heating_limit_type"] = heating_limit_type

    cooling_limit_type = arguments[4].clone
    assert(cooling_limit_type.setValue("NoLimit"))
    argument_map["cooling_limit_type"] = cooling_limit_type
    
    dehumid_type = arguments[5].clone
    assert(dehumid_type.setValue("ConstantSensibleHeatRatio"))
    argument_map["dehumid_type"] = dehumid_type
    
    cooling_sensible_heat_ratio = arguments[6].clone
    assert(cooling_sensible_heat_ratio.setValue(0.7))
    argument_map["cooling_sensible_heat_ratio"] = cooling_sensible_heat_ratio
    
    humid_type = arguments[7].clone
    assert(humid_type.setValue("None"))
    argument_map["humid_type"] = humid_type

    oa_spec = arguments[8].clone
    assert(oa_spec.setValue("Use Individual Zone Design Outdoor Air"))
    argument_map["oa_spec"] = oa_spec
        
    dcv_type = arguments[9].clone
    assert(dcv_type.setValue("OccupancySchedule"))
    argument_map["dcv_type"] = dcv_type

    economizer_type = arguments[10].clone
    assert(economizer_type.setValue("DifferentialDryBulb"))
    argument_map["economizer_type"] = economizer_type
    
    heat_recovery_type = arguments[11].clone
    assert(heat_recovery_type.setValue("Sensible"))
    argument_map["heat_recovery_type"] = heat_recovery_type
    
    sensible_effectiveness = arguments[12].clone
    assert(sensible_effectiveness.setValue(0.7))
    argument_map["sensible_effectiveness"] = sensible_effectiveness
    
    latent_effectiveness = arguments[13].clone
    assert(latent_effectiveness.setValue(0.65))
    argument_map["latent_effectiveness"] = latent_effectiveness
    
    add_meters = arguments[14].clone
    assert(add_meters.setValue(false))
    argument_map["add_meters"] = add_meters
    
    # run the measure
    measure.run(workspace, runner, argument_map)
    result = runner.result
    
    # show the output
    show_output(result)
    
    # assert that it ran correctly
    assert_equal("Fail", result.value.valueName)
    assert(result.warnings.size == 0)
    
    #save the workspace for testing purposes
    if !File.exist?("#{File.dirname(__FILE__)}/output")
      FileUtils.mkdir_p("#{File.dirname(__FILE__)}/output")
    end
    output_file_path = workspace_out_path(test_name)
    workspace.save(output_file_path,true)
  end

  def test_humidistats
    #this measure tests a curve applied to all fans
    test_name = "test_humidistats"

    # create an instance of the measure
    measure = IdealLoadsOptions.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/test_v2.4_office_ideal_humidistats.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)
    
    # set argument values to good values
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    
    availability_schedule = arguments[0].clone
    assert(availability_schedule.setValue("Always On Discrete"))
    argument_map["availability_schedule"] = availability_schedule

    heating_availability_schedule = arguments[1].clone
    assert(heating_availability_schedule.setValue("Always On Discrete"))
    argument_map["heating_availability_schedule"] = heating_availability_schedule
    
    cooling_availability_schedule = arguments[2].clone
    assert(cooling_availability_schedule.setValue("Always On Discrete"))
    argument_map["cooling_availability_schedule"] = cooling_availability_schedule
    
    heating_limit_type = arguments[3].clone
    assert(heating_limit_type.setValue("NoLimit"))
    argument_map["heating_limit_type"] = heating_limit_type

    cooling_limit_type = arguments[4].clone
    assert(cooling_limit_type.setValue("NoLimit"))
    argument_map["cooling_limit_type"] = cooling_limit_type
    
    dehumid_type = arguments[5].clone
    assert(dehumid_type.setValue("Humidistat"))
    argument_map["dehumid_type"] = dehumid_type
    
    cooling_sensible_heat_ratio = arguments[6].clone
    assert(cooling_sensible_heat_ratio.setValue(0.7))
    argument_map["cooling_sensible_heat_ratio"] = cooling_sensible_heat_ratio
    
    humid_type = arguments[7].clone
    assert(humid_type.setValue("Humidistat"))
    argument_map["humid_type"] = humid_type

    oa_spec = arguments[8].clone
    assert(oa_spec.setValue("Use Individual Zone Design Outdoor Air"))
    argument_map["oa_spec"] = oa_spec
        
    dcv_type = arguments[9].clone
    assert(dcv_type.setValue("OccupancySchedule"))
    argument_map["dcv_type"] = dcv_type

    economizer_type = arguments[10].clone
    assert(economizer_type.setValue("DifferentialDryBulb"))
    argument_map["economizer_type"] = economizer_type
    
    heat_recovery_type = arguments[11].clone
    assert(heat_recovery_type.setValue("Sensible"))
    argument_map["heat_recovery_type"] = heat_recovery_type
    
    sensible_effectiveness = arguments[12].clone
    assert(sensible_effectiveness.setValue(0.7))
    argument_map["sensible_effectiveness"] = sensible_effectiveness
    
    latent_effectiveness = arguments[13].clone
    assert(latent_effectiveness.setValue(0.65))
    argument_map["latent_effectiveness"] = latent_effectiveness
    
    add_meters = arguments[14].clone
    assert(add_meters.setValue(true))
    argument_map["add_meters"] = add_meters
    
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
  
end
