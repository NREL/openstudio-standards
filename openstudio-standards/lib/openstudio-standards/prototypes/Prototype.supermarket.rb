# Modules for building-type specific methods
module PrototypeBuilding
module SuperMarket
  def self.define_space_type_map(building_type, template, climate_zone)
  case template
    when 'NECB 2011'
      space_type_map = {
        'Sales' => ['Main Sales','West Perimeter Sales','East Perimeter Sales'],
		'Produce' => ['Produce'],
		'Deli' => ['Deli'],
	    'Bakery' => ['Bakery'],
		'Office' => ['Enclosed Office'],
		'Meeting' => ['Meeting Room'],
		'Dining' => ['Dining Room'],
		'Restroom' => ['Restroom'],
		'Elec/MechRoom' => ['Mechanical Room'],
		'Corridor' => ['Corridor'],
		'Vestibule' => ['Vestibule'],
		'DryStorage' => ['Active Storage']
      }
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      space_type_map = {
        'Sales' => ['Main Sales','West Perimeter Sales','East Perimeter Sales'],
		'Produce' => ['Produce'],
		'Deli' => ['Deli'],
	    'Bakery' => ['Bakery'],
		'Office' => ['Enclosed Office'],
		'Meeting' => ['Meeting Room'],
		'Dining' => ['Dining Room'],
		'Restroom' => ['Restroom'],
		'Elec/MechRoom' => ['Mechanical Room'],
		'Corridor' => ['Corridor'],
		'Vestibule' => ['Vestibule'],
		'DryStorage' => ['Active Storage']
      }
    end
    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
	case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      system_to_space_map = [
        {
          'type' => 'PSZ-AC',
          'name' => 'PSZ_1',
          'space_names' => ['Main Sales']
        },
        {
          'type' => 'PSZ-AC',
          'name' => 'PSZ_2',
          'space_names' => ['West Perimeter Sales']
        },
		       {
          'type' => 'PSZ-AC',
          'name' => 'PSZ_3',
          'space_names' => ['East Perimeter Sales']
        },
        {
          'type' => 'PSZ-AC',
          'name' => 'PSZ_4',
          'space_names' => ['Produce']
        },
		       {
          'type' => 'PSZ-AC',
          'name' => 'PSZ_5',
          'space_names' => ['Deli']
        },
        {
          'type' => 'PSZ-AC',
          'name' => 'PSZ_6',
          'space_names' => ['Bakery']
        },
		       {
          'type' => 'PSZ-AC',
          'name' => 'PSZ_7',
          'space_names' => ['Enclosed Office']
        },
        {
          'type' => 'PSZ-AC',
          'name' => 'PSZ_8',
          'space_names' => ['Meeting Room']
        },
		       {
          'type' => 'PSZ-AC',
          'name' => 'PSZ_9',
          'space_names' => ['Dining Room']
        },
        {
          'type' => 'PSZ-AC',
          'name' => 'PSZ_10',
          'space_names' => ['Restroom']
        },
		       {
          'type' => 'PSZ-AC',
          'name' => 'PSZ_11',
          'space_names' => ['Mechanical Room']
        },
        {
          'type' => 'PSZ-AC',
          'name' => 'PSZ_12',
          'space_names' => ['Corridor']
        },
		       {
          'type' => 'PSZ-AC',
          'name' => 'PSZ_13',
          'space_names' => ['Vestibule']
        },
        {
          'type' => 'PSZ-AC',
          'name' => 'PSZ_14',
          'space_names' => ['Active Storage']
        },
		{
          'type' => 'Exhaust Fan',
          'name' => 'Bakery Exahust Fan',
          'availability_sch_name' => 'SuperMarket MinOA_MotorizedDamper_Sched',
          'flow_rate' => OpenStudio.convert(9050, 'cfm', 'm^3/s').get,
		  'space_names' =>
          [
            'Bakery'
          ]
        },
		  {
          'type' => 'Exhaust Fan',
          'name' => 'Deli Exahust Fan',
          'availability_sch_name' => 'SuperMarket MinOA_MotorizedDamper_Sched',
          'flow_rate' => OpenStudio.convert(9050, 'cfm', 'm^3/s').get,
		  'space_names' =>
          [
            'Deli'
          ]
        },
	   {
		'type' =>'Refrigeration_system',
		'compressor_type' => 'Low Temp',
        'sys_name' =>'Rack A',
		'cases' => [
		{
			'case_type' => 'LT Reach-In Ice Cream',
			'case_name' => 'A Ice Cream Reach-Ins',
			'length' => 14.6,
			'number_of_cases' => 3,
		   'space_names' =>
           [
            'Main Sales'
           ]
		},
		{
			'case_type' => 'LT Coffin Ice Cream',
			'case_name' => 'A Ice Cream Coffins',
			'length' => 2.4,
			'number_of_cases' => 1,
			   'space_names' =>
           [
            'Main Sales'
           ]
		}
		],
		'walkins' => [
		{
		   'walkin_type' => 'Walk-In Freezer',
		   'walkin_name' => 'Grocery Freezer',
		   'insulated_floor_area' => 48,
		   'space_names' =>
           [
            'Active Storage'
           ],
 		    'number_of_walkins' => 1
		}
		],
		'space_names' => ['Main Sales']
        },
        {
		'type' =>'Refrigeration_system',
		'compressor_type' => 'Low Temp',
        'sys_name' =>'Rack B',
		'cases' => [
		{
			'case_type' => 'LT Reach-In Frozen Food',
			'case_name' => 'B Frozen Food Reach-Ins',
			'length' => 13.8,
			'number_of_cases' => 3,
			'space_names' =>
           [
            'Main Sales'
           ]
		}
		],
	    'walkins' => [
		{
		   'walkin_type' => 'Walk-In Freezer',
		   'walkin_name' => 'Bakery Freezer',
		   'insulated_floor_area' => 12,
		   'space_names' =>
           [
            'Bakery'
           ],
		   'number_of_walkins' => 1
        }
		],
		'space_names' => ['Main Sales']
        },
		{
		'type' =>'Refrigeration_system',
        'compressor_type' => 'Med Temp',
        'sys_name' =>'Rack C',
		'cases' => [
		{
			'case_type' => 'LT Reach-In Frozen Food',
			'case_name' => 'C Deli cases',
			'length' => 8.5,
			'number_of_cases' => 3,
			'space_names' =>
           [
            'Main Sales'
           ]
		},
		{
			'case_type' => 'MT Vertical Open',
			'case_name' => 'C Dairy cases',
			'length' => 7.3,
			'number_of_cases' => 1,
			'space_names' =>
           [
            'Main Sales'
           ]
		},
			{
			'case_type' => 'MT Vertical Open',
			'case_name' => 'C Dairy_Meat cases',
			'length' => 6.1,
			'number_of_cases' => 3,
			'space_names' =>
           [
            'Main Sales'
           ]
		},
		{
			'case_type' => 'MT Vertical Open',
			'case_name' => 'C Meat cases',
			'length' => 6.1,
			'number_of_cases' => 1,
			'space_names' =>
           [
            'Main Sales'
           ]
		},
		{
			'case_type' => 'MT Service',
			'case_name' => 'C Service Meat cases',
			'length' => 6.1,
			'number_of_cases' => 1,
			'space_names' =>
           [
            'Main Sales'
           ]
		}
		],
		'walkins' => [
		{
		   'walkin_type' => 'Walk-In Cooler Glass Door',
		   'walkin_name' => 'Dairy Cooler',
		   'insulated_floor_area' => 62,
		   'space_names' =>
           [
            'Active Storage'
           ],
		   'number_of_walkins' => 1
		},
		{
		 'walkin_type' => 'Walk-In Cooler Glass Door',
		   'walkin_name' => 'Beer Cooler',
		   'insulated_floor_area' => 44,
		   'space_names' =>
           [
            'Active Storage'
           ],
		   'number_of_walkins' => 1
		}
		],
		'space_names' => ['Main Sales']
        },
       {
		'type' =>'Refrigeration_system',
        'compressor_type' => 'Med Temp',
        'sys_name' =>'Rack D',
		'cases' => [
		{
			'case_type' => 'MT Vertical Open',
			'case_name' => 'D Beverage cases',
			'length' => 4.9,
			'number_of_cases' => 1,
			'space_names' =>
           [
            'Main Sales'
           ]
		},
		{
			'case_type' => 'MT Service',
			'case_name' => 'D Service Deli',
			'length' => 13.4,
			'number_of_cases' => 1,
			'space_names' =>
           [
            'Main Sales'
           ]
		},
			{
			'case_type' => 'MT Vertical Open',
			'case_name' => 'D Salad_Produce cases',
			'length' => 7.3,
			'number_of_cases' => 2,
			'space_names' =>
           [
            'Main Sales'
           ]
		},
		{
			'case_type' => 'MT Coffin',
			'case_name' => 'D Produce cases',
			'length' => 7.3,
			'number_of_cases' => 1,
			'space_names' =>
           [
            'Main Sales'
           ]
			
		},
		{
			'case_type' => 'MT Coffin',
			'case_name' => 'D Produce Islands',
			'length' => 11,
			'number_of_cases' => 1,
			'space_names' =>
           [
            'Main Sales'
           ]
		},
		{
			'case_type' => 'MT Vertical Open',
			'case_name' => 'D Floral',
			'length' => 3.7,
			'number_of_cases' => 1,
			'space_names' =>
           [
            'Main Sales'
           ]
		},
				{
			'case_type' => 'MT Service',
			'case_name' => 'D Service Bakery',
			'length' => 2.4,
			'number_of_cases' => 1,
			'space_names' =>
           [
            'Main Sales'
           ]
		},
		{
			'case_type' => 'MT Vertical Open',
			'case_name' => 'D Prepared Food',
			'length' => 8.5,
			'number_of_cases' => 2,
			'space_names' =>
           [
            'Main Sales'
           ]
		}
		],
		'walkins' => [
		{
		   'walkin_type' => 'Walk-In Cooler',
		   'walkin_name' => 'Meat Cooler',
		   'insulated_floor_area' => 38,
		   'space_names' =>
           [
            'Active Storage'
           ],
		   'number_of_walkins' => 1
		},
				{
		   'walkin_type' => 'Walk-In Cooler',
		   'walkin_name' => 'Meat Prep',
		   'insulated_floor_area' => 56,
		   'space_names' =>
           [
            'Deli'
           ],
		   'number_of_walkins' => 1
		},
				{
		   'walkin_type' => 'Walk-In Cooler',
		   'walkin_name' => 'Bloom Box',
		   'insulated_floor_area' => 6,
		   'space_names' =>
           [
            'Active Storage'
           ],
		   'number_of_walkins' => 1
		},
				{
		   'walkin_type' => 'Walk-In Cooler',
		   'walkin_name' => 'Deli Cooler',
		   'insulated_floor_area' => 11,
		   'space_names' =>
           [
            'Deli'
           ],
		   'number_of_walkins' => 1
		},
				{
		   'walkin_type' => 'Walk-In Cooler',
		   'walkin_name' => 'Produce Cooler',
		   'insulated_floor_area' => 37,
		   'space_names' =>
           [
            'Active Storage'
           ],
		   'number_of_walkins' => 1
		},
		{
		   'walkin_type' => 'Walk-In Cooler',
		   'walkin_name' => 'Fish Cooler',
		   'insulated_floor_area' => 7,
		   'space_names' =>
           [
            'Active Storage'
           ],
		   'number_of_walkins' => 1
		}
		],
		'space_names' => ['Main Sales']
        }  		
		]
    end

    return system_to_space_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')
	  
	# add humidistat to all spaces
    PrototypeBuilding::SuperMarket.add_humidistat(template, model)
	
	# additional kitchen loads
	PrototypeBuilding::SuperMarket.add_extra_equip_kitchen(template, model)
    
    # reset bakery & deli OA reset
	PrototypeBuilding::SuperMarket.reset_bakery_deli_oa(template, model)   

	OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')
	 
   return true
  end
 
 # define additional kitchen loads based on AEDG baseline model
   def self.add_extra_equip_kitchen(template, model)
     	space_names = ['Deli','Bakery']	
		space_names.each do |space_name|
			space = model.getSpaceByName(space_name).get
			kitchen_definition = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
			kitchen_definition.setName("kitchen load")
			kitchen_definition.setDesignLevel(24714.25)
            kitchen_definition.setFractionLatent(0.25)
            kitchen_definition.setFractionRadiant(0.3)
            kitchen_definition.setFractionLost(0.2)
    
			kitchen_equipment = OpenStudio::Model::ElectricEquipment.new(kitchen_definition)
			kitchen_equipment.setName("kitchen equipment")
			kitchen_sch = model.add_schedule("SuperMarketEle Kit Equip Sch")
			kitchen_equipment.setSchedule(kitchen_sch)
			kitchen_equipment.setSpace(space)
	    end
	end	

# add humidistat to all spaces
  def self.add_humidistat(template, model)
        space_names = ['Main Sales','Produce','West Perimeter Sales','East Perimeter Sales','Deli','Bakery',
		'Enclosed Office','Meeting Room','Dining Room','Restroom','Mechanical Room','Corridor','Vestibule','Active Storage']
	    space_names.each do |space_name|
	      space = model.getSpaceByName(space_name).get
          zone = space.thermalZone.get
          humidistat = OpenStudio::Model::ZoneControlHumidistat.new(model)
          humidistat.setHumidifyingRelativeHumiditySetpointSchedule(model.add_schedule('SuperMarket MinRelHumSetSch'))
          humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(model.add_schedule('SuperMarket MaxRelHumSetSch'))
          zone.setZoneControlHumidistat(humidistat)
	    end	
	end
 # Update exhuast fan efficiency 
 def self.update_exhaust_fan_efficiency(template, model)
      model.getFanZoneExhausts.sort.each do |exhaust_fan|
	    exhaust_fan.setFanEfficiency(0.45)
        exhaust_fan.setPressureRise(125)
     end
 end

 #reset bakery & deli OA from AEDG baseline model
  def self.reset_bakery_deli_oa(template, model)
    space_names = ['Deli','Bakery']	
		space_names.each do |space_name|
		space_kitchen = model.getSpaceByName(space_name).get
	    ventilation = space_kitchen.designSpecificationOutdoorAir.get
        ventilation.setOutdoorAirFlowperPerson(0.0075)
        ventilation.setOutdoorAirFlowperFloorArea(0)
    case template
    when '90.1-2004','90.1-2007','90.1-2010', '90.1-2013'
      ventilation.setOutdoorAirFlowRate(4.27112436)
    end
  end	
  end
  
  def self.update_waterheater_loss_coefficient(template, model)
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
      model.getWaterHeaterMixeds.sort.each do |water_heater|
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(0.798542707)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(0.798542707)
      end
    end
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    PrototypeBuilding::SuperMarket.update_waterheater_loss_coefficient(template, model)

    return true
  end
end
end