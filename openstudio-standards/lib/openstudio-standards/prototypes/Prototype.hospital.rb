
# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model

  def define_space_type_map(building_type, building_vintage, climate_zone)
    space_type_map = nil
    case building_vintage
    when 'NECB 2011'
      space_type_map ={
        "Electrical/Mechanical" => ["Basement"],
        "Corr. >= 2.4m wide" => ["Corridor_Flr_1", "Corridor_Flr_2", "Corridor_Flr_5", "Corridor_NW_Flr_3", "Corridor_NW_Flr_4", "Corridor_SE_Flr_3", "Corridor_SE_Flr_4"],
        "Dining - bar lounge/leisure" => ["Dining_Flr_5"],
        "Hospital - emergency" => ["ER_Exam1_Mult4_Flr_1", "ER_Exam3_Mult4_Flr_1", "ER_Trauma1_Flr_1", "ER_Trauma2_Flr_1", "ER_Triage_Mult4_Flr_1"],
        "Hospital - nurses' station" => ["ER_NurseStn_Lobby_Flr_1", "ICU_NurseStn_Lobby_Flr_2", "NurseStn_Lobby_Flr_3", "NurseStn_Lobby_Flr_4", "NurseStn_Lobby_Flr_5", "OR_NurseStn_Lobby_Flr_2"],
        "Hospital - patient room" => ["IC_PatRoom1_Mult5_Flr_2", "IC_PatRoom2_Flr_2", "IC_PatRoom3_Mult6_Flr_2", "PatRoom1_Mult10_Flr_3", "PatRoom1_Mult10_Flr_4", "PatRoom2_Flr_3", "PatRoom2_Flr_4", "PatRoom3_Mult10_Flr_3", "PatRoom3_Mult10_Flr_4", "PatRoom4_Flr_3", "PatRoom4_Flr_4", "PatRoom5_Mult10_Flr_3", "PatRoom5_Mult10_Flr_4", "PatRoom6_Flr_3", "PatRoom6_Flr_4", "PatRoom7_Mult10_Flr_3", "PatRoom7_Mult10_Flr_4", "PatRoom8_Flr_3", "PatRoom8_Flr_4"],
        "Hospital - recovery" => ["ICU_Flr_2"],
        "Food preparation" => ["Kitchen_Flr_5"],
        "Lab - research" => ["Lab_Flr_3", "Lab_Flr_4"],
        "Office - enclosed" => ["Lobby_Records_Flr_1", "Office1_Flr_5", "Office1_Mult4_Flr_1", "Office2_Mult5_Flr_5", "Office3_Flr_5", "Office4_Mult6_Flr_5"],
        "Hospital - operating room" => ["OR1_Flr_2", "OR2_Mult5_Flr_2", "OR3_Flr_2", "OR4_Flr_2"],
        "Hospital - physical therapy" => ["PhysTherapy_Flr_3"],
        "Hospital - radiology/imaging" => ["Radiology_Flr_4"]
      }

    else
      space_type_map = {
      # 'Basement', 'ER_Exam1_Mult4_Flr_1', 'ER_Trauma1_Flr_1', 'ER_Exam3_Mult4_Flr_1', 'ER_Trauma2_Flr_1', 'ER_Triage_Mult4_Flr_1', 'Office1_Mult4_Flr_1', 'Lobby_Records_Flr_1', 'Corridor_Flr_1', 'ER_NurseStn_Lobby_Flr_1', 'OR1_Flr_2', 'OR2_Mult5_Flr_2', 'OR3_Flr_2', 'OR4_Flr_2', 'IC_PatRoom1_Mult5_Flr_2', 'IC_PatRoom2_Flr_2', 'IC_PatRoom3_Mult6_Flr_2', 'ICU_Flr_2', 'ICU_NurseStn_Lobby_Flr_2', 'Corridor_Flr_2', 'OR_NurseStn_Lobby_Flr_2', 'PatRoom1_Mult10_Flr_3', 'PatRoom2_Flr_3', 'PatRoom3_Mult10_Flr_3', 'PatRoom4_Flr_3', 'PatRoom5_Mult10_Flr_3', 'PhysTherapy_Flr_3', 'PatRoom6_Flr_3', 'PatRoom7_Mult10_Flr_3', 'PatRoom8_Flr_3', 'NurseStn_Lobby_Flr_3', 'Lab_Flr_3', 'Corridor_SE_Flr_3', 'Corridor_NW_Flr_3', 'PatRoom1_Mult10_Flr_4', 'PatRoom2_Flr_4', 'PatRoom3_Mult10_Flr_4', 'PatRoom4_Flr_4', 'PatRoom5_Mult10_Flr_4', 'Radiology_Flr_4', 'PatRoom6_Flr_4', 'PatRoom7_Mult10_Flr_4', 'PatRoom8_Flr_4', 'NurseStn_Lobby_Flr_4', 'Lab_Flr_4', 'Corridor_SE_Flr_4', 'Corridor_NW_Flr_4', 'Dining_Flr_5', 'NurseStn_Lobby_Flr_5', 'Kitchen_Flr_5', 'Office1_Flr_5', 'Office2_Mult5_Flr_5', 'Office3_Flr_5', 'Office4_Mult6_Flr_5', 'Corridor_Flr_5'
      'Corridor' => ['Corridor_Flr_1', 'Corridor_Flr_2', 'Corridor_SE_Flr_3', 'Corridor_NW_Flr_3', 'Corridor_SE_Flr_4', 'Corridor_NW_Flr_4', 'Corridor_Flr_5'],
      'Dining' => ['Dining_Flr_5', ],
      'ER_Exam' => ['ER_Exam1_Mult4_Flr_1', 'ER_Exam3_Mult4_Flr_1', ],
      'ER_NurseStn' => ['ER_NurseStn_Lobby_Flr_1', ],
      'ER_Trauma' => ['ER_Trauma1_Flr_1', 'ER_Trauma2_Flr_1', ],
      'ER_Triage' => ['ER_Triage_Mult4_Flr_1', ],
      'ICU_NurseStn' => ['ICU_NurseStn_Lobby_Flr_2', ],
      'ICU_Open' => ['ICU_Flr_2', ],
      'ICU_PatRm' => ['IC_PatRoom1_Mult5_Flr_2', 'IC_PatRoom2_Flr_2', 'IC_PatRoom3_Mult6_Flr_2', ],
      'Kitchen' => ['Kitchen_Flr_5', ],
      'Lab' => ['Lab_Flr_3', 'Lab_Flr_4', ],
      'Lobby' => ['Lobby_Records_Flr_1', ],
      'NurseStn' => ['OR_NurseStn_Lobby_Flr_2', 'NurseStn_Lobby_Flr_3', 'NurseStn_Lobby_Flr_4', 'NurseStn_Lobby_Flr_5', ],
      'OR' => ['OR1_Flr_2', 'OR2_Mult5_Flr_2', 'OR3_Flr_2', 'OR4_Flr_2', ],
      'Office' => ['Office1_Mult4_Flr_1', 'Office1_Flr_5', 'Office2_Mult5_Flr_5', 'Office3_Flr_5', 'Office4_Mult6_Flr_5', ],
      'Basement' => ['Basement',], # 'PatCorridor' => [],
      'PatRoom' => ['PatRoom1_Mult10_Flr_3', 'PatRoom2_Flr_3', 'PatRoom3_Mult10_Flr_3', 'PatRoom4_Flr_3', 'PatRoom5_Mult10_Flr_3', 'PatRoom6_Flr_3',
      'PatRoom7_Mult10_Flr_3', 'PatRoom8_Flr_3', 'PatRoom1_Mult10_Flr_4', 'PatRoom2_Flr_4', 'PatRoom3_Mult10_Flr_4', 'PatRoom4_Flr_4', 'PatRoom5_Mult10_Flr_4',
      'PatRoom6_Flr_4', 'PatRoom7_Mult10_Flr_4', 'PatRoom8_Flr_4', ],
      'PhysTherapy' => ['PhysTherapy_Flr_3', ],
      'Radiology' => ['Radiology_Flr_4', ]   # total number of zones: 55 - equals to the IDF
    }
    end
    return space_type_map
  end

  def define_hvac_system_map(building_type, building_vintage, climate_zone)

    case building_vintage
      when '90.1-2010', '90.1-2013'
        exhaust_flow = 7200
      when '90.1-2004', '90.1-2007'
        exhaust_flow = 8000
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        exhaust_flow = 3710
        exhaust_flow_dining = 1589
    end

    case building_vintage
      when '90.1-2010', '90.1-2013','90.1-2004', '90.1-2007'
      system_to_space_map = [
        {
          'type' => 'VAV',
          'name' => 'VAV_1',
          'space_names' => [
            'Basement', 'Office1_Mult4_Flr_1', 'Lobby_Records_Flr_1', 'Corridor_Flr_1', 'ER_NurseStn_Lobby_Flr_1',
            'ICU_NurseStn_Lobby_Flr_2', 'Corridor_Flr_2', 'OR_NurseStn_Lobby_Flr_2'
          ]
        },
        {
          'type' => 'VAV',
          'name' => 'VAV_ER',
          'space_names' => [
            'ER_Exam1_Mult4_Flr_1', 'ER_Trauma1_Flr_1', 'ER_Exam3_Mult4_Flr_1', 'ER_Trauma2_Flr_1', 'ER_Triage_Mult4_Flr_1'
          ]
        },
        {
          'type' => 'VAV',
          'name' => 'VAV_OR',
          'space_names' => [
            'OR1_Flr_2', 'OR2_Mult5_Flr_2', 'OR3_Flr_2', 'OR4_Flr_2'
          ]
        },
        {
          'type' => 'VAV',
          'name' => 'VAV_ICU',
          'space_names' => [
            'IC_PatRoom1_Mult5_Flr_2', 'IC_PatRoom2_Flr_2', 'IC_PatRoom3_Mult6_Flr_2', 'ICU_Flr_2'
          ]
        },
        {
          'type' => 'VAV',
          'name' => 'VAV_PATRMS',
          'space_names' => [
            'PatRoom1_Mult10_Flr_3', 'PatRoom2_Flr_3', 'PatRoom3_Mult10_Flr_3', 'PatRoom4_Flr_3', 'PatRoom5_Mult10_Flr_3', 'PatRoom6_Flr_3',
            'PatRoom7_Mult10_Flr_3', 'PatRoom8_Flr_3', 'PatRoom1_Mult10_Flr_4', 'PatRoom2_Flr_4', 'PatRoom3_Mult10_Flr_4', 'PatRoom4_Flr_4',
            'PatRoom5_Mult10_Flr_4', 'PatRoom6_Flr_4', 'PatRoom7_Mult10_Flr_4', 'PatRoom8_Flr_4'
          ]
        },
        {
          'type' => 'VAV',
          'name' => 'VAV_2',
            'space_names' => [
              'PhysTherapy_Flr_3', 'NurseStn_Lobby_Flr_3', 'Corridor_SE_Flr_3', 'Corridor_NW_Flr_3', 'Radiology_Flr_4',
              'NurseStn_Lobby_Flr_4', 'Corridor_SE_Flr_4', 'Corridor_NW_Flr_4', 'Dining_Flr_5', 'NurseStn_Lobby_Flr_5',
              'Office1_Flr_5', 'Office2_Mult5_Flr_5', 'Office3_Flr_5', 'Office4_Mult6_Flr_5', 'Corridor_Flr_5'
            ]
        },
        {
          'type' => 'VAV',
          'name' => 'VAV_LABS',
          'space_names' => [
            'Lab_Flr_3', 'Lab_Flr_4'
          ]
        },
        {
          'type' => 'CAV',
          'name' => 'CAV_KITCHEN',
          'space_names' => [
            'Kitchen_Flr_5'
          ]                     # 55 spaces assigned.
        },
        {
          'type' => 'Exhaust Fan',
          'name' => 'Kitchen_Flr_5 Exhaust Fan',
          'availability_sch_name' => 'Hospital Kitchen_Exhaust_SCH',
          'flow_rate' => OpenStudio.convert(exhaust_flow,'cfm','m^3/s').get,
          'balanced_exhaust_fraction_schedule_name' => 'Hospital Kitchen Exhaust Fan Balanced Exhaust Fraction Schedule',
          'space_names' =>
          [
            'Kitchen_Flr_5'
          ]
        },
        {
          'type' => 'Refrigeration',
          'case_type' => 'Walkin Freezer',
          'cooling_capacity_per_length' => 734,
          'length' => 10.98,
          'evaporator_fan_pwr_per_length' => 69,
          'lighting_per_length' => 33,
          'lighting_sch_name' => 'Hospital BLDG_LIGHT_SCH',
          'defrost_pwr_per_length' => 364,
          'restocking_sch_name' => 'Hospital Kitchen_Flr_5_Case:1_WALKINFREEZER_WalkInStockingSched',
          'cop' => 1.5,
          'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
          'condenser_fan_pwr' => 1000,
          'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
          'space_names' =>
          [
            'Kitchen_Flr_5'
          ]
        },
        {
          'type' => 'Refrigeration',
          'case_type' => 'Display Case',
          'cooling_capacity_per_length' => 886.5,
          'length' => 8.93,
          'evaporator_fan_pwr_per_length' => 67,
          'lighting_per_length' => 40,
          'lighting_sch_name' => 'Hospital BLDG_LIGHT_SCH',
          'defrost_pwr_per_length' => 0.0,
          'restocking_sch_name' => 'Hospital Kitchen_Flr_5_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
          'cop' => 3.0,
          'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
          'condenser_fan_pwr' => 1000,
          'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
          'space_names' =>
          [
            'Kitchen_Flr_5'
          ]
        }
      ]
      return system_to_space_map
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      system_to_space_map = [
        {
          'type' => 'VAV',
          'name' => 'CAV_1',
          'space_names' => [
            'ER_Exam1_Mult4_Flr_1', 'ER_Trauma1_Flr_1', 'ER_Exam3_Mult4_Flr_1', 'ER_Trauma2_Flr_1', 'ER_Triage_Mult4_Flr_1','IC_PatRoom1_Mult5_Flr_2',
            'PatRoom1_Mult10_Flr_3','PatRoom5_Mult10_Flr_3', 'PatRoom7_Mult10_Flr_3', 'PatRoom3_Mult10_Flr_4', 'PatRoom5_Mult10_Flr_4',
            'PatRoom6_Flr_4', 'PatRoom7_Mult10_Flr_4'
          ]
        },
        {
          'type' => 'VAV',
          'name' => 'CAV_2',
          'space_names' => [
            'OR1_Flr_2','OR2_Mult5_Flr_2','OR3_Flr_2','OR4_Flr_2','IC_PatRoom2_Flr_2','PatRoom2_Flr_3','PatRoom6_Flr_3','PatRoom8_Flr_3','PatRoom4_Flr_4'
          ]
        },
        {
          'type' => 'VAV',
          'name' => 'VAV_1',
          'space_names' => [
            'Office1_Mult4_Flr_1','Lobby_Records_Flr_1','Corridor_Flr_1','ER_NurseStn_Lobby_Flr_1','IC_PatRoom3_Mult6_Flr_2','ICU_NurseStn_Lobby_Flr_2',
            'Corridor_Flr_2','OR_NurseStn_Lobby_Flr_2','PatRoom3_Mult10_Flr_3','Lab_Flr_3','PatRoom1_Mult10_Flr_4','PatRoom8_Flr_4'
          ]
        },
        {
          'type' => 'VAV',
          'name' => 'VAV_2',
          'space_names' => [
            'ICU_Flr_2',
            'PatRoom4_Flr_3',
            'PhysTherapy_Flr_3',
            'NurseStn_Lobby_Flr_3',
            'Corridor_SE_Flr_3',
            'Corridor_NW_Flr_3',
            'PatRoom2_Flr_4',
            'Radiology_Flr_4',
            'NurseStn_Lobby_Flr_4',
            'Lab_Flr_4',
            'Corridor_SE_Flr_4',
            'Corridor_NW_Flr_4',
            'Dining_Flr_5',
            'NurseStn_Lobby_Flr_5',
            'Kitchen_Flr_5',
            'Office1_Flr_5',
            'Office2_Mult5_Flr_5',
            'Office3_Flr_5',
            'Office4_Mult6_Flr_5',
            'Corridor_Flr_5'
          ]
        },
        {
          'type' => 'Exhaust Fan',
          'name' => 'Kitchen_Flr_5 Exhaust Fan',
          'availability_sch_name' => 'Hospital HVACOperationSchd',
          'flow_rate' => OpenStudio.convert(exhaust_flow,'cfm','m^3/s').get,
          'space_names' =>
          [
            'Kitchen_Flr_5'
          ]
        },
        {
          'type' => 'Exhaust Fan',
          'name' => 'Dining_Flr_5 Exhaust Fan',
          'availability_sch_name' => 'Hospital HVACOperationSchd',
          'flow_rate' => OpenStudio.convert(exhaust_flow_dining,'cfm','m^3/s').get,
          'space_names' =>
          [
            'Dining_Flr_5'
          ]
        },
        {
          'type' => 'Refrigeration',
          'case_type' => 'Walkin Freezer',
          'cooling_capacity_per_length' => 734,
          'length' => 10.98,
          'evaporator_fan_pwr_per_length' => 69,
          'lighting_per_length' => 33,
          'lighting_sch_name' => 'Hospital BLDG_LIGHT_SCH',
          'defrost_pwr_per_length' => 364,
          'restocking_sch_name' => 'Hospital Kitchen_Flr_5_Case:1_WALKINFREEZER_WalkInStockingSched',
          'cop' => 1.5,
          'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
          'condenser_fan_pwr' => 1000,
          'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
          'space_names' =>
          [
            'Kitchen_Flr_5'
          ]
        },
        {
          'type' => 'Refrigeration',
          'case_type' => 'Display Case',
          'cooling_capacity_per_length' => 886.5,
          'length' => 8.93,
          'evaporator_fan_pwr_per_length' => 67,
          'lighting_per_length' => 40,
          'lighting_sch_name' => 'Hospital BLDG_LIGHT_SCH',
          'defrost_pwr_per_length' => 0.0,
          'restocking_sch_name' => 'Hospital Kitchen_Flr_5_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
          'cop' => 3.0,
          'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
          'condenser_fan_pwr' => 1000,
          'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
          'space_names' =>
          [
            'Kitchen_Flr_5'
          ]
        }
      ]
      return system_to_space_map
    end
  end

  def define_space_multiplier

    space_multiplier_map = {
      'ER_Exam1_Mult4_Flr_1' => 4,
      'ER_Exam3_Mult4_Flr_1' => 4,
      'ER_Triage_Mult4_Flr_1' => 4,
      'Office1_Mult4_Flr_1' => 5,
      'OR2_Mult5_Flr_2' => 5,
      'IC_PatRoom1_Mult5_Flr_2' => 5,
      'IC_PatRoom3_Mult6_Flr_2' => 6,
      'PatRoom1_Mult10_Flr_3' => 10,
      'PatRoom3_Mult10_Flr_3' => 10,
      'PatRoom5_Mult10_Flr_3' => 10,
      'PatRoom7_Mult10_Flr_3' => 10,
      'PatRoom1_Mult10_Flr_4' => 10,
      'PatRoom3_Mult10_Flr_4' => 10,
      'PatRoom5_Mult10_Flr_4' => 10,
      'PatRoom7_Mult10_Flr_4' => 10,
      'Office2_Mult5_Flr_5' => 5,
      'Office4_Mult6_Flr_5' => 6
    }
    return space_multiplier_map
  end


  def custom_hvac_tweaks(building_type, building_vintage, climate_zone, prototype_input)

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')

    system_to_space_map = define_hvac_system_map(building_type, building_vintage, climate_zone)

    hot_water_loop = nil
    self.getPlantLoops.each do |loop|
      # If it has a boiler:hotwater, it is the correct loop
      if loop.supplyComponents('OS:Boiler:HotWater'.to_IddObjectType).size > 0
        hot_water_loop = loop
      end
    end
    if hot_water_loop
      case building_vintage
        when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
          self.add_humidifier_er(building_vintage, hot_water_loop)
          self.add_humidifier_or(building_vintage, hot_water_loop)
          self.add_humidifier_icu(building_vintage, hot_water_loop)
          self.add_humidifier_lab(building_vintage, hot_water_loop)
          self.add_humidifier_pat(building_vintage, hot_water_loop)
        when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
          self.add_humidifier_vav1(building_vintage, hot_water_loop)
          self.add_humidifier_vav2(building_vintage, hot_water_loop)
      end
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.model.Model', 'Could not find hot water loop to attach humidifier to.')
    end

    self.reset_kitchen_OA(building_vintage)
    self.update_exhaust_fan_efficiency(building_vintage)
    self.reset_or_room_vav_minimum_damper(prototype_input, building_vintage)

    return true
  end

  def update_waterheater_loss_coefficient(building_vintage)
    case building_vintage
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      self.getWaterHeaterMixeds.sort.each do |water_heater|
        if water_heater.name.to_s.include?("Booster")
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.053159296)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.053159296)
        else
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(15.60100708)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(15.60100708)
        end
      end
    end
  end

  def custom_swh_tweaks(building_type, building_vintage, climate_zone, prototype_input)

    self.update_waterheater_loss_coefficient(building_vintage)
    return true

  end

  def reset_kitchen_OA(building_vintage)
    space_kitchen = self.getSpaceByName('Kitchen_Flr_5').get
    ventilation = space_kitchen.designSpecificationOutdoorAir.get
    ventilation.setOutdoorAirFlowperPerson(0)
    ventilation.setOutdoorAirFlowperFloorArea(0)
    case building_vintage
      when '90.1-2010', '90.1-2013'
        ventilation.setOutdoorAirFlowRate(3.398)
      when '90.1-2004', '90.1-2007', 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        ventilation.setOutdoorAirFlowRate(3.776)
    end
  end

  def update_exhaust_fan_efficiency(building_vintage)
    case building_vintage
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        self.getFanZoneExhausts.sort.each do |exhaust_fan|
          exhaust_fan.setFanEfficiency(0.16)
          exhaust_fan.setPressureRise(125)
        end
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        self.getFanZoneExhausts.sort.each do |exhaust_fan|
          exhaust_fan.setFanEfficiency(0.338)
          exhaust_fan.setPressureRise(125)
        end
    end
  end

  def add_humidifier_er(building_vintage, hot_water_loop)
    er_exam_space = self.getSpaceByName('ER_Exam3_Mult4_Flr_1').get
    er_exam_zone = er_exam_space.thermalZone.get
    humidistat = OpenStudio::Model::ZoneControlHumidistat.new(self)
    humidistat.setHumidifyingRelativeHumiditySetpointSchedule(self.add_schedule('Hospital MinRelHumSetSch'))
    humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(self.add_schedule('Hospital MaxRelHumSetSch'))
    er_exam_zone.setZoneControlHumidistat(humidistat)

    self.getAirLoopHVACs.each do |air_loop|
      if air_loop.thermalZones.include? er_exam_zone
        humidifier = OpenStudio::Model::HumidifierSteamElectric.new(self)
        humidifier.setRatedCapacity(3.72E-5)
        humidifier.setRatedPower(100000)
        humidifier.setName("#{air_loop.name.get} Electric Steam Humidifier")
        # get the water heating coil and add humidifier to the outlet of heating coil (right before fan)
        htg_coil = nil
        air_loop.supplyComponents.each do |equip|
          if equip.to_CoilHeatingWater.is_initialized
            htg_coil = equip.to_CoilHeatingWater.get
          end
        end
        heating_coil_outlet_node = htg_coil.airOutletModelObject().get.to_Node.get
        supply_outlet_node = air_loop.supplyOutletNode
        humidifier.addToNode(heating_coil_outlet_node)
        humidity_spm = OpenStudio::Model::SetpointManagerSingleZoneHumidityMinimum.new(self)
        case building_vintage
        when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
          extra_elec_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(self,self.alwaysOnDiscreteSchedule)
          extra_elec_htg_coil.setName("ER extra Electric Htg Coil")
          extra_water_htg_coil = OpenStudio::Model::CoilHeatingWater.new(self,self.alwaysOnDiscreteSchedule)
          extra_water_htg_coil.setName("ER extra Water Htg Coil")
          hot_water_loop.addDemandBranchForComponent(extra_water_htg_coil)
          extra_elec_htg_coil.addToNode(supply_outlet_node)
          extra_water_htg_coil.addToNode(supply_outlet_node)
        end
        # humidity_spm.addToNode(supply_outlet_node)
        humidity_spm.addToNode(humidifier.outletModelObject().get.to_Node.get)
        humidity_spm.setControlZone(er_exam_zone)
      end
    end
  end

  def add_humidifier_or(building_vintage, hot_water_loop)
    or_exam_space = self.getSpaceByName('OR2_Mult5_Flr_2').get
    or_exam_zone = or_exam_space.thermalZone.get
    humidistat = OpenStudio::Model::ZoneControlHumidistat.new(self)
    humidistat.setHumidifyingRelativeHumiditySetpointSchedule(self.add_schedule('Hospital MinRelHumSetSch'))
    humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(self.add_schedule('Hospital MaxRelHumSetSch'))
    or_exam_zone.setZoneControlHumidistat(humidistat)

    self.getAirLoopHVACs.each do |air_loop|
      if air_loop.thermalZones.include? or_exam_zone
        humidifier = OpenStudio::Model::HumidifierSteamElectric.new(self)
        humidifier.setRatedCapacity(3.72E-5)
        humidifier.setRatedPower(100000)
        humidifier.setName("#{air_loop.name.get} Electric Steam Humidifier")
        # get the water heating coil and add humidifier to the outlet of heating coil (right before fan)
        htg_coil = nil
        air_loop.supplyComponents.each do |equip|
          if equip.to_CoilHeatingWater.is_initialized
            htg_coil = equip.to_CoilHeatingWater.get
          end
        end
        heating_coil_outlet_node = htg_coil.airOutletModelObject().get.to_Node.get
        supply_outlet_node = air_loop.supplyOutletNode
        humidifier.addToNode(heating_coil_outlet_node)
        humidity_spm = OpenStudio::Model::SetpointManagerSingleZoneHumidityMinimum.new(self)
        case building_vintage
        when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
          extra_elec_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(self,self.alwaysOnDiscreteSchedule)
          extra_elec_htg_coil.setName("OR extra Electric Htg Coil")
          extra_water_htg_coil = OpenStudio::Model::CoilHeatingWater.new(self,self.alwaysOnDiscreteSchedule)
          extra_water_htg_coil.setName("OR extra Water Htg Coil")
          hot_water_loop.addDemandBranchForComponent(extra_water_htg_coil)
          extra_elec_htg_coil.addToNode(supply_outlet_node)
          extra_water_htg_coil.addToNode(supply_outlet_node)
        end
        # humidity_spm.addToNode(supply_outlet_node)
        humidity_spm.addToNode(humidifier.outletModelObject().get.to_Node.get)
        humidity_spm.setControlZone(or_exam_zone)
      end
    end
  end

 def add_humidifier_icu(building_vintage, hot_water_loop)
    icu_space = self.getSpaceByName('ICU_Flr_2').get
    icu_zone = icu_space.thermalZone.get
    humidistat = OpenStudio::Model::ZoneControlHumidistat.new(self)
    humidistat.setHumidifyingRelativeHumiditySetpointSchedule(self.add_schedule('Hospital MinRelHumSetSch'))
    humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(self.add_schedule('Hospital MaxRelHumSetSch'))
    icu_zone.setZoneControlHumidistat(humidistat)

    self.getAirLoopHVACs.each do |air_loop|
      if air_loop.thermalZones.include? icu_zone
        humidifier = OpenStudio::Model::HumidifierSteamElectric.new(self)
        humidifier.setRatedCapacity(3.72E-5)
        humidifier.setRatedPower(100000)
        humidifier.setName("#{air_loop.name.get} Electric Steam Humidifier")
        # get the water heating coil and add humidifier to the outlet of heating coil (right before fan)
        htg_coil = nil
        air_loop.supplyComponents.each do |equip|
          if equip.to_CoilHeatingWater.is_initialized
            htg_coil = equip.to_CoilHeatingWater.get
          end
        end
        heating_coil_outlet_node = htg_coil.airOutletModelObject().get.to_Node.get
        supply_outlet_node = air_loop.supplyOutletNode
        humidifier.addToNode(heating_coil_outlet_node)
        humidity_spm = OpenStudio::Model::SetpointManagerSingleZoneHumidityMinimum.new(self)
        case building_vintage
        when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
          extra_elec_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(self,self.alwaysOnDiscreteSchedule)
          extra_elec_htg_coil.setName("ICU extra Electric Htg Coil")
          extra_water_htg_coil = OpenStudio::Model::CoilHeatingWater.new(self,self.alwaysOnDiscreteSchedule)
          extra_water_htg_coil.setName("ICU extra Water Htg Coil")
          hot_water_loop.addDemandBranchForComponent(extra_water_htg_coil)
          extra_elec_htg_coil.addToNode(supply_outlet_node)
          extra_water_htg_coil.addToNode(supply_outlet_node)
        end
        # humidity_spm.addToNode(supply_outlet_node)
        humidity_spm.addToNode(humidifier.outletModelObject().get.to_Node.get)
        humidity_spm.setControlZone(icu_zone)
      end
    end
  end

 def add_humidifier_pat(building_vintage, hot_water_loop)
    pat_space = self.getSpaceByName('PatRoom5_Mult10_Flr_4').get
    pat_zone = pat_space.thermalZone.get
    humidistat = OpenStudio::Model::ZoneControlHumidistat.new(self)
    humidistat.setHumidifyingRelativeHumiditySetpointSchedule(self.add_schedule('Hospital MinRelHumSetSch'))
    humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(self.add_schedule('Hospital MaxRelHumSetSch'))
    pat_zone.setZoneControlHumidistat(humidistat)

    self.getAirLoopHVACs.each do |air_loop|
      if air_loop.thermalZones.include? pat_zone
        humidifier = OpenStudio::Model::HumidifierSteamElectric.new(self)
        humidifier.setRatedCapacity(3.72E-5)
        humidifier.setRatedPower(100000)
        humidifier.setName("#{air_loop.name.get} Electric Steam Humidifier")
        # get the water heating coil and add humidifier to the outlet of heating coil (right before fan)
        htg_coil = nil
        air_loop.supplyComponents.each do |equip|
          if equip.to_CoilHeatingWater.is_initialized
            htg_coil = equip.to_CoilHeatingWater.get
          end
        end
        heating_coil_outlet_node = htg_coil.airOutletModelObject().get.to_Node.get
        supply_outlet_node = air_loop.supplyOutletNode
        humidifier.addToNode(heating_coil_outlet_node)
        humidity_spm = OpenStudio::Model::SetpointManagerSingleZoneHumidityMinimum.new(self)
        case building_vintage
        when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
          extra_elec_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(self,self.alwaysOnDiscreteSchedule)
          extra_elec_htg_coil.setName("Pat extra Electric Htg Coil")
          extra_water_htg_coil = OpenStudio::Model::CoilHeatingWater.new(self,self.alwaysOnDiscreteSchedule)
          extra_water_htg_coil.setName("Pat extra Water Htg Coil")
          hot_water_loop.addDemandBranchForComponent(extra_water_htg_coil)
          extra_elec_htg_coil.addToNode(supply_outlet_node)
          extra_water_htg_coil.addToNode(supply_outlet_node)
        end
        # humidity_spm.addToNode(supply_outlet_node)
        humidity_spm.addToNode(humidifier.outletModelObject().get.to_Node.get)
        humidity_spm.setControlZone(pat_zone)
      end
    end
  end

   def add_humidifier_lab(building_vintage, hot_water_loop)
    lab_space = self.getSpaceByName('Lab_Flr_3').get
    lab_zone = lab_space.thermalZone.get
    humidistat = OpenStudio::Model::ZoneControlHumidistat.new(self)
    humidistat.setHumidifyingRelativeHumiditySetpointSchedule(self.add_schedule('Hospital MinRelHumSetSch'))
    humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(self.add_schedule('Hospital MaxRelHumSetSch'))
    lab_zone.setZoneControlHumidistat(humidistat)

    self.getAirLoopHVACs.each do |air_loop|
      if air_loop.thermalZones.include? lab_zone
        humidifier = OpenStudio::Model::HumidifierSteamElectric.new(self)
        humidifier.setRatedCapacity(3.72E-5)
        humidifier.setRatedPower(100000)
        humidifier.setName("#{air_loop.name.get} Electric Steam Humidifier")
        # get the water heating coil and add humidifier to the outlet of heating coil (right before fan)
        htg_coil = nil
        air_loop.supplyComponents.each do |equip|
          if equip.to_CoilHeatingWater.is_initialized
            htg_coil = equip.to_CoilHeatingWater.get
          end
        end
        heating_coil_outlet_node = htg_coil.airOutletModelObject().get.to_Node.get
        supply_outlet_node = air_loop.supplyOutletNode
        humidifier.addToNode(heating_coil_outlet_node)
        humidity_spm = OpenStudio::Model::SetpointManagerSingleZoneHumidityMinimum.new(self)
        case building_vintage
        when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
          extra_elec_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(self,self.alwaysOnDiscreteSchedule)
          extra_elec_htg_coil.setName("lab extra Electric Htg Coil")
          extra_water_htg_coil = OpenStudio::Model::CoilHeatingWater.new(self,self.alwaysOnDiscreteSchedule)
          extra_water_htg_coil.setName("lab extra Water Htg Coil")
          hot_water_loop.addDemandBranchForComponent(extra_water_htg_coil)
          extra_elec_htg_coil.addToNode(supply_outlet_node)
          extra_water_htg_coil.addToNode(supply_outlet_node)
        end
        # humidity_spm.addToNode(supply_outlet_node)
        humidity_spm.addToNode(humidifier.outletModelObject().get.to_Node.get)
        humidity_spm.setControlZone(lab_zone)
      end
    end
  end

  def add_humidifier_vav1(building_vintage, hot_water_loop)
    or_exam_space = self.getSpaceByName('ER_Exam3_Mult4_Flr_1').get
    or_exam_zone = or_exam_space.thermalZone.get
    humidistat = OpenStudio::Model::ZoneControlHumidistat.new(self)
    humidistat.setHumidifyingRelativeHumiditySetpointSchedule(self.add_schedule('Hospital MinRelHumSetSch'))
    humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(self.add_schedule('Hospital MaxRelHumSetSch'))
    or_exam_zone.setZoneControlHumidistat(humidistat)

    self.getAirLoopHVACs.each do |air_loop|
      if air_loop.thermalZones.include? or_exam_zone
        humidifier = OpenStudio::Model::HumidifierSteamElectric.new(self)
        humidifier.setRatedCapacity(3.72E-5)
        humidifier.setRatedPower(100000)
        humidifier.setName("#{air_loop.name.get} Electric Steam Humidifier")
        # get the water heating coil and add humidifier to the outlet of heating coil (right before fan)
        htg_coil = nil
        air_loop.supplyComponents.each do |equip|
          if equip.to_CoilHeatingWater.is_initialized
            htg_coil = equip.to_CoilHeatingWater.get
          end
        end
        heating_coil_outlet_node = htg_coil.airOutletModelObject().get.to_Node.get
        supply_outlet_node = air_loop.supplyOutletNode
        humidifier.addToNode(heating_coil_outlet_node)
        humidity_spm = OpenStudio::Model::SetpointManagerSingleZoneHumidityMinimum.new(self)
        case building_vintage
        when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
          extra_elec_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(self,self.alwaysOnDiscreteSchedule)
          extra_elec_htg_coil.setName("OR extra Electric Htg Coil")
          extra_water_htg_coil = OpenStudio::Model::CoilHeatingWater.new(self,self.alwaysOnDiscreteSchedule)
          extra_water_htg_coil.setName("OR extra Water Htg Coil")
          hot_water_loop.addDemandBranchForComponent(extra_water_htg_coil)
          extra_elec_htg_coil.addToNode(supply_outlet_node)
          extra_water_htg_coil.addToNode(supply_outlet_node)
        end
        # humidity_spm.addToNode(supply_outlet_node)
        humidity_spm.addToNode(humidifier.outletModelObject().get.to_Node.get)
        humidity_spm.setControlZone(or_exam_zone)
      end
    end
  end

  def add_humidifier_vav2(building_vintage, hot_water_loop)
    or_exam_space = self.getSpaceByName('OR2_Mult5_Flr_2').get
    or_exam_zone = or_exam_space.thermalZone.get
    humidistat = OpenStudio::Model::ZoneControlHumidistat.new(self)
    humidistat.setHumidifyingRelativeHumiditySetpointSchedule(self.add_schedule('Hospital MinRelHumSetSch'))
    humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(self.add_schedule('Hospital MaxRelHumSetSch'))
    or_exam_zone.setZoneControlHumidistat(humidistat)

    self.getAirLoopHVACs.each do |air_loop|
      if air_loop.thermalZones.include? or_exam_zone
        humidifier = OpenStudio::Model::HumidifierSteamElectric.new(self)
        humidifier.setRatedCapacity(3.72E-5)
        humidifier.setRatedPower(100000)
        humidifier.setName("#{air_loop.name.get} Electric Steam Humidifier")
        # get the water heating coil and add humidifier to the outlet of heating coil (right before fan)
        htg_coil = nil
        air_loop.supplyComponents.each do |equip|
          if equip.to_CoilHeatingWater.is_initialized
            htg_coil = equip.to_CoilHeatingWater.get
          end
        end
        heating_coil_outlet_node = htg_coil.airOutletModelObject().get.to_Node.get
        supply_outlet_node = air_loop.supplyOutletNode
        humidifier.addToNode(heating_coil_outlet_node)
        humidity_spm = OpenStudio::Model::SetpointManagerSingleZoneHumidityMinimum.new(self)
        case building_vintage
        when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
          extra_elec_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(self,self.alwaysOnDiscreteSchedule)
          extra_elec_htg_coil.setName("OR extra Electric Htg Coil")
          extra_water_htg_coil = OpenStudio::Model::CoilHeatingWater.new(self,self.alwaysOnDiscreteSchedule)
          extra_water_htg_coil.setName("OR extra Water Htg Coil")
          hot_water_loop.addDemandBranchForComponent(extra_water_htg_coil)
          extra_elec_htg_coil.addToNode(supply_outlet_node)
          extra_water_htg_coil.addToNode(supply_outlet_node)
        end
        # humidity_spm.addToNode(supply_outlet_node)
        humidity_spm.addToNode(humidifier.outletModelObject().get.to_Node.get)
        humidity_spm.setControlZone(or_exam_zone)
      end
    end
  end

  def hospital_add_daylighting_controls(building_vintage)
    space_names = ['Office1_Flr_5','Office3_Flr_5','Lobby_Records_Flr_1']
    space_names.each do |space_name|
      space = self.getSpaceByName(space_name).get
      space.addDaylightingControls(building_vintage, false, false)
    end
  end

  def reset_or_room_vav_minimum_damper(prototype_input, building_vintage)
    case building_vintage
    when '90.1-2004', '90.1-2007'
      return true
    when '90.1-2010', '90.1-2013'
      self.getAirTerminalSingleDuctVAVReheats.sort.each do |airterminal|
        airterminal_name = airterminal.name.get
        if airterminal_name.include? "OR1" or airterminal_name.include? "OR2" or airterminal_name.include? "OR3" or airterminal_name.include? "OR4"
          airterminal.setZoneMinimumAirFlowMethod('Scheduled')
          airterminal.setMinimumAirFlowFractionSchedule(add_schedule("Hospital OR_MinSA_Sched"))
        end
      end
    end
  end



  def modify_hospital_OAcontroller(building_vintage)
    self.getAirLoopHVACs.each do |air_loop|
      oa_sys = air_loop.airLoopHVACOutdoorAirSystem.get
      oa_control = oa_sys.getControllerOutdoorAir
      case air_loop.name.get
        when 'VAV_ER', 'VAV_ICU' , 'VAV_LABS' , 'VAV_OR' , 'VAV_PATRMS','CAV_1','CAV_2'
          oa_control.setEconomizerControlType('NoEconomizer')
      end
    end
  end

end

