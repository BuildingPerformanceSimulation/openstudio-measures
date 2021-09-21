require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class RemoveHVACSystemsTest < MiniTest::Test
  # def setup
  # end

  # def teardown
  # end

  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = RemoveHVACSystems.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(7, arguments.size)
    assert_equal("remove_air_loops", arguments[0].name)
    assert_equal("remove_plant_loops", arguments[1].name)
    assert_equal("remove_shw_loops", arguments[2].name)
    assert_equal("remove_zone_equipment", arguments[3].name)
    assert_equal("remove_zone_exhaust_fans", arguments[4].name)
    assert_equal("remove_vrf", arguments[5].name)
    assert_equal("remove_unused_curves", arguments[6].name)
  end

  def test_default_values
    # create an instance of the measure
    measure = RemoveHVACSystems.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/example_model.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
    assert(result.info.size == 1)
    assert(result.warnings.size == 0)
  end

end
