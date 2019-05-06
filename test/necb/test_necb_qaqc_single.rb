require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'
require 'json'
require 'parallel'
require 'etc'

$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)

def run_dir(test_name, info)
  # always generate test output in specially named 'output' directory so result files are not made part of the measure
  "#{File.dirname(__FILE__)}/output/#{info['template']}/#{test_name}"
end

def model_out_path(test_name, info)
  "#{run_dir(test_name, info)}/ExampleModel.osm"
end

def workspace_path(test_name, info)
  "#{run_dir(test_name, info)}/ModelToIdf/in.idf"
end

def sql_path(test_name, info)
  "#{run_dir(test_name, info)}/ModelToIdf/EnergyPlusPreProcess-0/EnergyPlus-0/eplusout.sql"
end

def report_path(test_name, info)
  "#{run_dir(test_name, info)}/report.html"
end

#LargeOffice
class TestNECBQAQC < CreateDOEPrototypeBuildingTest

  def test_single_qaqc()
    building_types = [
    #    "FullServiceRestaurant"
    # "LargeHotel",
    # "LargeOffice",
    # "MediumOffice",
     "MidriseApartment"#,
    # "Outpatient",
    # "PrimarySchool",
    # "QuickServiceRestaurant",
    # "RetailStandalone",
    # "RetailStripmall",
    # "SmallHotel",
    # "SmallOffice",
    # "Warehouse"
    ]

    templates = ['NECB2011',
                 'NECB2015',
                 'NECB2017']
    climate_zones = 'NECB HDD Method'
    epw_files = ['CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw']

    start = Time.now
    run_argument_array = []
    building_types.each do |building|
      epw_files.each do |epw|
        templates.each {|template|
          run_argument_array << { 'building' => building,
                                  'epw' => epw,
                                  'template' => template}
        }
      end
    end

    processess = (Parallel::processor_count * 2.0 / 3.0).round
    puts "processess #{processess}"
    Parallel.map(run_argument_array, in_processes: 1) do |info|
      test_name = "#{info['building']}_#{info['epw']}"
      puts info
      puts "creating #{test_name}"
      unless File.exist?(run_dir(test_name, info))
        FileUtils.mkdir_p(run_dir(test_name, info))
      end
      #assert(File.exist?(run_dir(test_name)))

      if File.exist?(report_path(test_name, info))
        FileUtils.rm(report_path(test_name, info))
      end

      #assert(File.exist?(model_in_path))

      if File.exist?(model_out_path(test_name, info))
        FileUtils.rm(model_out_path(test_name, info))
      end
      output_folder = run_dir(test_name, info)
      prototype_creator = Standard.build(info['template'])
      model = prototype_creator.model_create_prototype_model(template: info['template'],
                                                             building_type: info['building'],
                                                             epw_file: info['epw'],
                                                             debug: false,
                                                             sizing_run_dir: output_folder)


      BTAP::Environment::WeatherFile.new(info['epw']).set_weather_file(model)
      prototype_creator.model_run_simulation_and_log_errors(model, run_dir(test_name, info))
      qaqc = prototype_creator.init_qaqc(model)
      #write to json file.
      File.open("#{output_folder}/qaqc.json", 'w') {|f| f.write(JSON.pretty_generate(qaqc, {:allow_nan => true}))}
      puts JSON.pretty_generate(qaqc)
    end
    # BTAP::FileIO.compile_qaqc_results("#{File.dirname(__FILE__)}/output#{Time.now.strftime("%m-%d")}")
    puts "completed in #{Time.now - start} secs"
  end
end
