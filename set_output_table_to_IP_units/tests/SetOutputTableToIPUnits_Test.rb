require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class SetOutputTableToIPUnits_Test < MiniTest::Unit::TestCase

  def workspace_out_path(test_name)
    # always generate test output in specially named 'output' directory so result files are not made part of the measure
    return "#{File.dirname(__FILE__)}/output/#{test_name}.idf"
  end
  
  def test_number_of_arguments_and_argument_names
    # this test ensures that the current test is matched to the measure inputs
    
    # create an instance of the measure
    measure = SetOutputTableToIPunits.new
    
    #load the example workspace
    workspace = OpenStudio::Workspace.new
    
    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(workspace)
    assert_equal(0, arguments.size)   
  end

  def test_run
    # this tests good input values
    test_name = "test_run"
    
    # create an instance of the measure
    measure = SetOutputTableToIPunits.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # load the workspace
    workspace = OpenStudio::Workspace::load(OpenStudio::Path.new("./example.idf")).get
    
    # set argument values to good values
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    
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