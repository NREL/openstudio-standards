require 'fileutils'

def generate_ci_bldg_test_files
  templates = ['NECB2011', 'NECB2015']
  building_types = [
      "FullServiceRestaurant",
      "HighriseApartment",
      "Hospital",
      "LargeHotel",
      "LargeOffice",
      "MediumOffice",
      "MidriseApartment",
      "Outpatient",
      "PrimarySchool",
      "QuickServiceRestaurant",
      "RetailStandalone",
      "RetailStripmall",
      "SecondarySchool",
      "SmallHotel",
      "SmallOffice",
      "Warehouse"
  ]
  fuel_types = ['gas', 'electric']
  out_dir = File.absolute_path(File.join(__FILE__,"..","..","ci_test_files"))
  FileUtils.mkdir_p out_dir
  templates.each {|template|
    building_types.each {|building_type|
      fuel_types.each {|fuel_type|
        filename = File.join(out_dir,"test_bldg_#{building_type}_#{template}_#{fuel_type}.rb")
        file_string =%Q{
require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'
require_relative '../helpers/compare_models_helper'
require_relative '../necb/regression_helper'

class Test_#{building_type}_#{template}_#{fuel_type} < NECBRegressionHelper
  def setup()
    super()
    @building_type = '#{building_type}'
  end
  def test_#{template}_#{building_type}_regression_#{fuel_type}()
    result, msg = create_model_and_regression_test(@building_type,
                                                   @#{fuel_type}_location,
                                                   '#{template}'
    )
    assert(result, msg)
  end
end
}
        File.open(filename, 'w') { |file| file.write(file_string) }
      }
    }
  }
end

def write_file_path_to_ci_tests_txt
  circleci_tests_txt_path = File.absolute_path(File.join(__FILE__, "..", "..", "circleci_tests.txt"))
  #puts circleci_tests_txt_path
  File.open(circleci_tests_txt_path, 'a') { |f|
    files_path = File.expand_path(File.join(__FILE__,"..","..","ci_test_files", "*.rb"))
    puts files_path
    Dir[files_path].sort.each {|path|
      f.puts(path.to_s.gsub(/^.+(openstudio-standards\/test\/)/,''))
    }
  }
end


generate_ci_bldg_test_files()
write_file_path_to_ci_tests_txt()