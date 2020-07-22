require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require 'json'
require 'parallel'
require 'etc'

$LOAD_PATH.unshift File.expand_path('/../../lib', __FILE__)

run_dir = "#{File.dirname(__FILE__)}/output/#{@template}/#{@model_name}"
model_out_path ="#{run_dir}/ExampleModel.osm"
workspace_path = "#{run_dir}/ModelToIdf/in.idf"
sql_path = "#{run_dir}/ModelToIdf/EnergyPlusPreProcess-0/EnergyPlus-0/eplusout.sql"
report_path = "#{run_dir}/report.html"


#LargeOffice
class TestNECBQAQC < CreateDOEPrototypeBuildingTest

  def test_single_qaqc()
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
  end