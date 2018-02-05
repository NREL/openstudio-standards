require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'
require_relative '../helpers/compare_models_helper'

##FullServiceRestaurant
class TestNECBFullServiceRestaurant < CreateDOEPrototypeBuildingTest
  building_type = 'FullServiceRestaurant'
  templates = ['NECB 2011']
  epw_files = ['CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw']

  def self.create_and_regression_test(building_type, epw_files, templates)
    test_dir = "#{File.dirname(__FILE__)}/output"
    if !Dir.exists?(test_dir)
      Dir.mkdir(test_dir)
    end
    templates.each do |template|
      epw_files.each do |epw_file|
        model_name = "#{building_type}-#{template}-#{File.basename(epw_file, '.epw')}"
        run_dir = "#{test_dir}/#{model_name}"
        if !Dir.exists?(run_dir)
          Dir.mkdir(run_dir)
        end
        filename = "#{run_dir}//#{model_name}.osm"
        FileUtils.mkdir_p(File.dirname(filename))
        File.delete(filename) if File.exist?(filename)
        model = Standard.build("#{template}_#{building_type}").model_create_prototype_model('NECB HDD Method', epw_file, run_dir)
        model.save(filename)
        puts compare_osm_files(model, model)
      end
    end
  end

  # Make a directory to save the resulting models
  create_and_regression_test(building_type, epw_files, templates)
end


