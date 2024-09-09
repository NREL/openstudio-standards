class NECB2011
    def detect_air_system_type(air_loop: nil , sys_abbr: nil , old_system_name: nil)
        # Determine system charecteristics. 
        puts air_loop
        unitary_hp = air_loop.components.detect(proc {false}) { |equip| equip.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized()} ? air_loop.components.detect() { |equip| equip.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized()}.to_AirLoopHVACUnitaryHeatPumpAirToAir.get : false
        unitary_heating_coil_elec = unitary_hp and unitary_hp.to_AirLoopHVACUnitaryHeatPumpAirToAir.get.heatingCoil.to_CoilHeatingElectric.is_initialized()? unitary_hp.to_AirLoopHVACUnitaryHeatPumpAirToAir.get.heatingCoil.get : false
        unitary_heating_coil_gas = unitary_hp and unitary_hp.to_AirLoopHVACUnitaryHeatPumpAirToAir.get.heatingCoil.to_CoilHeatingGas.is_initialized()? unitary_hp.to_AirLoopHVACUnitaryHeatPumpAirToAir.get.heatingCoil.get : false
        unitary_heating_coil_ashp = unitary_hp and unitary_hp.to_AirLoopHVACUnitaryHeatPumpAirToAir.get.heatingCoil.to_CoilHeatingDXSingleSpeed.is_initialized()? unitary_hp.to_AirLoopHVACUnitaryHeatPumpAirToAir.get.heatingCoil.to_CoilHeatingDXSingleSpeed.get : false
        unitary_supply_fan_on_off = unitary_hp and unitary_hp.to_AirLoopHVACUnitaryHeatPumpAirToAir.get.supplyAirFan.to_FanOnOff.is_initialized() ? unitary_hp.to_AirLoopHVACUnitaryHeatPumpAirToAir.get.supplyAirFan.to_FanOnOff.get : false
        heating_coil_elect = air_loop.components.detect(proc {false}) { |equip| equip.to_CoilHeatingElectric.is_initialized } ? air_loop.components.detect() { |equip| equip.to_CoilHeatingElectric.is_initialized}.to_CoilHeatingElectric.get : false
        heating_coil_ashp = air_loop.components.detect(proc {false}) { |equip| equip.to_CoilHeatingDXSingleSpeed.is_initialized and equip.to_CoilHeatingDXSingleSpeed.get.minimumOutdoorDryBulbTemperatureforCompressorOperation == -10} ? air_loop.components.detect() { |equip| equip.to_CoilHeatingDXSingleSpeed.is_initialized}.to_CoilHeatingDXSingleSpeed.get : false
        heating_coil_ccashp = air_loop.components.detect(proc {false}) { |equip| equip.to_CoilHeatingDXSingleSpeed.is_initialized and equip.to_CoilHeatingDXSingleSpeed.get.minimumOutdoorDryBulbTemperatureforCompressorOperation == -25} ? air_loop.components.detect() { |equip| equip.to_CoilHeatingDXSingleSpeed.is_initialized}.to_CoilHeatingDXSingleSpeed.get : false
        heating_coil_water = air_loop.components.detect(proc {false}) { |equip| equip.to_CoilHeatingWater.is_initialized } ? air_loop.components.detect() { |equip| equip.to_CoilHeatingWater.is_initialized}.to_CoilHeatingWater.get : false
        heating_coil_gas = air_loop.components.detect(proc {false}) { |equip| equip.to_CoilHeatingGas.is_initialized } ? air_loop.components.detect() { |equip| equip.to_CoilHeatingGas.is_initialized}.to_CoilHeatingGas.get : false
        cooling_coil_ashp = air_loop.components.detect(proc {false}) { |equip| equip.to_CoilCoolingDXSingleSpeed.is_initialized and heating_coil_ashp}
        cooling_coil_ccashp = air_loop.components.detect(proc {false}) { |equip| equip.to_CoilCoolingDXSingleSpeed.is_initialized and heating_coil_ccashp}
        cooling_coil_dx = air_loop.components.detect(proc {false}) { |equip| equip.to_CoilCoolingDXSingleSpeed.is_initialized and (heating_coil_gas or heating_coil_elect or heating_coil_water)}

        cooling_coil_water = air_loop.components.detect(proc {false}) { |equip| equip.to_CoilCoolingWater.is_initialized } ? air_loop.components.detect() { |equip| equip.to_CoilCoolingWater.is_initialized}.to_CoilCoolingWater.get : false
        zone_htg_b_elec = air_loop.thermalZones.first.equipment.detect(proc {false}) { |equip| equip.nameString.include?('Zone HVAC Baseboard Convective Electric') }
        zone_htg_b_water = air_loop.thermalZones.first.equipment.detect(proc {false}) { |equip| equip.nameString.include?('Zone HVAC Baseboard Convective Water') }
        zone_vav_rh = air_loop.components.detect(proc {false}) { |equip| equip.to_AirTerminalSingleDuctVAVReheat.is_initialized()} ? air_loop.components.detect() { |equip| equip.to_AirTerminalSingleDuctVAVReheat.is_initialized()}.to_AirTerminalSingleDuctVAVReheat.get : false


        #Check if TPFC is on or off.
        zone_tpfc = false
        zone_fpfc = false
        if air_loop.thermalZones.first.equipment.detect(proc {false}) { |equip| equip.to_ZoneHVACFourPipeFanCoil().is_initialized()}
            case air_loop.thermalZones.first.equipment.detect(proc {false}) { |equip| equip.to_ZoneHVACFourPipeFanCoil().is_initialized()}.to_ZoneHVACFourPipeFanCoil.get.coolingCoil.to_CoilCoolingWater.get.availabilitySchedule.nameString
            when 'tpfc_clg_availability'
            zone_tpfc = true
            when OpenStudio::Model::Model.new.alwaysOnDiscreteSchedule.nameString
            zone_fpfc = true
            else
            raise('unknown schedule type')
            end
        end  

        zone_htg_pthp = air_loop.thermalZones.first.equipment.detect(proc {false}) { |equip| equip.nameString.include?('Zone HVAC Packaged Terminal Heat Pump') }
        zone_clg_ptac = air_loop.thermalZones.first.equipment.detect(proc {false}) { |equip| equip.nameString.include?('PTAC') }
        zone_clg_pthp = air_loop.thermalZones.first.equipment.detect(proc {false}) { |equip| equip.nameString.include?('Zone HVAC Packaged Terminal Heat Pump') }
        zone_rh_elec = air_loop.thermalZones.first.equipment.detect(proc {false}) { |equip| equip.nameString.include?('Air Terminal Single Duct Constant Volume Reheat') and equip.to_AirTerminalSingleDuctConstantVolumeReheat.get.reheatCoil.nameString.include?('Coil Heating Electric') }
        zone_rh_gas = air_loop.thermalZones.first.equipment.detect(proc {false}) { |equip| equip.nameString.include?('Air Terminal Single Duct Constant Volume Reheat') and equip.to_AirTerminalSingleDuctConstantVolumeReheat.get.reheatCoil.nameString.include?('Coil Heating Gas') }
        zone_rh_hw = air_loop.thermalZones.first.equipment.detect(proc {false}) { |equip| equip.nameString.include?('Air Terminal Single Duct Constant Volume Reheat') and equip.to_AirTerminalSingleDuctConstantVolumeReheat.get.reheatCoil.nameString.include?('Coil Heating Water') }
        return_fan = air_loop.components.detect(proc {false}) { |equip| equip.nameString.include?('Fan') }
        # Determine System Outdoor Air type.
        oa_controller = air_loop.components.detect(proc {false}) { |equip| equip.nameString.include?('ControllerOutdoorAir') }
        oa_system = air_loop.components.detect(proc {false}) { |equip| equip.nameString.include?('OutdoorAirSystem') }
        # Determine System Heat Recovery type.
        heat_recovery = air_loop.components.detect(proc {false}) { |equip| equip.nameString.include?('HeatExchangerAirToAirSensibleAndLatent') }
        # Determine System Supply Fan type.
        fans_vv = air_loop.components.select{ |equip| equip.to_FanVariableVolume.is_initialized()}
        fans_cv = air_loop.components.select{ |equip| equip.to_FanConstantVolume.is_initialized()}
        case fans_vv.size
        when 1
            supply_fan_vv = fans_vv[1].to_FanVariableVolume.get
            return_fan_vv = false
        when 2
            return_fan_vv = fans_vv[0].to_FanVariableVolume.get
            supply_fan_vv = fans_vv[1].to_FanVariableVolume.get
        else
            supply_fan_vv = false
            return_fan_vv = false
        end
        case fans_cv.size
        when 1
            supply_fan_cv = fans_cv[0].to_FanConstantVolume.get
            return_fan_cv = false
        when 2
            return_fan_cv = fans_cv[0].to_FanConstantVolume.get
            supply_fan_cv = fans_cv[1].to_FanConstantVolume.get
        else
            supply_fan_cv = false
            return_fan_cv = false
        end

        # System Name and assumptions

        case sys_abbr
        when "sys_1"
            ref_sys = sys_abbr
            oa='doas'
            oa = 'mixed' if heating_coil_ashp or heating_coil_ccashp
        when "sys_2"
            ref_sys = sys_abbr
            oa='doas'
        when "sys_3"
            ref_sys = sys_abbr
            oa='mixed'
        when "sys_5"
            ref_sys = sys_abbr
            oa='doas'
        when "sys_4"
            ref_sys = sys_abbr
            oa='mixed'
        when "sys_6"
            ref_sys = sys_abbr
            oa='mixed'
        else
            raise("System name not recognized")
        end


            
        # Determine if the system is a DOAS based on
        # whether there is 100% OA in heating and cooling sizing.
        puts "allOutdoorAirinCooling #{air_loop.sizingSystem.allOutdoorAirinCooling}"
        puts "allOutdoorAirinHeating #{air_loop.sizingSystem.allOutdoorAirinHeating}"
        puts "typeofLoadtoSizeOn #{air_loop.sizingSystem.typeofLoadtoSizeOn}"





        # puts "heating_coil_elect: #{heating_coil_elect.nil?}"
        # puts "heating_coil_ashp: #{heating_coil_ashp}"
        # puts "heating_coil_ccashp: #{heating_coil_ccashp}"
        # puts "heating_coil_water: #{heating_coil_water}"
        # puts "cooling_coil_ashp: #{cooling_coil_ashp}"
        # puts "cooling_coil_ccashp: #{cooling_coil_ccashp}"
        # puts "cooling_coil_dx: #{cooling_coil_dx}"
        # puts "cooling_coil_water: #{cooling_coil_water}"
        # puts "heating_coil_gas: #{heating_coil_gas}"
        # puts "zone_htg_b_elec: #{zone_htg_b_elec}"
        # puts "zone_htg_b_water: #{zone_htg_b_water}"
        # puts "zone_htg_tpfc: #{zone_htg_tpfc}"
        # puts "zone_htg_fpfc: #{zone_htg_fpfc}"
        # puts "zone_htg_pthp: #{zone_htg_pthp}"
        # puts "zone_clg_tpfc: #{zone_clg_tpfc}"
        # puts "zone_clg_fpfc: #{zone_clg_fpfc}"
        # puts "zone_clg_ptac: #{zone_clg_ptac}"
        # puts "zone_clg_pthp: #{zone_clg_pthp}"
        # puts "return_fan: #{return_fan}"
        # puts "oa_controller: #{oa_controller}"
        # puts "oa_system: #{oa_system}"
        # puts "heat_recovery: #{heat_recovery}"
        # puts "supply_fan_vv: #{supply_fan_vv}"
        # puts "return_fan_vv: #{return_fan_vv}"
        # puts "supply_fan_cv: #{supply_fan_cv}"
        # puts "return_fan_cv: #{return_fan_cv}"
        # puts "zone_rh_elec: #{zone_rh_elec}"
        # puts "zone_rh_gas: #{zone_rh_gas}"
        # puts "unitary_hp: #{unitary_hp}"
        # puts "unitary_heating_coil_elec: #{unitary_heating_coil_elec}"
        # puts "unitary_heating_coil_gas: #{unitary_heating_coil_gas}"
        # puts "unitary_heating_coil_ashp: #{unitary_heating_coil_ashp}"
        # puts "unitary_supply_fan_on_off: #{unitary_supply_fan_on_off}"
        # puts "zone_htg_b_elec: #{zone_htg_b_elec}"
        # puts "zone_htg_b_water: #{zone_htg_b_water}"





        # sys_htg or sh>?
        if heating_coil_elect
            sh = 'sh>c-e'
        elsif heating_coil_ashp or unitary_hp
            sh = 'sh>ashp'
        elsif heating_coil_ccashp
            sh = 'sh>ccashp'
        elsif heating_coil_water
            sh = 'sh>c-hw'
        elsif heating_coil_gas
            sh = 'sh>c-g'
        else
            sh = 'sh>none'
        end

        # sys_clg or sc>?

        if cooling_coil_ashp or unitary_hp
            sc = 'sc>ashp'
        elsif cooling_coil_ccashp
            sc = 'sc>ccashp'
        elsif cooling_coil_dx
            sc = 'sc>dx'
        elsif cooling_coil_water
            sc = 'sc>c-chw'
        else
            sc = 'sc>none'
        end

        # sys_sf or ssf>?
        if supply_fan_cv or unitary_supply_fan_on_off
            ssf = 'ssf>cv'
        elsif supply_fan_vv
            ssf = 'ssf>vv'
        else
            ssf = 'ssf>none'
        end


        if return_fan_cv
            srf = 'srf>cv'
        elsif return_fan_vv
            srf = 'srf>vv'
        else
            srf = 'srf>none'
        end

        # zone_htg or zh>?
        if zone_htg_b_elec
            zh = 'zh>b-e'
        elsif zone_htg_b_water
            zh = 'zh>b-hw'
        elsif zone_tpfc
            zh = 'zh>tpfc'
        elsif zone_fpfc
            zh = 'zh>fpfc'
        elsif zone_htg_pthp
            zh = 'zh>pthp'
        else
            zh = 'zh>none'
        end

        if zone_tpfc
            zc = 'zc>tpfc'
        elsif zone_fpfc
            zc = 'zc>fpfc'
        elsif zone_clg_ptac
            zc = 'zc>ptac'
        elsif zone_clg_pthp
            zc = 'zc>pthp'
        else
            zc = 'zc>none'
        end
        name =""
        
        
        # sh and sc are reversed for system 6
        unless ref_sys == "sys_6"
            name = "#{ref_sys}|#{oa}|shr>none|#{sc}|#{sh}|#{ssf}|#{zh}|#{zc}|#{srf}|"
        else
            name = "#{ref_sys}|#{oa}|shr>none|#{sh}|#{sc}|#{ssf}|#{zh}|#{zc}|#{srf}|"
        end
        return old_system_name, name
    end
end