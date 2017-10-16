require_relative '../helpers/minitest_helper'


class TestRefactorNECB < Minitest::Test
  building_types = ["FullServiceRestaurant"] #, "Hospital", "HighriseApartment", "LargeHotel", "LargeOffice", "MediumOffice", "MidriseApartment", "Outpatient", "PrimarySchool", "QuickServiceRestaurant", "RetailStandalone", "SecondarySchool", "SmallHotel", "SmallOffice", "RetailStripmall", "Warehouse"]
  templates = ['NECB 2011']
  climate_zones = ['NECB HDD Method']
  epw_files = [
      'CAN_BC_Vancouver.718920_CWEC.epw' #, #  CZ 5 - Gas HDD = 3019
  #'CAN_ON_Toronto.716240_CWEC.epw', #CZ 6 - Gas HDD = 4088
  #'CAN_PQ_Sherbrooke.716100_CWEC.epw', #CZ 7a - Electric HDD = 5068
  #'CAN_YT_Whitehorse.719640_CWEC.epw', #CZ 7b - FuelOil1 HDD = 6946
  #'CAN_NU_Resolute.719240_CWEC.epw', # CZ 8  -FuelOil2 HDD = 12570
  #'CAN_PQ_Kuujjuarapik.719050_CWEC.epw', # CZ 8  -FuelOil2 HDD = 7986
  #'CAN_ON_Kingston.716200_CWEC.epw' # This did not run cleanly! Error in 671 of compliance.rb
  ]

  def compare_models(old_model, new_model)
    #strip of UUIDs

    new_model_sorted = new_model.modelObjects.sort_by {|p| [p.to_s.lines.first.strip, p.to_s.lines[2].strip]}
    counter = 0
    new_model_reindexed = new_model.modelObjects.map do |object|
      puts object.to_s.match(/\{(.*)\}/).captures[0]
      object.to_s.gsub(/\{.*\}/, counter.to_s)
      counter += 1
    end

    #old_model.sort_by{ |p| [p.x, p.y] }
    puts new_model.modelObjects[0].to_s
    puts new_model.modelObjects[0].to_s.lines.first.strip
    new_model
    puts new_model.modelObjects[0].to_s.gsub(/\{.*\}/, '')
    raise()


    #Check if OSM models have the same number of model objects.
    unless (old_model.modelObjects.size == new_model.modelObjects.size)
      puts "Warning: osm models have different number of objects #{old_model.modelObjects.size} new_model.size = #{new_model.modelObjects.size}"
    end

    #old_model.sort_by{ |p| [p.x, p.y] }

    #Check if IDF models have the same number of IDF objects.
    unless (old_model.toIdfFile.objects.size == new_model.toIdfFile.objects.size)
      puts "Warning: idf models have different number of objects #{old_model.toIdfFile.objects.size} new_model.size = #{new_model.toIdfFile.objects.size}"
    end
  end

  #iterate though all possibilities to test.. for now just these.
  templates.each do |template|
    building_types.each do |building_type|
      climate_zones.each do |climate_zone|
        epw_files.each do |epw_file|
          #set up folders for old and new way of doing things.
          run_dir = "#{Dir.pwd}/output/#{building_type}-#{template}-#{climate_zone}-#{epw_file}"
          refactored_run_dir = "#{run_dir}/refactored/"
          old_method_run_dir = "#{run_dir}/old_method/"
          FileUtils.mkdir_p(refactored_run_dir) unless Dir.exists?(refactored_run_dir)
          FileUtils.mkdir_p(old_method_run_dir) unless Dir.exists?(old_method_run_dir)
          puts run_dir
          #new method of create standards model
          new_model = StandardsModel.get_standard_model(template)
          # Will eventually use new_model.extend(building_type) here to add building type methods and data.
          # new_model.extend(building_type)

          # Once all template logic and building type logic is removed we will be able to remove the building_type and
          # template arguments and simply call new_model.create_protype_model(climate_zone, epw_file, refactored_run_dir)
          new_model.create_prototype_model(building_type, template, climate_zone, epw_file, refactored_run_dir)

          #old method of creating a model.
          old_model = OpenStudio::Model::Model.new()
          old_model.create_prototype_building(building_type, template, climate_zone, epw_file, old_method_run_dir)
          
        end
      end
    end
  end
end

class TestRefactorNREL < Minitest::Test
  building_types = ["FullServiceRestaurant"] #, "Hospital", "HighriseApartment", "LargeHotel", "LargeOffice", "MediumOffice", "MidriseApartment", "Outpatient", "PrimarySchool", "QuickServiceRestaurant", "RetailStandalone", "SecondarySchool", "SmallHotel", "SmallOffice", "RetailStripmall", "Warehouse"]
  templates = ['90.1-2010', 'DOE Ref Pre-1980']
  climate_zones = ['ASHRAE 169-2006-1A']
  epw_files = [nil] # we will need to keep this overloaded to keep arguments consistant.

  #iterate though all possibilities to test.. for now just these.
  templates.each do |template|
    building_types.each do |building_type|
      climate_zones.each do |climate_zone|
        epw_files.each do |epw_file|
          #set up folders for old and new way of doing things.
          run_dir = "#{Dir.pwd}/output/#{building_type}-#{template}-#{climate_zone}-#{epw_file}"
          refactored_run_dir = "#{run_dir}/refactored/"
          old_method_run_dir = "#{run_dir}/old_method/"
          FileUtils.mkdir_p(refactored_run_dir) unless Dir.exists?(refactored_run_dir)
          FileUtils.mkdir_p(old_method_run_dir) unless Dir.exists?(old_method_run_dir)
          puts run_dir
          #new method of create standards model
          new_model = StandardsModel.get_standard_model(template)
          # Will eventually use new_model.extend(building_type) here to add building type methods and data.
          # new_model.extend(building_type)

          # Once all template logic and building type logic is removed we will be able to remove the building_type and
          # template arguments and simply call new_model.create_protype_model(climate_zone, epw_file, refactored_run_dir)
          new_model.create_prototype_model(building_type, template, climate_zone, epw_file, refactored_run_dir)

          #old method of creating a model.
          old_model = OpenStudio::Model::Model.new()
          old_model.create_prototype_building(building_type, template, climate_zone, epw_file, old_method_run_dir)
          # need code to compare old and new methods models
        end
      end
    end
  end
end