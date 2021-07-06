require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'
require_relative '../measure.rb'

class ExportOutputMetertoCSV_Test < MiniTest::Test

  def run_dir
    return "#{File.dirname(__FILE__)}/example_model/"
  end

  def model_path
    return "#{File.dirname(__FILE__)}/example_model.osm"
  end

  def epw_path
    return "#{File.dirname(__FILE__)}/example_model_weather.epw"
  end

  def sql_path
    return "#{File.dirname(__FILE__)}/example_model/run/eplusout.sql"
  end

  def report_path
    return "#{File.dirname(__FILE__)}/reports/eplustbl.html"
  end

  # create test files if they do not exist when the test first runs 
  def setup_test

  assert(File.exist?(model_path))

  if !File.exist?(run_dir)
      FileUtils.mkdir_p(run_dir)
    end
    assert(File.exist?(run_dir))    

    if File.exist?(report_path)
      FileUtils.rm(report_path)
    end

    if !File.exist?(sql_path)
      puts "Running EnergyPlus"

      osw_path = File.join(run_dir, 'in.osw')
      osw_path = File.absolute_path(osw_path)

      workflow = OpenStudio::WorkflowJSON.new
      workflow.setSeedFile(File.absolute_path(model_path))
      workflow.setWeatherFile(File.absolute_path(epw_path))
      workflow.saveAs(osw_path)

      cli_path = OpenStudio.getOpenStudioCLI
      cmd = "\"#{cli_path}\" run -w \"#{osw_path}\""
      puts cmd
      system(cmd)
    end
  end

  def test_ExportMetertoCSV

    assert(File.exist?(model_path))

    if !File.exist?(sql_path)
      setup_test()
    end
    assert(File.exist?(sql_path))

    # create an instance of the measure
    measure = ExportMetertoCSV.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    translator = OpenStudio::OSVersion::VersionTranslator.new
    model = translator.loadModel(model_path)
    assert(!model.empty?)
    model = model.get

    # get arguments
    arguments = measure.arguments(model)
    assert_equal(2, arguments.size)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # set argument values to good values and run the measure
    meter_name = arguments[0].clone
    assert(meter_name.setValue("Electricity:Facility"))
    argument_map["meter_name"] = meter_name
    reporting_frequency = arguments[1].clone
    assert(reporting_frequency.setValue("Hourly"))
    argument_map["reporting_frequency"] = reporting_frequency

    # set up runner, this will happen automatically when measure is run in PAT or OpenStudio
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new(model_path()))
    runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sql_path()))

    # delete the output if it exists
    if File.exist?(report_path)
      FileUtils.rm(report_path)
    end
    assert(!File.exist?(report_path))

    # temporarily change directory to the run directory and run the measure
    start_dir = Dir.pwd
    begin
      Dir.chdir(run_dir())

      # run the measure
      measure.run(runner, argument_map)
      result = runner.result
      show_output(result)
      assert_equal("Success", result.value.valueName)
    ensure
      Dir.chdir(start_dir)
    end

  # make sure the report file exists
    #assert(File.exist?(report_path()))
  end

end
