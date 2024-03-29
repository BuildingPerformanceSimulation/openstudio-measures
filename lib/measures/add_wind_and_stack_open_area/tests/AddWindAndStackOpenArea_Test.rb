require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class AddWindAndStackOpenArea_Test < MiniTest::Test

  def model_out_path(test_name)
    # always generate test output in specially named 'output' directory so result files are not made part of the measure
    return "#{File.dirname(__FILE__)}/output/#{test_name}.osm"
  end

  def test_number_of_arguments_and_argument_names
    # this test ensures that the current test is matched to the measure inputs
    test_name = 'test_number_of_arguments_and_argument_names'

    # create an instance of the measure
    measure = AddWindAndStackOpenArea.new

    # make an empty model
    model = OpenStudio::Model::Model.new
  
    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(13, arguments.size)
    assert_equal('construction', arguments[0].name)
    assert_equal('open_area_fraction_schedule', arguments[1].name)
    assert_equal('min_indoor_temp', arguments[2].name)
    assert_equal('min_indoor_temp_schedule', arguments[3].name)
    assert_equal('max_indoor_temp', arguments[4].name)
    assert_equal('max_indoor_temp_schedule', arguments[5].name)
    assert_equal('delta_temp', arguments[6].name)
    assert_equal('delta_temp_schedule', arguments[7].name)
    assert_equal('min_outdoor_temp', arguments[8].name)
    assert_equal('min_outdoor_temp_schedule', arguments[9].name)
    assert_equal('max_outdoor_temp', arguments[10].name)
    assert_equal('max_outdoor_temp_schedule', arguments[11].name)
    assert_equal('max_wind_speed', arguments[12].name)
  end

  def test_good_inputs
    # this tests good input values
    test_name = 'test_good_inputs'

    # create an instance of the measure
    measure = AddWindAndStackOpenArea.new

    # create an instance of a runner
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + '/Office.osm')
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure::OSArgumentMap.new

    construction = arguments[0].clone
    assert(construction.setValue('U 0.62 SHGC 0.25 Dbl Ref-C-H Clr 6mm/6mm Air 2'))
    argument_map['construction'] = construction

    open_area_fraction_schedule = arguments[1].clone
    assert(open_area_fraction_schedule.setValue('Wind Stack Open Area Fraction Schedule'))
    argument_map['open_area_fraction_schedule'] = open_area_fraction_schedule

    min_indoor_temp = arguments[2].clone
    assert(min_indoor_temp.setValue(10.0))
    argument_map['min_indoor_temp'] = min_indoor_temp

    min_indoor_temp_schedule = arguments[3].clone
    argument_map['min_indoor_temp_schedule'] = min_indoor_temp_schedule

    max_indoor_temp = arguments[4].clone
    assert(max_indoor_temp.setValue(60.0))
    argument_map['max_indoor_temp'] = max_indoor_temp

    max_indoor_temp_schedule = arguments[5].clone
    argument_map['max_indoor_temp_schedule'] = max_indoor_temp_schedule

    delta_temp = arguments[6].clone
    assert(delta_temp.setValue(0.0))
    argument_map['delta_temp'] = delta_temp

    delta_temp_schedule = arguments[7].clone
    argument_map['delta_temp_schedule'] = delta_temp_schedule

    min_outdoor_temp = arguments[8].clone
    assert(min_outdoor_temp.setValue(18.3333))
    argument_map['min_outdoor_temp'] = min_outdoor_temp

    min_outdoor_temp_schedule = arguments[9].clone
    argument_map['min_outdoor_temp_schedule'] = min_outdoor_temp_schedule

    max_outdoor_temp = arguments[10].clone
    assert(max_outdoor_temp.setValue(25.5556))
    argument_map['max_outdoor_temp'] = max_outdoor_temp

    max_outdoor_temp_schedule = arguments[11].clone
    argument_map['max_outdoor_temp_schedule'] = max_outdoor_temp_schedule

    max_wind_speed = arguments[12].clone
    assert(max_wind_speed.setValue(5.4))
    argument_map['max_wind_speed'] = max_wind_speed

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
    assert(result.warnings.size == 0)

    #save the model for testing purposes
    if !File.exist?("#{File.dirname(__FILE__)}/output")
      FileUtils.mkdir_p("#{File.dirname(__FILE__)}/output")
    end
    output_file_path = model_out_path(test_name)
    model.save(output_file_path, true)
  end

  def test_bad_temps
    # this tests bad temperatures
    test_name = 'test_bad_temps'

    # create an instance of the measure
    measure = AddWindAndStackOpenArea.new

    # create an instance of a runner
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + '/Office.osm')
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure::OSArgumentMap.new

    construction = arguments[0].clone
    assert(construction.setValue('U 0.62 SHGC 0.25 Dbl Ref-C-H Clr 6mm/6mm Air 2'))
    argument_map['construction'] = construction

    open_area_fraction_schedule = arguments[1].clone
    assert(open_area_fraction_schedule.setValue('Wind Stack Open Area Fraction Schedule'))
    argument_map['open_area_fraction_schedule'] = open_area_fraction_schedule

    min_indoor_temp = arguments[2].clone
    assert(min_indoor_temp.setValue(-110.0))
    argument_map['min_indoor_temp'] = min_indoor_temp

    min_indoor_temp_schedule = arguments[3].clone
    argument_map['min_indoor_temp_schedule'] = min_indoor_temp_schedule

    max_indoor_temp = arguments[4].clone
    assert(max_indoor_temp.setValue(40.0))
    argument_map['max_indoor_temp'] = max_indoor_temp

    max_indoor_temp_schedule = arguments[5].clone
    argument_map['max_indoor_temp_schedule'] = max_indoor_temp_schedule

    delta_temp = arguments[6].clone
    assert(delta_temp.setValue(2.0))
    argument_map['delta_temp'] = delta_temp

    delta_temp_schedule = arguments[7].clone
    argument_map['delta_temp_schedule'] = delta_temp_schedule

    min_outdoor_temp = arguments[8].clone
    assert(min_outdoor_temp.setValue(18.3333))
    argument_map['min_outdoor_temp'] = min_outdoor_temp

    min_outdoor_temp_schedule = arguments[9].clone
    argument_map['min_outdoor_temp_schedule'] = min_outdoor_temp_schedule

    max_outdoor_temp = arguments[10].clone
    assert(max_outdoor_temp.setValue(25.5556))
    argument_map['max_outdoor_temp'] = max_outdoor_temp

    max_outdoor_temp_schedule = arguments[11].clone
    argument_map['max_outdoor_temp_schedule'] = max_outdoor_temp_schedule

    max_wind_speed = arguments[12].clone
    assert(max_wind_speed.setValue(5.4))
    argument_map['max_wind_speed'] = max_wind_speed

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal('Fail', result.value.valueName)
    assert(result.warnings.size == 0)
  end

  def test_bad_construction
    # this tests an incorrect construction 
    test_name = 'test_bad_construction'

    # create an instance of the measure
    measure = AddWindAndStackOpenArea.new

    # create an instance of a runner
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + '/Office.osm')
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure::OSArgumentMap.new

    construction = arguments[0].clone
    assert(construction.setValue('U 0.62 SHGC 0.25 Dbl Ref-C-H Clr 6mm/6mm Air 3'))
    argument_map['construction'] = construction

    open_area_fraction_schedule = arguments[1].clone
    assert(open_area_fraction_schedule.setValue('Wind Stack Open Area Fraction Schedule'))
    argument_map['open_area_fraction_schedule'] = open_area_fraction_schedule

    min_indoor_temp = arguments[2].clone
    assert(min_indoor_temp.setValue(21.67))
    argument_map['min_indoor_temp'] = min_indoor_temp

    min_indoor_temp_schedule = arguments[3].clone
    argument_map['min_indoor_temp_schedule'] = min_indoor_temp_schedule

    max_indoor_temp = arguments[4].clone
    assert(max_indoor_temp.setValue(40.0))
    argument_map['max_indoor_temp'] = max_indoor_temp

    max_indoor_temp_schedule = arguments[5].clone
    argument_map['max_indoor_temp_schedule'] = max_indoor_temp_schedule

    delta_temp = arguments[6].clone
    assert(delta_temp.setValue(2.0))
    argument_map['delta_temp'] = delta_temp

    delta_temp_schedule = arguments[7].clone
    argument_map['delta_temp_schedule'] = delta_temp_schedule

    min_outdoor_temp = arguments[8].clone
    assert(min_outdoor_temp.setValue(18.3333))
    argument_map['min_outdoor_temp'] = min_outdoor_temp

    min_outdoor_temp_schedule = arguments[9].clone
    argument_map['min_outdoor_temp_schedule'] = min_outdoor_temp_schedule

    max_outdoor_temp = arguments[10].clone
    assert(max_outdoor_temp.setValue(25.5556))
    argument_map['max_outdoor_temp'] = max_outdoor_temp

    max_outdoor_temp_schedule = arguments[11].clone
    argument_map['max_outdoor_temp_schedule'] = max_outdoor_temp_schedule

    max_wind_speed = arguments[12].clone
    assert(max_wind_speed.setValue(5.4))
    argument_map['max_wind_speed'] = max_wind_speed

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal('NA', result.value.valueName)
    assert(result.warnings.size == 0)
  end

  def test_no_construction
    # this tests good input values
    test_name = 'test_no_construction'

    # create an instance of the measure
    measure = AddWindAndStackOpenArea.new

    # create an instance of a runner
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + '/Office.osm')
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure::OSArgumentMap.new

    construction = arguments[0].clone
    assert(construction.setValue('*All Operable Windows*'))
    argument_map['construction'] = construction

    open_area_fraction_schedule = arguments[1].clone
    assert(open_area_fraction_schedule.setValue('Wind Stack Open Area Fraction Schedule'))
    argument_map['open_area_fraction_schedule'] = open_area_fraction_schedule

    min_indoor_temp = arguments[2].clone
    assert(min_indoor_temp.setValue(10.0))
    argument_map['min_indoor_temp'] = min_indoor_temp

    min_indoor_temp_schedule = arguments[3].clone
    argument_map['min_indoor_temp_schedule'] = min_indoor_temp_schedule

    max_indoor_temp = arguments[4].clone
    assert(max_indoor_temp.setValue(60.0))
    argument_map['max_indoor_temp'] = max_indoor_temp

    max_indoor_temp_schedule = arguments[5].clone
    argument_map['max_indoor_temp_schedule'] = max_indoor_temp_schedule

    delta_temp = arguments[6].clone
    assert(delta_temp.setValue(0.0))
    argument_map['delta_temp'] = delta_temp

    delta_temp_schedule = arguments[7].clone
    argument_map['delta_temp_schedule'] = delta_temp_schedule

    min_outdoor_temp = arguments[8].clone
    assert(min_outdoor_temp.setValue(18.3333))
    argument_map['min_outdoor_temp'] = min_outdoor_temp

    min_outdoor_temp_schedule = arguments[9].clone
    argument_map['min_outdoor_temp_schedule'] = min_outdoor_temp_schedule

    max_outdoor_temp = arguments[10].clone
    assert(max_outdoor_temp.setValue(25.5556))
    argument_map['max_outdoor_temp'] = max_outdoor_temp

    max_outdoor_temp_schedule = arguments[11].clone
    argument_map['max_outdoor_temp_schedule'] = max_outdoor_temp_schedule

    max_wind_speed = arguments[12].clone
    assert(max_wind_speed.setValue(5.4))
    argument_map['max_wind_speed'] = max_wind_speed

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
    assert(result.warnings.size == 0)

    #save the model for testing purposes
    if !File.exist?("#{File.dirname(__FILE__)}/output")
      FileUtils.mkdir_p("#{File.dirname(__FILE__)}/output")
    end
    output_file_path = model_out_path(test_name)
    model.save(output_file_path, true)
  end

  def test_good_schedule_inputs
    # this tests good input values with schedules defined
    test_name = 'test_good_schedule_inputs'

    # create an instance of the measure
    measure = AddWindAndStackOpenArea.new

    # create an instance of a runner
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + '/Office.osm')
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure::OSArgumentMap.new

    construction = arguments[0].clone
    assert(construction.setValue('U 0.62 SHGC 0.25 Dbl Ref-C-H Clr 6mm/6mm Air 2'))
    argument_map['construction'] = construction

    open_area_fraction_schedule = arguments[1].clone
    assert(open_area_fraction_schedule.setValue('Wind Stack Open Area Fraction Schedule'))
    argument_map['open_area_fraction_schedule'] = open_area_fraction_schedule

    min_indoor_temp = arguments[2].clone
    assert(min_indoor_temp.setValue(21.67))
    argument_map['min_indoor_temp'] = min_indoor_temp

    min_indoor_temp_schedule = arguments[3].clone
    assert(min_indoor_temp_schedule.setValue('Nat Vent Min Indoor Temp Sch - 50F'))
    argument_map['min_indoor_temp_schedule'] = min_indoor_temp_schedule

    max_indoor_temp = arguments[4].clone
    assert(max_indoor_temp.setValue(40.0))
    argument_map['max_indoor_temp'] = max_indoor_temp

    max_indoor_temp_schedule = arguments[5].clone
    assert(max_indoor_temp_schedule.setValue('Nat Vent Max Indoor Temp Sch - 140F'))
    argument_map['max_indoor_temp_schedule'] = max_indoor_temp_schedule

    delta_temp = arguments[6].clone
    assert(delta_temp.setValue(2.0))
    argument_map['delta_temp'] = delta_temp

    delta_temp_schedule = arguments[7].clone
    argument_map['delta_temp_schedule'] = delta_temp_schedule

    min_outdoor_temp = arguments[8].clone
    assert(min_outdoor_temp.setValue(18.3333))
    argument_map['min_outdoor_temp'] = min_outdoor_temp

    min_outdoor_temp_schedule = arguments[9].clone
    assert(min_outdoor_temp_schedule.setValue('Nat Vent Min Outdoor Temp Sch - 65F'))
    argument_map['min_outdoor_temp_schedule'] = min_outdoor_temp_schedule

    max_outdoor_temp = arguments[10].clone
    assert(max_outdoor_temp.setValue(25.5556))
    argument_map['max_outdoor_temp'] = max_outdoor_temp

    max_outdoor_temp_schedule = arguments[11].clone
    assert(max_outdoor_temp_schedule.setValue('Nat Vent Max Outdoor Temp Sch - 78F'))
    argument_map['max_outdoor_temp_schedule'] = max_outdoor_temp_schedule

    max_wind_speed = arguments[12].clone
    assert(max_wind_speed.setValue(5.4))
    argument_map['max_wind_speed'] = max_wind_speed

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
    assert(result.warnings.size == 0)

    #save the model for testing purposes
    if !File.exist?("#{File.dirname(__FILE__)}/output")
      FileUtils.mkdir_p("#{File.dirname(__FILE__)}/output")
    end
    output_file_path = model_out_path(test_name)
    model .save(output_file_path, true)
  end

  def test_default_open_fraction_sch
    # this tests good input values with default open fraction schedule
    test_name = 'test_default_open_fraction_sch'

    # create an instance of the measure
    measure = AddWindAndStackOpenArea.new

    # create an instance of a runner
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + '/Office.osm')
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # set argument values to good values
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure::OSArgumentMap.new

    construction = arguments[0].clone
    assert(construction.setValue('U 0.62 SHGC 0.25 Dbl Ref-C-H Clr 6mm/6mm Air 2'))
    argument_map['construction'] = construction

    open_area_fraction_schedule = arguments[1].clone
    argument_map['open_area_fraction_schedule'] = open_area_fraction_schedule

    min_indoor_temp = arguments[2].clone
    assert(min_indoor_temp.setValue(21.67))
    argument_map['min_indoor_temp'] = min_indoor_temp

    min_indoor_temp_schedule = arguments[3].clone
    argument_map['min_indoor_temp_schedule'] = min_indoor_temp_schedule

    max_indoor_temp = arguments[4].clone
    assert(max_indoor_temp.setValue(40.0))
    argument_map['max_indoor_temp'] = max_indoor_temp

    max_indoor_temp_schedule = arguments[5].clone
    argument_map['max_indoor_temp_schedule'] = max_indoor_temp_schedule

    delta_temp = arguments[6].clone
    assert(delta_temp.setValue(2.0))
    argument_map['delta_temp'] = delta_temp

    delta_temp_schedule = arguments[7].clone
    argument_map['delta_temp_schedule'] = delta_temp_schedule

    min_outdoor_temp = arguments[8].clone
    assert(min_outdoor_temp.setValue(18.3333))
    argument_map['min_outdoor_temp'] = min_outdoor_temp

    min_outdoor_temp_schedule = arguments[9].clone
    argument_map['min_outdoor_temp_schedule'] = min_outdoor_temp_schedule

    max_outdoor_temp = arguments[10].clone
    assert(max_outdoor_temp.setValue(25.5556))
    argument_map['max_outdoor_temp'] = max_outdoor_temp

    max_outdoor_temp_schedule = arguments[11].clone
    argument_map['max_outdoor_temp_schedule'] = max_outdoor_temp_schedule

    max_wind_speed = arguments[12].clone
    assert(max_wind_speed.setValue(5.4))
    argument_map['max_wind_speed'] = max_wind_speed

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
    assert(result.warnings.size == 0)

    #save the model for testing purposes
    if !File.exist?("#{File.dirname(__FILE__)}/output")
      FileUtils.mkdir_p("#{File.dirname(__FILE__)}/output")
    end
    output_file_path = model_out_path(test_name)
    model.save(output_file_path, true)
  end
end