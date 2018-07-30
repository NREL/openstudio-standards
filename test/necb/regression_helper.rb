require 'minitest/unit'


class NECBRegressionHelper < Minitest::Test
  def setup()
    @building_type = nil
    @gas_location = 'CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw'
    @electric_location = 'CAN_QC_Kuujjuaq.AP.719060_CWEC2016.epw'
  end


  def create_model_and_regression_test(building_type, epw_file, template, performQAQC = false)
    begin
      diffs = []
      test_dir = "#{File.dirname(__FILE__)}/output"
      if !Dir.exists?(test_dir)
        Dir.mkdir(test_dir)
      end
      model_name = "#{building_type}-#{template}-#{File.basename(epw_file, '.epw')}"
      run_dir = "#{test_dir}/#{model_name}"
      if !Dir.exists?(run_dir)
        Dir.mkdir(run_dir)
      end

      model = Standard.build("#{template}_#{building_type}").model_create_prototype_model('NECB HDD Method', epw_file, run_dir)

      #Save osm file.
      filename = "#{File.dirname(__FILE__)}/regression_models/#{model_name}_test_result.osm"
      FileUtils.mkdir_p(File.dirname(filename))
      File.delete(filename) if File.exist?(filename)
      puts "Saving osm file to : #{filename}"
      model.save(filename)

      #old models
      # Load the geometry .osm
      osm_file = "#{File.dirname(__FILE__)}/regression_models/#{model_name}_expected_result.osm"
      unless File.exist?(osm_file)
        raise("The initial osm path: #{osm_file} does not exist.")
      end
      osm_model_path = OpenStudio::Path.new(osm_file.to_s)
      # Upgrade version if required.
      version_translator = OpenStudio::OSVersion::VersionTranslator.new
      old_model = version_translator.loadModel(osm_model_path).get


      # Compare the two models.
      diffs = compare_osm_files(old_model, model)
    rescue => exception
      # Log error/exception and then keep going.
      error = "#{exception.backtrace.first}: #{exception.message} (#{exception.class})"
      exception.backtrace.drop(1).map {|s| "\n#{s}"}.each {|bt| error << bt.to_s}
      diffs << "#{model_name}: Error \n#{error}"

    end
    #Write out diff or error message
    diff_file = "#{File.dirname(__FILE__)}/regression_models/#{model_name}_diffs.json"
    FileUtils.rm(diff_file) if File.exists?(diff_file)
    if diffs.size > 0
      File.write(diff_file, JSON.pretty_generate(diffs))
      msg = "There were #{diffs.size} differences/errors in #{building_type} #{template} #{epw_file} :\n#{diffs.join("\n")}"
      return false, msg
    else
      return true, nil
    end
  end

end
