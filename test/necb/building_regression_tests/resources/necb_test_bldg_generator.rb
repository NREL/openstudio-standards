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
    @file_out_dir = File.absolute_path(File.join(__dir__, "..", 'tests'))


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

    epw_files = [
        'CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw'
    ]
    templates = [
        'NECB2011',
        'NECB2015',
        'NECB2017',
        'BTAPPRE1980'
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
    primary_heating_fuels =
        [
            'NaturalGas',
            'Electricity',
        ]
    #load regression necb template
    necb_bldg_template = File.read("#{__dir__}/template_test_necb_bldg.erb")
    filenames = []
    templates.each do |template|
      building_types.each do |building_type|
        primary_heating_fuels.each do |primary_heating_fuel|
          epw_files.each do |epw_file|
            test_name =
            filename = File.join(@file_out_dir, "test_necb_bldg_#{building_type}_#{template}_#{primary_heating_fuel}.rb")
            file_string = ERB.new(necb_bldg_template, 0, "", "@html").result(binding)
            File.open(filename, 'w') {|file| file.write(file_string)}
            filenames << filename
          end
        end
      end
    end
    return filenames
  end
end
puts GeneratorNECBRegressionTests.new().generate_necb_bldg_test_files



