
# This module defines checks that test various aspects
# of the baseline model against 90.1-2013 Appendix G.
module Baseline9012013

  # G3.1.2.7 Economizers. Outdoor air economizers shall not be included in baseline HVAC Systems 1, 2, 9, and 10.
  # Outdoor air economizers shall be included in baseline HVAC Systems 3 through 8, and 11, 12, and 13 based on climate as
  # specified in Table G3.1.2.7.
  # Exceptions: Economizers shall not be included for systems meeting one or more of the exceptions listed below.
  # 1. Systems that include gas-phase air cleaning to meet the requirements of Section 6.1.2 in Standard 62.1. 
  # This exception shall be used only if the system in the proposed design does not match thebuilding design.
  # 2. Where the use of outdoor air for cooling will affect supermarket open refrigerated casework systems. 
  # This exception shall only be used if the system in the proposed design does not use an economizer.
  # If the exception is used, an economizer shall not be included in the baseline building design.
  # 3. Systems that serve computer rooms complying with Section G3.1.2.7.1.
  # @author Eric Ringold, Ambient Energy
  def check_economizers(model)

    econ_bad = []
    econ_limit_bad = []
    economizer_required = false
    high_limit = nil
    model.getAirLoopHVACs.each do |sys|
      
      # get systems 3 and 5 in the baseline model
      if sys.name.get.include?('PSZ-AC') || sys.name.get.include?('(Sys5)')
        economizer_required = true
        # models are all zone 5b
        high_limit = 75 #F
        oa_sys = sys.airLoopHVACOutdoorAirSystem
        if !oa_sys.empty?
          oa_sys = oa_sys.get
        end
        oa_control = oa_sys.getControllerOutdoorAir
        # check economizer control setting
        unless oa_control.getEconomizerControlType == "FixedDryBulb"
          econ_bad << "#{sys.name.get} econ type was #{oa_control.getEconomizerControlType}"
        end
        
        # get economiser db high limit and check if correct
        drybulb_limit_c = oa_control.getEconomizerMaximumLimitDryBulbTemperature
        if drybulb_limit_c.is_initialized
          drybulb_limit_c = drybulb_limit_c.get
        end
        drybulb_limit_f = OpenStudio.convert(drybulb_limit_c,"C","F").get
        
        if (drybulb_limit_f - high_limit).abs > 0.1
          econ_limit_bad << "#{sys.name.get} high limit was #{drybulb_limit_f}F."
        end
      end    
    end
    assert_equal(econ_bad.size, 0, "Systems #{econ_bad.sort.join("\n")} required to have dry-bulb economizer, but do not.")
    assert_equal(econ_limit_bad.size, 0, "Systems #{econ_limit_bad.sort.join("\n")} required to have economizer high-limit of #{high_limit}, but do not.")    
    
    return true
    
  end

  # G3.1.2.9.1 Baseline All System Types Except System Types 9 and 10. 
  # System design supply airflow rates for the baseline building design shall be based on a supply-air-to room-air 
  # temperature difference of 20°F or the minimum outdoor airflow rate, or the airflow rate required to comply with
  # applicable codes or accreditation standards, whichever is greater. If return or relief fans are specified in the 
  # proposed design, the baseline building design shall also be modeled with fans serving the same functions and sized 
  # for the baseline system supply fan air quantity less the minimum outdoorair, or 90% of the supply fan air quantity, whichever is larger.
  # @author Eric Ringold, Ambient Energy
  def check_sat_delta(model)

    delta_good = []
    cool_delta_bad = []
    heat_delta_bad = []
    
    model.getThermalZones.each do |zone|
      # get zone thermostats
      tstat = zone.thermostatSetpointDualSetpoint
      if !tstat.empty?
        tstat = tstat.get
      
        heating_sch = tstat.heatingSetpointTemperatureSchedule.get.to_ScheduleRuleset.get
        cooling_sch = tstat.coolingSetpointTemperatureSchedule.get.to_ScheduleRuleset.get
        
        # get heating and cooling setpoints 
        heating_min_max = heating_sch.annual_min_max_value
        cooling_min_max = cooling_sch.annual_min_max_value
        
        heat_set_t = OpenStudio.convert(heating_min_max['max'],"C","F").get
        cool_set_t = OpenStudio.convert(cooling_min_max['min'],"C","F").get
        
        # get sizing:zone supply air temperatures
        cool_sizing = zone.sizingZone.zoneCoolingDesignSupplyAirTemperature
        heat_sizing = zone.sizingZone.zoneHeatingDesignSupplyAirTemperature
        
        cool_sizing_f = OpenStudio.convert(cool_sizing,"C","F").get
        heat_sizing_f = OpenStudio.convert(heat_sizing,"C","F").get
        
        # calculate temperature deltas and put zone names in arrays
        cool_delta = (cool_set_t - cool_sizing_f).round
        if (cool_delta - 20).abs > 0.1
          cool_delta_bad << "#{zone.name} Clg delta =#{cool_delta}"
        end  
        
        heat_delta = (heat_sizing_f - heat_set_t).round
        if (heat_delta - 20).abs > 0.1
          heat_delta_bad << "#{zone.name} Htg delta =#{heat_delta}"
        end
      end # if !tstat  
    end #model.get
    assert_equal(cool_delta_bad.size, 0, "Cooling supply air to room air temperature difference is not 20F for zones #{cool_delta_bad.sort.join("\n")}.")
    assert_equal(heat_delta_bad.size, 0, "Heating supply air to room air temperature difference is not 20F for zones #{heat_delta_bad.sort.join("\n")}.")

    return true
    
  end

  # G3.1.3.12 Supply Air Temperature Reset (Systems 5 through 8). 
  # The air temperature for cooling shall be reset higher by 5°F under the minimum cooling load conditions.
  # @author Eric Ringold, Ambient Energy
  def check_sat_reset(model)

    no_reset = []
    reset_bad = []
    model.getAirLoopHVACs.each do |sys|
      if sys.name.get.include?('(Sys5)') # checking system 5
        supp_node = sys.supplyOutletNode
        supp_node.setpointManagers.each do |spm|
          if spm.to_SetpointManagerOutdoorAirReset.is_initialized
            spm = spm.to_SetpointManagerOutdoorAirReset.get
            low_temp = OpenStudio.convert(spm.setpointatOutdoorHighTemperature,"C","F").get
            high_temp = OpenStudio.convert(spm.setpointatOutdoorLowTemperature,"C","F").get
            
            # check if reset is correct
            delta = high_temp - low_temp
            if (delta - 5.0).abs > 0.1
              reset_bad << "#{sys.name} reset = #{delta} delta-F"
            end
          else # no setpointmanager:outdoorairreset
            no_reset << sys.name.get
          end
        end #supp_node.each
        
        
      end #if sys.name.get
    end #model.get
    
    assert_equal(no_reset.size,0,"Supply Air Temperature not reset for systems #{no_reset.sort.join("\n")}.")
    assert_equal(reset_bad.size,0,"Supply Air Temperature is reset, but not by the required 5 degrees F for systems: #{reset_bad.sort.join("\n")}.")
     
    return true
    
  end

  # G3.1.3.13 VAV Minimum Flow Setpoints (Systems 5 and 7). Minimum volume setpoints for VAV reheat boxes shall be 30%
  # of zone peak airflow, the minimum outdoor airflow rate or the airflow rate required to comply with applicable codes 
  # or accreditation standards, whichever is larger.
  # @author Eric Ringold, Ambient Energy
  def check_min_vav_setpoints(model)
  
    min_good = []
    min_bad = []
    
    model.getAirLoopHVACs.each do |sys|
      # get only systems 5 and 7
      if sys.name.get.include?('(Sys5)') || sys.name.get.include?('(Sys7)')
      
        sys.thermalZones.each do |zone|
          terminal = nil
          zone.equipment.each do |equip|
            next if equip.to_AirTerminalSingleDuctVAVReheat.empty?
            terminal = equip.to_AirTerminalSingleDuctVAVReheat.get
          end
          # get terminal design flow rate
          des_flow = terminal.autosizedMaximumAirFlowRate
          if des_flow.is_initialized
            des_flow = des_flow.get
          else puts "CANT GET TERMINAL DESIGN FLOW"
          end
          
          #assuming minimum is always specified as a constant fraction
          min_flow_frac = terminal.constantMinimumAirFlowFraction
          
          #get outdoor air rate from DSOA
          oa_rate = zone.outdoor_airflow_rate

          # Calculate the actual fraction
          act_oa_frac = oa_rate / des_flow
          
          #check if terminal minimum meets requirements
          
          if (act_oa_frac - min_flow_frac).abs < 0.01  
            puts "Min Flow from OA Rate"
          elsif min_flow_frac == 0.3
            puts "Min Flow is 30% Peak Flow"
          else min_bad << "#{zone.name}, actual min OA frac = #{act_oa_frac.round(2)}, min damper pos = #{min_flow_frac.round(2)}"
          end          
        end
      end
    end #model.getAirLoopHVACs
    
    assert_equal(min_bad.size,0,"The following zones' terminal units do not meet the minimum flow criteria of 30% or minimum outdoor airflow rate: #{min_bad.sort.join("\n")}. They may still may meet the requirement if applicable codes or standards require additional airflow.")    
  
    return true
    
  end  

  # G3.1.2.1 Equipment Efficiencies. 
  # All HVAC equipment in the baseline building design shall be modeled at the minimum efficiency levels, both part load and full load, 
  # in accordance with Section 6.4. Chillers shall use Path A efficiencies as shown in Table 6.8.1-3 where efficiency ratings include supply fan energy, 
  # the efficiency rating shall be adjusted toremove the supply fan energy. For Baseline HVAC Systems 1,2, 3, 4, 5, and 6, calculate the minimum COP_nfcooling 
  # and COP_nfheating using the equation for the applicable performance rating as indicated in Tables 6.8.1-1 through 6.8.1-4.
  # Where a full- and part-load efficiency rating is provided in Tables 6.8.1-1 through 6.8.1-4, the full-load equation below shall be used:
  # COP_nfcooling = 7.84E-8 × EER × Q + 0.338 × EER
  # COP_nfcooling = –0.0076 × SEER^2 + 0.3796 × SEER
  # COP_nfheating = 1.48E-7 × COP_47 × Q + 1.062 × COP_47 (applies to heat-pump heating efficiency only)
  # COP_nfheating = –0.0296 × HSPF2 + 0.7134 × HSPF 
  # where COP_nfcooling and COP_nfheating are the packaged HVAC equipment cooling and heating energy efficiency, respectively, to be used in the baseline building, 
  # which excludes supply fan power, and Q is the AHRI-rated cooling capacity in Btu/h. EER, SEER, COP, and HSPF shall be at AHRI test conditions. 
  # Fan energy shall be modeled separately according to Section G3.1.2.10.
  # @author Eric Ringold, Ambient Energy
  def check_coil_efficiencies(model)

    # Cooling efficiency tables:
    # Systems 1 & 2: Table 6.8.1D (6.8.1-4 in 2013)
    # Systems 3, 5, & 6: Table 6.8.1A (6.8.1-1 in 2013)
    # System 4: Table 6.8.1B (6.8.1-2 in 2013)
    # Systems 7-10: N/A
    
    # Heating efficiency tables:
    # System 2: Table 6.8.1D
    # Systems 3 & 9: Table 6.8.1E
    # System 4: Table 6.8.1B
    # Systems 1, 5-8, 10: N/A
    
    #conversions
    si_cap = "W"
    ip_cap = "Btu/h"
    
    #arrays to put same or different values in
    eff_same = []
    eff_diff = []
    
    #currently only gets coils associated with air loops
    #TODO: cover zone system coils
    model.getAirLoopHVACs.sort.each do |lp|
      coil = lp.supplyComponents.each do |comp|
        size = nil
        if !comp.to_CoilCoolingDXTwoSpeed.empty?
          #we have a System 5 or 6
          #system 6 not being created yet
          #TODO: add logic to check for heating coil type, changes standard efficiencies
          coil = comp.to_CoilCoolingDXTwoSpeed.get
          name = coil.name.get
          
          # get assigned coil COP
          coil_cop = coil.ratedHighSpeedCOP.get

          # get coil capacity for EER calculation
          if coil.autosizedRatedHighSpeedTotalCoolingCapacity.is_initialized
            size = coil.autosizedRatedHighSpeedTotalCoolingCapacity.get
          else
            eff_diff << "#{coil.name} capacity couldn't be found"
            next
          end
          size = OpenStudio.convert(size,si_cap,ip_cap).get

        elsif !comp.to_CoilCoolingDXSingleSpeed.empty?
          #System 3 or system 4
          #TODO: refine system type by heating coil - system 4 efficiencies come from different table
          coil = comp.to_CoilCoolingDXSingleSpeed.get
          name = coil.name.get
          
          # get assigned coil COP
          coil_cop = coil.ratedCOP.get
          
          # get coil capacity for EER calculation            
          if coil.autosizedRatedTotalCoolingCapacity.is_initialized
            size = coil.autosizedRatedTotalCoolingCapacity.get
          else
            eff_diff << "#{coil.name} capacity couldn't be found"
            next
          end
          size = OpenStudio.convert(size,si_cap,ip_cap).get
        end
          
        unless size.nil?
          
          seer = nil
          eer = nil
          cop = nil
          # tests against 90.1-2013 efficiencies
          if size < 65000
            seer = 14.0
            cop = -0.0076 * seer * seer + 0.3796 * seer
          elsif size >= 65000 && size < 135000
            eer = 11.0
            cop = 7.84e-8 * eer * size + 0.338 * eer
          elsif size >= 135000 && size < 240000
            eer = 10.8
            cop = 7.84e-8 * eer * size + 0.338 * eer
          elsif size >= 240000 && size < 760000
            eer = 9.8
            cop = 7.84e-8 * eer * size + 0.338 * eer
          else # size >= 760000
            eer = 9.5
            cop = 7.84e-8 * eer * size + 0.338 * eer
          end
        
          if (coil_cop - cop).abs >= 0.1
            eff_diff << "#{name}, capacity = #{size.round} Btu/hr, expected COP = #{cop.round(2)}, was #{coil_cop.round(2)}"
          else
            eff_same << name
          end

        end #unless size.nil
      end
    end
    assert_equal(eff_diff.size, 0, "Coils #{eff_diff.sort.join("\n")} found with efficiencies that differ from standard-calculated values")
  
    return true
  
  end

  # G3.1.2.6 Ventilation. 
  # Minimum ventilation system outdoor air intake flow shall be the same for the proposed and baseline building designs.
  # Exceptions:
  # 1. When modeling demand-control ventilation in the proposed design when its use is not required by Section 6.3.2(q) or Section 6.4.3.10.
  # 2. When designing systems in accordance with Standard 62.1, Section 6.2, “Ventilation Rate Procedure,” reduced ventilation airflow rates may be 
  # calculated for each HVAC zone in the proposed design with a zone air distribution effectiveness (Ez) > 1.0 as defined by Table 6-2in Standard 62.1. 
  # Baseline ventilation airflow rates in those zones shall be calculated using the proposed design Ventilation Rate Procedure calculation with the 
  # following change only. Zone air distribution effectiveness shall be changed to (Ez)= 1.0 in each zone having a zone air distributioneffectiveness (Ez) > 1.0. 
  # Proposed design and baseline design Ventilation Rate Procedure calculations, as described in Standard 62.1, shall be submitted to the rating authority 
  # to claim credit for this exception.
  # 3. If the minimum outdoor air intake flow in the proposed design is provided in excess of the amount required by the rating authority or building official 
  # then the baseline building design shall be modeled to reflect the greater of that required by the rating authority or building official and will be less 
  # than the proposed design.
  # 4. For baseline systems serving only laboratory spaces that are prohibited from recirculating return air by code or accreditation standards, the baseline system 
  # shall be modeled as 100% outdoor air.  
  # @author Eric Ringold, Ambient Energy
  def check_ventilation_rates(model, proposed_model)
    
    # get proposed ventilation from designSpecificationOutdoorAir
    zone_oa = {}
    proposed_model.getThermalZones.sort.each do |zone|
      oa_rate = zone.outdoor_airflow_rate
      zone_oa["#{zone.name.get}"] = oa_rate
    end

    zones_same = []
    zones_dif = []
    
    zone_oa.each do |k,v|
      # get baseline ventilation rates
      bzone = model.getThermalZoneByName(k.to_s)
      if bzone.is_initialized
        bzone = bzone.get
        #puts bzone.name
        oa_rate = bzone.outdoor_airflow_rate
        # compare baseline and proposed rates
        if (oa_rate - zone_oa[k]).abs <= 0.0001 
          #puts "#{bzone.name} MEETS Requirement with Prop OA: #{zone_oa[k]}, Base OA: #{oa_rate}"
          zones_same << bzone.name.get
        else
          puts "#{bzone.name} FAILS Requirement with Prop OA: #{zone_oa[k]}, Base OA: #{oa_rate}"
          zones_dif << bzone.name.get
        end
      else puts "can't find #{k}"
      end
    end
    
    assert_equal(zones_dif.size, 0, "Zones #{zones_dif.sort} found with differing OA rates")
    
  end
  
  # @author Matt Steen, Ambient Energy
  def check_baseline_system_type(base_model, prop_model, building_type, climate_zone)

    prm_maj_sec = 'G3.1.1 Baseline HVAC System Type' 
    
    # get model objects
    climate_zone = climate_zone.gsub('ASHRAE 169-2006-', '')
    model_area_si = prop_model.getBuilding.floorArea
    model_area_ip = OpenStudio.convert(model_area_si, 'm^2', 'ft^2').get
    building_storys = prop_model.getBuildingStorys.size
    base_zones = base_model.getThermalZones
        
    climate_zones_1to3a = ['1A', '1B', '2A', '2B', '3A']
    climate_zones_3bto8 = ['3B', '3C', '4A', '4B', '4C', '5A', '5B', '5C', '6A', '6B', '7A', '7B', '8A', '8B']
    
    # puts "AREA = #{model_area_ip}"
    # puts "STORYS = #{building_storys}"
    # puts "CZ = #{climate_zone}"   
    # #array.any? { |item| string.include?(item) }    
    
    # determine expected baseline system type
    if climate_zones_3bto8.include?(climate_zone)
    
      if building_type == 'MidriseApartment'
        system_type = 'PTAC' #building_type_prm = 'Residential'
      # 5. Public assembly building types include
      # houses of worship, auditoriums, movie theaters, performance theaters, 
      # concert halls, arenas, enclosed stadiums, ice rinks, gymnasiums, 
      # convention centers, exhibition centers, and natatoriums. 
      # elsif (building_type == 'PublicAssembly' && model_area_ip < 120000)
      #   system_type = 'PSZ_AC' #TODO add boolean for this PRM building type since not included in prototypes
      # elsif (building_type == 'PublicAssembly' && model_area_ip >= 120000)
      #   system_type = 'SZ_CV_HW' #TODO
      elsif (building_storys <= 3 && model_area_ip < 25000)
        system_type = 'PSZ_AC'
      elsif ( (building_storys = 4 || building_storys = 5) && model_area_ip < 25000 )
        system_type = 'PVAV_Reheat'
      elsif ( building_storys <= 5 && (model_area_ip >= 25000 && model_area_ip <= 150000) )
        system_type = 'PVAV_Reheat'
      elsif (building_storys >= 5 || model_area_ip > 150000)
        system_type = 'VAV_Reheat'
      else
        puts "#{prm_maj_sec}: baseline system could not be determined"
      end
      
    elsif climate_zones_1to3a.include?(climate_zone)
      
      if building_type == 'MidriseApartment'
        system_type = 'PTHP' #building_type_prm = 'Residential'
      # 5. Public assembly building types include
      # houses of worship, auditoriums, movie theaters, performance theaters, 
      # concert halls, arenas, enclosed stadiums, ice rinks, gymnasiums, 
      # convention centers, exhibition centers, and natatoriums. 
      # elsif building_type == 'PublicAssembly' && model_area_ip < 120000
      #   system_type = 'PSZ_HP' #TODO add boolean for this PRM building type since not included in prototypes
      # elsif building_type == 'PublicAssembly' && model_area_ip >= 120000
      #   system_type = 'SZ_CV_ER' #TODO
      elsif building_storys <= 3 && model_area_ip < 25000
        system_type = 'PSZ_HP'
      elsif (building_storys = 4 || building_storys = 5) && model_area_ip < 25000
        system_type = 'PVAV_PFP_Boxes'
      elsif building_storys <= 5 && (model_area_ip >= 25000 && model_area_ip <= 150000)
        system_type = 'PVAV_PFP_Boxes'
      elsif building_storys >= 5 && model_area_ip > 150000
        system_type = 'VAV_PFP_Boxes'
      else
        puts "#{prm_maj_sec}: baseline system could not be determined"
      end
      
    else
      
      puts 'CLIMATE ZONE NOT FOUND' 
      
    end

    # determine actual baseline system type
    zone_eqpt = []
    
    base_zones.each do |z|
      
      unless OpenStudio.convert(z.floorArea, 'm^2', 'ft^2').get > 20000
        
        z.equipment.each do |ze|
          obj_type = ze.iddObjectType.valueName
          obj_type_name = obj_type.gsub('OS_','').gsub('_','')
          zone_eqpt << obj_type_name
        end
        
      end
      
    end
    
    # determine the most frequent zone equipment
    base_model_primary_system = zone_eqpt.max_by { |i| zone_eqpt.count(i) }
        
    # check baseline cooling type
    if base_model.getChillerElectricEIRs.size > 0
      clg_type = 'CHW'
    else
      clg_type = 'DX'
    end
    
    # check baseline heating type
    if base_model.getBoilerHotWaters.size > 0
      htg_type = 'HW'
    else
      htg_type = 'Electric'
    end
    
    # tests
    case base_model_primary_system
      
    when 'ZoneHVACPackagedTerminalAirConditioner' 
      
      assert_equal('PTAC', system_type, "#{prm_maj_sec}: primary baseline system type incorrect") #sys1
      
    when 'ZoneHVACPackagedTerminalHeatPump'
      
      assert_equal('PTHP', system_type, "#{prm_maj_sec}: primary baseline system type incorrect") #sys2
      
    when 'AirTerminalSingleDuctUncontrolled'
      
      if clg_type == 'DX' && htg_type == 'HW'
        assert_equal('PSZ_AC', system_type, "#{prm_maj_sec}: primary baseline system type incorrect") #sys 3
      elsif clg_type == 'DX' && htg_type == 'Electric'
        assert_equal('PSZ_HP', system_type, "#{prm_maj_sec}: primary baseline system type incorrect") #sys 4
      end
      
    when 'AirTerminalSingleDuctVAVReheat'
      
      if clg_type == 'DX' && htg_type == 'HW'
        assert_equal('PVAV_Reheat', system_type, "#{prm_maj_sec}: primary baseline system type incorrect") #sys 5
      elsif clg_type == 'DX' && htg_type == 'Electric'
        assert_equal('PVAV_PFP_Boxes', system_type, "#{prm_maj_sec}: primary baseline system type incorrect") #sys 6
      elsif clg_type == 'CHW' && htg_type == 'HW'
        assert_equal('VAV_Reheat', system_type, "#{prm_maj_sec}: primary baseline system type incorrect") #sys 7
      elsif clg_type == 'CHW' && htg_type == 'Electric'
        assert_equal('VAV_PFP_Boxes', system_type, "#{prm_maj_sec}: primary baseline system type incorrect") #sys 8    
      end
      
    end     
    
  end  
 
  # @author Matt Steen, Ambient Energy
  def check_purchased_energy(base_model, prop_model)

    prm_maj_sec = 'G3.1.1 Baseline HVAC System Type'
  
    # get model objects, could use zone.heating_fuels    
    prop_dist_htgs = prop_model.getDistrictHeatings
    prop_dist_clgs = prop_model.getDistrictCoolings
    base_dist_htgs = base_model.getDistrictHeatings
    base_dist_clgs = base_model.getDistrictCoolings
  
    # tests
    
    if prop_dist_htgs.size > 0 && prop_dist_clgs.size > 0
  
      assert(base_dist_clgs.size >= 1 && base_dist_htgs.size >= 1, "#{prm_maj_sec}: baseline model missing district cooling and heating.")
      
    elsif prop_dist_htgs.size > 0
      
      assert(base_dist_htgs.size >= 1, "#{prm_maj_sec}: baseline model missing district heating.")
      
    elsif prop_dist_clgs.size > 0
        
      assert(base_dist_clgs.size >= 1, "#{prm_maj_sec}: baseline model missing district cooling.")
      
    else
      
      puts 'NA: Test Purchased Energy'
      
    end
    
  end

  # @author Matt Steen, Ambient Energy
  def check_num_boilers(base_model, prop_model)

    prm_maj_sec = 'G3.1.3 System-Specific Baseline HVAC System Requirements'
    
    # get model objects
    model_area_si = prop_model.getBuilding.floorArea
    model_area_ip = OpenStudio.convert(model_area_si, 'm^2', 'ft^2').get
    boilers = base_model.getBoilerHotWaters
    boiler_num = boilers.size
    
    unless boiler_num == 0
          
      if model_area_ip <= 15000
        
        assert(boiler_num = 1, "#{prm_maj_sec}")
        
      elsif model_area_ip > 15000
  
        assert(boiler_num = 2, "#{prm_maj_sec}") 
        
        sizing = []
        
        boilers.each do |b|
          
          autosized = b.isNominalCapacityAutosized()
          case autosized
          when true
            sizing << autosized
          when false
            size = b.nominalCapacity.get
            sizing << size
          end
          
        end
        
        assert_equal(sizing[0], sizing[1], "#{prm_maj_sec}")
        
      end
    
    end
        
  end

  # @author Matt Steen, Ambient Energy
  def check_num_chillers(base_model, prop_model)
    
    prm_maj_sec = 'G3.1.3 System-Specific Baseline HVAC System Requirements'
    
    # get model objects
    chillers = base_model.getChillerElectricEIRs
    
    model_area_si = prop_model.getBuilding.floorArea
    model_area_ip = OpenStudio.convert(model_area_si, 'm^2', 'ft^2').get
    chiller_num = chillers.size
    
    # get baseline peak cooling laod
    base_peak_clg_si = 'TODO' #get from sql
    base_peak_clg_ip = 200 #OpenStudio.convert(base_peak_clg_si, 'W', 'tons').get
    
    chiller_cap = []
    
    unless chiller_num == 0    
      
      if base_peak_clg_ip <= 300
        assert_equal(1, chiller_num, "#{prm_maj_sec}: number of chillers")
      elsif base_peak_clg_ip > 300 && base_peak_clg_ip < 600
        assert_equal(2, chiller_num, "#{prm_maj_sec}: number of chillers")
      elsif base_peak_clg_ip >= 600
        assert(chiller_num >= 2, "#{prm_maj_sec}: number of chillers")
        chillers.each do |c|
          #TODO get size
                    
        end
      end
        
    end  
    
  end

  # @author Matt Steen, Ambient Energy
  def check_plant_controls(base_model, prop_model)

    prm_maj_sec = 'G3.1.3 System-Specific Baseline HVAC System Requirements'

    # get model objects
    base_plant_loops = base_model.getPlantLoops
    des_days = base_model.getDesignDays
    
    # tests    
    if base_plant_loops.size > 0
      
      base_plant_loops.each do |pl|
        
        # get plant components
        sizing_plant = pl.sizingPlant
        loop_type = sizing_plant.loopType
        supply_outlet_node = pl.supplyOutletNode
        setpoint_managers = supply_outlet_node.setpointManagers
        
        # set assert delta to account for unit conversions
        delta = 0.1
        
        case loop_type
        when 'Heating'
        # TODO handle cases where loop provides SHW: https://github.com/NREL/EnergyPlus/issues/5613
        
          # G3.1.3.3 Hot-Water Supply Temperature (Systems 1, 5, 7, and 12)
          prm_min_sec = 'Hot-Water Supply Temperature'
          assert_msg = "#{prm_maj_sec}: #{prm_min_sec}"
          
          des_temp = sizing_plant.getDesignLoopExitTemperature(returnIP=true).value
          des_temp_diff = sizing_plant.getLoopDesignTemperatureDifference(returnIP=true).value
          assert_in_delta(180, des_temp, delta, assert_msg)
          assert_in_delta(50, des_temp_diff, delta, assert_msg)
          
          # G3.1.3.4 Hot-Water Supply Temperature Reset (Systems 1, 5, 7, 11, and 12)
          prm_min_sec = 'Hot-Water Supply Temperature Reset'
          assert_msg = "#{prm_maj_sec}: #{prm_min_sec}"
          
          if setpoint_managers[0].to_SetpointManagerOutdoorAirReset.is_initialized
            spm_oar = setpoint_managers[0].to_SetpointManagerOutdoorAirReset.get
          else
            assert(setpoint_managers[0].to_SetpointManagerOutdoorAirReset.is_initialized, assert_msg)
          end
          
          set_oat_lo = spm_oar.getSetpointatOutdoorLowTemperature(returnIP=true).value
          oat_lo = spm_oar.getOutdoorLowTemperature(returnIP=true).value
          set_oat_hi = spm_oar.getSetpointatOutdoorHighTemperature(returnIP=true).value
          oat_hi = spm_oar.getOutdoorHighTemperature(returnIP=true).value
                    
          assert_in_delta(180, set_oat_lo, delta, assert_msg)
          assert_in_delta(20, oat_lo, delta, assert_msg)
          assert_in_delta(150, set_oat_hi, delta, assert_msg)
          assert_in_delta(50, oat_hi, delta, assert_msg)
          
        when 'Cooling'
          
          # G3.1.3.8 Chilled-Water Design Supply Temperature (Systems 7, 8, 11, 12, and 13)
          prm_min_sec = 'Chilled-Water Design Supply Temperature'
          assert_msg = "#{prm_maj_sec}: #{prm_min_sec}"
          
          des_temp = sizing_plant.getDesignLoopExitTemperature(returnIP=true).value
          des_temp_diff = sizing_plant.getLoopDesignTemperatureDifference(returnIP=true).value
          assert_in_delta(44, des_temp, delta, assert_msg)
          assert_in_delta(12, des_temp_diff, delta, assert_msg)
          
          # G3.1.3.9 Chilled-Water Supply Temperature Reset (Systems 7, 8, 11, 12, and 13)
          prm_min_sec = 'Chilled-Water Supply Temperature Reset'  
          assert_msg = "#{prm_maj_sec}: #{prm_min_sec}"
          
          if setpoint_managers[0].to_SetpointManagerOutdoorAirReset.is_initialized
            spm_oar = setpoint_managers[0].to_SetpointManagerOutdoorAirReset.get
          else
            assert(setpoint_managers[0].to_SetpointManagerOutdoorAirReset.is_initialized, assert_msg)
          end
          
          set_oat_lo = spm_oar.getSetpointatOutdoorLowTemperature(returnIP=true).value
          oat_lo = spm_oar.getOutdoorLowTemperature(returnIP=true).value
          set_oat_hi = spm_oar.getSetpointatOutdoorHighTemperature(returnIP=true).value
          oat_hi = spm_oar.getOutdoorHighTemperature(returnIP=true).value
                    
          assert_in_delta(54, set_oat_lo, delta, assert_msg)
          assert_in_delta(60, oat_lo, delta, assert_msg)
          assert_in_delta(44, set_oat_hi, delta, assert_msg)
          assert_in_delta(80, oat_hi, delta, assert_msg)
    
        when 'Condenser'
          
          # 90.1-2013
          # G3.1.3.11 Heat Rejection (Systems 7, 8, 9, 12, and 13)
          prm_min_sec = 'Heat Rejection'
          assert_msg = "#{prm_maj_sec}: #{prm_min_sec}"
          
          if setpoint_managers[0].to_SetpointManagerFollowOutdoorAirTemperature.is_initialized
            spm_follow_oat = setpoint_managers[0].to_SetpointManagerFollowOutdoorAirTemperature.get
          else
            assert(setpoint_managers[0].to_SetpointManagerFollowOutdoorAirTemperature.is_initialized, assert_msg)
          end 
          
          spm_ctrl_var = spm_follow_oat.controlVariable
          spm_ref_temp = spm_follow_oat.referenceTemperatureType
          spm_offset_temp_diff_si = spm_follow_oat.offsetTemperatureDifference
          spm_max_temp_si = spm_follow_oat.maximumSetpointTemperature
          spm_min_temp_si = spm_follow_oat.minimumSetpointTemperature
          spm_offset_temp_diff_ip = OpenStudio.convert(spm_offset_temp_diff_si, 'K', 'R').get
          spm_max_temp_ip = OpenStudio.convert(spm_max_temp_si, 'C', 'F').get
          spm_min_temp_ip = OpenStudio.convert(spm_min_temp_si, 'C', 'F').get
          
          des_day_wb_ip = []
          
          des_days.each do |dd|
            
            next unless dd.dayType == 'SummerDesignDay'
            next unless dd.name.get.to_s.include?('WB=>MDB')
            
            if dd.humidityIndicatingType == 'Wetbulb'
              des_day_wb_si = dd.humidityIndicatingConditionsAtMaximumDryBulb
              des_day_wb_ip << OpenStudio.convert(des_day_wb_si, 'C', 'F').get
              puts "DD WB = #{des_day_wb_ip}"
            else
              puts "#{prm_maj_sec}: #{prm_min_sec}: cannot determine design day information"
            end
            
          end
        
          if des_day_wb_ip.size == 0
            wb = 78
          else
            wb = des_day_wb_ip.max
          end
          
          # EnergyPlus limit
          if wb > 80
            wb = 80
          end
          #TODO reconcile EP and PRM limits
          # PRM limits
          if wb < 55
            wb = 55
          elsif wb > 90
            wb = 90
          end            
          
          prm_approach = 25.72 - (0.24*wb)
          prm_max_temp = prm_approach + wb #approach = LWT - Twb    
          
          assert_equal('Temperature', spm_ctrl_var, assert_msg)
          assert_equal('OutdoorAirWetBulb', spm_ref_temp, assert_msg)
          assert_in_delta(prm_approach, spm_offset_temp_diff_ip, delta, assert_msg)
          assert_in_delta(prm_max_temp, spm_max_temp_ip, delta, assert_msg)    
          assert_in_delta(70, spm_min_temp_ip, delta, assert_msg)
          
          # puts "PRM WB = #{wb}"
          # puts "PRM APPROACH = #{prm_approach}"
          # puts "PRM MAX = #{prm_max_temp}"
          # puts "SPM MAX = #{spm_max_temp_ip}"
          
        end
        
      end
      
    else
      
      puts "#{prm_maj_sec}: NA plant loops not found in baseline"
      
    end
  
  end
  
  # @author Matt Steen, Ambient Energy
  def check_shw(base_model, prop_model, building_type)

    prm_maj_sec = 'Table G3.1 No. 11: Service Hot Water'
    
    # get model objects
    base_wtr_htr_mixeds = base_model.getWaterHeaterMixeds
    prop_wtr_htr_mixeds = prop_model.getWaterHeaterMixeds
    
    # test baseline water heater
    if prop_wtr_htr_mixeds.size > 0
      # assert(base_wtr_htr_mixeds.size > 0, 'PRM: proposed model contains water heater(s), but baseline model does not')
    end
    
    # determine building area type
    # 90.1-2013, Table G3.1.1-2
    # TODO building types here do not match measure options
    if building_type.include?('Office') || building_type.include?('Retail')
      prm_shw_fuel = 'NaturalGas'
    else
      prm_shw_fuel = 'Electricity'
    end   
    
    # 90.1-2013 Table 7.8
    prm_cap_elec = OpenStudio.convert(12, 'kW', 'Btu/h').get
    prm_vol_elec = 12 #gal
    prm_cap_gas = 75000
        
    base_wtr_htr_mixeds.each do |wh|
      
      if wh.to_WaterHeaterMixed.is_initialized
        
        wh = wh.to_WaterHeaterMixed.get
        fuel = wh.heaterFuelType
        eff = wh.getHeaterThermalEfficiency(returnIP=true).get.value
        cap = wh.getHeaterMaximumCapacity(returnIP=true).get.value
        vol = wh.getTankVolume(returnIP=true).get.value
        ua_off = wh.getOffCycleLossCoefficienttoAmbientTemperature(returnIP=true).get.value
        ua_on = wh.getOnCycleLossCoefficienttoAmbientTemperature(returnIP=true).get.value
        
        # test baseline water heater fuel
         assert_equal(prm_shw_fuel, fuel, "#{prm_maj_sec}: baseline water heater fuel type")
        
        # test baseline water heater efficiency
        # e_ht = EnergyPlus Heater Thermal Efficiency, which is gross
        # e_t = thermal efficiency, which is net
        
        case prm_shw_fuel
        
        when 'Electricity'
          
          if cap <= prm_cap_elec && vol >= prm_vol_elec
            # from standard
            ef = 0.97 - 0.00035 * vol
            # from PNNL
            e_ht = 1
            ua = (41094 * (1/ef - 1)) / (24 * 67.5)
            # test
            assert_equal(e_ht, eff, "#{prm_maj_sec}: baseline water heater efficiency")
          elsif cap > prm_cap_elec && vol >= prm_vol_elec
            e_ht = 1
            # ua = sl * 1 / 70
            #TODO
          end  
          
        when 'NaturalGas' 
          
          if cap <= prm_cap_gas
            # from standard
            ef = 0.67 - 0.0005 * vol
            # from PNNL
            e_ht = 0.82
            #TODO solve equations
            assert_in_delta(0.82, eff, delta=0, "#{prm_maj_sec}: baseline water heater efficiency")
          elsif cap > prm_cap_gas
            # from standard
            e_t = 0.8
            cap = 75000
            sl = cap / 800 + 110 * Math.sqrt(vol) #per 2013 errata
            # from PNNL
            ua = sl * e_t / 70
            p_on = 75000 #Btu/h
            e_ht = (ua * 70 + p_on * e_t) / p_on
            # test
            assert_in_delta(e_ht, eff, delta=0.001, "#{prm_maj_sec}: baseline water heater efficiency")
            assert_in_delta(ua, ua_off, delta=0.1, "#{prm_maj_sec}: baseline water heater UA")
            assert_in_delta(ua, ua_on, delta=0.1, "#{prm_maj_sec}: baseline water heater UA")
          end
      
        end
      
      end
      
    end
  
  end  
  
end


 