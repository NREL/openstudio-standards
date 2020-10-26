module BTAP
  def self.perform_qaqc(model)
    surfaces = {}
    outdoor_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(model.getSurfaces(), "Outdoors")
    outdoor_walls = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Wall")
    outdoor_roofs = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "RoofCeiling")
    outdoor_floors = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Floor")
    outdoor_subsurfaces = BTAP::Geometry::Surfaces::get_subsurfaces_from_surfaces(outdoor_surfaces)

    ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(model.getSurfaces(), "Ground")
    ground_walls = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "Wall")
    ground_roofs = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "RoofCeiling")
    ground_floors = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "Floor")

    windows = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["FixedWindow" , "OperableWindow" ])
    skylights = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["Skylight", "TubularDaylightDiffuser","TubularDaylightDome" ])
    doors = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["Door" , "GlassDoor" ])
    overhead_doors = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["OverheadDoor" ])
    electric_peak = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM tabulardatawithstrings WHERE ReportName='EnergyMeters'" +
        " AND ReportForString='Entire Facility' AND TableName='Annual and Peak Values - Electricity' AND RowName='Electricity:Facility'" +
        " AND ColumnName='Electricity Maximum Value' AND Units='W'")
    natural_gas_peak = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM tabulardatawithstrings WHERE ReportName='EnergyMeters'" +
        " AND ReportForString='Entire Facility' AND TableName='Annual and Peak Values - Gas' AND RowName='Gas:Facility'" +
        " AND ColumnName='Gas Maximum Value' AND Units='W'")

    # Create hash to store all the collected data. 
    qaqc = {}
    error_warning=[]
    qaqc[:os_standards_revision] = OpenstudioStandards::git_revision
    qaqc[:os_standards_version] = OpenstudioStandards::VERSION
    # Store Building data. 
    qaqc[:building] = {}
    qaqc[:building][:name] = model.building.get.name.get
    qaqc[:building][:conditioned_floor_area_m2]=nil
    unless model.building.get.conditionedFloorArea().empty?
      qaqc[:building][:conditioned_floor_area_m2] = model.building.get.conditionedFloorArea().get 
    else
      error_warning <<  "model.building.get.conditionedFloorArea() is empty for #{model.building.get.name.get}"
    end
    qaqc[:building][:exterior_area_m2] = model.building.get.exteriorSurfaceArea() #m2
    qaqc[:building][:volume] = model.building.get.airVolume() #m3
    qaqc[:building][:number_of_stories] = model.getBuildingStorys.size
    # Store Geography Data
    qaqc[:geography] ={}
    qaqc[:geography][:hdd] = BTAP::Environment::WeatherFile.new( model.getWeatherFile.path.get.to_s ).hdd18
    qaqc[:geography][:cdd] = BTAP::Environment::WeatherFile.new( model.getWeatherFile.path.get.to_s ).cdd18
    qaqc[:geography][:climate_zone] = NECB2011.new().get_climate_zone_name(qaqc[:geography][:hdd])
    qaqc[:geography][:city] = model.getWeatherFile.city
    qaqc[:geography][:state_province_region] = model.getWeatherFile.stateProvinceRegion
    qaqc[:geography][:country] = model.getWeatherFile.country
    qaqc[:geography][:latitude] = model.getWeatherFile.latitude
    qaqc[:geography][:longitude] = model.getWeatherFile.longitude
    
    #Spacetype Breakdown
    qaqc[:spacetype_area_breakdown]={}
    model.getSpaceTypes.sort.each do |spaceType|
      next if spaceType.floorArea == 0

      # data for space type breakdown
      display = spaceType.name.get
      floor_area_si = 0
      # loop through spaces so I can skip if not included in floor area
      spaceType.spaces.sort.each do |space|
        next if not space.partofTotalFloorArea
        floor_area_si += space.floorArea * space.multiplier
      end
      qaqc[:spacetype_area_breakdown][spaceType.name.get.gsub(/\s+/, "_").downcase.to_sym] = floor_area_si
    end
    
    
    
    #Economics Section
    qaqc[:economics] = {}
    costing_rownames = model.sqlFile().get().execAndReturnVectorOfString("SELECT RowName FROM TabularDataWithStrings WHERE ReportName='LEEDsummary' AND ReportForString='Entire Facility' AND TableName='EAp2-7. Energy Cost Summary' AND ColumnName='Total Energy Cost'")
    #==> ["Electricity", "Natural Gas", "Additional", "Total"]
    costing_rownames = validate_optional(costing_rownames, model, "N/A")
    unless costing_rownames == "N/A"
      costing_rownames.each do |rowname|
        case rowname
        when "Electricity"
          qaqc[:economics][:electricity_cost] = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='LEEDsummary' AND ReportForString='Entire Facility' AND TableName='EAp2-7. Energy Cost Summary' AND ColumnName='Total Energy Cost' AND RowName='#{rowname}'").get
          qaqc[:economics][:electricity_cost_per_m2]=qaqc[:economics][:electricity_cost]/qaqc[:building][:conditioned_floor_area_m2] unless model.building.get.conditionedFloorArea().empty?
        when "Natural Gas"
          qaqc[:economics][:natural_gas_cost] = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='LEEDsummary' AND ReportForString='Entire Facility' AND TableName='EAp2-7. Energy Cost Summary' AND ColumnName='Total Energy Cost' AND RowName='#{rowname}'").get
          qaqc[:economics][:natural_gas_cost_per_m2]=qaqc[:economics][:natural_gas_cost]/qaqc[:building][:conditioned_floor_area_m2] unless model.building.get.conditionedFloorArea().empty?
      
        when "Additional"
          qaqc[:economics][:additional_cost] = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='LEEDsummary' AND ReportForString='Entire Facility' AND TableName='EAp2-7. Energy Cost Summary' AND ColumnName='Total Energy Cost' AND RowName='#{rowname}'").get
          qaqc[:economics][:additional_cost_per_m2]=qaqc[:economics][:additional_cost]/qaqc[:building][:conditioned_floor_area_m2] unless model.building.get.conditionedFloorArea().empty?
      
        when "Total"
          qaqc[:economics][:total_cost] = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='LEEDsummary' AND ReportForString='Entire Facility' AND TableName='EAp2-7. Energy Cost Summary' AND ColumnName='Total Energy Cost' AND RowName='#{rowname}'").get
          qaqc[:economics][:total_cost_per_m2]=qaqc[:economics][:total_cost]/qaqc[:building][:conditioned_floor_area_m2] unless model.building.get.conditionedFloorArea().empty?
        end
      end
    else
      error_warning <<  "costing is unavailable because the sql statement is nil RowName FROM TabularDataWithStrings WHERE ReportName='LEEDsummary' AND ReportForString='Entire Facility' AND TableName='EAp2-7. Energy Cost Summary' AND ColumnName='Total Energy Cost'"
    end
    
    #Store end_use data
    end_uses = [
      'Heating',
      'Cooling',
      'Interior Lighting',
      'Exterior Lighting',
      'Interior Equipment',
      'Exterior Equipment',
      'Fans',
      'Pumps',
      'Heat Rejection',
      'Humidification',
      'Heat Recovery',
      'Water Systems',
      'Refrigeration',
      'Generators',                                                                                
      'Total End Uses'
    ]
    
    fuels = [ 
      ['Electricity', 'GJ'],       
      ['Natural Gas', 'GJ'] , 
      ['Additional Fuel', 'GJ'],
      ['District Cooling','GJ'],             
      ['District Heating', 'GJ'], 
    ]
    
    qaqc[:end_uses] = {}
    qaqc[:end_uses_eui] = {}
    end_uses.each do |use_type|
      qaqc[:end_uses]["#{use_type.gsub(/\s+/, "_").downcase.to_sym}_gj"] = 0
      qaqc[:end_uses_eui]["#{use_type.gsub(/\s+/, "_").downcase.to_sym}_gj_per_m2"] = 0
      fuels.each do |fuel_type|
        value = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='#{use_type}' AND ColumnName='#{fuel_type[0]}' AND Units='#{fuel_type[1]}'")
        if value.empty? or value.get == 0
        else
          qaqc[:end_uses]["#{use_type.gsub(/\s+/, "_").downcase.to_sym}_gj"] += value.get
          unless qaqc[:building][:conditioned_floor_area_m2].nil?
            qaqc[:end_uses_eui]["#{use_type.gsub(/\s+/, "_").downcase.to_sym}_gj_per_m2"] += value.get / qaqc[:building][:conditioned_floor_area_m2]
          end
        end
      end
      value = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM tabulardatawithstrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='#{use_type}' AND ColumnName='Water' AND Units='m3'")
	    if value.empty? or value.get == 0
      else
        qaqc[:end_uses]["#{use_type.gsub(/\s+/, "_").downcase.to_sym}_water_m3"] = value.get
        unless qaqc[:building][:conditioned_floor_area_m2].nil?
          qaqc[:end_uses_eui]["#{use_type.gsub(/\s+/, "_").downcase.to_sym}_water_m3_per_m2"] = value.get / qaqc[:building][:conditioned_floor_area_m2]
        end
      end
    end
    
    # Store Peak Data
    qaqc[:meter_peaks] = {}
    qaqc[:meter_peaks][:electric_w] = electric_peak.empty? ? "NA" : electric_peak.get  
    qaqc[:meter_peaks][:natural_gas_w] = natural_gas_peak.empty? ? "NA" : natural_gas_peak.get 
    
    
    #Store unmet hour data
    qaqc[:unmet_hours] = {}
    qaqc[:unmet_hours][:cooling] = model.getFacility.hoursCoolingSetpointNotMet().get unless model.getFacility.hoursCoolingSetpointNotMet().empty?
    qaqc[:unmet_hours][:heating] = model.getFacility.hoursHeatingSetpointNotMet().get unless model.getFacility.hoursHeatingSetpointNotMet().empty?
    
    
    
    
    
    
    #puts "\n\n\n#{costing_rownames}\n\n\n"
    #Padmassun's Code -- Tarrif end


    #Padmassun's Code -- Service Hotwater Heating *start*
    qaqc[:service_water_heating] = {}
    qaqc[:service_water_heating][:total_nominal_occupancy]=-1
    #qaqc[:service_water_heating][:total_nominal_occupancy]=model.sqlFile().get().execAndReturnVectorOfDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='OutdoorAirSummary' AND ReportForString='Entire Facility' AND TableName='Average Outdoor Air During Occupied Hours' AND ColumnName='Nominal Number of Occupants'").get.inject(0, :+)
    qaqc[:service_water_heating][:total_nominal_occupancy]=get_total_nominal_capacity(model)
    
    qaqc[:service_water_heating][:electricity_per_year]=model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND ColumnName='Electricity' AND RowName='Water Systems'")
    qaqc[:service_water_heating][:electricity_per_year]= validate_optional(qaqc[:service_water_heating][:electricity_per_year], model, -1)

    qaqc[:service_water_heating][:electricity_per_day]=qaqc[:service_water_heating][:electricity_per_year]/365.5
    qaqc[:service_water_heating][:electricity_per_day_per_occupant]=qaqc[:service_water_heating][:electricity_per_day]/qaqc[:service_water_heating][:total_nominal_occupancy]
	
    
    qaqc[:service_water_heating][:natural_gas_per_year]=model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND ColumnName='Natural Gas' AND RowName='Water Systems'")
    qaqc[:service_water_heating][:natural_gas_per_year]=validate_optional(qaqc[:service_water_heating][:natural_gas_per_year], model, -1)

    qaqc[:service_water_heating][:additional_fuel_per_year]=model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND ColumnName='Additional Fuel' AND RowName='Water Systems'")
    qaqc[:service_water_heating][:additional_fuel_per_year] = validate_optional(qaqc[:service_water_heating][:additional_fuel_per_year], model, -1)
    
    qaqc[:service_water_heating][:water_m3_per_year]=model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='AnnualBuildingUtilityPerformanceSummary' AND ReportForString='Entire Facility' AND TableName='End Uses' AND ColumnName='Water' AND RowName='Water Systems'")
    qaqc[:service_water_heating][:water_m3_per_year]=validate_optional(qaqc[:service_water_heating][:water_m3_per_year], model, -1)
    
    qaqc[:service_water_heating][:water_m3_per_day]=qaqc[:service_water_heating][:water_m3_per_year]/365.5
    qaqc[:service_water_heating][:water_m3_per_day_per_occupant]=qaqc[:service_water_heating][:water_m3_per_day]/qaqc[:service_water_heating][:total_nominal_occupancy]
    #puts qaqc[:service_water_heating][:total_nominal_occupancy]
    #Padmassun's Code -- Service Hotwater Heating *end*

    #Store Envelope data.
    qaqc[:envelope] = {}
	
    qaqc[:envelope][:outdoor_walls_average_conductance_w_per_m2_k] 	= BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(outdoor_walls).round(4) if outdoor_walls.size > 0
    qaqc[:envelope][:outdoor_roofs_average_conductance_w_per_m2_k]  = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(outdoor_roofs).round(4) if outdoor_roofs.size > 0
    qaqc[:envelope][:outdoor_floors_average_conductance_w_per_m2_k] = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(outdoor_floors).round(4) if outdoor_floors.size > 0
    qaqc[:envelope][:ground_walls_average_conductance_w_per_m2_k]  	= BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(ground_walls).round(4) if ground_walls.size > 0
    qaqc[:envelope][:ground_roofs_average_conductance_w_per_m2_k]  	= BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(ground_roofs).round(4) if ground_roofs.size > 0
    qaqc[:envelope][:ground_floors_average_conductance_w_per_m2_k]  = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(ground_floors).round(4) if ground_floors.size > 0
    qaqc[:envelope][:windows_average_conductance_w_per_m2_k]  		= BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(windows).round(4) if windows.size > 0
    qaqc[:envelope][:skylights_average_conductance_w_per_m2_k]  	= BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(skylights).round(4) if skylights.size > 0
    qaqc[:envelope][:doors_average_conductance_w_per_m2_k]  		= BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(doors).round(4) if doors.size > 0
    qaqc[:envelope][:overhead_doors_average_conductance_w_per_m2_k] = BTAP::Geometry::Surfaces::get_weighted_average_surface_conductance(overhead_doors).round(4) if overhead_doors.size > 0
    qaqc[:envelope][:fdwr]  										= (BTAP::Geometry::get_fwdr(model) * 100.0).round(1)
    qaqc[:envelope][:srr]  											= (BTAP::Geometry::get_srr(model) * 100.0).round(1)
	
	
    qaqc[:envelope][:constructions] = {}
    qaqc[:envelope][:constructions][:exterior_fenestration] = []
    constructions = []
    outdoor_subsurfaces.each { |surface| constructions << surface.construction.get }
    ext_const_base = Hash.new(0)
    constructions.each { |name| ext_const_base[name] += 1 }
    #iterate thought each construction and get store data
    ext_const_base.sort.each do |construction, count|
      construction_info = {}
      qaqc[:envelope][:constructions][:exterior_fenestration] << construction_info
      construction_info[:name] = construction.name.get
      construction_info[:net_area_m2] = construction.getNetArea.round(2)
      construction_info[:thermal_conductance_m2_w_per_k] = BTAP::Resources::Envelope::Constructions::get_conductance(construction).round(3)
      construction_info[:solar_transmittance] = BTAP::Resources::Envelope::Constructions::get_shgc(model, construction).round(3)
      construction_info[:visible_tranmittance] = BTAP::Resources::Envelope::Constructions::get_tvis(model,construction).round(3)
    end	
    
    #Exterior
    qaqc[:envelope][:constructions][:exterior_opaque] = []
    constructions = []
    outdoor_surfaces.each { |surface| constructions << surface.construction.get }
    ext_const_base = Hash.new(0)
    constructions.each { |name| ext_const_base[name] += 1 }
    #iterate thought each construction and get store data
    ext_const_base.sort.each do |construction, count|
      construction_info = {}
      qaqc[:envelope][:constructions][:exterior_opaque] << construction_info
      construction_info[:name] = construction.name.get
      construction_info[:net_area_m2] = construction.getNetArea.round(2)
      construction_info[:thermal_conductance_m2_w_per_k] = construction.thermalConductance.get.round(3) if construction.thermalConductance.is_initialized
      construction_info[:net_area_m2] = construction.to_Construction.get.getNetArea.round(2)
      construction_info[:solar_absorptance] = construction.to_Construction.get.layers[0].exteriorVisibleAbsorptance.get
    end
	
    #Ground
    qaqc[:envelope][:constructions][:ground] = []
    constructions = []
    ground_surfaces.each { |surface| constructions << surface.construction.get }
    ext_const_base = Hash.new(0)
    constructions.each { |name| ext_const_base[name] += 1 }
    #iterate thought each construction and get store data
    ext_const_base.sort.each do |construction, count|
      construction_info = {}
      qaqc[:envelope][:constructions][:ground] << construction_info
      construction_info[:name] = construction.name.get
      construction_info[:net_area_m2] = construction.getNetArea.round(2)
      construction_info[:thermal_conductance_m2_w_per_k] = construction.thermalConductance.get.round(3) if construction.thermalConductance.is_initialized
      construction_info[:net_area_m2] = construction.to_Construction.get.getNetArea.round(2)
      construction_info[:solar_absorptance] = construction.to_Construction.get.layers[0].exteriorVisibleAbsorptance.get
    end
	

    # Store Space data.
    qaqc[:spaces] =[]
    model.getSpaces.sort.each do |space|
      spaceinfo = {}
      qaqc[:spaces] << spaceinfo
      spaceinfo[:name] = space.name.get #name should be defined test
      spaceinfo[:multiplier] = space.multiplier 
      spaceinfo[:volume] = space.volume # should be greater than zero
      spaceinfo[:exterior_wall_area] = space.exteriorWallArea # just for information. 
      spaceinfo[:space_type_name] = space.spaceType.get.name.get unless space.spaceType.empty? #should have a space types name defined. 
      spaceinfo[:thermal_zone] = space.thermalZone.get.name.get unless space.thermalZone.empty? # should be assigned a thermalzone name.
      #puts space.name.get
      #puts space.thermalZone.empty?
      spaceinfo[:breathing_zone_outdoor_airflow_vbz] =-1
      breathing_zone_outdoor_airflow_vbz= model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='Standard62.1Summary' AND ReportForString='Entire Facility' AND TableName='Zone Ventilation Parameters' AND ColumnName='Breathing Zone Outdoor Airflow - Vbz' AND Units='m3/s' AND RowName='#{spaceinfo[:thermal_zone].to_s.upcase}' ")
      spaceinfo[:breathing_zone_outdoor_airflow_vbz] =breathing_zone_outdoor_airflow_vbz.get unless breathing_zone_outdoor_airflow_vbz.empty?
      spaceinfo[:infiltration_method] = 'N/A' 
      spaceinfo[:infiltration_flow_per_m2]  =-1.0
      unless space.spaceInfiltrationDesignFlowRates[0].nil?
        spaceinfo[:infiltration_method] = space.spaceInfiltrationDesignFlowRates[0].designFlowRateCalculationMethod
        spaceinfo[:infiltration_flow_per_m2] = "N/A"
        spaceinfo[:infiltration_flow_per_m2] = space.spaceInfiltrationDesignFlowRates[0].flowperExteriorSurfaceArea.get.round(5) unless space.spaceInfiltrationDesignFlowRates[0].flowperExteriorSurfaceArea.empty?
      else
        error_warning <<  "space.spaceInfiltrationDesignFlowRates[0] is empty for #{spaceinfo[:name]}"
        error_warning <<  "space.spaceInfiltrationDesignFlowRates[0].designFlowRateCalculationMethod is empty for #{spaceinfo[:name]}"
        error_warning <<  "space.spaceInfiltrationDesignFlowRates[0].flowperExteriorSurfaceArea is empty for #{spaceinfo[:name]}"
      end  

      #the following should have values unless the spacetype is "undefined" other they should be set to the correct NECB values. 
      unless space.spaceType.empty?
        spaceinfo[:occupancy_schedule] = nil
        unless (space.spaceType.get.defaultScheduleSet.empty?)
          unless space.spaceType.get.defaultScheduleSet.get.numberofPeopleSchedule.empty?
            spaceinfo[:occupancy_schedule] = space.spaceType.get.defaultScheduleSet.get.numberofPeopleSchedule.get.name.get  #should not empty.
          else
            error_warning <<  "space.spaceType.get.defaultScheduleSet.get.numberofPeopleSchedule is empty for #{space.name.get }"
          end
        else
          error_warning <<  "space.spaceType.get.defaultScheduleSet is empty for #{space.name.get }"
        end
      
        spaceinfo[:occ_per_m2] = space.spaceType.get.people[0].peopleDefinition.peopleperSpaceFloorArea.get.round(3) unless space.spaceType.get.people[0].nil? 
        unless space.spaceType.get.lights[0].nil?
          spaceinfo[:lighting_w_per_m2] = space.spaceType.get.lights[0].lightsDefinition.wattsperSpaceFloorArea#.get.round(3) unless space.spaceType.get.lights[0].nil?
          spaceinfo[:lighting_w_per_m2] = validate_optional(spaceinfo[:lighting_w_per_m2], model, -1.0)
          unless spaceinfo[:lighting_w_per_m2].nil?
            spaceinfo[:lighting_w_per_m2] = spaceinfo[:lighting_w_per_m2].round(3)
          end
        end
        #spaceinfo[:electric_w_per_m2] = space.spaceType.get.electricEquipment[0].electricEquipmentDefinition.wattsperSpaceFloorArea.get.round(3) unless space.spaceType.get.electricEquipment[0].nil?
      
        unless space.spaceType.get.electricEquipment[0].nil?
          unless space.spaceType.get.electricEquipment[0].electricEquipmentDefinition.wattsperSpaceFloorArea.empty?
            spaceinfo[:electric_w_per_m2] = space.spaceType.get.electricEquipment[0].electricEquipmentDefinition.wattsperSpaceFloorArea.get.round(3)
          end
        end
        spaceinfo[:shw_m3_per_s] = space.waterUseEquipment[0].waterUseEquipmentDefinition.peakFlowRate.round(3) unless space.waterUseEquipment[0].nil?
        spaceinfo[:waterUseEquipment] = []
        if !space.waterUseEquipment.empty?
          waterUseEquipment_info={}
          spaceinfo[:waterUseEquipment] << waterUseEquipment_info
          waterUseEquipment_info[:peak_flow_rate]= space.waterUseEquipment[0].waterUseEquipmentDefinition.peakFlowRate
          waterUseEquipment_info[:peak_flow_rate_per_area] = waterUseEquipment_info[:peak_flow_rate] / space.floorArea
          area_per_occ = space.spaceType.get.people[0].spaceFloorAreaPerPerson.get
          #                             Watt per person =             m3/s/m3                * 1000W/kW * (specific heat * dT) * m2/person
          waterUseEquipment_info[:shw_watts_per_person] = waterUseEquipment_info[:peak_flow_rate_per_area] * 1000 * (4.19 * 44.4) * 1000 * area_per_occ
          #puts waterUseEquipment_info[:shw_watts_per_person]
          #puts "\n\n\n"
        end
      else
        error_warning <<  "space.spaceType is empty for #{space.name.get }"
      end
    end
    
    # Store Thermal zone data
    qaqc[:thermal_zones] = [] 
    model.getThermalZones.sort.each do  |zone|
      zoneinfo = {}
      qaqc[:thermal_zones] << zoneinfo
      zoneinfo[:name] = zone.name.get
      zoneinfo[:floor_area] = zone.floorArea
      zoneinfo[:multiplier] = zone.multiplier
      zoneinfo[:is_conditioned] = "N/A"
      unless zone.isConditioned.empty?
        zoneinfo[:is_conditioned] = zone.isConditioned.get
      else
        error_warning <<  "zone.isConditioned is empty for #{zone.name.get}"
      end
      
      zoneinfo[:is_ideal_air_loads] = zone.useIdealAirLoads
      zoneinfo[:heating_sizing_factor] = -1.0
      unless zone.sizingZone.zoneHeatingSizingFactor.empty?
        zoneinfo[:heating_sizing_factor] = zone.sizingZone.zoneHeatingSizingFactor.get
      else
        error_warning <<  "zone.sizingZone.zoneHeatingSizingFactor is empty for #{zone.name.get}"
      end  
      
      zoneinfo[:cooling_sizing_factor] = -1.0 #zone.sizingZone.zoneCoolingSizingFactor.get
      unless zone.sizingZone.zoneCoolingSizingFactor.empty?
        zoneinfo[:cooling_sizing_factor] = zone.sizingZone.zoneCoolingSizingFactor.get
      else
        error_warning <<  "zone.sizingZone.zoneCoolingSizingFactor is empty for #{zone.name.get}"
      end  
      
      zoneinfo[:zone_heating_design_supply_air_temperature] = zone.sizingZone.zoneHeatingDesignSupplyAirTemperature
      zoneinfo[:zone_cooling_design_supply_air_temperature] = zone.sizingZone.zoneCoolingDesignSupplyAirTemperature
      zoneinfo[:spaces] = []
      zone.spaces.sort.each do |space|
        spaceinfo ={}
        zoneinfo[:spaces] << spaceinfo
        spaceinfo[:name] = space.name.get  
        spaceinfo[:type] = space.spaceType.get.name.get unless space.spaceType.empty?
      end
      zoneinfo[:equipment] = []
      zone.equipmentInHeatingOrder.each do |equipment|
        item = {}
        zoneinfo[:equipment] << item
        item[:name] = equipment.name.get
        if equipment.to_ZoneHVACComponent.is_initialized
          item[:type] = 'ZoneHVACComponent'
        elsif  equipment.to_StraightComponent.is_initialized
          item[:type] = 'StraightComponent'
        end
      end
    end #zone
    # Store Air Loop Information
    qaqc[:air_loops] = []
    model.getAirLoopHVACs.sort.each do |air_loop|
      air_loop_info = {}
      air_loop_info[:name] = air_loop.name.get
      air_loop_info[:thermal_zones] = []
      air_loop_info[:total_floor_area_served] = 0.0
      air_loop_info[:total_breathing_zone_outdoor_airflow_vbz] = 0.0
      air_loop.thermalZones.sort.each do |zone|
        air_loop_info[:thermal_zones] << zone.name.get
        vbz = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='Standard62.1Summary' AND ReportForString='Entire Facility' AND TableName='Zone Ventilation Parameters' AND ColumnName='Breathing Zone Outdoor Airflow - Vbz' AND Units='m3/s' AND RowName='#{zone.name.get.to_s.upcase}' ")
        vbz = validate_optional(vbz, model, 0)
        air_loop_info[:total_breathing_zone_outdoor_airflow_vbz] += vbz
        air_loop_info[:total_floor_area_served] += zone.floorArea
      end
      air_loop_info[:area_outdoor_air_rate_m3_per_s_m2] = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='Standard62.1Summary' AND ReportForString='Entire Facility' AND TableName='System Ventilation Parameters' AND ColumnName='Area Outdoor Air Rate - Ra' AND Units='m3/s-m2' AND RowName='#{air_loop_info[:name].to_s.upcase}' ")
      air_loop_info[:area_outdoor_air_rate_m3_per_s_m2] = validate_optional(air_loop_info[:area_outdoor_air_rate_m3_per_s_m2], model, -1.0)
      
      air_loop_info[:outdoor_air_L_per_s] = -1.0
      unless air_loop_info[:area_outdoor_air_rate_m3_per_s_m2] ==-1.0
        air_loop_info[:outdoor_air_L_per_s] = air_loop_info[:area_outdoor_air_rate_m3_per_s_m2]*air_loop_info[:total_floor_area_served]*1000
      end
      #Fan

      unless air_loop.supplyFan.empty?
        air_loop_info[:supply_fan] = {}
        if air_loop.supplyFan.get.to_FanConstantVolume.is_initialized 
          air_loop_info[:supply_fan][:type] = 'CV'
          fan = air_loop.supplyFan.get.to_FanConstantVolume.get
        elsif air_loop.supplyFan.get.to_FanVariableVolume.is_initialized 
          air_loop_info[:supply_fan][:type]  = 'VV'
          fan = air_loop.supplyFan.get.to_FanVariableVolume.get
        end
        air_loop_info[:supply_fan][:name] = fan.name.get
        #puts "\n\n\n\n#{fan.name.get}\n\n\n\n"
        air_loop_info[:supply_fan][:fan_efficiency] = fan.fanEfficiency
        air_loop_info[:supply_fan][:motor_efficiency] = fan.motorEfficiency
        air_loop_info[:supply_fan][:pressure_rise] = fan.pressureRise
        air_loop_info[:supply_fan][:max_air_flow_rate_m3_per_s]  = -1.0
       
        max_air_flow_info = model.sqlFile().get().execAndReturnVectorOfString("SELECT RowName FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Fans' AND ColumnName='Max Air Flow Rate' AND Units='m3/s' ")
        max_air_flow_info = validate_optional(max_air_flow_info, model, "N/A")
        unless max_air_flow_info == "N/A"
          if max_air_flow_info.include? "#{air_loop_info[:supply_fan][:name].to_s.upcase}"
            air_loop_info[:supply_fan][:max_air_flow_rate_m3_per_s] = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Fans' AND ColumnName='Max Air Flow Rate' AND Units='m3/s' AND RowName='#{air_loop_info[:supply_fan][:name].upcase}' ").get
            air_loop_info[:supply_fan][:rated_electric_power_w] = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Fans' AND ColumnName='Rated Electric Power' AND Units='W' AND RowName='#{air_loop_info[:supply_fan][:name].upcase}' ").get
          else
            error_warning <<  "#{air_loop_info[:supply_fan][:name]} does not exist in sql file WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Fans' AND ColumnName='Max Air Flow Rate' AND Units='m3/s'"
          end
        else
          error_warning <<  "max_air_flow_info is nil because the following sql statement returned nil: RowName FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Fans' AND ColumnName='Max Air Flow Rate' AND Units='m3/s' "
        end
      end

      #economizer                                                                                             
      air_loop_info[:economizer] = {}
      air_loop_info[:economizer][:name] = air_loop.airLoopHVACOutdoorAirSystem.get.getControllerOutdoorAir.name.get
      air_loop_info[:economizer][:control_type] = air_loop.airLoopHVACOutdoorAirSystem.get.getControllerOutdoorAir.getEconomizerControlType

      #DX cooling coils
      air_loop_info[:cooling_coils] ={}
      air_loop_info[:cooling_coils][:dx_single_speed]=[]
      air_loop_info[:cooling_coils][:dx_two_speed]=[]

      #Heating Coil
      air_loop_info[:heating_coils] = {}
      air_loop_info[:heating_coils][:coil_heating_gas] = []
      air_loop_info[:heating_coils][:coil_heating_electric]= []
      air_loop_info[:heating_coils][:coil_heating_water]= []

      #Heat Excahnger
      air_loop_info[:heat_exchanger] = {}
      
      air_loop.supplyComponents.each do |supply_comp|
        if supply_comp.to_CoilHeatingGas.is_initialized
          coil={}
          air_loop_info[:heating_coils][:coil_heating_gas] << coil
          gas = supply_comp.to_CoilHeatingGas.get
          coil[:name]=gas.name.get
          coil[:type]="Gas"
          coil[:efficency] = gas.gasBurnerEfficiency
          #coil[:nominal_capacity]= gas.nominalCapacity()
          coil[:nominal_capacity]= model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Heating Coils' AND ColumnName='Nominal Total Capacity' AND RowName='#{coil[:name].to_s.upcase}'")
          coil[:nominal_capacity]=validate_optional(coil[:nominal_capacity],model,-1.0 )
        end
        if supply_comp.to_CoilHeatingElectric.is_initialized
          coil={}
          air_loop_info[:heating_coils][:coil_heating_electric] << coil
          electric = supply_comp.to_CoilHeatingElectric.get
          coil[:name]= electric.name.get
          coil[:type]= "Electric"
          coil[:nominal_capacity]= model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Heating Coils' AND ColumnName='Nominal Total Capacity' AND RowName='#{coil[:name].to_s.upcase}'")
          coil[:nominal_capacity]=validate_optional(coil[:nominal_capacity],model,-1.0 )
        end
        if supply_comp.to_CoilHeatingWater.is_initialized
          coil={}
          air_loop_info[:heating_coils][:coil_heating_water] << coil
          water = supply_comp.to_CoilHeatingWater.get
          coil[:name]= water.name.get
          coil[:type]= "Water"
          coil[:nominal_capacity]= model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Heating Coils' AND ColumnName='Nominal Total Capacity' AND RowName='#{coil[:name].to_s.upcase}'")
          coil[:nominal_capacity]=validate_optional(coil[:nominal_capacity],model,-1.0 )
        end
        if supply_comp.to_HeatExchangerAirToAirSensibleAndLatent.is_initialized
          heatExchanger = supply_comp.to_HeatExchangerAirToAirSensibleAndLatent.get
          air_loop_info[:heat_exchanger][:name] = heatExchanger.name.get
        end
      end
      
      #I dont think i need to get the type of heating coil from the sql file, because the coils are differentiated by class, and I have hard coded the information
      #model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName= 'Heating Coils' AND ColumnName='Type' ").get #padmussen to complete #AND RowName='#{air_loop_info[:heating_coils][:name].upcase}'
      
      
      #Collect all the fans into the the array.
      air_loop.supplyComponents.each do |supply_comp|
        if supply_comp.to_CoilCoolingDXSingleSpeed.is_initialized
          coil = {}
          air_loop_info[:cooling_coils][:dx_single_speed] << coil
          single_speed = supply_comp.to_CoilCoolingDXSingleSpeed.get
          coil[:name] = single_speed.name.get
          coil[:cop] = single_speed.ratedCOP.get
          coil[:nominal_total_capacity_w] = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Cooling Coils' AND ColumnName='Nominal Total Capacity' AND RowName='#{coil[:name].upcase}' ")
          coil[:nominal_total_capacity_w] = validate_optional(coil[:nominal_total_capacity_w], model, -1.0)
        end
        if supply_comp.to_CoilCoolingDXTwoSpeed.is_initialized
          coil = {}
          air_loop_info[:cooling_coils][:dx_two_speed] << coil
          two_speed = supply_comp.to_CoilCoolingDXTwoSpeed.get
          coil[:name] = two_speed.name.get
          coil[:cop_low] = two_speed.ratedLowSpeedCOP.get
          coil[:cop_high] =  two_speed.ratedHighSpeedCOP.get
          coil[:nominal_total_capacity_w] = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Cooling Coils' AND ColumnName='Nominal Total Capacity' AND RowName='#{coil[:name].upcase}' ")
          coil[:nominal_total_capacity_w] = validate_optional(coil[:nominal_total_capacity_w] , model,-1.0)
        end
      end
      qaqc[:air_loops] << air_loop_info
    end


    qaqc[:plant_loops] = []
    model.getPlantLoops.sort.each do |plant_loop|
      plant_loop_info = {}
      qaqc[:plant_loops] << plant_loop_info
      plant_loop_info[:name] = plant_loop.name.get
      
      sizing = plant_loop.sizingPlant
      plant_loop_info[:design_loop_exit_temperature] = sizing.designLoopExitTemperature
      plant_loop_info[:loop_design_temperature_difference] = sizing.loopDesignTemperatureDifference
      
      #Create Container for plant equipment arrays.
      plant_loop_info[:pumps] = []
      plant_loop_info[:boilers] = []
      plant_loop_info[:chiller_electric_eir] = []
      plant_loop_info[:cooling_tower_single_speed] = []
      plant_loop_info[:water_heater_mixed] =[]
      plant_loop.supplyComponents.each do |supply_comp|
      
        #Collect Constant Speed
        if supply_comp.to_PumpConstantSpeed.is_initialized
          pump = supply_comp.to_PumpConstantSpeed.get
          pump_info = {}
          plant_loop_info[:pumps] << pump_info
          pump_info[:name] = pump.name.get
          pump_info[:type] = "Pump:ConstantSpeed"
          pump_info[:head_pa] = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Pumps' AND ColumnName='Head' AND RowName='#{pump_info[:name].upcase}' ")
          pump_info[:head_pa] = validate_optional(pump_info[:head_pa], model, -1.0)
          pump_info[:water_flow_m3_per_s] = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Pumps' AND ColumnName='Water Flow' AND RowName='#{pump_info[:name].upcase}' ")
          pump_info[:water_flow_m3_per_s] = validate_optional(pump_info[:water_flow_m3_per_s], model, -1.0)
          pump_info[:electric_power_w] = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Pumps' AND ColumnName='Electric Power' AND RowName='#{pump_info[:name].upcase}' ")
          pump_info[:electric_power_w] = validate_optional(pump_info[:electric_power_w], model, -1.0)
          pump_info[:motor_efficency] = pump.motorEfficiency
        end
        
        #Collect Variable Speed
        if supply_comp.to_PumpVariableSpeed.is_initialized
          pump = supply_comp.to_PumpVariableSpeed.get
          pump_info = {}
          plant_loop_info[:pumps] << pump_info
          pump_info[:name] = pump.name.get
          pump_info[:type] = "Pump:VariableSpeed" 
          pump_info[:head_pa] = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Pumps' AND ColumnName='Head' AND RowName='#{pump_info[:name].upcase}' ")
          pump_info[:head_pa] = validate_optional(pump_info[:head_pa], model, -1.0)
          pump_info[:water_flow_m3_per_s] = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Pumps' AND ColumnName='Water Flow' AND RowName='#{pump_info[:name].upcase}' ")
          pump_info[:water_flow_m3_per_s] = validate_optional(pump_info[:water_flow_m3_per_s], model, -1.0)
          pump_info[:electric_power_w] = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='EquipmentSummary' AND ReportForString='Entire Facility' AND TableName='Pumps' AND ColumnName='Electric Power' AND RowName='#{pump_info[:name].upcase}' ")
          pump_info[:electric_power_w] = validate_optional(pump_info[:electric_power_w], model, -1.0)
          pump_info[:motor_efficency] = pump.motorEfficiency
        end
        
        # Collect HotWaterBoilers
        if supply_comp.to_BoilerHotWater.is_initialized
          boiler = supply_comp.to_BoilerHotWater.get
          boiler_info = {}
          plant_loop_info[:boilers] << boiler_info
          boiler_info[:name] = boiler.name.get
          boiler_info[:type] = "Boiler:HotWater" 
          boiler_info[:fueltype] = boiler.fuelType
          boiler_info[:nominal_capacity] = boiler.nominalCapacity
          boiler_info[:nominal_capacity] = validate_optional(boiler_info[:nominal_capacity], model, -1.0)
        end
        
        # Collect ChillerElectricEIR
        if supply_comp.to_ChillerElectricEIR.is_initialized
          chiller = supply_comp.to_ChillerElectricEIR.get
          chiller_info = {}
          plant_loop_info[:chiller_electric_eir] << chiller_info
          chiller_info[:name] = chiller.name.get
          chiller_info[:type] = "Chiller:Electric:EIR" 
          chiller_info[:reference_capacity] = validate_optional(chiller.referenceCapacity, model, -1.0)
          chiller_info[:reference_leaving_chilled_water_temperature] =chiller.referenceLeavingChilledWaterTemperature
        end
        
        # Collect CoolingTowerSingleSpeed
        if supply_comp.to_CoolingTowerSingleSpeed.is_initialized
          coolingTower = supply_comp.to_CoolingTowerSingleSpeed.get
          coolingTower_info = {}
          plant_loop_info[:cooling_tower_single_speed] << coolingTower_info
          coolingTower_info[:name] = coolingTower.name.get
          coolingTower_info[:type] = "CoolingTower:SingleSpeed" 
          coolingTower_info[:fan_power_at_design_air_flow_rate] = validate_optional(coolingTower.fanPoweratDesignAirFlowRate, model, -1.0)

        end

        # Collect WaterHeaterMixed
        if supply_comp.to_WaterHeaterMixed.is_initialized
          waterHeaterMixed = supply_comp.to_WaterHeaterMixed.get
          waterHeaterMixed_info = {}
          plant_loop_info[:water_heater_mixed] << waterHeaterMixed_info
          waterHeaterMixed_info[:name] = waterHeaterMixed.name.get
          waterHeaterMixed_info[:type] = "WaterHeater:Mixed"
          waterHeaterMixed_info[:heater_thermal_efficiency] = waterHeaterMixed.heaterThermalEfficiency.get unless waterHeaterMixed.heaterThermalEfficiency.empty?
          waterHeaterMixed_info[:heater_fuel_type] = waterHeaterMixed.heaterFuelType
        end
      end
      
      qaqc[:eplusout_err] ={}  
      warnings = model.sqlFile().get().execAndReturnVectorOfString("SELECT ErrorMessage FROM Errors WHERE ErrorType='0' ")
      warnings = validate_optional(warnings, model, "N/A")
      unless warnings == "N/A"
        qaqc[:eplusout_err][:warnings] = model.sqlFile().get().execAndReturnVectorOfString("SELECT ErrorMessage FROM Errors WHERE ErrorType='0' ").get
        qaqc[:eplusout_err][:fatal] =model.sqlFile().get().execAndReturnVectorOfString("SELECT ErrorMessage FROM Errors WHERE ErrorType='2' ").get
        qaqc[:eplusout_err][:severe] =model.sqlFile().get().execAndReturnVectorOfString("SELECT ErrorMessage FROM Errors WHERE ErrorType='1' ").get
      end
      
      qaqc[:ruby_warnings] = error_warning
    end
       
    
    # Perform qaqc
    necb_2011_qaqc(qaqc, model) if qaqc[:building][:name].include?("NECB2011") #had to nodify this because this is specifically for "NECB-2011" standard
    sanity_check(qaqc)
    
    qaqc[:information] = qaqc[:information].sort
    qaqc[:warnings] = qaqc[:warnings].sort
    qaqc[:errors] = qaqc[:errors].sort
    qaqc[:unique_errors]= qaqc[:unique_errors].sort
    
    return qaqc
  end
end

def validate_optional (var, model, return_value = "N/A")
  if var.empty?
    return return_value
  else
    return var.get
  end
end

def look_up_csv_data(csv_fname, search_criteria)
  options = { :headers    => :first_row,
    :converters => [ :numeric ] }
  unless File.exist?(csv_fname)
    raise ("File: [#{csv_fname}] Does not exist")
  end
  # we'll save the matches here
  matches = nil
  # save a copy of the headers
  headers = nil
  CSV.open( csv_fname, "r", options ) do |csv|

    # Since CSV includes Enumerable we can use 'find_all'
    # which will return all the elements of the Enumerble for 
    # which the block returns true

    matches = csv.find_all do |row|
      match = true
      search_criteria.keys.each do |key|
        match = match && ( row[key].strip == search_criteria[key].strip )
      end
      match
    end
    headers = csv.headers
  end
  #puts matches
  raise("More than one match") if matches.size > 1
  puts "Zero matches found for [#{search_criteria}]" if matches.size == 0
  #return matches[0]
  return matches[0]
end


def necb_section_test(qaqc,result_value,bool_operator,expected_value,necb_section_name,test_text,tolerance = nil)
  test = "eval_failed"
  command = ''
  if tolerance.is_a?(Integer)
    command = "#{result_value}.round(#{tolerance}) #{bool_operator} #{expected_value}.round(#{tolerance})"
  elsif expected_value.is_a?(String) and result_value.is_a?(String)
    command = "'#{result_value}' #{bool_operator} '#{expected_value}'"
  else
    command = "#{result_value} #{bool_operator} #{expected_value}"
  end
  test = eval(command)
  test == 'true' ? true :false
  raise ("Eval command failed #{test}") if !!test != test 
  if test
    qaqc[:information] << "[Info][TEST-PASS][#{necb_section_name}]:#{test_text} result value:#{result_value} #{bool_operator} expected value:#{expected_value}"
  else
    qaqc[:errors] << "[ERROR][TEST-FAIL][#{necb_section_name}]:#{test_text} expected value:#{expected_value} #{bool_operator} result value:#{result_value}"
    unless (expected_value == -1.0 or expected_value == 'N/A')
      qaqc[:unique_errors] << "[ERROR][TEST-FAIL][#{necb_section_name}]:#{test_text} expected value:#{expected_value} #{bool_operator} result value:#{result_value}"
    end
  end
end

def check_boolean_value (value,varname)
  return true if value =~ (/^(true|t|yes|y|1)$/i)
  return false if value.empty? || value =~ (/^(false|f|no|n|0)$/i)

  raise ArgumentError.new "invalid value for #{varname}: #{value}"
end
  
  
def get_total_nominal_capacity (model)
  total_nominal_capacity = 0
  model.getSpaces.sort.each do |space|
    zone_name = space.thermalZone.get.name.get.upcase
    area = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='InputVerificationandResultsSummary' AND ReportForString='Entire Facility' AND TableName='Zone Summary' AND ColumnName='Area' AND RowName='#{zone_name}'")
    area = validate_optional(area, model, -1)
    multiplier = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='InputVerificationandResultsSummary' AND ReportForString='Entire Facility' AND TableName='Zone Summary' AND ColumnName='Multipliers' AND RowName='#{zone_name}'")
    multiplier = validate_optional(multiplier, model, -1)
    area_per_person = model.sqlFile().get().execAndReturnFirstDouble("SELECT Value FROM TabularDataWithStrings WHERE ReportName='InputVerificationandResultsSummary' AND ReportForString='Entire Facility' AND TableName='Zone Summary' AND ColumnName='People' AND RowName='#{zone_name}'")
    area_per_person = validate_optional(area_per_person, model, -1)
    next if area_per_person == 0
    puts "area: #{area}  multiplier: #{multiplier}   area_per_person: #{area_per_person}"
    total_nominal_capacity += area*multiplier/area_per_person
  end
  return total_nominal_capacity
end

def sanity_check(qaqc)
  qaqc[:sanity_check] = {}
  qaqc[:sanity_check][:fail] = []
  qaqc[:sanity_check][:pass] = []
  #Padmassun's code for isConditioned start
  qaqc[:thermal_zones].each do |zoneinfo|
    zoneinfo[:spaces].each do |space|
      #skip plenums and undefined spaces/zones
      if zoneinfo[:name].to_s.include?"- undefined -"
        next
      end
      if zoneinfo[:space_type_name].to_s.include?"Space Function - undefined -"
        if zoneinfo[:is_conditioned].to_s == "No"
          qaqc[:sanity_check][:pass] << "[TEST-PASS][SANITY_CHECK-PASS] for [SPACE][#{space[:name]}] and [THERMAL ZONE] [#{zoneinfo[:name]}] where isConditioned is supposed to be [""No""] and found as #{zoneinfo[:is_conditioned]}"
        else
          qaqc[:sanity_check][:fail] << "[ERROR][SANITY_CHECK-FAIL] for [SPACE][#{space[:name]}] and [THERMAL ZONE] [#{zoneinfo[:name]}] where isConditioned is supposed to be [""No""] but found as #{zoneinfo[:is_conditioned]}"
        end
      else
        if zoneinfo[:is_conditioned].to_s == "Yes"
          qaqc[:sanity_check][:pass] << "[TEST-PASS][SANITY_CHECK-PASS] for [SPACE][#{space[:name]}] and [THERMAL ZONE] [#{zoneinfo[:name]}] where isConditioned is supposed to be [""Yes""] and found as #{zoneinfo[:is_conditioned]}"
        elsif zoneinfo[:name]
          qaqc[:sanity_check][:fail] << "[ERROR][SANITY_CHECK-FAIL] for [SPACE][#{space[:name]}] and [THERMAL ZONE] [#{zoneinfo[:name]}] where isConditioned is supposed to be [""Yes""] but found as #{zoneinfo[:is_conditioned]}"
        end          
      end
    end
  end	
  qaqc[:sanity_check][:fail] = qaqc[:sanity_check][:fail].sort
  qaqc[:sanity_check][:pass] = qaqc[:sanity_check][:pass].sort
  #Padmassun's code for isConditioned end
end
  
  
def necb_2011_qaqc(qaqc, model)
  #Now perform basic QA/QC on items for NECB2011 
  qaqc[:information] = []
  qaqc[:warnings] =[]
  qaqc[:errors] = []
  qaqc[:unique_errors]=[]
    

  #    #Padmassun's Code Start
  csv_file_name ="#{File.dirname(__FILE__)}/necb_2011_spacetype_info.csv"
  puts csv_file_name
  qaqc[:spaces].each do |space|
    building_type =""
    space_type =""
    if space[:space_type_name].include? 'Space Function '
      space_type = (space[:space_type_name].to_s.rpartition('Space Function '))[2].strip
      building_type = 'Space Function'
    elsif space[:space_type_name].include? ' WholeBuilding'
      space_type = (space[:space_type_name].to_s.rpartition(' WholeBuilding'))[0].strip
      building_type = 'WholeBuilding'
    end
    row = look_up_csv_data(csv_file_name,{2 => space_type, 1 => building_type})
    if row.nil?
      #raise ("space type of [#{space_type}] and/or building type of [#{building_type}] was not found in the excel sheet for space: [#{space[:name]}]")
      qaqc[:ruby_warnings] << "space type of [#{space_type}] and/or building type of [#{building_type}] was not found in the excel sheet for space: [#{space[:name]}]"
      puts "space type of [#{space_type}] and/or building type of [#{building_type}] was not found in the excel sheet for space: [#{space[:name]}]"
    else
      #correct the data from the csv file to include a multiplier of 0.9 for specific space types.
      
      reduceLPDSpaces = ["Classroom/lecture/training", "Conf./meet./multi-purpose", "Lounge/recreation",
        "Washroom-sch-A", "Washroom-sch-B", "Washroom-sch-C", "Washroom-sch-D", "Washroom-sch-E", 
        "Washroom-sch-F", "Washroom-sch-G", "Washroom-sch-H", "Washroom-sch-I", "Dress./fitt. - performance arts", 
        "Locker room", "Retail - dressing/fitting","Locker room-sch-A","Locker room-sch-B","Locker room-sch-C",
        "Locker room-sch-D","Locker room-sch-E","Locker room-sch-F","Locker room-sch-G","Locker room-sch-H",
        "Locker room-sch-I", "Office - open plan - occsens", "Office - enclosed - occsens", "Storage area - occsens",
        "Hospital - medical supply - occsens", "Storage area - refrigerated - occsens"]
      
      if reduceLPDSpaces.include?(space_type)
        row[3] = row[3]*0.9
        puts "\n============================\nspace_type: #{space_type}\n============================\n"
      end
      
      # Start of Space Compliance
      necb_section_name = "NECB2011-Section 8.4.3.6"
      data = {}
      data[:lighting_per_area] 		        = [ row[3],'==',space[:lighting_w_per_m2] , "Table 4.2.1.6"     ,1 ] unless space[:lighting_w_per_m2].nil?
      data[:occupancy_per_area]           = [ row[4],'==',space[:occ_per_m2]        , "Table A-8.4.3.3.1" ,3 ] unless space[:occ_per_m2].nil?
      data[:occupancy_schedule]           = [ row[5],'==',space[:occupancy_schedule], "Table A-8.4.3.3.1" ,nil ] unless space[:occupancy_schedule].nil?
      data[:electric_equipment_per_area]  = [ row[6],'==',space[:electric_w_per_m2] , "Table A-8.4.3.3.1" ,1 ] unless space[:electric_w_per_m2].nil?
      data.each do |key,value|
        #puts key
        necb_section_test(
          qaqc,
          value[0],
          value[1],
          value[2],
          value[3],
          "[SPACE][#{space[:name]}]-[TYPE:][#{space_type}]#{key}",
          value[4]
        )
      end
    end#space Compliance
  end
  #Padmassun's Code End
    

  # Envelope
  necb_section_name = "NECB2011-Section 3.2.1.4"
  #store hdd in short form
  hdd = qaqc[:geography][:hdd]
  #calculate fdwr based on hdd. 
  fdwr = 0
  if hdd < 4000
    fdwr = 0.40
  elsif hdd >= 4000 and hdd <=7000
    fdwr = (2000-0.2 * hdd)/3000
  elsif hdd >7000
    fdwr = 0.20
  end
  #hardset srr to 0.05 
  srr = 0.05
  #create table of expected values and results.
  data = {}
  data[:fenestration_to_door_and_window_percentage]  = [ fdwr * 100,qaqc[:envelope][:fdwr].round(3)]
  data[:skylight_to_roof_percentage]  = [  srr * 100,qaqc[:envelope][:srr].round(3)]
  #perform test. result must be less than or equal to.
  data.each {|key,value| necb_section_test( 
      qaqc, 
      value[0],
      '>=',
      value[1],
      necb_section_name,
      "[ENVELOPE]#{key}",
      1 #padmassun added tollerance
    )
  }

  #Infiltration
  necb_section_name = "NECB2011-Section 8.4.3.6"
  qaqc[:spaces].each do |spaceinfo|
    data = {}
    data[:infiltration_method] 		= [ "Flow/ExteriorArea", spaceinfo[:infiltration_method] , nil ] 
    data[:infiltration_flow_per_m2] = [ 0.00025,			 spaceinfo[:infiltration_flow_per_m2], 5 ]
    data.each do |key,value|
      #puts key
      necb_section_test( 
        qaqc,
        value[0],
        '==',
        value[1],
        necb_section_name,
        "[SPACE][#{spaceinfo[:name]}]-#{key}",
        value[2]
      )
    end
  end
  #Exterior Opaque
  necb_section_name = "NECB2011-Section 3.2.2.2"
  climate_index = NECB2011.new().get_climate_zone_index(qaqc[:geography][:hdd])
  result_value_index = 6
  round_precision = 3
  data = {}
  data[:ext_wall_conductances]        =  [0.315,0.278,0.247,0.210,0.210,0.183,qaqc[:envelope][:outdoor_walls_average_conductance_w_per_m2_k]] unless qaqc[:envelope][:outdoor_walls_average_conductance_w_per_m2_k].nil?
  data[:ext_roof_conductances]        =  [0.227,0.183,0.183,0.162,0.162,0.142,qaqc[:envelope][:outdoor_roofs_average_conductance_w_per_m2_k]] unless qaqc[:envelope][:outdoor_roofs_average_conductance_w_per_m2_k].nil?
  data[:ext_floor_conductances]       =  [0.227,0.183,0.183,0.162,0.162,0.142,qaqc[:envelope][:outdoor_floors_average_conductance_w_per_m2_k]] unless qaqc[:envelope][:outdoor_floors_average_conductance_w_per_m2_k].nil?
    
  data.each {|key,value| necb_section_test( 
      qaqc,
      value[result_value_index],
      '==',
      value[climate_index],
      necb_section_name,
      "[ENVELOPE]#{key}",
      round_precision
    )
  }
  #Exterior Fenestration
  necb_section_name = "NECB2011-Section 3.2.2.3"
  climate_index = NECB2011.new().get_climate_zone_index(qaqc[:geography][:hdd])
  result_value_index = 6
  round_precision = 3
  data = {}
  data[:ext_window_conductances]      =     [2.400,2.200,2.200,2.200,2.200,1.600,qaqc[:envelope][:windows_average_conductance_w_per_m2_k]] unless qaqc[:envelope][:windows_average_conductance_w_per_m2_k].nil?
  data[:ext_door_conductances]        =     [2.400,2.200,2.200,2.200,2.200,1.600,qaqc[:envelope][:doors_average_conductance_w_per_m2_k]]   unless qaqc[:envelope][:doors_average_conductance_w_per_m2_k].nil?
  data[:ext_overhead_door_conductances] =   [2.400,2.200,2.200,2.200,2.200,1.600,qaqc[:envelope][:overhead_doors_average_conductance_w_per_m2_k]] unless qaqc[:envelope][:overhead_doors_average_conductance_w_per_m2_k].nil?
  data[:ext_skylight_conductances]  =       [2.400,2.200,2.200,2.200,2.200,1.600,qaqc[:envelope][:skylights_average_conductance_w_per_m2_k]] unless qaqc[:envelope][:skylights_average_conductance_w_per_m2_k].nil?
  data.each do |key,value|
	
    #puts key
    necb_section_test( 
      qaqc,
      value[result_value_index].round(round_precision),
      '==',
      value[climate_index].round(round_precision),
      necb_section_name,
      "[ENVELOPE]#{key}",
      round_precision
    )
  end    
  #Exterior Ground surfaces
  necb_section_name = "NECB2011-Section 3.2.3.1"
  climate_index = NECB2011.new().get_climate_zone_index(qaqc[:geography][:hdd])
  result_value_index = 6
  round_precision = 3
  data = {}
  data[:ground_wall_conductances]  = [ 0.568,0.379,0.284,0.284,0.284,0.210, qaqc[:envelope][:ground_walls_average_conductance_w_per_m2_k] ]  unless qaqc[:envelope][:ground_walls_average_conductance_w_per_m2_k].nil?
  data[:ground_roof_conductances]  = [ 0.568,0.379,0.284,0.284,0.284,0.210, qaqc[:envelope][:ground_roofs_average_conductance_w_per_m2_k] ]  unless qaqc[:envelope][:ground_roofs_average_conductance_w_per_m2_k].nil?
  data[:ground_floor_conductances] = [ 0.757,0.757,0.757,0.757,0.757,0.379, qaqc[:envelope][:ground_floors_average_conductance_w_per_m2_k] ] unless qaqc[:envelope][:ground_floors_average_conductance_w_per_m2_k].nil?
  data.each {|key,value| necb_section_test( 
      qaqc,
      value[result_value_index],
      '==',
      value[climate_index],
      necb_section_name,
      "[ENVELOPE]#{key}",
      round_precision
    )
  }
  #Zone Sizing and design supply temp tests
  necb_section_name = "NECB2011-?"
  qaqc[:thermal_zones].each do |zoneinfo|
    #    skipping undefined schedules
    if zoneinfo[:name].to_s.include?"- undefined -"
      next
    end
    data = {}
    data[:heating_sizing_factor] = [1.3 , zoneinfo[:heating_sizing_factor]]
    data[:cooling_sizing_factor] = [1.1 ,zoneinfo[:cooling_sizing_factor]]
    data[:heating_design_supply_air_temp] =   [43.0, zoneinfo[:zone_heating_design_supply_air_temperature] ] #unless zoneinfo[:zone_heating_design_supply_air_temperature].nil?
    data[:cooling_design_supply_temp] 	=   [13.0, zoneinfo[:zone_cooling_design_supply_air_temperature] ]
    data.each do |key,value| 
      #puts key
      necb_section_test( 
        qaqc,
        value[0],
        '==',
        value[1],
        necb_section_name,
        "[ZONE][#{zoneinfo[:name]}] #{key}",
        round_precision
      )
    end
  end	
  #Air flow sizing check
  #determine correct economizer usage according to section 5.2.2.7 of NECB2011
  necb_section_name = "NECB2011-5.2.2.7"
  qaqc[:air_loops].each do |air_loop_info|
    #    air_loop_info[:name] 
    #    air_loop_info[:thermal_zones] 
    #    air_loop_info[:total_floor_area_served]
    #    air_loop_info[:cooling_coils][:dx_single_speed]
    #    air_loop_info[:cooling_coils][:dx_two_speed]
    #    air_loop_info[:supply_fan][:max_air_flow_rate]
    #    
    #    air_loop_info[:heating_coils][:coil_heating_gas][:nominal_capacity]
    #    air_loop_info[:heating_coils][:coil_heating_electric][:nominal_capacity]
    #    air_loop_info[:heating_coils][:coil_heating_water][:nominal_capacity]
    #    
    #    air_loop_info[:economizer][:control_type]
    
    capacity = -1.0
    
    if !air_loop_info[:cooling_coils][:dx_single_speed][0].nil?
      puts "air_loop_info[:heating_coils][:coil_heating_gas][0][:nominal_capacity]"
      capacity = air_loop_info[:cooling_coils][:dx_single_speed][0][:nominal_total_capacity_w]
    elsif !air_loop_info[:cooling_coils][:dx_two_speed][0].nil?
      puts "capacity = air_loop_info[:heating_coils][:coil_heating_electric]"
      capacity = air_loop_info[:cooling_coils][:dx_two_speed][0][:cop_high]
    end
    puts capacity
    if capacity == -1.0
      #This should not happen
      puts "air_loop_info[:heating_coils] does not have a capacity or the type is not gas/electric/water for #{air_loop_info[:name]}"
    else
      #check for correct economizer usage
      puts "air_loop_info[:supply_fan][:max_air_flow_rate]: #{air_loop_info[:supply_fan][:max_air_flow_rate]}"
      unless air_loop_info[:supply_fan][:max_air_flow_rate_m3_per_s] == -1.0
        #capacity should be in kW
        if capacity > 20000 or air_loop_info[:supply_fan][:max_air_flow_rate_m3_per_s]*1000 >1500
          #diff enth
          #puts "diff"
          necb_section_test( 
            qaqc,
            "DifferentialEnthalpy",
            '==',
            air_loop_info[:economizer][:control_type],
            necb_section_name,
            "[AIR LOOP][#{air_loop_info[:name]}][:economizer][:control_type]"
          )
        else
          #no economizer
          #puts "no econ"
          necb_section_test( 
            qaqc,
            'NoEconomizer',
            '==',
            air_loop_info[:economizer][:control_type],
            necb_section_name,
            "[AIR LOOP][#{air_loop_info[:name]}][:economizer][:control_type]"
          )
        end
      end
    end
  end
  
  #*TODO*
  necb_section_name = "NECB2011-5.2.10.1"
  qaqc[:air_loops].each do |air_loop_info|
    unless air_loop_info[:supply_fan][:max_air_flow_rate_m3_per_s] == -1.0
      hrv_calc = 0.00123*air_loop_info[:outdoor_air_L_per_s]*(21-BTAP::Environment::WeatherFile.new( model.getWeatherFile.path.get.to_s ).db990) #=AP46*(21-O$1)
      hrv_reqd = hrv_calc > 150 ? true : false
      #qaqc[:information] << "[Info][TEST-PASS][#{necb_section_name}]:#{test_text} result value:#{result_value} #{bool_operator} expected value:#{expected_value}"
      hrv_present = false
      unless air_loop_info[:heat_exchanger].empty?
        hrv_present = true
      end
      necb_section_test( 
        qaqc,
        hrv_reqd,
        '==',
        hrv_present,
        necb_section_name,
        "[AIR LOOP][:heat_exchanger] for [#{air_loop_info[:name]}] is present?"
      )
      
    end
  end
  
  necb_section_name = "NECB2011-5.2.3.3"
  qaqc[:air_loops].each do |air_loop_info|
    #necb_clg_cop = air_loop_info[:cooling_coils][:dx_single_speed][:cop] #*assuming that the cop is defined correctly*
    if air_loop_info[:supply_fan][:max_air_flow_rate_m3_per_s].nil?
      qaqc[:ruby_warnings] << "air_loop_info[:supply_fan][:max_air_flow_rate_m3_per_s] is nil"
      next
    end
    necb_supply_fan_w = (air_loop_info[:supply_fan][:max_air_flow_rate_m3_per_s]*1000*1.6).round(2)

    if air_loop_info[:name].include? "PSZ"
      necb_supply_fan_w = (air_loop_info[:supply_fan][:max_air_flow_rate_m3_per_s]*1000*1.6).round(2)
    elsif air_loop_info[:name].include? "VAV"
      necb_supply_fan_w = (air_loop_info[:supply_fan][:max_air_flow_rate_m3_per_s]*1000*2.65).round(2)
    end

    if air_loop_info[:supply_fan][:rated_electric_power_w].nil?
      qaqc[:ruby_warnings] << "air_loop_info[:supply_fan][:rated_electric_power_w] is nil"
      next
    end

    supply_fan_w = (air_loop_info[:supply_fan][:rated_electric_power_w]).round(3)
    absolute_diff = (necb_supply_fan_w - supply_fan_w).to_f.abs
    if absolute_diff < 10
      #This case should ALWAYS PASS
      necb_section_test(
        qaqc,
        10,
        '>=',
        absolute_diff,
        necb_section_name,
        "[AIR LOOP][#{air_loop_info[:name]}][:supply_fan][:rated_electric_power_w] [#{supply_fan_w}] Absolute Difference from NECB value [#{necb_supply_fan_w}]"
      )
      next
    else
      #The test should pass if and only if the percent difference is less than 10%
      percent_diff = ((necb_supply_fan_w - supply_fan_w).to_f.abs/necb_supply_fan_w * 100).round(3)
      necb_section_test( 
        qaqc,
        10,
        '>=',
        percent_diff,
        necb_section_name,
        "[AIR LOOP][#{air_loop_info[:name]}][:supply_fan][:rated_electric_power_w] [#{supply_fan_w}] Percent Diff from NECB value [#{necb_supply_fan_w}]"
      )
    end
  end
  
  necb_section_name = "SANITY-??"
  qaqc[:plant_loops].each do |plant_loop_info|  
    pump_head = plant_loop_info[:pumps][0][:head_pa]
    flow_rate = plant_loop_info[:pumps][0][:water_flow_m3_per_s]*1000
    hp_check = ((flow_rate*60*60)/1000*1000*9.81*pump_head*0.000101997)/3600000
    puts "\npump_head #{pump_head}"
    puts "name: #{qaqc[:building][:name]}"
    puts "name: #{plant_loop_info[:name]}"
    puts "flow_rate #{flow_rate}"
    puts "hp_check #{hp_check}\n"
    pump_power_hp = plant_loop_info[:pumps][0][:electric_power_w]/1000*0.746
    percent_diff = (hp_check - pump_power_hp).to_f.abs/hp_check * 100
    
    if percent_diff.nan?
      qaqc[:ruby_warnings] << "(hp_check - pump_power_hp).to_f.abs/hp_check * 100 for #{plant_loop_info[:name]} is NaN"
      next
    end
    
    necb_section_test( 
      qaqc,
      20, #diff of 20%
      '>=',
      percent_diff,
      necb_section_name,
      "[PLANT LOOP][#{plant_loop_info[:name]}][:pumps][0][:electric_power_hp] [#{pump_power_hp}] Percent Diff from NECB value [#{hp_check}]"
    )
    
  end
end
