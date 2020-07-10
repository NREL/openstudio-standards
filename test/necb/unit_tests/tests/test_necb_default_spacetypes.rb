require_relative '../../../helpers/minitest_helper'



# This class will perform tests that are Spacetype dependant, Test model will be created
# to specifically test aspects of the NECB2011 code that are Spacetype dependant. 
class NECB2011DefaultSpaceTypesTests < Minitest::Test
  #Standards
  Templates = ['NECB2011', 'NECB2015', 'BTAPPRE1980']#,'90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013']


  def setup()
    @file_folder = __dir__
    @test_folder = File.join(@file_folder, '..')
    @root_folder = File.join(@test_folder, '..')
    @resources_folder = File.join(@test_folder, 'resources')
    @expected_results_folder = File.join(@test_folder, 'expected_results')
    @test_results_folder = @expected_results_folder
    @top_output_folder = "#{@test_folder}/output/"
  end
  # Tests to ensure that the NECB default schedules are being defined correctly.
  # This is not for compliance, but for archetype development. 
  # @return [Bool] true if successful. 
  def test_schedule_type_defaults()
    #Create new model for testing. 
    @model = OpenStudio::Model::Model.new
    #Create only above ground geometry (Used for infiltration tests) 
    length = 100.0; width = 100.0 ; num_above_ground_floors = 1; num_under_ground_floors = 0; floor_to_floor_height = 3.8 ; plenum_height = 1; perimeter_zone_depth = 4.57; initial_height = 10.0
    BTAP::Geometry::Wizards::create_shape_rectangle(@model,length, width, num_above_ground_floors,num_under_ground_floors, floor_to_floor_height, plenum_height,perimeter_zone_depth, initial_height )
#    standard = Standard.build('NECB2015')

    header_output = ""
    output = ""
    #Iterate through all spacetypes/buildingtypes. 
    Templates.each do |template|
      #Get spacetypes from googledoc.
      standard = Standard.build(template)

      search_criteria = {
        "template" => template,
      }
      # lookup space type properties
      standards_table = standard.standards_data['space_types']
      standard.model_find_objects(standards_table, search_criteria).each do |space_type_properties|
        header_output = ""
        # Create a space type
        st = OpenStudio::Model::SpaceType.new(@model)
        st.setStandardsBuildingType(space_type_properties['building_type'])
        st.setStandardsSpaceType(space_type_properties['space_type'])
        st.setName("#{template}-#{space_type_properties['building_type']}-#{space_type_properties['space_type']}")
        standard.space_type_apply_rendering_color(st)
        standard.model_add_loads(@model)
  
        #Set all spaces to spacetype
        @model.getSpaces.each do |space|
          space.setSpaceType(st)
        end
          
        #Add Infiltration rates to the space objects themselves. 
        standard.model_apply_infiltration_standard(@model)
          
        #Get handle for space. 
        space = @model.getSpaces[0]
        space_area = space.floorArea #m2
          
  
        #Lights
        total_lpd = []
        lpd_sched = []
        occSensLPDfactor = 1.0
        if template == "NECB2011"
          # NECB2011 space types that require a reduction in the LPD to account for
          # the requirement of an occupancy sensor (8.4.4.6(3) and 4.2.2.2(2))
          reduceLPDSpaces = ["Classroom/lecture/training", "Conf./meet./multi-purpose", "Lounge/recreation",
            "Conf./meet./multi-purpose", "Washroom-sch-A",
            "Washroom-sch-B", "Washroom-sch-C", "Washroom-sch-D", "Washroom-sch-E", "Washroom-sch-F", "Washroom-sch-G",
            "Washroom-sch-H", "Washroom-sch-I", "Dress./fitt. - performance arts", "Locker room", "Retail - dressing/fitting"]
          space_type_name = st.standardsSpaceType.get
          if reduceLPDSpaces.include?(space_type_name)
            occSensLPDfactor = 0.9
          elsif ( (space_type_name=='Storage area' && space_area < 100) || 
               (space_type_name=='Storage area - refrigerated' && space_area < 100) || 
               (space_type_name=='Office - enclosed' && space_area < 25) )
            # Do nothing! In this case, we use the duplicate space type name appended with " - occsens"!
          end
        end
        st.lights.each {|light| total_lpd << light.powerPerFloorArea.get * occSensLPDfactor ; lpd_sched << light.schedule.get.name}
        assert(total_lpd.size <= 1 , "#{total_lpd.size} light definitions given. Expecting <= 1.")
        
        #People / Occupancy
        total_occ_dens = []
        occ_sched = []
        st.people.each {|people_def| total_occ_dens << people_def.peoplePerFloorArea ; occ_sched << people_def.numberofPeopleSchedule.get.name}
        assert(total_occ_dens.size <= 1 , "#{total_occ_dens.size} people definitions given. Expecting <= 1.")

        #Equipment -Gas
        gas_equip_power = []
        gas_equip_sched = []
        st.gasEquipment.each {|gas_equip| gas_equip_power << gas_equip.powerPerFloorArea.get ; gas_equip_sched << gas_equip.schedule.get.name}
        assert( gas_equip_power.size <= 1 , "#{gas_equip_power.size} gas definitions given. Expecting <= 1." ) 
        
        #Equipment -Electric
        elec_equip_power = []
        elec_equip_sched = []
        st.electricEquipment.each {|elec_equip| elec_equip_power << elec_equip.powerPerFloorArea.get ; elec_equip_sched << elec_equip.schedule.get.name}
        assert( elec_equip_power.size <= 1 , "#{elec_equip_power.size} electric definitions given. Expecting <= 1." ) 
        
        #Equipment - Steam
        steam_equip_power = []
        steam_equip_sched = []
        st.steamEquipment.each {|steam_equip| steam_equip_power << steam_equip.powerPerFloorArea.get ; steam_equip_sched << steam_equip.schedule.get.name}
        assert( steam_equip_power.size <= 1 , "#{steam_equip_power.size} steam definitions given. Expecting <= 1." ) 
        
        #Hot Water Equipment
        hw_equip_power = []
        hw_equip_sched = []
        st.hotWaterEquipment.each {|equip| hw_equip_power << equip.powerPerFloorArea.get ; hw_equip_sched << equip.schedule.get.name}
        assert( hw_equip_power.size <= 1 , "#{hw_equip_power.size} hw definitions given. Expecting <= 1." ) 
        
        #Other Equipment
        other_equip_power = []
        other_equip_sched = []
        st.otherEquipment.each {|equip| other_equip_power << equip.powerPerFloorArea.get ; other_equip_sched << equip.schedule.get.name}
        assert( other_equip_power.size <= 1 , "#{other_equip_power.size} other equipment definitions given. Expecting <= 1." ) 
            
        #SHW
        shw_loop = OpenStudio::Model::PlantLoop.new(@model)
        shw_peak_flow_per_area = []
        shw_heating_target_temperature = []
        shw__schedule = ""
        area_per_occ = 0.0
        area_per_occ = 1/total_occ_dens[0].to_f unless total_occ_dens[0].nil?
        water_fixture = standard.model_add_swh_end_uses_by_space(@model, shw_loop, space)
        if water_fixture.nil?
          shw_watts_per_person = 0.0
          shw__fraction_schedule = 0.0
          shw_target_temperature_schedule = "NA"
        else
          shw__fraction_schedule = water_fixture.flowRateFractionSchedule.get.name
          shw_peak_flow = water_fixture.waterUseEquipmentDefinition.peakFlowRate # m3/s
          shw_peak_flow_per_area = shw_peak_flow / space_area #m3/s/m2
          # # Watt per person =             m3/s/m3        * 1000W/kW * (specific heat * dT) * m2/person
          shw_watts_per_person = shw_peak_flow_per_area * 1000 * (4.19 * 44.4) * 1000 * area_per_occ
          shw_target_temperature_schedule = water_fixture.waterUseEquipmentDefinition.targetTemperatureSchedule.get.to_ScheduleRuleset.get.defaultDaySchedule.values
          shw_target_temperature_schedule = shw_target_temperature_schedule.map{|val| val.to_f.round(1) }
        end

        header_output << "SpaceType,"
        output << "#{st.name},"
        #standardsSpaceType
        header_output << "StandardsSpaceType,"
        output << "#{st.standardsSpaceType.get},"
        #standardsBuildingType
        header_output << "standardsBuildingType,"
        output << "#{st.standardsBuildingType.get},"
          
        #lights
        if total_lpd[0].nil?
          total_lpd[0] = 0.0
          lpd_sched[0] = "NA"
        end
        header_output << "Lighting Power Density (W/m2),"
        output << "#{total_lpd[0].round(4)},"
        header_output << "Lighting Schedule,"
        output << "#{lpd_sched[0]},"
        
        #people
        if total_occ_dens[0].nil?
          total_occ_dens[0] = 0.0
          occ_sched[0] = "NA"
        else
          total_occ_dens[0] = 1/total_occ_dens[0].to_f
        end
        header_output << "Occupancy Density (m2/person),"
        output << "#{total_occ_dens[0].round(4)},"
        header_output << "Occupancy Schedule Name,"
        output << "#{occ_sched[0]},"
  
        #equipment - Elec
        if elec_equip_power[0].nil?
          elec_equip_power[0] = 0.0
          elec_equip_sched[0] = "NA"
        end
        header_output << "Elec Equip Power Density (W/m2),"
        output << "#{elec_equip_power[0].round(4)},"
        header_output << "Elec Equip Schedule,"
        output << "#{elec_equip_sched[0]}," 
        
        #equipment - Gas
        if gas_equip_power[0].nil?
          gas_equip_power[0] = 0.0
          gas_equip_sched[0] = "NA"
        end
        header_output << "Gas Equip Power Density (W/m2),"
        output << "#{gas_equip_power[0].round(4)},"
        header_output << "Gas Equip Schedule Name,"
        output << "#{gas_equip_sched[0]}," 
        
        #equipment - steam
        if steam_equip_power[0].nil?
          steam_equip_power[0] = 0.0
          steam_equip_sched[0] = "NA"
        end
        header_output << "Steam Equip Power Density (W/m2),"
        output << "#{steam_equip_power[0].round(4)},"
        header_output << "Steam Equip Schedule,"
        output << "#{steam_equip_sched[0]},"
        
        #equipment - hot water
        if hw_equip_power[0].nil?
          hw_equip_power[0] = 0.0
          hw_equip_sched[0] = "NA"
        end
        header_output << "HW Equip Power Density (W/m2),"
        output << "#{hw_equip_power[0].round(4)},"
        header_output << "HW Equip Schedule,"
        output << "#{hw_equip_sched[0]},"
            
        #SHW
        header_output << "SHW Watt/Person (W/person),"
        output << "#{shw_watts_per_person.round(0)},"
        header_output << "SHW Fraction Schedule,"
        output << "#{shw__fraction_schedule},"
        header_output << "SHW Temperature Setpoint Schedule Values (C),"
        output << "#{shw_target_temperature_schedule},"
          
  
        #Outdoor Air / Ventilation
        dsoa = st.designSpecificationOutdoorAir.get
        header_output << "outdoorAirMethod,"         
        output << "#{dsoa.outdoorAirMethod },"
        header_output << "OutdoorAirFlowperFloorArea (m/s) ,"
        output << "#{dsoa.outdoorAirFlowperFloorArea.round(4)},"
          
        header_output << "OutdoorAirFlowperPerson  (m^3/s*person) ,"
        output << "#{dsoa.outdoorAirFlowperPerson.round(4)},"
          
        header_output << "OutdoorAirFlowRate (m^3/s) ,"
        output << "#{dsoa.outdoorAirFlowRate.round(4)},"
          
        header_output << "OutdoorAirFlowAirChangesperHour (1/h) ,"
        output << "#{dsoa.outdoorAirFlowAirChangesperHour.round(4)},"
          
        header_output << "outdoorAirFlowRateFractionSchedule,"
        if dsoa.outdoorAirFlowRateFractionSchedule.empty?
          output << "NA,"
        else
          output << "#{dsoa.outdoorAirFlowRateFractionSchedule.get.name},"
        end
        #End line
        header_output << "\n"
        output << "\n"
            
        #remove space_type (This speeds things up a bit. 
        st.remove
        shw_loop.remove
        water_fixture.remove unless water_fixture.nil? 
            
      end #loop spacetypes
      puts template
    end #loop Template
    #Write test report file. 
    test_result_file = File.join( @test_results_folder,'space_type_test_results.csv')
    File.open(test_result_file, 'w') {|f| f.write(header_output + output) }
      
    #Test that the values are correct by doing a file compare.
    expected_result_file = File.join(@expected_results_folder,'space_type_expected_results.csv')
    b_result = FileUtils.compare_file(expected_result_file , test_result_file )
    assert( b_result, 
      "Spacetype test results do not match expected results! Compare/diff the output with the stored values here #{expected_result_file} and #{test_result_file}"
    )  
  end 
  
end

