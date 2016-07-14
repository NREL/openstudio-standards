require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require 'json'
require_relative '../measure.rb'
require 'fileutils'
require 'socket'

class CreatePerformanceRatingMethodBaselineBuildingTest < Minitest::Unit::TestCase

  def setup
    # Make a directory to save the resulting models
    @test_dir = "#{File.dirname(__FILE__)}/output"
    if !Dir.exists?(@test_dir)
      Dir.mkdir(@test_dir)
    end
  end

  def apply_measure_to_model(model_name, standard, climate_zone, building_type)

    # Create an instance of the measure
    measure = CreatePerformanceRatingMethodBaselineBuilding.new
    
    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{Dir.pwd}/#{model_name}")
    model = translator.loadModel(path)
    assert(model.is_initialized)
    model = model.get
    
    # Create an empty argument map
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    # Set argument values
    arg_values = {
    "standard" => standard,
    "building_type" => building_type,
    "climate_zone" => climate_zone,
    "custom" => "*None*",
    "debug" => false
    }
    
    i = 0
    arg_values.each do |name, val|
      arg = arguments[i].clone
      assert(arg.setValue(val))
      argument_map[name] = arg
      i += 1
    end

    # Run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)

    # Ensure the measure finished as expected
    assert(result.value.valueName == "Success")
  
    model.save(OpenStudio::Path.new("output/#{model_name}_baseline.osm"), true)  
  
    return model
  
  end
  
  def dont_test_901_2013_sec_school
  
    model = apply_measure_to_model('SecondarySchool-DOE Ref Pre-1980-ASHRAE 169-2006-2A.osm', '90.1-2013', 'ASHRAE 169-2006-2A', 'SecondarySchool')
  
    # Conditions expected to be true in the baseline model
    
    # Lighting power densities

  end
  
  def test_901_2010_sec_school
  
    model = apply_measure_to_model('SecondarySchool-DOE Ref Pre-1980-ASHRAE 169-2006-2A.osm', '90.1-2010', 'ASHRAE 169-2006-2A', 'SecondarySchool')
  
    # Conditions expected to be true in the baseline model
    
    # Lighting power densities

  end   
  
end
