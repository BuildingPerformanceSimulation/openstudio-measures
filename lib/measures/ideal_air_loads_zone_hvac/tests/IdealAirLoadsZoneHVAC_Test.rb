require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class IdealAirLoadsZoneHVAC_Test < Minitest::Test

  def model_out_path(test_name)
    # always generate test output in specially named 'output' directory so result files are not made part of the measure
    return "#{File.dirname(__FILE__)}/output/#{test_name}.osm"
  end

  def test_number_of_arguments_and_argument_names
    #this test ensures that the current test is matched to the measure inputs

    # create an instance of the measure
    measure = IdealAirLoadsZoneHVAC.new

    #load the example workspace
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(15, arguments.size)
    assert_equal("availability_schedule", arguments[0].name)
    assert_equal("heating_availability_schedule", arguments[1].name)
    assert_equal("cooling_availability_schedule", arguments[2].name)
    assert_equal("heating_limit_type", arguments[3].name)
    assert_equal("cooling_limit_type", arguments[4].name)
    assert_equal("dehumid_type", arguments[5].name)
    assert_equal("cooling_sensible_heat_ratio", arguments[6].name)
    assert_equal("humid_type", arguments[7].name)
    assert_equal("include_outdoor_air", arguments[8].name)
    assert_equal("enable_dcv", arguments[9].name)
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
    measure = IdealAirLoadsZoneHVAC.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/office.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure::OSArgumentMap.new

    availability_schedule = arguments[0].clone
    assert(availability_schedule.setValue("HVAC Availability Schedule"))
    argument_map["availability_schedule"] = availability_schedule

    heating_availability_schedule = arguments[1].clone
    assert(heating_availability_schedule.setValue("Default Always On"))
    argument_map["heating_availability_schedule"] = heating_availability_schedule

    cooling_availability_schedule = arguments[2].clone
    assert(cooling_availability_schedule.setValue("Default Always On"))
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

    include_outdoor_air = arguments[8].clone
    assert(include_outdoor_air.setValue(true))
    argument_map["include_outdoor_air"] = include_outdoor_air

    enable_dcv = arguments[9].clone
    assert(enable_dcv.setValue(false))
    argument_map["enable_dcv"] = enable_dcv

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
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
    assert(result.warnings.size == 0)

    #save the model for testing purposes
    if !File.exist?("#{File.dirname(__FILE__)}/output")
      FileUtils.mkdir_p("#{File.dirname(__FILE__)}/output")
    end
    output_file_path = model_out_path(test_name)
    model.save(output_file_path, true)
  end

  def test_bad_oa_input
    #this measure tests a curve applied to all fans
    test_name = "test_bad_oa_input"

    # create an instance of the measure
    measure = IdealAirLoadsZoneHVAC.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/office_no_design_oa.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure::OSArgumentMap.new

    availability_schedule = arguments[0].clone
    assert(availability_schedule.setValue("HVAC Availability Schedule"))
    argument_map["availability_schedule"] = availability_schedule

    heating_availability_schedule = arguments[1].clone
    assert(heating_availability_schedule.setValue("Default Always On"))
    argument_map["heating_availability_schedule"] = heating_availability_schedule

    cooling_availability_schedule = arguments[2].clone
    assert(cooling_availability_schedule.setValue("Default Always On"))
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

    include_outdoor_air = arguments[8].clone
    assert(include_outdoor_air.setValue(true))
    argument_map["include_outdoor_air"] = include_outdoor_air

    enable_dcv = arguments[9].clone
    assert(enable_dcv.setValue(false))
    argument_map["enable_dcv"] = enable_dcv

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
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal("Fail", result.value.valueName)
    assert(result.warnings.size == 0)

    #save the model for testing purposes
    if !File.exist?("#{File.dirname(__FILE__)}/output")
      FileUtils.mkdir_p("#{File.dirname(__FILE__)}/output")
    end
    output_file_path = model_out_path(test_name)
    model.save(output_file_path, true)
  end

  def test_no_oa_inputs
    #this measure tests a curve applied to all fans
    test_name = "test_no_oa_inputs"

    # create an instance of the measure
    measure = IdealAirLoadsZoneHVAC.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/office.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure::OSArgumentMap.new

    availability_schedule = arguments[0].clone
    assert(availability_schedule.setValue("HVAC Availability Schedule"))
    argument_map["availability_schedule"] = availability_schedule

    heating_availability_schedule = arguments[1].clone
    assert(heating_availability_schedule.setValue("Default Always On"))
    argument_map["heating_availability_schedule"] = heating_availability_schedule

    cooling_availability_schedule = arguments[2].clone
    assert(cooling_availability_schedule.setValue("Default Always On"))
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

    include_outdoor_air = arguments[8].clone
    assert(include_outdoor_air.setValue(false))
    argument_map["include_outdoor_air"] = include_outdoor_air

    enable_dcv = arguments[9].clone
    assert(enable_dcv.setValue(false))
    argument_map["enable_dcv"] = enable_dcv

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
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
    assert(result.warnings.size == 1)

    #save the model for testing purposes
    if !File.exist?("#{File.dirname(__FILE__)}/output")
      FileUtils.mkdir_p("#{File.dirname(__FILE__)}/output")
    end
    output_file_path = model_out_path(test_name)
    model.save(output_file_path, true)
  end
end
