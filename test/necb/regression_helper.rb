def create_model_and_regression_test(building_type, epw_files, templates)
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

      model = Standard.build("#{template}_#{building_type}").model_create_prototype_model('NECB HDD Method', epw_file, run_dir)

      #Save osm file.
      filename = "#{File.dirname(__FILE__)}/regression_models/#{model_name}_expected_result.osm"
      FileUtils.mkdir_p(File.dirname(filename))
      File.delete(filename) if File.exist?(filename)
      puts "Saving osm file to : #{filename}"
      model.save(filename)

      #old models
      # Load the geometry .osm
      osm_file = filename
      unless File.exist?(osm_file)
        raise("The initial osm path: #{osm_file} does not exist.")
      end
      osm_model_path = OpenStudio::Path.new(osm_file.to_s)
      # Upgrade version if required.
      version_translator = OpenStudio::OSVersion::VersionTranslator.new
      old_model = version_translator.loadModel(osm_model_path).get

      puts compare_osm_files(old_model, model)
    end
  end
end

