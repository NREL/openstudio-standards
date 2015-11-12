require_relative 'minitest_helper'

class TestSecondarySchool < CreateDOEPrototypeBuildingTest

  # building_types = ['SecondarySchool']
  # templates = ['90.1-2010']
  # climate_zones = ['ASHRAE 169-2006-2A']
  # building_types = ['SecondarySchool']
  # templates = ['DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010']
  # climate_zones = ['ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A','ASHRAE 169-2006-2B',
                    # 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-3C', 'ASHRAE 169-2006-4A',
                    # 'ASHRAE 169-2006-4B', 'ASHRAE 169-2006-4C', 'ASHRAE 169-2006-5A', 'ASHRAE 169-2006-5B',
                    # 'ASHRAE 169-2006-6A', 'ASHRAE 169-2006-6B', 'ASHRAE 169-2006-7A', 'ASHRAE 169-2006-8A']
  building_types = ['SecondarySchool']
  templates = ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2010']
  climate_zones = ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
  
  create_models = true
  run_models = false
  compare_results = false
  
  TestSecondarySchool.create_run_model_tests(building_types, templates, climate_zones, create_models, run_models, compare_results)
  
end




=begin
class TestSecondarySchool < CreateDOEPrototypeBuildingTest

    test_dir = "#{File.dirname(__FILE__)}/output"
   
    if !Dir.exists?(test_dir)
      Dir.mkdir(test_dir)
    end   
    
    building_types = ['test_a','test_b','test_c']
    #building_types = ['SecondarySchool']
    templates = ['DOE Ref Pre-1980']
    climate_zones = ['ASHRAE 169-2006-2A', 'ASHRAE 169-2006-4A']

    # Create the models
    create_models(building_types, templates, climate_zones, test_dir)

    puts CreateDOEPrototypeBuildingTest.methods.sort
    puts CreateDOEPrototypeBuildingTest.test_methods
    
  # def setup
    # @test_dir = "#{File.dirname(__FILE__)}/output"
    # @building_types = ['SecondarySchool']
    # @templates = ['DOE Ref Pre-1980']
    # @climate_zones = ['ASHRAE 169-2006-2A', 'ASHRAE 169-2006-4A']
  # end

    # Run the models
    #all_failures += run_models(bldg_types, vintages, climate_zones)

    # Compare the results to the legacy idf results
    #all_failures += compare_results(bldg_types, vintages, climate_zones)

    # Assert if there are any errors
    # puts "There were #{all_failures.size} failures"
    # assert(all_failures.size == 0, "FAILURES: #{all_failures.join("\n")}")

end
=end
=begin
class TestSecondarySchool < CreateDOEPrototypeBuildingTest

  def setup
    # Make a directory to save the resulting models
    @test_dir = "#{File.dirname(__FILE__)}/output"
    if !Dir.exists?(@test_dir)
      Dir.mkdir(@test_dir)
    end

  end  
  
  
  
  
  @test_dir = "#{File.dirname(__FILE__)}/output"
  @building_types = ['SecondarySchool']
  @templates = ['DOE Ref Pre-1980']
  @climate_zones = ['ASHRAE 169-2006-2A', 'ASHRAE 169-2006-4A']
  @building_types.each do |building_type|
    @templates.each do |template|
      @climate_zones.each do |climate_zone|
        
        # Dynamically create a test for each building type/template/climate zone
        # so that if one combo fails the others still run
        method_name = "test_create_#{building_type}-#{template}-#{climate_zone}".gsub(' ','_')
        define_method(method_name) do
          
          model_name = "#{building_type}-#{template}-#{climate_zone}"
          
          run_dir = "#{@test_dir}/#{model_name}"
          if !Dir.exists?(run_dir)
            Dir.mkdir(run_dir)
          end
          
          # Create the model
          model = OpenStudio::Model::Model.new
          model.create_prototype_building(building_type,template,climate_zone,run_dir)

          # Report out errors
          errors = []
          $OPENSTUDIO_LOG.logMessages.each do |msg|
            if /openstudio.*/.match(msg.logChannel)
              # Skip certain messages that are irrelevant/misleading
              next if msg.logMessage.include?("Skipping layer") || # Annoying/bogus "Skipping layer" warnings
                  msg.logChannel.include?("runmanager") || # RunManager messages
                  msg.logChannel.include?("setFileExtension") || # .ddy extension unexpected
                  msg.logChannel.include?("Translator") || # Forward translator and geometry translator
                  msg.logMessage.include?("UseWeatherFile") # 'UseWeatherFile' is not yet a supported option for YearDescription
              # Only fail on the errors
              if msg.logLevel == OpenStudio::Error #|| msg.logLevel == OpenStudio::Warn
                errors << "#{model_name} [#{msg.logChannel}] #{msg.logMessage}"
              end
            end
          end          
          
          # Reset the error log for the next run
          reset_log   
  
          # Convert the model to energyplus idf
          forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
          idf = forward_translator.translateModel(model)
          idf_path_string = "#{run_dir}/#{model_name}.idf"
          idf_path = OpenStudio::Path.new(idf_path_string)
          idf.save(idf_path,true)     
          
          # Assert if errors    
          run_dir = "#{@test_dir}/#{building_type}-#{template}-#{climate_zone}"
          empty_model = OpenStudio::Model::Model.new
          model_created = @empty_model.create_prototype_building(building_type,template,climate_zone,run_dir, false)
          assert(errors.size == 0, errors)
        end
        
      end
    end
  end
=end
=begin  
  def test_case
    # RetailStandalone, LargeHotel, RetailStripmall
    building_types = ['SecondarySchool']
    templates = ['DOE Ref Pre-1980']
    climate_zones = ['ASHRAE 169-2006-2A', 'ASHRAE 169-2006-4A']  
    # building_types = ['SecondarySchool']
    # templates = ['DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010']
    # climate_zones = ['ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A','ASHRAE 169-2006-2B',
                      # 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-3C', 'ASHRAE 169-2006-4A',
                      # 'ASHRAE 169-2006-4B', 'ASHRAE 169-2006-4C', 'ASHRAE 169-2006-5A', 'ASHRAE 169-2006-5B',
                      # 'ASHRAE 169-2006-6A', 'ASHRAE 169-2006-6B', 'ASHRAE 169-2006-7A', 'ASHRAE 169-2006-8A']

    building_types.each do |building_type|
      templates.each do |template|
        climate_zones.each do |climate_zone|
          
          # Dynamically create a test for each building type/template/climate zone
          # so that if one combo fails the others still run
          method_name = "test_create_#{building_type}-#{template}-#{climate_zone}".gsub(' ','_')
          define_method(method_name) do
            
            run_dir = "#{@test_dir}/#{building_type}-#{template}-#{climate_zone}"
            if !Dir.exists?(run_dir)
              Dir.mkdir(run_dir)
            end
            
            # Create the model
            model.create_prototype_building(building_type,template,climate_zone,osm_directory)

            # Report out errors
            errors = []
            $OPENSTUDIO_LOG.logMessages.each do |msg|
              if /openstudio.*/.match(msg.logChannel)
                # Skip certain messages that are irrelevant/misleading
                next if msg.logMessage.include?("Skipping layer") || # Annoying/bogus "Skipping layer" warnings
                    msg.logChannel.include?("runmanager") || # RunManager messages
                    msg.logChannel.include?("setFileExtension") || # .ddy extension unexpected
                    msg.logChannel.include?("Translator") || # Forward translator and geometry translator
                    msg.logMessage.include?("UseWeatherFile") # 'UseWeatherFile' is not yet a supported option for YearDescription
                # Only fail on the errors
                if msg.logLevel == OpenStudio::Error #|| msg.logLevel == OpenStudio::Warn
                  errors << "#{model_name} [#{msg.logChannel}] #{msg.logMessage}"
                end
              end
            end          
            
            # Reset the error log for the next run
            reset_log   
    
            # Convert the model to energyplus idf
            forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
            idf = forward_translator.translateModel(model)
            idf_path_string = "#{osm_directory}/#{model_name}.idf"
            idf_path = OpenStudio::Path.new(idf_path_string)
            idf.save(idf_path,true)     
            
            # Assert if errors    
            run_dir = "#{@test_dir}/#{building_type}-#{template}-#{climate_zone}"
            empty_model = OpenStudio::Model::Model.new
            model_created = @empty_model.create_prototype_building(building_type,template,climate_zone,run_dir, false)
            assert(errors.size == 0, errors)
          end
          
        end
      end
    end
                      
    # Create the models
    # bldg_types.sort.each do |building_type|
      # vintages.sort.each do |template|
        # climate_zones.sort.each do |climate_zone|
          # errors = create_model(building_type, template, climate_zone)
          # assert(errors.size == 0, "#{building_type}-#{template}-#{climate_zone} #{errors.join("\n")}")
        # end
      # end
    # end
    
    # all_failures = []

    # Run the models
    #all_failures += run_models(bldg_types, vintages, climate_zones)

    # Compare the results to the legacy idf results
    #all_failures += compare_results(bldg_types, vintages, climate_zones)

    # Assert if there are any errors
    #assert(all_failures.size == 0, "FAILURES: #{all_failures.join("\n")}")
  end
=end
