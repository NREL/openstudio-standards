require 'minitest_helper'

class TestOpenstudioStandards < Minitest::Test
=begin
  def setup
    @building_types = ['SmallOffice','SecondarySchool']
    @templates = ['DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013']
    @climate_zones = ['ASHRAE 169-2006-2A', 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-4A', 'ASHRAE 169-2006-5A']
  
    # Make a directory to save the resulting models for debugging
    @build_dir = "#{Dir.pwd}/test/build"
    if !Dir.exists?(@build_dir)
      Dir.mkdir(@build_dir)
    end

  end

  # Dynamically create a test for each building type/template/climate zone
  # so that if one combo fails the others still run
  # @building_types.each do |building_type|
    # @templates.each do |template|
      # @climate_zones.each do |climate_zone|
        # define_method("test_create_#{building_type}-#{template}-#{climate_zone}") do
          # run_dir = "#{@build_dir}/#{building_type}-#{template}-#{climate_zone}"
          # if !Dir.exists?(run_dir)
            # Dir.mkdir(run_dir)
          # end
          # run_dir = "#{@build_dir}/#{building_type}-#{template}-#{climate_zone}"
          # empty_model = OpenStudio::Model::Model.new
          # model_created = @empty_model.create_prototype_building(building_type,template,climate_zone,run_dir, false)
          # assert(model_created, "Failed to create #{building_type}-#{template}-#{climate_zone}")
        # end
      # end
    # end
  # end

  # def test_create_small_office

    # building_type = 'SmallOffice'
    # ['DOE Ref Pre-1980'].each do |template|
      # @climate_zones.each do |climate_zone|
        # run_dir = "#{@build_dir}/#{building_type}-#{template}-#{climate_zone}"
        # if !Dir.exists?(run_dir)
          # Dir.mkdir(run_dir)
        # end
        # run_dir = "#{@build_dir}/#{building_type}-#{template}-#{climate_zone}"
        # model_created = @empty_model.create_prototype_building(building_type,template,climate_zone,run_dir, false)
        # assert(model_created, "Failed to create #{building_type}-#{template}-#{climate_zone}")
      # end
    # end
  
  # end 
  
  def test_create_secondary_school

    building_type = 'SecondarySchool'
    ['DOE Ref Pre-1980'].each do |template|
      @climate_zones.each do |climate_zone|
        run_dir = "#{@build_dir}/#{building_type}-#{template}-#{climate_zone}"
        if !Dir.exists?(run_dir)
          Dir.mkdir(run_dir)
        end
        run_dir = "#{@build_dir}/#{building_type}-#{template}-#{climate_zone}"
        empty_model = OpenStudio::Model::Model.new
        model_created = empty_model.create_prototype_building(building_type,template,climate_zone,run_dir)
        assert(model_created, "Failed to create #{building_type}-#{template}-#{climate_zone}")
      end
    end
      
  end  
  
  def teardown
    return true
  end  
=end
end
