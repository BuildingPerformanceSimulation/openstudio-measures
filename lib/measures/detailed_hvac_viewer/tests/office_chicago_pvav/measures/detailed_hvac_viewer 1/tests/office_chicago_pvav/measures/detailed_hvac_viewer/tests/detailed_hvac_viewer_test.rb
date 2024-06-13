require 'openstudio'
require 'openstudio-standards'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'
require 'json'

class DetailedHVACViewerTest < Minitest::Test

  def run_dir(test_name)
    # always generate test output in specially named 'output' directory so result files are not made part of the measure
    return "#{File.dirname(__FILE__)}/output/#{test_name}"
  end

  def model_output_path(test_name)
    return "#{run_dir(test_name)}/#{test_name}.osm"
  end

  def workspace_path(test_name)
    return "#{run_dir(test_name)}/run/in.idf"
  end

  def sql_path(test_name)
    return "#{run_dir(test_name)}/run/eplusout.sql"
  end

  def report_path(test_name)
    return "#{run_dir(test_name)}/reports/eplustbl.html"
  end

  def run_test(test_name, osm_path, epw_path)
    # create run directory if it does not exist
    unless File.exist?(run_dir(test_name))
      FileUtils.mkdir_p(run_dir(test_name))
    end
    assert(File.exist?(run_dir(test_name)))

    # change into run directory for tests
    start_dir = Dir.pwd
    Dir.chdir run_dir(test_name)

    # create an instance of the measure
    measure = DetailedHVACViewer.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # Load the input model to set up runner, this will happen automatically when measure is run in PAT or OpenStudio
    translator = OpenStudio::OSVersion::VersionTranslator.new
    model = translator.loadModel(osm_path)
    assert(model.is_initialized)
    model = model.get
    runner.setLastOpenStudioModel(model)

    # get arguments
    arguments = measure.arguments()
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # get the energyplus output requests, this will be done automatically by OS App and PAT
    idf_output_requests = measure.energyPlusOutputRequests(runner, argument_map)

    # convert output requests to OSM for testing, OS App and PAT will add these to the E+ Idf
    workspace = OpenStudio::Workspace.new('Draft'.to_StrictnessLevel, 'EnergyPlus'.to_IddFileType)
    workspace.addObjects(idf_output_requests)
    rt = OpenStudio::EnergyPlus::ReverseTranslator.new
    request_model = rt.translateWorkspace(workspace)

    # load the test model and add output requests
    translator = OpenStudio::OSVersion::VersionTranslator.new
    model = translator.loadModel(OpenStudio::Path.new(osm_path))
    assert(!model.empty?)
    model = model.get
    model.addObjects(request_model.objects)
    model.save(model_output_path(test_name), true)

    # set model weather file
    assert(File.exist?(epw_path))
    epw_file = OpenStudio::EpwFile.new(OpenStudio::Path.new(epw_path))
    OpenStudio::Model::WeatherFile.setWeatherFile(model, epw_file)
    assert(model.weatherFile.is_initialized)

    # run the simulation if necessary
    unless File.exist?(sql_path(test_name))
      puts "\nRUNNING JANUARY FOR #{test_name}..."

      run_period = model.getRunPeriod
      run_period.setBeginMonth(1)
      run_period.setBeginDayOfMonth(1)
      run_period.setEndMonth(1)
      run_period.setEndDayOfMonth(31)

      std = Standard.build('90.1-2013')
      std.model_run_simulation_and_log_errors(model, run_dir(test_name))
    end
    assert(File.exist?(model_output_path(test_name)))
    assert(File.exist?(sql_path(test_name)))

    # set up runner, this will happen automatically when measure is run in PAT or OpenStudio
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new(model_output_path(test_name)))
    runner.setLastEnergyPlusWorkspacePath(OpenStudio::Path.new(workspace_path(test_name)))
    runner.setLastEpwFilePath(epw_path)
    runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sql_path(test_name)))

    # delete the output if it exists
    if File.exist?(report_path(test_name))
      FileUtils.rm(report_path(test_name))
    end
    assert(!File.exist?(report_path(test_name)))

    # run the measure
    puts "\nRUNNING MEASURE RUN FOR #{test_name}..."
    measure.run(runner, argument_map)
    result = runner.result
    show_output(result)

    # log result to file for comparisons
    values = []
    result.stepValues.each do |value|
      values << value.string
    end
    File.write(run_dir(test_name)+"/output.txt", "[\n#{values.join(',').strip}\n]")

    assert_equal('Success', result.value.valueName)

    # change back directory
    Dir.chdir(start_dir)
    return true
  end

  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = DetailedHVACViewer.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    argument_names = [
      'include_demand_nodes',
      'reporting_frequency',
      'System Node Temperature',
      'System Node Setpoint Temperature',
      'System Node Mass Flow Rate',
      'System Node Humidity Ratio',
      'System Node Setpoint High Temperature',
      'System Node Setpoint Low Temperature',
      'System Node Setpoint Humidity Ratio',
      'System Node Setpoint Minimum Humidity Ratio',
      'System Node Setpoint Maximum Humidity Ratio',
      'System Node Relative Humidity',
      'System Node Pressure',
      'System Node Standard Density Volume Flow Rate',
      'System Node Current Density Volume Flow Rate',
      'System Node Current Density',
      'System Node Enthalpy',
      'System Node Wetbulb Temperature',
      'System Node Dewpoint Temperature',
      'System Node Quality',
      'System Node Height'
    ]

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(argument_names.size, arguments.size)

    argument_names.each_with_index do |name, i|
      assert_equal(name, arguments[i].name)
    end
  end

  def test_office_chicago_pvav
    test_name = 'office_chicago_pvav'
    puts "\n######\nTEST:#{test_name}\n######\n"
    osm_path = File.dirname(__FILE__) + '/office_chicago_pvav.osm'
    epw_path = File.dirname(__FILE__) + '/USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'
    assert(run_test(test_name, osm_path, epw_path))
  end
end
