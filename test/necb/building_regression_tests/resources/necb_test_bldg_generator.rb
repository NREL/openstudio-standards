require 'fileutils'
require 'erb'

# copied and modified from https://github.com/rubyworks/facets/blob/master/lib/core/facets/string/snakecase.rb
class String
  def snek
    #gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
        gsub(/([a-z\d])([A-Z])/, '\1_\2').
        tr('-', '_').
        gsub(/\s/, '_').
        gsub(/__+/, '_').
        gsub(/#+/, '').
        gsub(/\"/, '').
        downcase
  end
end

class GeneratorNECBRegressionTests
  # default loation circleci_tests.txt file when run on

  def initialize()
    @file_out_dir = File.absolute_path(File.join(__dir__,  "..",'tests'))


    reset_folder(@file_out_dir)
  end


  def reset_folder(dirname)
    if File.directory?(dirname)
      puts "Removing directory : [#{dirname}]"
      FileUtils.rm_r(dirname)
    end
    FileUtils.mkdir_p(dirname)
  end

  # Method that will generate the necb building test files.
  def generate_necb_bldg_test_files
    reset_folder(@file_out_dir)
    templates = [
        'NECB2011',
        'NECB2015',
        'NECB2017'
    ]
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
    fuel_types = [
        'gas',
        'electric'
    ]
    #load regression necb template
    necb_bldg_template = File.read("#{__dir__}/template_test_necb_bldg.erb")
    filenames = []
    templates.each {|template|
      building_types.each {|building_type|
        fuel_types.each {|fuel_type|
          filename = File.join(@file_out_dir, "test_necb_bldg_#{building_type}_#{template}_#{fuel_type}.rb")
          file_string = ERB.new(necb_bldg_template, 0, "", "@html").result(binding)
          File.open(filename, 'w') {|file| file.write(file_string)}
          filenames << filename
        }
      }
    }
    return filenames
  end
end
puts GeneratorNECBRegressionTests.new().generate_necb_bldg_test_files



