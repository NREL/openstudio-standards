require_relative '../helpers/minitest_helper'



# This class will perform tests that are Spacetype dependant, Test model will be created
# to specifically test aspects of the NECB2011 code that are Spacetype dependant. 
class NECB2011DefaultSystemSelectionTests < Minitest::Test
  #Standards
  Templates = ['NECB 2011']#,'90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013']



  #  # This test will ensure that the system selection for each of the 133 spacetypes are 
  #  # being assigned the appropriate values for LPD.
  #  # @return [Bool] true if successful.
  def test_system_selection()
    #report variables. 
    header_output = ""
    results_array = []
    standard = StandardsModel.get_standard_model('NECB 2011')
    
    #Create new model for testing. 
    empty_model = OpenStudio::Model::Model.new
    #Hardcode heating load to 20kW
    heatingDesignLoad = 20.0

    #GGo through all combinations of floors and cooling loads
    [0,20,21].each do |coolingDesignLoad| 
      [2,4,5].each do |number_of_floors| 
        #Create new model for testing. 
        model = OpenStudio::Model::Model.new
        template = 'NECB 2011'
        #Set weather file
        standard.model_add_design_days_and_weather_file(model, template, File.basename('CAN_BC_Vancouver.718920_CWEC.epw'))
        standard.model_add_ground_temperatures(model, 'HighriseApartment', 'NECB HDD Method')
        #Create Floors
        (1..number_of_floors).each {|floor| OpenStudio::Model::BuildingStory.new(model)}
        
        #Go Through each space type. with a counter
        standard.model_find_objects(standard.standards_data["space_types"], { "template" => 'NECB 2011'}).each_with_index do |space_type_properties , index|

          # Create a space type
          #puts "Testing spacetype #{space_type_properties["building_type"]}-#{space_type_properties["space_type"]}"
          st = OpenStudio::Model::SpaceType.new( model )
          st.setStandardsBuildingType(space_type_properties['building_type'])
          st.setStandardsSpaceType(space_type_properties['space_type'])
          st_name = "#{template}-#{space_type_properties['building_type']}-#{space_type_properties['space_type']}"
          st.setName(st_name)
          standard.space_type_apply_rendering_color(st)
          
          #create space and add the space type to it. 
          space = OpenStudio::Model::Space.new(model)
          space.setSpaceType(st)

        end
        standard.model_add_loads(model)
      
        #Assign Thermal zone and thermostats
        standard.model_create_thermal_zones(model, nil)

        #Run method to test. 
        schedule_type_array , space_zoning_data_array = BTAP::Compliance::NECB2011::necb_spacetype_system_selection(model,heatingDesignLoad,coolingDesignLoad)
        
        #iterate through results          
        space_zoning_data_array.each  do |data| 
          results_array << { 
            :necb_hvac_selection_type => "#{data.necb_hvac_system_selection_type}",
            :space_type_name          => "#{data.building_type_name}-#{data.space_type_name}",
            :number_of_stories        => "#{data.number_of_stories}",
            :heating_capacity         => "#{data.heating_capacity}", 
            :cooling_capacity         => "#{data.cooling_capacity}",
            :system_number            => "#{data.system_number}"
          } 
        end
      end
    end
    test_result_file = File.join(File.dirname(__FILE__),'data','space_type_system_selection_test_results.csv')
    #remove duplicates if any. 
    results_array.uniq!
    #sort array. 
    results_array.sort_by! { |k| [k[:necb_hvac_selection_type],k[:space_type_name],k[:number_of_stories],k[:heating_capacity],k[:cooling_capacity]] }
    CSV.open(test_result_file, "wb") do |csv|
      csv << results_array.first.keys # adds the attributes name on the first line
      results_array.each do |hash|
        csv << hash.values
      end
    end#csv
    
    #Test that the values are correct by doing a file compare.
    expected_result_file = File.join(File.dirname(__FILE__),'data','space_type_system_selection_expected_results.csv')
    b_result = FileUtils.compare_file(expected_result_file , test_result_file )
    assert( b_result, 
      "Spacetype test results do not match expected results! Compare/diff the output with the stored values here #{expected_result_file} and #{test_result_file}"
    )  
    
  end
end
