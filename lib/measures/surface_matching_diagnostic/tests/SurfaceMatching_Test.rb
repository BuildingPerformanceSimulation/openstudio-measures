require 'openstudio'

require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'minitest/autorun'

class SurfaceMatchingDiagnostic_Test < MiniTest::Unit::TestCase

  
  def test_SurfaceMatchingDiagnostic
     
    # create an instance of the measure
    measure = SurfaceMatchingDiagnostic.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/SurfaceMatching_test.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(6, arguments.size)

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1
    remove_duplicate_vertices = arguments[count += 1].clone
    assert(remove_duplicate_vertices.setValue(true))
    argument_map["remove_duplicate_vertices"] = remove_duplicate_vertices

    remove_collinear_vertices = arguments[count += 1].clone
    assert(remove_collinear_vertices.setValue(true))
    argument_map["remove_collinear_vertices"] = remove_collinear_vertices

    remove_duplicate_surfaces = arguments[count += 1].clone
    assert(remove_duplicate_surfaces.setValue(true))
    argument_map["remove_duplicate_surfaces"] = remove_duplicate_surfaces

    remove_adiabatic = arguments[count += 1].clone
    assert(remove_adiabatic.setValue(true))
    argument_map["remove_adiabatic"] = remove_adiabatic
    
    intersect_surfaces = arguments[count += 1].clone
    assert(intersect_surfaces.setValue(true))
    argument_map["intersect_surfaces"] = intersect_surfaces

    match_surfaces = arguments[count += 1].clone
    assert(match_surfaces.setValue(true))
    argument_map["match_surfaces"] = match_surfaces

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    #assert(result.warnings.size == 1)
    #assert(result.info.size == 2)

    # save the model in an output directory
    output_dir = File.expand_path('output', File.dirname(__FILE__))
    FileUtils.mkdir output_dir unless Dir.exist? output_dir
    model.save("#{output_dir}/test.osm", true)
  end

  def test_SurfaceMatchingDiagnostic_colliner

    # create an instance of the measure
    measure = SurfaceMatchingDiagnostic.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/temp_test.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(6, arguments.size)

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    count = -1
    remove_duplicate_vertices = arguments[count += 1].clone
    assert(remove_duplicate_vertices.setValue(true))
    argument_map["remove_duplicate_vertices"] = remove_duplicate_vertices

    remove_collinear_vertices = arguments[count += 1].clone
    assert(remove_collinear_vertices.setValue(true))
    argument_map["remove_collinear_vertices"] = remove_collinear_vertices

    remove_duplicate_surfaces = arguments[count += 1].clone
    assert(remove_duplicate_surfaces.setValue(true))
    argument_map["remove_duplicate_surfaces"] = remove_duplicate_surfaces

    remove_adiabatic = arguments[count += 1].clone
    assert(remove_adiabatic.setValue(true))
    argument_map["remove_adiabatic"] = remove_adiabatic

    intersect_surfaces = arguments[count += 1].clone
    assert(intersect_surfaces.setValue(true))
    argument_map["intersect_surfaces"] = intersect_surfaces

    match_surfaces = arguments[count += 1].clone
    assert(match_surfaces.setValue(true))
    argument_map["match_surfaces"] = match_surfaces

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    #assert(result.warnings.size == 1)
    #assert(result.info.size == 2)

    # save the model in an output directory
    output_dir = File.expand_path('output', File.dirname(__FILE__))
    FileUtils.mkdir output_dir unless Dir.exist? output_dir
    model.save("#{output_dir}/test.osm", true)
  end

end
