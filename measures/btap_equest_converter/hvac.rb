require "#{File.dirname(__FILE__)}/btap"

module BTAP
  module Resources #Resources


    # This module contains methods that relate to Materials, Constructions and Construction Sets

    module HVAC # BTAP::Resources::HVAC


      def self.clear_all_loops(model)
        model.getPlantLoops().each {|loop| loop.remove }
        model.getAirLoopHVACs().each {|loop| loop.remove }
      end

      def self.clear_all_zone_equipment_from_zone(thermal_zone)
        thermal_zone.equipment().each do |zone_equipment|
          zone_equipment.remove()
        end
      end

      def self.clear_all_zone_equipment_from_model(model)
        model.getThermalZones.each do |thermal_zone|
          BTAP::Resources::HVAC::clear_all_zone_equipment_from_zone(thermal_zone)
        end
      end

      def self.clear_all_hvac_from_model(model)
        BTAP::Resources::HVAC::clear_all_zone_equipment_from_model(model)
        BTAP::Resources::HVAC::clear_all_loops(model)
      end

      def self.enable_demand_control_ventilation(model,is_enabled)
        log = ""
        log << "ControllerMechanicalVentilation_handle,enabled?\n"
        model.getControllerMechanicalVentilations.each do |item|
          item.setDemandControlledVentilation( is_enabled )
          log << "#{item.handle},#{item.demandControlledVentilation.to_s}\n"
        end
        return log
      end

      def self.enable_erv(
          model,
          autosizeNominalSupplyAirFlowRate = true,
          setNominalSupplyAirFlowRate = nil,
          setHeatExchangerType = 'Plate', # 'Rotary' or 'Plate'
          setSensibleEffectivenessat100CoolingAirFlow = 0.76,
          setSensibleEffectivenessat75CoolingAirFlow  = 0.81,
          setLatentEffectiveness100Cooling = 0.68,
          setLatentEffectiveness75Cooling = 0.73,
          setSensibleEffectiveness100Heating = 0.76,
          setSensibleEffectiveness75Heating = 0.81,
          setLatentEffectiveness100Heating = 0.68,
          setLatentEffectiveness75Heating = 0.73,
          setSupplyAirOutletTemperatureControl = true,
          setFrostControlType = 'None', # 'None', 'ExhaustAirRecirculation','ExhaustOnly','MinimumExhaustTemperature'
          setThresholdTemperature  = 1.7,
          setInitialDefrostTimeFraction = 0,
          nominal_electric_power = nil,
          setEconomizerLockout = true
        )
        erv_array = Array.new()
        erv_array << model.getAirLoopHVACs().each do |air_loop|
          BTAP::Resources::HVAC::Plant::add_erv(
            model,
            air_loop,
            autosizeNominalSupplyAirFlowRate,
            setNominalSupplyAirFlowRate,
            setHeatExchangerType, # 'Rotary' or 'Plate'
            setSensibleEffectivenessat100CoolingAirFlow,
            setSensibleEffectivenessat75CoolingAirFlow,
            setLatentEffectiveness100Cooling,
            setLatentEffectiveness75Cooling,
            setSensibleEffectiveness100Heating,
            setSensibleEffectiveness75Heating,
            setLatentEffectiveness100Heating,
            setLatentEffectiveness75Heating,
            setSupplyAirOutletTemperatureControl,
            setFrostControlType, # 'None', 'ExhaustAirRecirculation','ExhaustOnly','MinimumExhaustTemperature'
            setThresholdTemperature,
            setInitialDefrostTimeFraction,
            nominal_electric_power,
            setEconomizerLockout)
        end
        return erv_array
      end


      def self.enable_economizer(
          model,
          setEconomizerControlType = "FixedDryBulb",
          setEconomizerControlActionType = "ModulateFlow",
          setEconomizerMaximumLimitDryBulbTemperature = 28.0,
          setEconomizerMaximumLimitEnthalpy = 64000,
          setEconomizerMaximumLimitDewpointTemperature = 0.0,
          setEconomizerMinimumLimitDryBulbTemperature = -100.0
        )
        log = ""
        log << "air_loop_handle,economizer_control_type,	economizer_control_action_type,	economizer_maximum_limit_dry_bulb_temperature,	economizer_maximum_limit_enthalpy,	economizer_maximum_limit_dewpoint_temperature,	economizer_minimum_limit_dry_bulb_temperature"

        model.getAirLoopHVACs().each do |air_loop|
          controller_oa = BTAP::Resources::HVAC::Plant::add_economizer(
            model,
            air_loop,
            setEconomizerControlType,
            setEconomizerControlActionType,
            setEconomizerMaximumLimitDryBulbTemperature,
            setEconomizerMaximumLimitEnthalpy,
            setEconomizerMaximumLimitDewpointTemperature,
            setEconomizerMinimumLimitDryBulbTemperature
          )
          if !!controller_oa == controller_oa  and controller_oa == false
            log << "no controller present and not adding any."
          else
            log << "#{air_loop.handle},#{controller_oa.getEconomizerControlType}, #{controller_oa.getEconomizerControlActionType},#{controller_oa.getEconomizerMaximumLimitDryBulbTemperature},#{controller_oa.getEconomizerMaximumLimitEnthalpy},#{controller_oa.getEconomizerMaximumLimitDewpointTemperature},#{controller_oa.getEconomizerMinimumLimitDryBulbTemperature}\n"
          end
        end
        return log
      end

      module Plant


        #Test Plant Module
        if __FILE__ == $0
          require 'test/unit'
          class PlantTests < Test::Unit::TestCase

            def test_add_water_loop()
              model = OpenStudio::Model::Model.new()
              loop = BTAP::Resources::HVAC::Plant::add_water_loop(model)
              assert( !(loop.to_PlantLoop.empty?))
            end

            def test_add_air_loop()
              model = OpenStudio::Model::Model.new()
              loop = BTAP::Resources::HVAC::Plant::add_air_loop(model)
              assert( !(loop.to_AirLoopHVAC.empty?))
            end

            def test_add_boiler_hot_water_to_water_loop()
              model = OpenStudio::Model::Model.new()
              loop = BTAP::Resources::HVAC::Plant::add_water_loop(model)
              boiler = BTAP::Resources::HVAC::Plant::add_boiler_hot_water_to_water_loop(model,loop)
              assert( !(boiler.to_BoilerHotWater.empty?))
            end

            def test_add_cooling_tower_to_water_loop()
              model = OpenStudio::Model::Model.new()
              loop = BTAP::Resources::HVAC::Plant::add_water_loop(model)
              tower = BTAP::Resources::HVAC::Plant::add_cooling_tower_to_water_loop(model,loop )
              assert( !(tower.to_CoolingTowerSingleSpeed.empty?))
            end

            def test_add_chiller_electric_eir_to_water_loop()
              model = OpenStudio::Model::Model.new()
              loop = BTAP::Resources::HVAC::Plant::add_water_loop(model)
              chiller = BTAP::Resources::HVAC::Plant::add_chiller_electric_eir_to_water_loop(model,loop )
              assert( !(chiller.to_ChillerElectricEIR.empty?))
            end

            def test_add_district_heating_to_water_loop()
              model = OpenStudio::Model::Model.new()
              loop = BTAP::Resources::HVAC::Plant::add_water_loop(model)
              des = BTAP::Resources::HVAC::Plant::add_district_heating_to_water_loop(model,loop )
              assert( !(des.to_DistrictHeating.empty?))
            end

            def test_add_district_cooling_to_water_loop()
              model = OpenStudio::Model::Model.new()
              loop = BTAP::Resources::HVAC::Plant::add_water_loop(model)
              des = BTAP::Resources::HVAC::Plant::add_district_cooling_to_water_loop(model,loop )
              assert( !(des.to_DistrictCooling.empty?))
            end

            def test_add_pump_variable_speed_to_water_loop()
              model = OpenStudio::Model::Model.new()
              water_loop = BTAP::Resources::HVAC::Plant::add_water_loop(model)
              pump = BTAP::Resources::HVAC::Plant::add_pump_variable_speed(model, water_loop)
              assert( !(pump.to_PumpVariableSpeed.empty?))
            end



          end
        end # End Test Plant

        #Add a new water loop to the model.
        def self.add_water_loop(model)
          return OpenStudio::Model::PlantLoop.new(model);
        end


        #Add a hot water boiler to a water loop
        def self.add_boiler_hot_water_to_water_loop(model,water_loop,fuel_type = "NaturalGas" )
          raise("Invalid Fuel Type #{fuel_type} entered. Please use the following valid entries #{OpenStudio::Model::BoilerHotWater::validFuelTypeValues()}") unless  OpenStudio::Model::BoilerHotWater::validFuelTypeValues().include?(fuel_type)
          #get default boiler from
          boiler = BTAP::OpenStudioLibrary.instance.library.getBoilerHotWaterByName("OS:Boiler:HotWater 1").get
          #clone object from library into current model.
          new_boiler = boiler.clone(model).to_BoilerHotWater.get
          water_loop.addSupplyBranchForComponent(new_boiler)
          return boiler
        end


        #Add a cooling tower to a water loop
        def self.add_cooling_tower_to_water_loop(model,water_loop )

          tower = BTAP::OpenStudioLibrary.instance.library.getCoolingTowerSingleSpeedByName("OS:CoolingTower:SingleSpeed 1").get
          #clone object fron library into current model.
          new_tower = tower.clone(model).to_CoolingTowerSingleSpeed.get
          water_loop.addSupplyBranchForComponent(new_tower)
          return tower
        end

        #Add a chiller to a water loop
        def self.add_chiller_electric_eir_to_water_loop(model,water_loop )
          library_chiller = BTAP::OpenStudioLibrary.instance.library.getChillerElectricEIRByName("OS:Chiller:Electric:EIR 1").get
          #clone object fron library into current model.
          new_chiller = library_chiller.clone(model).to_ChillerElectricEIR.get
          water_loop.addSupplyBranchForComponent(new_chiller)
          return new_chiller
        end

        #Add a district heating to a water loop
        def self.add_district_heating_to_water_loop(model,water_loop )
          des = OpenStudio::Model::DistrictHeating.new(model);
          des.setNominalCapacity(1000000)
          water_loop.addSupplyBranchForComponent(des)
          return des
        end

        #Add a district cooling to a water loop
        def self.add_district_cooling_to_water_loop(model,water_loop )
          des = OpenStudio::Model::DistrictCooling.new(model)
          des.setNominalCapacity(1000000)
          water_loop.addSupplyBranchForComponent(des)
          return des
        end

        #Add Variable Speed Pump
        def self.add_pump_variable_speed(model,water_loop)
          library_pump = BTAP::OpenStudioLibrary.instance.library.getPumpVariableSpeedByName("OS:Pump:VariableSpeed 1").get
          supply_inlet_node = water_loop.supplyInletNode()
          #clone object from library into current model.
          new_pump = library_pump.clone(model).to_PumpVariableSpeed.get
          new_pump.addToNode(supply_inlet_node)
          return new_pump
        end
        
        #Add Constant Speed Pump
        def self.add_pump_constant_speed(model,water_loop)
          library_pump = BTAP::OpenStudioLibrary.instance.library.getPumpConstantSpeedByName("Pump Constant Speed").get
          supply_inlet_node = water_loop.supplyInletNode()
          #clone object fron library into current model.
          new_pump = library_pump.clone(model).to_PumpConstantSpeed.get
          new_pump.addToNode(supply_inlet_node)
          return new_pump
        end

        #Add a new air loop to the model.
        def self.add_air_loop(model)
          return OpenStudio::Model::AirLoopHVAC.new(model);
        end

        #Add a new constant volume fan
        def self.add_const_fan(model,avail_sched)
          return OpenStudio::Model::FanConstantVolume.new(model,avail_sched);
        end

        #Add a hydronic heating coil
        def self.add_hydronic_heating_coil(model,avail_sched)
          return OpenStudio::Model::CoilHeatingWater.new(model,avail_sched);
        end

        #Create a new biquadratic performance curve
        def self.add_biquad_curve(model)
          return OpenStudio::Model::CurveBiquadratic.new(model);
        end

        #Create a new quadratic curve
        def self.add_quad_curve(model)
          return OpenStudio::Model::CurveQuadratic.new(model);
        end

        #Create a new cubic curve
        def self.add_cubic_curve(model)
          return OpenStudio::Model::CurveCubic.new(model);
        end

        #Create a new DX cooling coil with NECB curve characteristics
        def self.add_onespeed_DX_coil(model,always_on)

              #clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
              clg_cap_f_of_temp = BTAP::Resources::HVAC::Plant::add_biquad_curve(model)
              clg_cap_f_of_temp.setCoefficient1Constant(0.867905)
              clg_cap_f_of_temp.setCoefficient2x(0.0142459)
              clg_cap_f_of_temp.setCoefficient3xPOW2(0.000554364)
              clg_cap_f_of_temp.setCoefficient4y(-0.00755748)
              clg_cap_f_of_temp.setCoefficient5yPOW2(3.3048e-05)
              clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.000191808)
              clg_cap_f_of_temp.setMinimumValueofx(13.0)
              clg_cap_f_of_temp.setMaximumValueofx(24.0)
              clg_cap_f_of_temp.setMinimumValueofy(24.0)
              clg_cap_f_of_temp.setMaximumValueofy(46.0)

              #clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
              clg_cap_f_of_flow = BTAP::Resources::HVAC::Plant::add_quad_curve(model)
              clg_cap_f_of_flow.setCoefficient1Constant(1.0)
              clg_cap_f_of_flow.setCoefficient2x(0.0)
              clg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
              clg_cap_f_of_flow.setMinimumValueofx(0.0)
              clg_cap_f_of_flow.setMaximumValueofx(1.0)

              #clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
              clg_energy_input_ratio_f_of_temp = BTAP::Resources::HVAC::Plant::add_biquad_curve(model)
              clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(0.116936)
              clg_energy_input_ratio_f_of_temp.setCoefficient2x(0.0284933)
              clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(-0.000411156)
              clg_energy_input_ratio_f_of_temp.setCoefficient4y(0.0214108)
              clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.000161028)
              clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.000679104)
              clg_energy_input_ratio_f_of_temp.setMinimumValueofx(13.0)
              clg_energy_input_ratio_f_of_temp.setMaximumValueofx(24.0)
              clg_energy_input_ratio_f_of_temp.setMinimumValueofy(24.0)
              clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.0)

              #clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
              clg_energy_input_ratio_f_of_flow = BTAP::Resources::HVAC::Plant::add_quad_curve(model)
              clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.0)
              clg_energy_input_ratio_f_of_flow.setCoefficient2x(0.0)
              clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0)
              clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.0)
              clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.0)

              #clg_part_load_ratio = OpenStudio::Model::CurveCubic.new(model)
              clg_part_load_ratio = BTAP::Resources::HVAC::Plant::add_cubic_curve(model)
              #these coefficients are directly from NECB
              clg_part_load_ratio.setCoefficient1Constant(0.2012301)
              clg_part_load_ratio.setCoefficient2x(-0.0312175)
              clg_part_load_ratio.setCoefficient3xPOW2(1.9504979)
              clg_part_load_ratio.setCoefficient4xPOW3(-1.1205105)
              clg_part_load_ratio.setMinimumValueofx(0.0)
              clg_part_load_ratio.setMaximumValueofx(1.0)

              # NECB curve modified to take into account how PLF is used in E+, and PLF ranges (> 0.7)
              clg_part_load_ratio = BTAP::Resources::HVAC::Plant::add_cubic_curve(model)
              clg_part_load_ratio.setCoefficient1Constant(0.0277)
              clg_part_load_ratio.setCoefficient2x(4.9151)
              clg_part_load_ratio.setCoefficient3xPOW2(-8.184)
              clg_part_load_ratio.setCoefficient4xPOW3(4.2702)
              clg_part_load_ratio.setMinimumValueofx(0.7)
              clg_part_load_ratio.setMaximumValueofx(1.0)


          return OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
            always_on,
            clg_cap_f_of_temp,
            clg_cap_f_of_flow,
            clg_energy_input_ratio_f_of_temp,
            clg_energy_input_ratio_f_of_flow,
            clg_part_load_ratio);
        end

        #Create a new DX heating coil with NECB curve characteristics
        def self.add_onespeed_DX_coil_heating(model,always_on)

              htg_cap_f_of_temp = OpenStudio::Model::CurveCubic.new(model)
              htg_cap_f_of_temp.setCoefficient1Constant(0.729)
              htg_cap_f_of_temp.setCoefficient2x(0.031927)
              htg_cap_f_of_temp.setCoefficient3xPOW2(0.0001364)
              htg_cap_f_of_temp.setCoefficient4xPOW3(-0.000008748)
              htg_cap_f_of_temp.setMinimumValueofx(-20.0)
              htg_cap_f_of_temp.setMaximumValueofx(20.0)

              htg_cap_f_of_flow = OpenStudio::Model::CurveCubic.new(model)
              htg_cap_f_of_flow.setCoefficient1Constant(0.84)
              htg_cap_f_of_flow.setCoefficient2x(0.16)
              htg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
              htg_cap_f_of_flow.setCoefficient4xPOW3(0.0)
              htg_cap_f_of_flow.setMinimumValueofx(0.5)
              htg_cap_f_of_flow.setMaximumValueofx(1.5)

              htg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveCubic.new(model)
              htg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.2183)
              htg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.036117)
              htg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.0014204)
              htg_energy_input_ratio_f_of_temp.setCoefficient4xPOW3(-0.000026827)
              htg_energy_input_ratio_f_of_temp.setMinimumValueofx(-20.0)
              htg_energy_input_ratio_f_of_temp.setMaximumValueofx(20.0)

              htg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
              htg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.3824)
              htg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.4336)
              htg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0512)
              htg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.0)
              htg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.0)

              htg_part_load_fraction = OpenStudio::Model::CurveCubic.new(model)
              htg_part_load_fraction.setCoefficient1Constant(0.3696)
              htg_part_load_fraction.setCoefficient2x(2.3362)
              htg_part_load_fraction.setCoefficient3xPOW2(-2.9577)
              htg_part_load_fraction.setCoefficient4xPOW3(1.2596)
              htg_part_load_fraction.setMinimumValueofx(0.7)
              htg_part_load_fraction.setMaximumValueofx(1.0)

              return OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model,
                always_on,
                htg_cap_f_of_temp,
                htg_cap_f_of_flow,
                htg_energy_input_ratio_f_of_temp,
                htg_energy_input_ratio_f_of_flow,
                htg_part_load_fraction)
        end
 
        #Create a new outdoor air controller
        def self.add_oa_controller(model)
          return OpenStudio::Model::ControllerOutdoorAir.new(model);
        end

        #Create a new HVAC air loop outdoor air system
        def self.add_OA_system(model,oa_controller)
          return OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model,oa_controller);
        end

        #Create a new single zone reheat setpoint manager
        def self.add_sz_reheat_setpoint(model)
          return OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model);
        end

        # Create a scheduled setpoint manager
        def self.add_sched_setpoint_mgr(model,temp_sched)
          return OpenStudio::Model::SetpointManagerScheduled.new(model,temp_sched)
        end
        

        #Create a heat recovery ventilator; this differs from add_erv in that it does not set hrv parameters
        def self.add_hrv(model)
          return OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(model);
        end

        #Create a new hot water boiler; this differs from add_boiler_hot_water_to_water_loop in that it does not set
        #boiler parameters (eg. fuel source) and does not connect it to a water loop
        def self.add_hw_boiler(model)
          return OpenStudio::Model::BoilerHotWater.new(model);
        end

        #Create a new outdoor air reset setpoint manager
        def self.add_oareset_setpoint_mgr(model)
          return OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model);
        end

        #Create a new hot water baseboard coil
        def self.add_hw_baseboard_coil(model)
          return OpenStudio::Model::CoilHeatingWaterBaseboard.new(model);
        end

        #Create a new diffuser
        def self.add_diffuser(model, avail_sched)
          return OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model,avail_sched);
        end

        #Create a constant speed pump. This differs from add_pump_constant_speed in that it
        #does not connect the pump to the water loop
        def self.add_pump_const_speed(model)
          return OpenStudio::Model::PumpConstantSpeed.new(model);
        end

        #Create a variable speed pump. This differs from add_pump_variable_speed in that it
        #does not connect the pump to the water loop
        def self.add_pump_var_speed(model)
          return OpenStudio::Model::PumpVariableSpeed.new(model);
        end

        # Create new adiabatic pipe
        def self.add_adiabatic_pipe(model)
          return OpenStudio::Model::PipeAdiabatic.new(model);
        end
        
        # Create a new electric heating coil
        def self.add_elec_heating_coil(model, avail_sched)
          return OpenStudio::Model::CoilHeatingElectric.new(model,avail_sched)
        end

        # Create a direct-fired gas heating coil
        def self.add_gas_heating_coil(model,avail_sched)
          return OpenStudio::Model::CoilHeatingGas.new(model,avail_sched)
        end

        # Create an electric baseboard
        def self.add_elec_baseboard(model)
          return OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(model)
        end

        # Create an electric chiller. This differs from add_chiller_electric_eir_to_water_loop in
        # that it does not connect the chiller to a water loop
        def self.add_elec_chiller(model,clg_cap_f_of_temp,
              eir_f_of_avail_to_nom_cap,
              eir_f_of_plr)
          return OpenStudio::Model::ChillerElectricEIR.new(model,clg_cap_f_of_temp,
              eir_f_of_avail_to_nom_cap,
              eir_f_of_plr)
        end

        # Create a one speed cooling tower. This routine does not attach cooling tower
        # to condenser loop
        def self.add_1speed_cooling_tower(model)
          return OpenStudio::Model::CoolingTowerSingleSpeed.new(model)
        end

        # Create a hydronic cooling coil
        def self.add_hydronic_cool_coil(model,avail_sched)
          return OpenStudio::Model::CoilCoolingWater.new(model,avail_sched)
        end
        
        #Adds an ERV to an airloop. Returns false if not possible.
        def self.add_erv(
            model,
            air_loop,
            autosizeNominalSupplyAirFlowRate = true,
            setNominalSupplyAirFlowRate = nil,
            setHeatExchangerType = 'Plate', # 'Rotary' or 'Plate'
            setSensibleEffectivenessat100CoolingAirFlow = 0.76,
            setSensibleEffectivenessat75CoolingAirFlow  = 0.81,
            setLatentEffectiveness100Cooling = 0.68,
            setLatentEffectiveness75Cooling = 0.73,
            setSensibleEffectiveness100Heating = 0.76,
            setSensibleEffectiveness75Heating = 0.81,
            setLatentEffectiveness100Heating = 0.68,
            setLatentEffectiveness75Heating = 0.73,
            setSupplyAirOutletTemperatureControl = true,
            setFrostControlType = 'None', # 'None', 'ExhaustAirRecirculation','ExhaustOnly','MinimumExhaustTemperature'
            setThresholdTemperature  = 1.7,
            setInitialDefrostTimeFraction = 0.0,
            nominal_electric_power = 0.0,
            setEconomizerLockout = true
          )

          #Check to see if ERV can be applied. If there is no OA system, return false.
          oa_system = nil
          air_loop.supplyComponents.each do |supply_component|
            oa_system = supply_component.to_AirLoopHVACOutdoorAirSystem.get unless supply_component.to_AirLoopHVACOutdoorAirSystem.empty?
          end
          return false if oa_system.nil?

          #Check to see if there is already an ERV.
          erv = nil
          air_loop.supplyComponents.each do |supply_component|
            erv = supply_component.to_HeatExchangerAirToAirSensibleAndLatent.get unless supply_component.to_HeatExchangerAirToAirSensibleAndLatent.empty?
          end
          #if no HRV, create one.
          if erv.nil?
            erv = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(model)
            oa_node = oa_system.outboardOANode
            erv.addToNode(oa_node.get)
          end
          erv.setNominalSupplyAirFlowRate == setNominalSupplyAirFlowRate unless setNominalSupplyAirFlowRate.nil?
          erv.autosizeNominalSupplyAirFlowRate() if  autosizeNominalSupplyAirFlowRate == true
          raise("setHeatExchangerType for erv not correct") unless erv.setHeatExchangerType(setHeatExchangerType)
          raise("setSensibleEffectivenessat100CoolingAirFlow for erv not correct")  unless  erv.setSensibleEffectivenessat100CoolingAirFlow(setSensibleEffectivenessat100CoolingAirFlow)
          raise("setSensibleEffectivenessat75CoolingAirFlow for erv not correct")  unless  erv.setSensibleEffectivenessat75CoolingAirFlow(setSensibleEffectivenessat75CoolingAirFlow)
          raise("setLatentEffectivenessat100CoolingAirFlow for erv not correct")  unless  erv.setLatentEffectivenessat100CoolingAirFlow(setLatentEffectiveness100Cooling)
          raise("setLatentEffectivenessat75CoolingAirFlow for erv not correct")  unless  erv.setLatentEffectivenessat75CoolingAirFlow(setLatentEffectiveness75Cooling)
          raise("setSensibleEffectivenessat100HeatingAirFlow for erv not correct") unless  erv.setSensibleEffectivenessat100HeatingAirFlow(setSensibleEffectiveness100Heating)
          raise("setSensibleEffectivenessat75HeatingAirFlow for erv not correct")  unless  erv.setSensibleEffectivenessat75HeatingAirFlow(setSensibleEffectiveness75Heating)
          raise("setLatentEffectivenessat100HeatingAirFlow for erv not correct")  unless  erv.setLatentEffectivenessat100HeatingAirFlow(setLatentEffectiveness100Heating)
          raise("setLatentEffectivenessat75HeatingAirFlow for erv not correct") unless  erv.setLatentEffectivenessat75HeatingAirFlow(setLatentEffectiveness75Heating)
          setEconomizerLockout.to_bool ? erv.setString(23, "Yes") : erv.setString(23, "No")
          setSupplyAirOutletTemperatureControl.to_bool ? erv.setString(17, "Yes") : erv.setString(17, "No")
          raise("setFrostControlType for erv not correct")  unless   erv.setFrostControlType(setFrostControlType)
          raise("setInitialDefrostTimeFraction for erv not correct") unless   erv.setInitialDefrostTimeFraction(setInitialDefrostTimeFraction.to_f)
          raise("setNominalElectricPower for erv not correct")  unless   erv.setNominalElectricPower(nominal_electric_power)

        # Temporary solution, may need to fix later. 12/22/2013 Da
        #erv.setEconomizerLockout('Yes')
        #erv.setEconomizerLockout(true)
        #erv.setString(23, "Yes")

        #erv.setSupplyAirOutletTemperatureControl ('No')
        #erv.setSupplyAirOutletTemperatureControl (false)
        #erv.setString(17, "No")

        return erv
      end
      def self.add_economizer(
          model,
            air_loop,
            setEconomizerControlType = "FixedDryBulb",
            setEconomizerControlActionType = "ModulateFlow",
            setEconomizerMaximumLimitDryBulbTemperature = 28.0,
            setEconomizerMaximumLimitEnthalpy = 64000,
            setEconomizerMaximumLimitDewpointTemperature = 0.0,
            setEconomizerMinimumLimitDryBulbTemperature = -100.0
          )
          #Check to see if ERV can be applied. If there is no OA system, return false.
          oa_system = nil
          air_loop.supplyComponents.each do |supply_component|
            oa_system = supply_component.to_AirLoopHVACOutdoorAirSystem.get unless supply_component.to_AirLoopHVACOutdoorAirSystem.empty?
          end
          return false if oa_system.nil?
          #get ControllerOutdoorAir
          controller_oa = oa_system.getControllerOutdoorAir


          #set economizer to the requested control type
          controller_oa.setEconomizerControlType(setEconomizerControlType)

          #set economizer to control action type. Either "ModulateFlow" or "MinimumFlowWithBypass"
          controller_oa.setEconomizerControlActionType(setEconomizerControlActionType)

          #set maximum limit drybulb temperature
          controller_oa.setEconomizerMaximumLimitDryBulbTemperature(setEconomizerMaximumLimitDryBulbTemperature)

          #set maximum limit enthalpy
          controller_oa.setEconomizerMaximumLimitEnthalpy(setEconomizerMaximumLimitEnthalpy)

          #set maximum limit dewpoint temperature
          controller_oa.setEconomizerMaximumLimitDewpointTemperature(setEconomizerMaximumLimitDewpointTemperature)

          #set minimum limit drybulb temperature
          controller_oa.setEconomizerMinimumLimitDryBulbTemperature(setEconomizerMinimumLimitDryBulbTemperature)
          return controller_oa
        end


      end


      module ZoneEquipment


        #Test Plant Module
        if __FILE__ == $0
          require 'test/unit'
          class ZoneEquipmentTests < Test::Unit::TestCase

            def test_add_unit_heater()
              #create model
              model = OpenStudio::Model::Model.new()
              #Create hot water loop
              water_loop = BTAP::Resources::HVAC::Plant::add_water_loop(model)
              #Create a CV pump
              BTAP::Resources::HVAC::Plant::add_pump_constant_speed(model, water_loop)
              #Create boiler and add to loop
              BTAP::Resources::HVAC::Plant::add_boiler_hot_water_to_water_loop(model, water_loop, "NaturalGas")

              #Create cold water loop
              cold_water_loop = BTAP::Resources::HVAC::Plant::add_water_loop(model)
              #Create a CV pump
              BTAP::Resources::HVAC::Plant::add_pump_constant_speed(model, cold_water_loop)
              #Create boiler and add to loop
              BTAP::Resources::HVAC::Plant::add_chiller_electric_eir_to_water_loop(model,cold_water_loop )


              #create geometry and spaces
              BTAP::Geometry::Wizards::create_shape_rectangle(model)
              #For each space.
              model.getSpaces.each do |space|
                #create zone
                zone = BTAP::Geometry::Zones::create_thermal_zone(model, space)
                #assign electric unit heater
                BTAP::Resources::HVAC::ZoneEquipment::add_unit_heater(model, zone, "NaturalGas","CV")
                BTAP::Resources::HVAC::ZoneEquipment::add_unit_heater(model, zone, "Electric","CV")
                BTAP::Resources::HVAC::ZoneEquipment::add_unit_heater(model, zone, "Hotwater","CV", water_loop)
                BTAP::Resources::HVAC::ZoneEquipment::add_unit_heater(model, zone, "NaturalGas","VAV")
                BTAP::Resources::HVAC::ZoneEquipment::add_unit_heater(model, zone, "Electric","VAV")
                BTAP::Resources::HVAC::ZoneEquipment::add_unit_heater(model, zone, "Hotwater","VAV", water_loop)
                BTAP::Resources::HVAC::ZoneEquipment::add_low_temp_radiant_electric(model,zone)
                BTAP::Resources::HVAC::ZoneEquipment::add_low_temp_radiant_var_flow(model,zone,water_loop, cold_water_loop)
                BTAP::Resources::HVAC::ZoneEquipment::add_low_temp_radiant_constant_flow(model,zone,water_loop,cold_water_loop)
                BTAP::Resources::HVAC::ZoneEquipment::add_ptac(model,zone,water_loop)
                BTAP::Resources::HVAC::ZoneEquipment::add_water_to_air_heat_pump(model,zone,"naturalgas",water_loop, cold_water_loop)
                BTAP::Resources::HVAC::ZoneEquipment::add_water_to_air_heat_pump(model,zone,"electric",water_loop, cold_water_loop)
                BTAP::Resources::HVAC::ZoneEquipment::add_water_to_air_heat_pump(model,zone,"hotwater",water_loop, cold_water_loop, water_loop)
                BTAP::Resources::HVAC::ZoneEquipment::add_pthp(model,zone)
                BTAP::Resources::HVAC::ZoneEquipment::add_four_pipe_fan_coil(model,zone,water_loop,cold_water_loop)
                BTAP::Resources::HVAC::ZoneEquipment::add_baseboard_convective_water(model,zone,water_loop)
                BTAP::Resources::HVAC::ZoneEquipment::add_baseboard_convective_electric(model,zone)
              end
              BTAP::FileIO::save_osm(model, BTAP::TESTING_FOLDER + "/unitheater2.osm")
            end

          end
        end # End Test ZoneEquipment

        def self.add_ideal_air_loads(model,zone)
          zone.setUseIdealAirLoads(true)
        end



        def self.add_low_temp_radiant_electric(model,zone)
          equipment = BTAP::OpenStudioLibrary.instance.library.getZoneHVACLowTemperatureRadiantElectricByName("Low Temperature Radiant Electric").get
          equipment = equipment.clone(model).to_ZoneHVACLowTemperatureRadiantElectric.get
          equipment.addToThermalZone(zone)
          return equipment
        end

        def self.add_low_temp_radiant_var_flow(model,zone,hot_water_loop,cold_water_loop)
          equipment = BTAP::OpenStudioLibrary.instance.library.getZoneHVACLowTempRadiantVarFlowByName("Low Temp Radiant Var Flow").get
          equipment = equipment.clone(model).to_ZoneHVACLowTempRadiantVarFlow.get
          equipment.addToThermalZone(zone)
          hot_water_loop.addDemandBranchForComponent(equipment.heatingCoil()) unless hot_water_loop.to_PlantLoop.empty?
          cold_water_loop.addDemandBranchForComponent(equipment.coolingCoil()) unless cold_water_loop.to_PlantLoop.empty?
          return equipment
        end

        def self.add_low_temp_radiant_constant_flow(model,zone,hot_water_loop,cold_water_loop)
          equipment = BTAP::OpenStudioLibrary.instance.library.getZoneHVACLowTempRadiantConstFlowByName("Low Temp Radiant Const Flow").get
          equipment = equipment.clone(model).to_ZoneHVACLowTempRadiantConstFlow.get
          equipment.addToThermalZone(zone)
          hot_water_loop.addDemandBranchForComponent(equipment.heatingCoil()) unless hot_water_loop.to_PlantLoop.empty?
          cold_water_loop.addDemandBranchForComponent(equipment.coolingCoil()) unless cold_water_loop.to_PlantLoop.empty?
          return equipment
        end

        def self.add_four_pipe_fan_coil(model,zone,hot_water_loop,cold_water_loop)
          equipment = BTAP::OpenStudioLibrary.instance.library.getZoneHVACFourPipeFanCoilByName("Zone HVAC Four Pipe Fan Coil 1").get
          equipment = equipment.clone(model).to_ZoneHVACFourPipeFanCoil.get
          equipment.addToThermalZone(zone)
          hot_water_loop.addDemandBranchForComponent(equipment.heatingCoil()) unless hot_water_loop.to_PlantLoop.empty?
          cold_water_loop.addDemandBranchForComponent(equipment.coolingCoil()) unless cold_water_loop.to_PlantLoop.empty?
          return equipment
        end

        def self.add_zoneHVAC_fpfc(model,avail_sched,supply_fan,cool_coil,htg_coil)
          return OpenStudio::Model::ZoneHVACFourPipeFanCoil.new(model,avail_sched,supply_fan,cool_coil,htg_coil)
        end

        def self.add_pthp(model,zone)
          equipment = BTAP::OpenStudioLibrary.instance.library.getZoneHVACPackagedTerminalHeatPumpByName("OS:ZoneHVAC:PackagedTerminalHeatPump 1").get
          equipment = equipment.clone(model).to_ZoneHVACPackagedTerminalHeatPump.get
          equipment.addToThermalZone(zone)
          return equipment
        end

        def self.add_ptac(model,zone,hot_water_loop)
          equipment = BTAP::OpenStudioLibrary.instance.library.getZoneHVACPackagedTerminalAirConditionerByName("OS:ZoneHVAC:PackagedTerminalAirConditioner 1").get
          equipment = equipment.clone(model).to_ZoneHVACPackagedTerminalAirConditioner.get
          equipment.addToThermalZone(zone)
          hot_water_loop.addDemandBranchForComponent(equipment.heatingCoil()) unless hot_water_loop.to_PlantLoop.empty?
          return equipment
        end

        def self.add_baseboard_convective_water(model,zone,hot_water_loop)
          equipment = BTAP::OpenStudioLibrary.instance.library.getZoneHVACBaseboardConvectiveWaterByName("Convective Baseboard Water").get
          equipment = equipment.clone(model).to_ZoneHVACBaseboardConvectiveWater.get
          equipment.addToThermalZone(zone)
          hot_water_loop.addDemandBranchForComponent(equipment.heatingCoil()) unless hot_water_loop.to_PlantLoop.empty?
          return equipment
        end

        def self.add_zone_baseboard_convective_water(model,avail_sched,baseboard_coil)
          return OpenStudio::Model::ZoneHVACBaseboardConvectiveWater.new(model,avail_sched,baseboard_coil);
        end

        def self.add_baseboard_convective_electric(model,zone)
          equipment = BTAP::OpenStudioLibrary.instance.library.getZoneHVACBaseboardConvectiveElectricByName("Zone HVAC Baseboard Convective Electric 1").get
          equipment = equipment.clone(model).to_ZoneHVACBaseboardConvectiveElectric.get
          equipment.addToThermalZone(zone)
          return equipment
        end


        def self.add_low_temp_radiant_var_flow(model,zone,hot_water_loop,cold_water_loop)
          equipment = BTAP::OpenStudioLibrary.instance.library.getZoneHVACLowTempRadiantVarFlowByName("Low Temp Radiant Var Flow").get
          equipment = equipment.clone(model).to_ZoneHVACLowTempRadiantVarFlow.get
          equipment.addToThermalZone(zone)
          hot_water_loop.addDemandBranchForComponent(equipment.heatingCoil()) unless hot_water_loop.to_PlantLoop.empty?
          cold_water_loop.addDemandBranchForComponent(equipment.coolingCoil()) unless cold_water_loop.to_PlantLoop.empty?
          return equipment
        end

        def self.add_water_to_air_heat_pump(model,zone,backup_source = "naturalgas",hp_hot_water_loop = nil,hp_cold_water_loop = nil,hot_water_backup_loop = nil)
          backup_source = backup_source.downcase
          valid_heat_sources = ["electric","naturalgas","hotwater"]
          raise("Backup Heat Source #{backup_source} is invalid. please use #{valid_heat_sources}. ") unless valid_heat_sources.include?(backup_source)
          lib_name = ""
          lib_name = "Water To Air Heat Pump w Gas Supplemental Coil" if backup_source == "naturalgas"
          lib_name = "Water to Air Heat Pump w Hot Water Supplemental Coil"  if backup_source == "hotwater"
          lib_name = "Water To Air HP w Elec Supplemental Coil"  if backup_source == "electric"
          equipment = BTAP::OpenStudioLibrary.instance.library.getZoneHVACWaterToAirHeatPumpByName(lib_name).get
          equipment = equipment.clone(model).to_ZoneHVACWaterToAirHeatPump.get
          equipment.addToThermalZone(zone)
          hp_hot_water_loop.addDemandBranchForComponent(equipment.heatingCoil()) unless hp_hot_water_loop.nil? or hp_hot_water_loop.to_PlantLoop.empty?
          hp_cold_water_loop.addDemandBranchForComponent(equipment.coolingCoil()) unless hp_hot_water_loop.nil? or hp_cold_water_loop.to_PlantLoop.empty?
          hot_water_backup_loop.addDemandBranchForComponent(equipment.supplementalHeatingCoil()) unless hot_water_backup_loop.nil? or hot_water_backup_loop.to_PlantLoop.empty?
        end

        def self.add_unit_heater(model,zone,heat_source="electric",fan_source = "CV",hot_water_loop = nil)
          heat_source = heat_source.downcase
          fan_source = fan_source.downcase
          valid_heat_sources = ["electric","naturalgas","hotwater"]
          raise("Heat source #{heat_source} is invalid. please use #{valid_heat_sources}. ") unless valid_heat_sources.include?(heat_source)
          valid_fan_sources = ["vav","cv"]
          raise("Fan source #{fan_source} is invalid. please use a valid fan source name...#{valid_fan_sources}. ") unless valid_fan_sources.include?(fan_source)
          lib_name = ""
          if heat_source.downcase == "electric"
            if fan_source == "cv"
              lib_name = "Unit Heater CV - Electric"
            elsif fan_source == "vav"
              lib_name = "Unit Heater VAV - Electric"
            end
          elsif heat_source.downcase == "naturalgas"
            if fan_source == "cv"
              lib_name = "Unit Heater CV - Gas"
            elsif fan_source == "vav"
              lib_name = "Unit Heater VAV - Gas"
            end
          elsif heat_source.downcase == "hotwater"
            if fan_source == "cv"
              lib_name = "Unit Heater CV - Hot Water"
            elsif fan_source == "vav"
              lib_name = "Unit Heater VAV - Hot Water"
            end
          end
          unit_heater = BTAP::OpenStudioLibrary.instance.library.getZoneHVACUnitHeaterByName(lib_name).get
          new_unit_heater = unit_heater.clone(model).to_ZoneHVACUnitHeater.get
          new_unit_heater.addToThermalZone(zone);
          hot_water_loop.addDemandBranchForComponent(new_unit_heater.heatingCoil()) unless hot_water_loop.nil? or hot_water_loop.to_PlantLoop.empty?
          return unit_heater
        end
      end



      module HVACTemplates
        module OS

          def self.add_rooftop_vav_with_reheat( model, zones = [] )
            airloop = OpenStudio::Model::addSystemType3(model).to_AirLoopHVAC.get
            zones.each { |zone| airloop.addBranchForZone(zone) }
            return airloop
          end

          def self.add_rooftop_hp(model, zones = [] )
            airloop = OpenStudio::Model::addSystemType4(model).to_AirLoopHVAC.get
            zones.each { |zone| airloop.addBranchForZone(zone) }
          end

          def self.add_rooftop_vav_with_reheat(model, zones = [] )
            airloop = OpenStudio::Model::addSystemType5(model).to_AirLoopHVAC.get
            zones.each { |zone| airloop.addBranchForZone(zone) }
            return airloop
          end

          def self.add_packaged_rooftop_vav_with_pfp_boxes_and_reheat(model,zones = [])
            airloop = OpenStudio::Model::addSystemType6(model).to_AirLoopHVAC.get
            zones.each { |zone| airloop.addBranchForZone(zone) }
            return airloop
          end

          def self.add_vav_with_reheat(model,zones = [])
            airloop = OpenStudio::Model::addSystemType7(model).to_AirLoopHVAC.get
            zones.each { |zone| airloop.addBranchForZone(zone) }
            return airloop
          end

          def self.add_vav_with_pfp_boxes_and_reheat(model,zones = [])
            airloop = OpenStudio::Model::addSystemType8(model).to_AirLoopHVAC.get
            zones.each { |zone| airloop.addBranchForZone(zone) }
            return airloop
          end

          def self.add_gas_fired_furnace(model,zones = [])
            airloop = OpenStudio::Model::addSystemType9(model).to_AirLoopHVAC.get
            zones.each { |zone| airloop.addBranchForZone(zone) }
            return airloop
          end

          def self.add_electric_furnace(model,zones = [])
            airloop = OpenStudio::Model::addSystemType10(model).to_AirLoopHVAC.get
            zones.each { |zone| airloop.addBranchForZone(zone) }
            return airloop
          end
        end #OpenStudio
        module ASHRAE90_1
          #These methods are works in progresss from Andrew Parker at NREL.
          def self.addSys1PTACResidential(model)
            # System Type 1: PTAC, Residential
            # This measure creates:
            # a single hot water loop with natural gas boiler for the building
            # a constant volume packaged terminal A/C unit with hot water heat
            # and DX cooling for each zone in the building

            # How water loop
            hot_water_plant = OpenStudio::Model::PlantLoop.new(model)
            hot_water_plant.setName("Hot Water Loop")
            sizing_plant = hot_water_plant.sizingPlant
            sizing_plant.setLoopType("Heating")
            sizing_plant.setDesignLoopExitTemperature(82.0) # TODO units
            sizing_plant.setLoopDesignTemperatureDifference(11.0) # TODO units

            hot_water_outlet_node = hot_water_plant.supplyOutletNode
            hot_water_inlet_node = hot_water_plant.supplyInletNode

            pump = OpenStudio::Model::PumpVariableSpeed.new(model)

            boiler_htg_eff_f_of_part_load_ratio = OpenStudio::Model::CurveBiquadratic.new(model)
            boiler_htg_eff_f_of_part_load_ratio.setName("Constant Boiler Efficiency")
            boiler_htg_eff_f_of_part_load_ratio.setCoefficient1Constant(1.0)
            boiler_htg_eff_f_of_part_load_ratio.setInputUnitTypeforX("Dimensionless")
            boiler_htg_eff_f_of_part_load_ratio.setInputUnitTypeforY("Dimensionless")
            boiler_htg_eff_f_of_part_load_ratio.setOutputUnitType("Dimensionless")

            boiler = OpenStudio::Model::BoilerHotWater.new(model)
            boiler.setNormalizedBoilerEfficiencyCurve(boiler_htg_eff_f_of_part_load_ratio)
            boiler.setEfficiencyCurveTemperatureEvaluationVariable("LeavingBoiler")

            boiler_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

            hot_water_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

            # Add the equipment to the hot water plant loop
            pump.addToNode(hot_water_inlet_node)

            hot_water_plant.addSupplyBranchForComponent(boiler)

            hot_water_plant.addSupplyBranchForComponent(boiler_bypass_pipe)

            hot_water_outlet_pipe.addToNode(hot_water_outlet_node)

            # Add temperature setpoint control for the loop

            # Make the hot water schedule
            twenty_four_hrs = OpenStudio::Time.new(0,24,0,0)
            hot_water_temp = 67 # TODO units
            hot_water_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
            hot_water_temp_sch.setName("Hot Water Temp")
            hot_water_temp_schWinter = OpenStudio::Model::ScheduleDay.new(model)
            hot_water_temp_sch.setWinterDesignDaySchedule(hot_water_temp_schWinter)
            hot_water_temp_sch.winterDesignDaySchedule().setName("Hot Water Temp Winter Design Day")
            hot_water_temp_sch.winterDesignDaySchedule().addValue(twenty_four_hrs,hot_water_temp)
            hot_water_temp_schSummer = OpenStudio::Model::ScheduleDay.new(model)
            hot_water_temp_sch.setSummerDesignDaySchedule(hot_water_temp_schSummer)
            hot_water_temp_sch.summerDesignDaySchedule().setName("Hot Water Temp Summer Design Day")
            hot_water_temp_sch.summerDesignDaySchedule().addValue(twenty_four_hrs,hot_water_temp)
            hot_water_temp_sch.defaultDaySchedule().setName("Hot Water Temp Default")
            hot_water_temp_sch.defaultDaySchedule().addValue(twenty_four_hrs,hot_water_temp)

            hot_water_setpoint_manager = OpenStudio::Model::SetpointManagerScheduled.new(model,hot_water_temp_sch)

            hot_water_setpoint_manager.addToNode(hot_water_outlet_node)

            always_on = model.alwaysOnDiscreteSchedule

            # Make a PTAC with hot water heating and DX cooling for each zone
            # and connect the hot water coil to the hot water plant loop
            model.getThermalZones.each do |zone|

              fan = OpenStudio::Model::FanConstantVolume.new(model,always_on)
              fan.setPressureRise(500) #TODO units

              htg_coil = OpenStudio::Model::CoilHeatingWater.new(model,always_on)

              clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
              clg_cap_f_of_temp.setCoefficient1Constant(0.942587793)
              clg_cap_f_of_temp.setCoefficient2x(0.009543347)
              clg_cap_f_of_temp.setCoefficient3xPOW2(0.000683770)
              clg_cap_f_of_temp.setCoefficient4y(-0.011042676)
              clg_cap_f_of_temp.setCoefficient5yPOW2(0.000005249)
              clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.000009720)
              clg_cap_f_of_temp.setMinimumValueofx(17.0)
              clg_cap_f_of_temp.setMaximumValueofx(22.0)
              clg_cap_f_of_temp.setMinimumValueofy(13.0)
              clg_cap_f_of_temp.setMaximumValueofy(46.0)

              clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
              clg_cap_f_of_flow.setCoefficient1Constant(0.8)
              clg_cap_f_of_flow.setCoefficient2x(0.2)
              clg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
              clg_cap_f_of_flow.setMinimumValueofx(0.5)
              clg_cap_f_of_flow.setMaximumValueofx(1.5)

              energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
              energy_input_ratio_f_of_temp.setCoefficient1Constant(0.342414409)
              energy_input_ratio_f_of_temp.setCoefficient2x(0.034885008)
              energy_input_ratio_f_of_temp.setCoefficient3xPOW2(-0.000623700)
              energy_input_ratio_f_of_temp.setCoefficient4y(0.004977216)
              energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.000437951)
              energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.000728028)
              energy_input_ratio_f_of_temp.setMinimumValueofx(17.0)
              energy_input_ratio_f_of_temp.setMaximumValueofx(22.0)
              energy_input_ratio_f_of_temp.setMinimumValueofy(13.0)
              energy_input_ratio_f_of_temp.setMaximumValueofy(46.0)

              energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
              energy_input_ratio_f_of_flow.setCoefficient1Constant(1.1552)
              energy_input_ratio_f_of_flow.setCoefficient2x(-0.1808)
              energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0256)
              energy_input_ratio_f_of_flow.setMinimumValueofx(0.5)
              energy_input_ratio_f_of_flow.setMaximumValueofx(1.5)

              part_load_fraction = OpenStudio::Model::CurveQuadratic.new(model)
              part_load_fraction.setCoefficient1Constant(0.85)
              part_load_fraction.setCoefficient2x(0.15)
              part_load_fraction.setCoefficient3xPOW2(0.0)
              part_load_fraction.setMinimumValueofx(0.0)
              part_load_fraction.setMaximumValueofx(1.0)

              clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                always_on,
                clg_cap_f_of_temp,
                clg_cap_f_of_flow,
                energy_input_ratio_f_of_temp,
                energy_input_ratio_f_of_flow,
                part_load_fraction)

              ptac = OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner.new(model,
                always_on,
                fan,
                htg_coil,
                clg_coil)
              ptac.setName("#{zone.name} PTAC")
              ptac.addToThermalZone(zone)
              hot_water_plant.addDemandBranchForComponent(htg_coil)
            end
            return true
          end

          def self.addSys2PTHPResidential(model)

            # System Type 2: PTHP, Residential
            # This measure creates:
            # a constant volume packaged terminal heat pump unit with DX heating
            # and cooling for each zone in the building

            always_on = model.alwaysOnDiscreteSchedule

            # Make a PTHP for each zone
            model.getThermalZones.each do |zone|

              fan = OpenStudio::Model::FanConstantVolume.new(model,always_on)
              fan.setPressureRise(300)

              supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model,always_on)

              clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
              clg_cap_f_of_temp.setCoefficient1Constant(0.942587793)
              clg_cap_f_of_temp.setCoefficient2x(0.009543347)
              clg_cap_f_of_temp.setCoefficient3xPOW2(0.0018423)
              clg_cap_f_of_temp.setCoefficient4y(-0.011042676)
              clg_cap_f_of_temp.setCoefficient5yPOW2(0.000005249)
              clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.000009720)
              clg_cap_f_of_temp.setMinimumValueofx(17.0)
              clg_cap_f_of_temp.setMaximumValueofx(22.0)
              clg_cap_f_of_temp.setMinimumValueofy(13.0)
              clg_cap_f_of_temp.setMaximumValueofy(46.0)

              clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
              clg_cap_f_of_flow.setCoefficient1Constant(0.718954)
              clg_cap_f_of_flow.setCoefficient2x(0.435436)
              clg_cap_f_of_flow.setCoefficient3xPOW2(-0.154193)
              clg_cap_f_of_flow.setMinimumValueofx(0.75)
              clg_cap_f_of_flow.setMaximumValueofx(1.25)

              clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
              clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(0.342414409)
              clg_energy_input_ratio_f_of_temp.setCoefficient2x(0.034885008)
              clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(-0.000623700)
              clg_energy_input_ratio_f_of_temp.setCoefficient4y(0.004977216)
              clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.000437951)
              clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.000728028)
              clg_energy_input_ratio_f_of_temp.setMinimumValueofx(17.0)
              clg_energy_input_ratio_f_of_temp.setMaximumValueofx(22.0)
              clg_energy_input_ratio_f_of_temp.setMinimumValueofy(13.0)
              clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.0)

              clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
              clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.1552)
              clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.1808)
              clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0256)
              clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.5)
              clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.5)

              clg_part_load_fraction = OpenStudio::Model::CurveQuadratic.new(model)
              clg_part_load_fraction.setCoefficient1Constant(0.75)
              clg_part_load_fraction.setCoefficient2x(0.25)
              clg_part_load_fraction.setCoefficient3xPOW2(0.0)
              clg_part_load_fraction.setMinimumValueofx(0.0)
              clg_part_load_fraction.setMaximumValueofx(1.0)

              clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                always_on,
                clg_cap_f_of_temp,
                clg_cap_f_of_flow,
                clg_energy_input_ratio_f_of_temp,
                clg_energy_input_ratio_f_of_flow,
                clg_part_load_fraction)

              htg_cap_f_of_temp = OpenStudio::Model::CurveCubic.new(model)
              htg_cap_f_of_temp.setCoefficient1Constant(0.758746)
              htg_cap_f_of_temp.setCoefficient2x(0.027626)
              htg_cap_f_of_temp.setCoefficient3xPOW2(0.000148716)
              htg_cap_f_of_temp.setCoefficient4xPOW3(0.0000034992)
              htg_cap_f_of_temp.setMinimumValueofx(-20.0)
              htg_cap_f_of_temp.setMaximumValueofx(20.0)

              htg_cap_f_of_flow = OpenStudio::Model::CurveCubic.new(model)
              htg_cap_f_of_flow.setCoefficient1Constant(0.84)
              htg_cap_f_of_flow.setCoefficient2x(0.16)
              htg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
              htg_cap_f_of_flow.setCoefficient4xPOW3(0.0)
              htg_cap_f_of_flow.setMinimumValueofx(0.5)
              htg_cap_f_of_flow.setMaximumValueofx(1.5)

              htg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveCubic.new(model)
              htg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.19248)
              htg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.0300438)
              htg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00103745)
              htg_energy_input_ratio_f_of_temp.setCoefficient4xPOW3(-0.000023328)
              htg_energy_input_ratio_f_of_temp.setMinimumValueofx(-20.0)
              htg_energy_input_ratio_f_of_temp.setMaximumValueofx(20.0)

              htg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
              htg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.3824)
              htg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.4336)
              htg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0512)
              htg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.0)
              htg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.0)

              htg_part_load_fraction = OpenStudio::Model::CurveQuadratic.new(model)
              htg_part_load_fraction.setCoefficient1Constant(0.75)
              htg_part_load_fraction.setCoefficient2x(0.25)
              htg_part_load_fraction.setCoefficient3xPOW2(0.0)
              htg_part_load_fraction.setMinimumValueofx(0.0)
              htg_part_load_fraction.setMaximumValueofx(1.0)

              htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new( model,
                always_on,
                htg_cap_f_of_temp,
                htg_cap_f_of_flow,
                htg_energy_input_ratio_f_of_temp,
                htg_energy_input_ratio_f_of_flow,
                htg_part_load_fraction )

              pthp = OpenStudio::Model::ZoneHVACPackagedTerminalHeatPump.new(model,
                always_on,
                fan,
                htg_coil,
                clg_coil,
                supplemental_htg_coil)

              pthp.setName("#{zone.name} PTHP")
              pthp.addToThermalZone(zone)

            end


            return true

          end

          def self.addSys3PSZAC(model)

            # System Type 3: PSZ-AC
            # This measure creates:
            # a constant volume packaged single-zone A/C unit with gas heat
            # and DX cooling for each zone in the building

            always_on = model.alwaysOnDiscreteSchedule

            # Make a PSZ-AC for each zone
            model.getThermalZones.each do |zone|

              air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
              air_loop.setName("#{zone.name} Packaged Rooftop Air Conditioner")

              # When an air_loop is contructed, its constructor creates a sizing:system object
              # the default sizing:system contstructor makes a system:sizing object
              # appropriate for a multizone VAV system
              # this systems is a constant volume system with no VAV terminals,
              # and therfore needs different default settings
              air_loop_sizing = air_loop.sizingSystem # TODO units
              air_loop_sizing.setTypeofLoadtoSizeOn("Sensible")
              air_loop_sizing.autosizeDesignOutdoorAirFlowRate
              air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
              air_loop_sizing.setPreheatDesignTemperature(7.0)
              air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
              air_loop_sizing.setPrecoolDesignTemperature(12.8)
              air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
              air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(12.8)
              air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(40.0)
              air_loop_sizing.setSizingOption("NonCoincident")
              air_loop_sizing.setAllOutdoorAirinCooling(false)
              air_loop_sizing.setAllOutdoorAirinHeating(false)
              air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
              air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
              air_loop_sizing.setCoolingDesignAirFlowMethod("DesignDay")
              air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
              air_loop_sizing.setHeatingDesignAirFlowMethod("DesignDay")
              air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
              air_loop_sizing.setSystemOutdoorAirMethod("ZoneSum")

              fan = OpenStudio::Model::FanConstantVolume.new(model,always_on)
              fan.setPressureRise(500)

              htg_coil = OpenStudio::Model::CoilHeatingGas.new(model,always_on)

              clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
              clg_cap_f_of_temp.setCoefficient1Constant(0.42415)
              clg_cap_f_of_temp.setCoefficient2x(0.04426)
              clg_cap_f_of_temp.setCoefficient3xPOW2(-0.00042)
              clg_cap_f_of_temp.setCoefficient4y(0.00333)
              clg_cap_f_of_temp.setCoefficient5yPOW2(-0.00008)
              clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.00021)
              clg_cap_f_of_temp.setMinimumValueofx(17.0)
              clg_cap_f_of_temp.setMaximumValueofx(22.0)
              clg_cap_f_of_temp.setMinimumValueofy(13.0)
              clg_cap_f_of_temp.setMaximumValueofy(46.0)

              clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
              clg_cap_f_of_flow.setCoefficient1Constant(0.77136)
              clg_cap_f_of_flow.setCoefficient2x(0.34053)
              clg_cap_f_of_flow.setCoefficient3xPOW2(-0.11088)
              clg_cap_f_of_flow.setMinimumValueofx(0.75918)
              clg_cap_f_of_flow.setMaximumValueofx(1.13877)

              clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
              clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.23649)
              clg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.02431)
              clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00057)
              clg_energy_input_ratio_f_of_temp.setCoefficient4y(-0.01434)
              clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.00063)
              clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.00038)
              clg_energy_input_ratio_f_of_temp.setMinimumValueofx(17.0)
              clg_energy_input_ratio_f_of_temp.setMaximumValueofx(22.0)
              clg_energy_input_ratio_f_of_temp.setMinimumValueofy(13.0)
              clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.0)

              clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
              clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.20550)
              clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.32953)
              clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.12308)
              clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.75918)
              clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.13877)

              clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(model)
              clg_part_load_ratio.setCoefficient1Constant(0.77100)
              clg_part_load_ratio.setCoefficient2x(0.22900)
              clg_part_load_ratio.setCoefficient3xPOW2(0.0)
              clg_part_load_ratio.setMinimumValueofx(0.0)
              clg_part_load_ratio.setMaximumValueofx(1.0)

              clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                always_on,
                clg_cap_f_of_temp,
                clg_cap_f_of_flow,
                clg_energy_input_ratio_f_of_temp,
                clg_energy_input_ratio_f_of_flow,
                clg_part_load_ratio)

              oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)

              oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model,oa_controller)

              # Add the components to the air loop
              # in order from closest to zone to furthest from zone
              supply_inlet_node = air_loop.supplyInletNode
              fan.addToNode(supply_inlet_node)
              htg_coil.addToNode(supply_inlet_node)
              clg_coil.addToNode(supply_inlet_node)
              oa_system.addToNode(supply_inlet_node)

              # Add a setpoint manager single zone reheat to control the
              # supply air temperature based on the needs of this zone
              setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
              setpoint_mgr_single_zone_reheat.setControlZone(zone)
              setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)

              # Create a diffuser and attach the zone/diffuser pair to the air loop
              diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model,always_on)
              air_loop.addBranchForZone(zone,diffuser.to_StraightComponent)

            end


            return true
          end

          def self.addSys4PSZHP(model)

            # System Type 4: PSZ-HP
            # This measure creates:
            # a constant volume packaged single-zone heat pump unit with DX heating
            # and cooling and electric resistance supplemental/backup heating
            # for each zone in the building

            always_on = model.alwaysOnDiscreteSchedule

            # Make a PSZ-HP for each zone
            model.getThermalZones.each do |zone|

              air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
              air_loop.setName("Packaged Rooftop Heat Pump")

              # When an air_loop is contructed, its constructor creates a sizing:system object
              # the default sizing:system contstructor makes a system:sizing object
              # appropriate for a multizone VAV system
              # this systems is a constant volume system with no VAV terminals,
              # and therfore needs different default settings
              air_loop_sizing = air_loop.sizingSystem
              air_loop_sizing.setTypeofLoadtoSizeOn("Sensible")
              air_loop_sizing.autosizeDesignOutdoorAirFlowRate
              air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
              air_loop_sizing.setPreheatDesignTemperature(7.0)
              air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
              air_loop_sizing.setPrecoolDesignTemperature(12.8)
              air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
              air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(12.8)
              air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(40.0)
              air_loop_sizing.setSizingOption("NonCoincident")
              air_loop_sizing.setAllOutdoorAirinCooling(false)
              air_loop_sizing.setAllOutdoorAirinHeating(false)
              air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
              air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
              air_loop_sizing.setCoolingDesignAirFlowMethod("DesignDay")
              air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
              air_loop_sizing.setHeatingDesignAirFlowMethod("DesignDay")
              air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
              air_loop_sizing.setSystemOutdoorAirMethod("ZoneSum")

              fan = OpenStudio::Model::FanConstantVolume.new(model,always_on)
              fan.setPressureRise(500)

              clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
              clg_cap_f_of_temp.setCoefficient1Constant(0.766956)
              clg_cap_f_of_temp.setCoefficient2x(0.0107756)
              clg_cap_f_of_temp.setCoefficient3xPOW2(-0.0000414703)
              clg_cap_f_of_temp.setCoefficient4y(0.00134961)
              clg_cap_f_of_temp.setCoefficient5yPOW2(-0.000261144)
              clg_cap_f_of_temp.setCoefficient6xTIMESY(0.000457488)
              clg_cap_f_of_temp.setMinimumValueofx(17.0)
              clg_cap_f_of_temp.setMaximumValueofx(22.0)
              clg_cap_f_of_temp.setMinimumValueofy(13.0)
              clg_cap_f_of_temp.setMaximumValueofy(46.0)

              clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
              clg_cap_f_of_flow.setCoefficient1Constant(0.8)
              clg_cap_f_of_flow.setCoefficient2x(0.2)
              clg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
              clg_cap_f_of_flow.setMinimumValueofx(0.5)
              clg_cap_f_of_flow.setMaximumValueofx(1.5)

              clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
              clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(0.297145)
              clg_energy_input_ratio_f_of_temp.setCoefficient2x(0.0430933)
              clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(-0.000748766)
              clg_energy_input_ratio_f_of_temp.setCoefficient4y(0.00597727)
              clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.000482112)
              clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.000956448)
              clg_energy_input_ratio_f_of_temp.setMinimumValueofx(17.0)
              clg_energy_input_ratio_f_of_temp.setMaximumValueofx(22.0)
              clg_energy_input_ratio_f_of_temp.setMinimumValueofy(13.0)
              clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.0)

              clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
              clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.156)
              clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.1816)
              clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0256)
              clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.5)
              clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.5)

              clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(model)
              clg_part_load_ratio.setCoefficient1Constant(0.75)
              clg_part_load_ratio.setCoefficient2x(0.25)
              clg_part_load_ratio.setCoefficient3xPOW2(0.0)
              clg_part_load_ratio.setMinimumValueofx(0.0)
              clg_part_load_ratio.setMaximumValueofx(1.0)

              clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                always_on,
                clg_cap_f_of_temp,
                clg_cap_f_of_flow,
                clg_energy_input_ratio_f_of_temp,
                clg_energy_input_ratio_f_of_flow,
                clg_part_load_ratio)

              htg_cap_f_of_temp = OpenStudio::Model::CurveCubic.new(model)
              htg_cap_f_of_temp.setCoefficient1Constant(0.758746)
              htg_cap_f_of_temp.setCoefficient2x(0.027626)
              htg_cap_f_of_temp.setCoefficient3xPOW2(0.000148716)
              htg_cap_f_of_temp.setCoefficient4xPOW3(0.0000034992)
              htg_cap_f_of_temp.setMinimumValueofx(-20.0)
              htg_cap_f_of_temp.setMaximumValueofx(20.0)

              htg_cap_f_of_flow = OpenStudio::Model::CurveCubic.new(model)
              htg_cap_f_of_flow.setCoefficient1Constant(0.84)
              htg_cap_f_of_flow.setCoefficient2x(0.16)
              htg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
              htg_cap_f_of_flow.setCoefficient4xPOW3(0.0)
              htg_cap_f_of_flow.setMinimumValueofx(0.5)
              htg_cap_f_of_flow.setMaximumValueofx(1.5)

              htg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveCubic.new(model)
              htg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.19248)
              htg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.0300438)
              htg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00103745)
              htg_energy_input_ratio_f_of_temp.setCoefficient4xPOW3(-0.000023328)
              htg_energy_input_ratio_f_of_temp.setMinimumValueofx(-20.0)
              htg_energy_input_ratio_f_of_temp.setMaximumValueofx(20.0)

              htg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
              htg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.3824)
              htg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.4336)
              htg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0512)
              htg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.0)
              htg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.0)

              htg_part_load_fraction = OpenStudio::Model::CurveQuadratic.new(model)
              htg_part_load_fraction.setCoefficient1Constant(0.75)
              htg_part_load_fraction.setCoefficient2x(0.25)
              htg_part_load_fraction.setCoefficient3xPOW2(0.0)
              htg_part_load_fraction.setMinimumValueofx(0.0)
              htg_part_load_fraction.setMaximumValueofx(1.0)

              htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model,
                always_on,
                htg_cap_f_of_temp,
                htg_cap_f_of_flow,
                htg_energy_input_ratio_f_of_temp,
                htg_energy_input_ratio_f_of_flow,
                htg_part_load_fraction)

              supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model,always_on)

              oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)

              oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model,oa_controller)

              # Add the components to the air loop
              # in order from closest to zone to furthest from zone
              supply_inlet_node = air_loop.supplyInletNode
              fan.addToNode(supply_inlet_node)
              supplemental_htg_coil.addToNode(supply_inlet_node)
              htg_coil.addToNode(supply_inlet_node)
              clg_coil.addToNode(supply_inlet_node)
              oa_system.addToNode(supply_inlet_node)

              # Add a setpoint manager single zone reheat to control the
              # supply air temperature based on the needs of this zone
              setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
              setpoint_mgr_single_zone_reheat.setControlZone(zone)
              setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)

              # Create a diffuser and attach the zone/diffuser pair to the air loop
              diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model,always_on)
              air_loop.addBranchForZone(zone,diffuser.to_StraightComponent)

            end


            return true
          end

          def self.addSys5PVAVR(model)

            # System Type 5: Packaged VAV w/ Reheat
            # This measure creates:
            # a single hot water loop with a natural gas boiler for the building
            # a VAV system w/ hot water heating, DX cooling, and
            # hot water reheat for each story of the building

            always_on = model.alwaysOnDiscreteSchedule

            # Hot Water Loop

            hw_loop = OpenStudio::Model::PlantLoop.new(model)
            hw_loop.setName("Hot Water Loop for Packaged Rooftop VAV with Reheat")
            sizing_plant = hw_loop.sizingPlant
            sizing_plant.setLoopType("Heating")
            sizing_plant.setDesignLoopExitTemperature(82.0) #TODO units
            sizing_plant.setLoopDesignTemperatureDifference(11.0)

            pump = OpenStudio::Model::PumpVariableSpeed.new(model)

            boiler = OpenStudio::Model::BoilerHotWater.new(model)

            boiler_eff_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
            boiler_eff_f_of_temp.setName("Boiler Efficiency")
            boiler_eff_f_of_temp.setCoefficient1Constant(1.0)
            boiler_eff_f_of_temp.setInputUnitTypeforX("Dimensionless")
            boiler_eff_f_of_temp.setInputUnitTypeforY("Dimensionless")
            boiler_eff_f_of_temp.setOutputUnitType("Dimensionless")

            boiler.setNormalizedBoilerEfficiencyCurve(boiler_eff_f_of_temp)
            boiler.setEfficiencyCurveTemperatureEvaluationVariable("LeavingBoiler")

            boiler_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

            supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

            # Add the components to the hot water loop
            hw_supply_inlet_node = hw_loop.supplyInletNode
            hw_supply_outlet_node = hw_loop.supplyOutletNode
            pump.addToNode(hw_supply_inlet_node)
            hw_loop.addSupplyBranchForComponent(boiler)
            hw_loop.addSupplyBranchForComponent(boiler_bypass_pipe)
            supply_outlet_pipe.addToNode(hw_supply_outlet_node)

            # Add a setpoint manager to control the
            # hot water to a constant temperature
            hw_t_c = OpenStudio::convert(153,"F","C").get
            hw_t_sch = OpenStudio::Model::ScheduleRuleset.new(model)
            hw_t_sch.setName("HW Temp")
            hw_t_sch.defaultDaySchedule().setName("HW Temp Default")
            hw_t_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),hw_t_c)
            hw_t_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model,hw_t_sch)
            hw_t_stpt_manager.addToNode(hw_supply_outlet_node)

            # Make a Packaged VAV w/ Reheat for each story of the building
            model.getBuildingStorys.sort.each do |story|

              air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
              air_loop.setName("#{story.name} Packaged Rooftop VAV with Reheat")
              sizingSystem = air_loop.sizingSystem
              sizingSystem.setCentralCoolingDesignSupplyAirTemperature(12.8)
              sizingSystem.setCentralHeatingDesignSupplyAirTemperature(12.8)

              fan = OpenStudio::Model::FanVariableVolume.new(model,always_on)
              fan.setPressureRise(500)

              htg_coil = OpenStudio::Model::CoilHeatingWater.new(model,always_on)
              hw_loop.addDemandBranchForComponent(htg_coil)

              clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
              clg_cap_f_of_temp.setCoefficient1Constant(0.42415)
              clg_cap_f_of_temp.setCoefficient2x(0.04426)
              clg_cap_f_of_temp.setCoefficient3xPOW2(-0.00042)
              clg_cap_f_of_temp.setCoefficient4y(0.00333)
              clg_cap_f_of_temp.setCoefficient5yPOW2(-0.00008)
              clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.00021)
              clg_cap_f_of_temp.setMinimumValueofx(17.0)
              clg_cap_f_of_temp.setMaximumValueofx(22.0)
              clg_cap_f_of_temp.setMinimumValueofy(13.0)
              clg_cap_f_of_temp.setMaximumValueofy(46.0)

              clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
              clg_cap_f_of_flow.setCoefficient1Constant(0.77136)
              clg_cap_f_of_flow.setCoefficient2x(0.34053)
              clg_cap_f_of_flow.setCoefficient3xPOW2(-0.11088)
              clg_cap_f_of_flow.setMinimumValueofx(0.75918)
              clg_cap_f_of_flow.setMaximumValueofx(1.13877)

              clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
              clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.23649)
              clg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.02431)
              clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00057)
              clg_energy_input_ratio_f_of_temp.setCoefficient4y(-0.01434)
              clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.00063)
              clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.00038)
              clg_energy_input_ratio_f_of_temp.setMinimumValueofx(17.0)
              clg_energy_input_ratio_f_of_temp.setMaximumValueofx(22.0)
              clg_energy_input_ratio_f_of_temp.setMinimumValueofy(13.0)
              clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.0)

              clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
              clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.20550)
              clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.32953)
              clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.12308)
              clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.75918)
              clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.13877)

              clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(model)
              clg_part_load_ratio.setCoefficient1Constant(0.77100)
              clg_part_load_ratio.setCoefficient2x(0.22900)
              clg_part_load_ratio.setCoefficient3xPOW2(0.0)
              clg_part_load_ratio.setMinimumValueofx(0.0)
              clg_part_load_ratio.setMaximumValueofx(1.0)

              clg_cap_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(model)
              clg_cap_f_of_temp_low_spd.setCoefficient1Constant(0.42415)
              clg_cap_f_of_temp_low_spd.setCoefficient2x(0.04426)
              clg_cap_f_of_temp_low_spd.setCoefficient3xPOW2(-0.00042)
              clg_cap_f_of_temp_low_spd.setCoefficient4y(0.00333)
              clg_cap_f_of_temp_low_spd.setCoefficient5yPOW2(-0.00008)
              clg_cap_f_of_temp_low_spd.setCoefficient6xTIMESY(-0.00021)
              clg_cap_f_of_temp_low_spd.setMinimumValueofx(17.0)
              clg_cap_f_of_temp_low_spd.setMaximumValueofx(22.0)
              clg_cap_f_of_temp_low_spd.setMinimumValueofy(13.0)
              clg_cap_f_of_temp_low_spd.setMaximumValueofy(46.0)

              clg_energy_input_ratio_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(model)
              clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient1Constant(1.23649)
              clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient2x(-0.02431)
              clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient3xPOW2(0.00057)
              clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient4y(-0.01434)
              clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient5yPOW2(0.00063)
              clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient6xTIMESY(-0.00038)
              clg_energy_input_ratio_f_of_temp_low_spd.setMinimumValueofx(17.0)
              clg_energy_input_ratio_f_of_temp_low_spd.setMaximumValueofx(22.0)
              clg_energy_input_ratio_f_of_temp_low_spd.setMinimumValueofy(13.0)
              clg_energy_input_ratio_f_of_temp_low_spd.setMaximumValueofy(46.0)

              clg_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(model,
                always_on,
                clg_cap_f_of_temp,
                clg_cap_f_of_flow,
                clg_energy_input_ratio_f_of_temp,
                clg_energy_input_ratio_f_of_flow,
                clg_part_load_ratio,
                clg_cap_f_of_temp_low_spd,
                clg_energy_input_ratio_f_of_temp_low_spd)

              clg_coil.setRatedLowSpeedSensibleHeatRatio(OpenStudio::OptionalDouble.new(0.69))
              clg_coil.setBasinHeaterCapacity(10)
              clg_coil.setBasinHeaterSetpointTemperature(2.0)

              oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)

              oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model,oa_controller)

              # Add the components to the air loop
              # in order from closest to zone to furthest from zone
              supply_inlet_node = air_loop.supplyInletNode
              supply_outlet_node = air_loop.supplyOutletNode
              fan.addToNode(supply_inlet_node)
              htg_coil.addToNode(supply_inlet_node)
              clg_coil.addToNode(supply_inlet_node)
              oa_system.addToNode(supply_inlet_node)

              # Add a setpoint manager to control the
              # supply air to a constant temperature
              sat_c = OpenStudio::convert(55,"F","C").get
              sat_sch = OpenStudio::Model::ScheduleRuleset.new(model)
              sat_sch.setName("Supply Air Temp")
              sat_sch.defaultDaySchedule().setName("Supply Air Temp Default")
              sat_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),sat_c)
              sat_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model,sat_sch)
              sat_stpt_manager.addToNode(supply_outlet_node)

              # Get all zones on this story
              zones = []
              story.spaces.each do |space|
                if space.thermalZone.is_initialized
                  zones << space.thermalZone.get
                end
              end

              # Make a VAV terminal with HW reheat for each zone on this story
              # and hook the reheat coil to the HW loop
              zones.each do |zone|
                reheat_coil = OpenStudio::Model::CoilHeatingWater.new(model,always_on)
                hw_loop.addDemandBranchForComponent(reheat_coil)
                vav_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model,always_on,reheat_coil)
                air_loop.addBranchForZone(zone,vav_terminal.to_StraightComponent)
              end

            end # next story


            return true

          end

          def self.addSys6PVAVwPFPBoxes(model)

            # System Type 6: Packaged VAV w/ PFP Boxes
            # This measure creates:
            # a VAV system w/ electric heating, DX cooling, and electric reheat
            # in a parallel fan powered terminal for each story of the building

            always_on = model.alwaysOnDiscreteSchedule

            # Make a Packaged VAV w/ PFP Boxes for each story of the building
            model.getBuildingStorys.sort.each do |story|

              air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
              air_loop.setName("#{story.name} Packaged Rooftop VAV with PFP Boxes and Reheat")

              fan = OpenStudio::Model::FanVariableVolume.new(model,always_on)
              fan.setPressureRise(500)

              htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model,always_on)

              clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
              clg_cap_f_of_temp.setCoefficient1Constant(0.42415)
              clg_cap_f_of_temp.setCoefficient2x(0.04426)
              clg_cap_f_of_temp.setCoefficient3xPOW2(-0.00042)
              clg_cap_f_of_temp.setCoefficient4y(0.00333)
              clg_cap_f_of_temp.setCoefficient5yPOW2(-0.00008)
              clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.00021)
              clg_cap_f_of_temp.setMinimumValueofx(17.0)
              clg_cap_f_of_temp.setMaximumValueofx(22.0)
              clg_cap_f_of_temp.setMinimumValueofy(13.0)
              clg_cap_f_of_temp.setMaximumValueofy(46.0)

              clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
              clg_cap_f_of_flow.setCoefficient1Constant(0.77136)
              clg_cap_f_of_flow.setCoefficient2x(0.34053)
              clg_cap_f_of_flow.setCoefficient3xPOW2(-0.11088)
              clg_cap_f_of_flow.setMinimumValueofx(0.75918)
              clg_cap_f_of_flow.setMaximumValueofx(1.13877)

              clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
              clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.23649)
              clg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.02431)
              clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00057)
              clg_energy_input_ratio_f_of_temp.setCoefficient4y(-0.01434)
              clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.00063)
              clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.00038)
              clg_energy_input_ratio_f_of_temp.setMinimumValueofx(17.0)
              clg_energy_input_ratio_f_of_temp.setMaximumValueofx(22.0)
              clg_energy_input_ratio_f_of_temp.setMinimumValueofy(13.0)
              clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.0)

              clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
              clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.20550)
              clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.32953)
              clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.12308)
              clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.75918)
              clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.13877)

              clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(model)
              clg_part_load_ratio.setCoefficient1Constant(0.77100)
              clg_part_load_ratio.setCoefficient2x(0.22900)
              clg_part_load_ratio.setCoefficient3xPOW2(0.0)
              clg_part_load_ratio.setMinimumValueofx(0.0)
              clg_part_load_ratio.setMaximumValueofx(1.0)

              clg_cap_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(model)
              clg_cap_f_of_temp_low_spd.setCoefficient1Constant(0.42415)
              clg_cap_f_of_temp_low_spd.setCoefficient2x(0.04426)
              clg_cap_f_of_temp_low_spd.setCoefficient3xPOW2(-0.00042)
              clg_cap_f_of_temp_low_spd.setCoefficient4y(0.00333)
              clg_cap_f_of_temp_low_spd.setCoefficient5yPOW2(-0.00008)
              clg_cap_f_of_temp_low_spd.setCoefficient6xTIMESY(-0.00021)
              clg_cap_f_of_temp_low_spd.setMinimumValueofx(17.0)
              clg_cap_f_of_temp_low_spd.setMaximumValueofx(22.0)
              clg_cap_f_of_temp_low_spd.setMinimumValueofy(13.0)
              clg_cap_f_of_temp_low_spd.setMaximumValueofy(46.0)

              clg_energy_input_ratio_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(model)
              clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient1Constant(1.23649)
              clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient2x(-0.02431)
              clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient3xPOW2(0.00057)
              clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient4y(-0.01434)
              clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient5yPOW2(0.00063)
              clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient6xTIMESY(-0.00038)
              clg_energy_input_ratio_f_of_temp_low_spd.setMinimumValueofx(17.0)
              clg_energy_input_ratio_f_of_temp_low_spd.setMaximumValueofx(22.0)
              clg_energy_input_ratio_f_of_temp_low_spd.setMinimumValueofy(13.0)
              clg_energy_input_ratio_f_of_temp_low_spd.setMaximumValueofy(46.0)

              clg_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(model,
                always_on,
                clg_cap_f_of_temp,
                clg_cap_f_of_flow,
                clg_energy_input_ratio_f_of_temp,
                clg_energy_input_ratio_f_of_flow,
                clg_part_load_ratio,
                clg_cap_f_of_temp_low_spd,
                clg_energy_input_ratio_f_of_temp_low_spd)

              clg_coil.setRatedLowSpeedSensibleHeatRatio(OpenStudio::OptionalDouble.new(0.69))
              clg_coil.setBasinHeaterCapacity(10)
              clg_coil.setBasinHeaterSetpointTemperature(2.0)

              oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)

              oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model,oa_controller)

              # Add the components to the air loop
              # in order from closest to zone to furthest from zone
              supply_inlet_node = air_loop.supplyInletNode
              supply_outlet_node = air_loop.supplyOutletNode
              fan.addToNode(supply_inlet_node)
              htg_coil.addToNode(supply_inlet_node)
              clg_coil.addToNode(supply_inlet_node)
              oa_system.addToNode(supply_inlet_node)

              # Add a setpoint manager to control the
              # supply air to a constant temperature
              sat_c = OpenStudio::convert(55,"F","C").get
              sat_sch = OpenStudio::Model::ScheduleRuleset.new(model)
              sat_sch.setName("Supply Air Temp")
              sat_sch.defaultDaySchedule().setName("Supply Air Temp Default")
              sat_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),sat_c)
              sat_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model,sat_sch)
              sat_stpt_manager.addToNode(supply_outlet_node)

              # Get all zones on this story
              zones = []
              story.spaces.each do |space|
                if space.thermalZone.is_initialized
                  zones << space.thermalZone.get
                end
              end

              # Make a PFP terminal with electric reheat for each zone on this story
              zones.each do |zone|
                pfp_fan = OpenStudio::Model::FanConstantVolume.new(model,always_on)
                pfp_fan.setPressureRise(300)
                reheat_coil = OpenStudio::Model::CoilHeatingElectric.new(model,always_on)
                pfp_terminal = OpenStudio::Model::AirTerminalSingleDuctParallelPIUReheat.new(model,
                  always_on,
                  pfp_fan,
                  reheat_coil)
                air_loop.addBranchForZone(zone,pfp_terminal.to_StraightComponent)
              end

            end # next story


            return true
          end

          def self.addSys7VAVwReheat(model)

            # System Type 7: VAV w/ Reheat
            # This measure creates:
            # a single hot water loop with a natural gas boiler for the building
            # a single chilled water loop with water cooled chiller for the building
            # a single condenser water loop for heat rejection from the chiller
            # a VAV system w/ hot water heating, chilled water cooling, and
            # hot water reheat for each story of the building

            always_on = model.alwaysOnDiscreteSchedule

            # Hot Water Plant

            hw_loop = OpenStudio::Model::PlantLoop.new(model)
            hw_loop.setName("Hot Water Loop for VAV with Reheat")
            hw_sizing_plant = hw_loop.sizingPlant
            hw_sizing_plant.setLoopType("Heating")
            hw_sizing_plant.setDesignLoopExitTemperature(82.0) #TODO units
            hw_sizing_plant.setLoopDesignTemperatureDifference(11.0)

            hw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)

            boiler = OpenStudio::Model::BoilerHotWater.new(model)

            boiler_eff_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
            boiler_eff_f_of_temp.setName("Boiler Efficiency")
            boiler_eff_f_of_temp.setCoefficient1Constant(1.0)
            boiler_eff_f_of_temp.setInputUnitTypeforX("Dimensionless")
            boiler_eff_f_of_temp.setInputUnitTypeforY("Dimensionless")
            boiler_eff_f_of_temp.setOutputUnitType("Dimensionless")

            boiler.setNormalizedBoilerEfficiencyCurve(boiler_eff_f_of_temp)
            boiler.setEfficiencyCurveTemperatureEvaluationVariable("LeavingBoiler")

            boiler_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

            hw_supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

            # Add the components to the hot water loop
            hw_supply_inlet_node = hw_loop.supplyInletNode
            hw_supply_outlet_node = hw_loop.supplyOutletNode
            hw_pump.addToNode(hw_supply_inlet_node)
            hw_loop.addSupplyBranchForComponent(boiler)
            hw_loop.addSupplyBranchForComponent(boiler_bypass_pipe)
            hw_supply_outlet_pipe.addToNode(hw_supply_outlet_node)

            # Add a setpoint manager to control the
            # hot water to a constant temperature
            hw_t_c = OpenStudio::convert(153,"F","C").get
            hw_t_sch = OpenStudio::Model::ScheduleRuleset.new(model)
            hw_t_sch.setName("HW Temp")
            hw_t_sch.defaultDaySchedule().setName("HW Temp Default")
            hw_t_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),hw_t_c)
            hw_t_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model,hw_t_sch)
            hw_t_stpt_manager.addToNode(hw_supply_outlet_node)

            # Chilled Water Plant

            chw_loop = OpenStudio::Model::PlantLoop.new(model)
            chw_loop.setName("Chilled Water Loop for VAV with Reheat")
            chw_sizing_plant = chw_loop.sizingPlant
            chw_sizing_plant.setLoopType("Cooling")
            chw_sizing_plant.setDesignLoopExitTemperature(7.22) #TODO units
            chw_sizing_plant.setLoopDesignTemperatureDifference(6.67)

            chw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)

            clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
            clg_cap_f_of_temp.setCoefficient1Constant(1.0215158)
            clg_cap_f_of_temp.setCoefficient2x(0.037035864)
            clg_cap_f_of_temp.setCoefficient3xPOW2(0.0002332476)
            clg_cap_f_of_temp.setCoefficient4y(-0.003894048)
            clg_cap_f_of_temp.setCoefficient5yPOW2(-6.52536e-005)
            clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.0002680452)
            clg_cap_f_of_temp.setMinimumValueofx(5.0)
            clg_cap_f_of_temp.setMaximumValueofx(10.0)
            clg_cap_f_of_temp.setMinimumValueofy(24.0)
            clg_cap_f_of_temp.setMaximumValueofy(35.0)

            eir_f_of_avail_to_nom_cap = OpenStudio::Model::CurveBiquadratic.new(model)
            eir_f_of_avail_to_nom_cap.setCoefficient1Constant(0.70176857)
            eir_f_of_avail_to_nom_cap.setCoefficient2x(-0.00452016)
            eir_f_of_avail_to_nom_cap.setCoefficient3xPOW2(0.0005331096)
            eir_f_of_avail_to_nom_cap.setCoefficient4y(-0.005498208)
            eir_f_of_avail_to_nom_cap.setCoefficient5yPOW2(0.0005445792)
            eir_f_of_avail_to_nom_cap.setCoefficient6xTIMESY(-0.0007290324)
            eir_f_of_avail_to_nom_cap.setMinimumValueofx(5.0)
            eir_f_of_avail_to_nom_cap.setMaximumValueofx(10.0)
            eir_f_of_avail_to_nom_cap.setMinimumValueofy(24.0)
            eir_f_of_avail_to_nom_cap.setMaximumValueofy(35.0)

            eir_f_of_plr = OpenStudio::Model::CurveQuadratic.new(model)
            eir_f_of_plr.setCoefficient1Constant(0.06369119)
            eir_f_of_plr.setCoefficient2x(0.58488832)
            eir_f_of_plr.setCoefficient3xPOW2(0.35280274)
            eir_f_of_plr.setMinimumValueofx(0.0)
            eir_f_of_plr.setMaximumValueofx(1.0)

            chiller = OpenStudio::Model::ChillerElectricEIR.new(model,
              clg_cap_f_of_temp,
              eir_f_of_avail_to_nom_cap,
              eir_f_of_plr)

            chiller_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

            chw_supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

            # Add the components to the chilled water loop
            chw_supply_inlet_node = chw_loop.supplyInletNode
            chw_supply_outlet_node = chw_loop.supplyOutletNode
            chw_pump.addToNode(chw_supply_inlet_node)
            chw_loop.addSupplyBranchForComponent(chiller)
            chw_loop.addSupplyBranchForComponent(chiller_bypass_pipe)
            chw_supply_outlet_pipe.addToNode(chw_supply_outlet_node)

            # Add a setpoint manager to control the
            # chilled water to a constant temperature
            chw_t_c = OpenStudio::convert(44,"F","C").get
            chw_t_sch = OpenStudio::Model::ScheduleRuleset.new(model)
            chw_t_sch.setName("CHW Temp")
            chw_t_sch.defaultDaySchedule().setName("HW Temp Default")
            chw_t_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),chw_t_c)
            chw_t_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model,chw_t_sch)
            chw_t_stpt_manager.addToNode(chw_supply_outlet_node)

            # Condenser System

            cw_loop = OpenStudio::Model::PlantLoop.new(model)
            cw_loop.setName("Condenser Water Loop for VAV with Reheat")
            cw_sizing_plant = chw_loop.sizingPlant
            cw_sizing_plant.setLoopType("Condenser")
            cw_sizing_plant.setDesignLoopExitTemperature(29.4) #TODO units
            cw_sizing_plant.setLoopDesignTemperatureDifference(5.6)

            cw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)

            clg_tower = OpenStudio::Model::CoolingTowerSingleSpeed.new(model)

            clg_tower_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

            cw_supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

            # Add the components to the condenser water loop
            cw_supply_inlet_node = cw_loop.supplyInletNode
            cw_supply_outlet_node = cw_loop.supplyOutletNode
            cw_pump.addToNode(cw_supply_inlet_node)
            cw_loop.addSupplyBranchForComponent(clg_tower)
            cw_loop.addSupplyBranchForComponent(clg_tower_bypass_pipe)
            cw_supply_outlet_pipe.addToNode(cw_supply_outlet_node)
            cw_loop.addDemandBranchForComponent(chiller)

            # Add a setpoint manager to control the
            # condenser water to follow the OA temp
            cw_t_stpt_manager = OpenStudio::Model::SetpointManagerFollowOutdoorAirTemperature.new(model)
            cw_t_stpt_manager.addToNode(cw_supply_outlet_node)

            # Make a Packaged VAV w/ PFP Boxes for each story of the building
            model.getBuildingStorys.sort.each do |story|

              air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
              air_loop.setName("VAV with Reheat")
              sizingSystem = air_loop.sizingSystem
              sizingSystem.setCentralCoolingDesignSupplyAirTemperature(12.8)
              sizingSystem.setCentralHeatingDesignSupplyAirTemperature(12.8)

              fan = OpenStudio::Model::FanVariableVolume.new(model,always_on)
              fan.setPressureRise(500)

              htg_coil = OpenStudio::Model::CoilHeatingWater.new(model,always_on)
              hw_loop.addDemandBranchForComponent(htg_coil)

              clg_coil = OpenStudio::Model::CoilCoolingWater.new(model,always_on)
              chw_loop.addDemandBranchForComponent(clg_coil)

              oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)

              oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model,oa_controller)

              # Add the components to the air loop
              # in order from closest to zone to furthest from zone
              supply_inlet_node = air_loop.supplyInletNode
              supply_outlet_node = air_loop.supplyOutletNode
              fan.addToNode(supply_inlet_node)
              htg_coil.addToNode(supply_inlet_node)
              clg_coil.addToNode(supply_inlet_node)
              oa_system.addToNode(supply_inlet_node)

              # Add a setpoint manager to control the
              # supply air to a constant temperature
              sat_c = OpenStudio::convert(55,"F","C").get
              sat_sch = OpenStudio::Model::ScheduleRuleset.new(model)
              sat_sch.setName("Supply Air Temp")
              sat_sch.defaultDaySchedule().setName("Supply Air Temp Default")
              sat_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),sat_c)
              sat_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model,sat_sch)
              sat_stpt_manager.addToNode(supply_outlet_node)

              # Get all zones on this story
              zones = []
              story.spaces.each do |space|
                if space.thermalZone.is_initialized
                  zones << space.thermalZone.get
                end
              end

              # Make a VAV terminal with HW reheat for each zone on this story
              # and hook the reheat coil to the HW loop
              zones.each do |zone|
                reheat_coil = OpenStudio::Model::CoilHeatingWater.new(model,always_on)
                hw_loop.addDemandBranchForComponent(reheat_coil)
                vav_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model,always_on,reheat_coil)
                air_loop.addBranchForZone(zone,vav_terminal.to_StraightComponent)
              end

            end # next story


            return true

          end

          def self.addSys8VAVwPFPBoxes(model)

            # System Type 8: VAV w/ PFP Boxes and Reheat
            # This measure creates:
            # a single chilled water loop with air cooled chiller for the building
            # a VAV system w/ electric heat, chilled water cooling, and electric reheat
            # in parallel fan powered terminal for each story of the building
            always_on = model.alwaysOnDiscreteSchedule

            # Chilled Water Plant

            chw_loop = OpenStudio::Model::PlantLoop.new(model)
            chw_loop.setName("Chilled Water Loop for VAV with PFP Boxes")
            chw_sizing_plant = chw_loop.sizingPlant
            chw_sizing_plant.setLoopType("Cooling")
            chw_sizing_plant.setDesignLoopExitTemperature(7.22) #TODO units
            chw_sizing_plant.setLoopDesignTemperatureDifference(6.67)

            chw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)

            clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
            clg_cap_f_of_temp.setCoefficient1Constant(1.0215158)
            clg_cap_f_of_temp.setCoefficient2x(0.037035864)
            clg_cap_f_of_temp.setCoefficient3xPOW2(0.0002332476)
            clg_cap_f_of_temp.setCoefficient4y(-0.003894048)
            clg_cap_f_of_temp.setCoefficient5yPOW2(-6.52536e-005)
            clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.0002680452)
            clg_cap_f_of_temp.setMinimumValueofx(5.0)
            clg_cap_f_of_temp.setMaximumValueofx(10.0)
            clg_cap_f_of_temp.setMinimumValueofy(24.0)
            clg_cap_f_of_temp.setMaximumValueofy(35.0)

            eir_f_of_avail_to_nom_cap = OpenStudio::Model::CurveBiquadratic.new(model)
            eir_f_of_avail_to_nom_cap.setCoefficient1Constant(0.70176857)
            eir_f_of_avail_to_nom_cap.setCoefficient2x(-0.00452016)
            eir_f_of_avail_to_nom_cap.setCoefficient3xPOW2(0.0005331096)
            eir_f_of_avail_to_nom_cap.setCoefficient4y(-0.005498208)
            eir_f_of_avail_to_nom_cap.setCoefficient5yPOW2(0.0005445792)
            eir_f_of_avail_to_nom_cap.setCoefficient6xTIMESY(-0.0007290324)
            eir_f_of_avail_to_nom_cap.setMinimumValueofx(5.0)
            eir_f_of_avail_to_nom_cap.setMaximumValueofx(10.0)
            eir_f_of_avail_to_nom_cap.setMinimumValueofy(24.0)
            eir_f_of_avail_to_nom_cap.setMaximumValueofy(35.0)

            eir_f_of_plr = OpenStudio::Model::CurveQuadratic.new(model)
            eir_f_of_plr.setCoefficient1Constant(0.06369119)
            eir_f_of_plr.setCoefficient2x(0.58488832)
            eir_f_of_plr.setCoefficient3xPOW2(0.35280274)
            eir_f_of_plr.setMinimumValueofx(0.0)
            eir_f_of_plr.setMaximumValueofx(1.0)

            chiller = OpenStudio::Model::ChillerElectricEIR.new(model,
              clg_cap_f_of_temp,
              eir_f_of_avail_to_nom_cap,
              eir_f_of_plr)

            chiller_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

            chw_supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

            # Add the components to the chilled water loop
            chw_supply_inlet_node = chw_loop.supplyInletNode
            chw_supply_outlet_node = chw_loop.supplyOutletNode
            chw_pump.addToNode(chw_supply_inlet_node)
            chw_loop.addSupplyBranchForComponent(chiller)
            chw_loop.addSupplyBranchForComponent(chiller_bypass_pipe)
            chw_supply_outlet_pipe.addToNode(chw_supply_outlet_node)

            # Add a setpoint manager to control the
            # chilled water to a constant temperature
            chw_t_c = OpenStudio::convert(44,"F","C").get
            chw_t_sch = OpenStudio::Model::ScheduleRuleset.new(model)
            chw_t_sch.setName("CHW Temp")
            chw_t_sch.defaultDaySchedule().setName("HW Temp Default")
            chw_t_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),chw_t_c)
            chw_t_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model,chw_t_sch)
            chw_t_stpt_manager.addToNode(chw_supply_outlet_node)

            # Make a Packaged VAV w/ PFP Boxes for each story of the building
            model.getBuildingStorys.sort.each do |story|
              air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
              air_loop.setName("VAV with PFP Boxes and Reheat")
              sizingSystem = air_loop.sizingSystem
              sizingSystem.setCentralCoolingDesignSupplyAirTemperature(12.8)
              sizingSystem.setCentralHeatingDesignSupplyAirTemperature(12.8)

              fan = OpenStudio::Model::FanVariableVolume.new(model,always_on)
              fan.setPressureRise(500)

              htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model,always_on)

              clg_coil = OpenStudio::Model::CoilCoolingWater.new(model,always_on)
              chw_loop.addDemandBranchForComponent(clg_coil)

              oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)

              oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model,oa_controller)

              # Add the components to the air loop
              # in order from closest to zone to furthest from zone
              supply_inlet_node = air_loop.supplyInletNode
              supply_outlet_node = air_loop.supplyOutletNode
              fan.addToNode(supply_inlet_node)
              htg_coil.addToNode(supply_inlet_node)
              clg_coil.addToNode(supply_inlet_node)
              oa_system.addToNode(supply_inlet_node)

              # Add a setpoint manager to control the
              # supply air to a constant temperature
              sat_c = OpenStudio::convert(55,"F","C").get
              sat_sch = OpenStudio::Model::ScheduleRuleset.new(model)
              sat_sch.setName("Supply Air Temp")
              sat_sch.defaultDaySchedule().setName("Supply Air Temp Default")
              sat_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),sat_c)
              sat_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model,sat_sch)
              sat_stpt_manager.addToNode(supply_outlet_node)

              # Get all zones on this story
              zones = []
              story.spaces.each do |space|
                if space.thermalZone.is_initialized
                  zones << space.thermalZone.get
                end
              end

              # Make a PFP terminal with electric reheat for each zone
              zones.each do |zone|
                pfp_fan = OpenStudio::Model::FanConstantVolume.new(model,always_on)
                pfp_fan.setPressureRise(300)
                reheat_coil = OpenStudio::Model::CoilHeatingElectric.new(model,always_on)
                pfp_terminal = OpenStudio::Model::AirTerminalSingleDuctParallelPIUReheat.new(model,
                  always_on,
                  pfp_fan,
                  reheat_coil)
                air_loop.addBranchForZone(zone,pfp_terminal.to_StraightComponent)
              end

            end # Next story


            return true

          end

          def self.addSys9GasFiredWarmAirFurnace(model)

            # System Type 9: Gas Fired Warm Air Furnace
            # This measure creates:
            # a constant volume furnace with gas heating and no cooling
            # for each zone in the building

            # Make a furnace with gas heating and no cooling for each zone
            always_on = model.alwaysOnDiscreteSchedule

            model.getThermalZones.each do |zone|
              air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
              air_loop.setName("Gas Furnace")
              sizingSystem = air_loop.sizingSystem
              sizingSystem.setTypeofLoadtoSizeOn("Sensible")
              sizingSystem.autosizeDesignOutdoorAirFlowRate()
              sizingSystem.setMinimumSystemAirFlowRatio(1.0)
              sizingSystem.setPreheatDesignTemperature(7.0)
              sizingSystem.setPreheatDesignHumidityRatio(0.008)
              sizingSystem.setPrecoolDesignTemperature(12.8)
              sizingSystem.setPrecoolDesignHumidityRatio(0.008)
              sizingSystem.setCentralCoolingDesignSupplyAirTemperature(12.8)
              sizingSystem.setCentralHeatingDesignSupplyAirTemperature(40.0)
              sizingSystem.setSizingOption("NonCoincident")
              sizingSystem.setAllOutdoorAirinCooling(false)
              sizingSystem.setAllOutdoorAirinHeating(false)
              sizingSystem.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
              sizingSystem.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
              sizingSystem.setCoolingDesignAirFlowMethod("DesignDay")
              sizingSystem.setCoolingDesignAirFlowRate(0.0)
              sizingSystem.setHeatingDesignAirFlowMethod("DesignDay")
              sizingSystem.setHeatingDesignAirFlowRate(0.0)
              sizingSystem.setSystemOutdoorAirMethod("ZoneSum")

              fan = OpenStudio::Model::FanConstantVolume.new(model,always_on)
              fan.setPressureRise(500)

              htg_coil = OpenStudio::Model::CoilHeatingGas.new(model,always_on)

              oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)

              oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model,oa_controller)

              # Add the components to the air loop
              # in order from closest to zone to furthest from zone
              supply_inlet_node = air_loop.supplyInletNode
              supply_outlet_node = air_loop.supplyOutletNode
              fan.addToNode(supply_inlet_node)
              htg_coil.addToNode(supply_inlet_node)
              oa_system.addToNode(supply_inlet_node)

              # Add a setpoint manager single zone reheat to control the
              # supply air temperature based on the needs of this zone
              setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
              setpoint_mgr_single_zone_reheat.setControlZone(zone)
              setpoint_mgr_single_zone_reheat.addToNode(supply_outlet_node)

              # Create a diffuser and attach the zone/diffuser pair to the air loop
              diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model,always_on)
              air_loop.addBranchForZone(zone,diffuser.to_StraightComponent)
            end
            return true
          end

          def self.addSys10ElectricWarmAirFurnace(model)
            # System Type 10: Electric Warm Air Furnace
            # This measure creates:
            # a constant volume furnace with electric resistance heating and no cooling
            # for each zone in the building

            # Make a furnace with gas heating and no cooling for each zone
            always_on = model.alwaysOnDiscreteSchedule

            model.getThermalZones.each do |zone|

              air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
              air_loop.setName("Electric Furnace")
              sizingSystem = air_loop.sizingSystem
              sizingSystem.setTypeofLoadtoSizeOn("Sensible")
              sizingSystem.autosizeDesignOutdoorAirFlowRate()
              sizingSystem.setMinimumSystemAirFlowRatio(1.0)
              sizingSystem.setPreheatDesignTemperature(7.0)
              sizingSystem.setPreheatDesignHumidityRatio(0.008)
              sizingSystem.setPrecoolDesignTemperature(12.8)
              sizingSystem.setPrecoolDesignHumidityRatio(0.008)
              sizingSystem.setCentralCoolingDesignSupplyAirTemperature(12.8)
              sizingSystem.setCentralHeatingDesignSupplyAirTemperature(40.0)
              sizingSystem.setSizingOption("NonCoincident")
              sizingSystem.setAllOutdoorAirinCooling(false)
              sizingSystem.setAllOutdoorAirinHeating(false)
              sizingSystem.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
              sizingSystem.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
              sizingSystem.setCoolingDesignAirFlowMethod("DesignDay")
              sizingSystem.setCoolingDesignAirFlowRate(0.0)
              sizingSystem.setHeatingDesignAirFlowMethod("DesignDay")
              sizingSystem.setHeatingDesignAirFlowRate(0.0)
              sizingSystem.setSystemOutdoorAirMethod("ZoneSum")

              fan = OpenStudio::Model::FanConstantVolume.new(model,always_on)
              fan.setPressureRise(500)

              htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model,always_on)

              oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)

              oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model,oa_controller)

              # Add the components to the air loop
              # in order from closest to zone to furthest from zone
              supply_inlet_node = air_loop.supplyInletNode
              supply_outlet_node = air_loop.supplyOutletNode
              fan.addToNode(supply_inlet_node)
              htg_coil.addToNode(supply_inlet_node)
              oa_system.addToNode(supply_inlet_node)

              # Add a setpoint manager single zone reheat to control the
              # supply air temperature based on the needs of this zone
              setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
              setpoint_mgr_single_zone_reheat.setControlZone(zone)
              setpoint_mgr_single_zone_reheat.addToNode(supply_outlet_node)

              # Create a diffuser and attach the zone/diffuser pair to the air loop
              diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model,always_on)
              air_loop.addBranchForZone(zone,diffuser.to_StraightComponent)

            end


            return true

          end
        end

        module NECB2011

          #wrapper methods for the auto_zoner
          def self.assign_zones_sys1( model, zones, boiler_fueltype, mau, mau_heating_coil_type, baseboard_type )
            return self.add_sys1_unitary_ac_baseboard_heating( model,zones,boiler_fueltype,mau,mau_heating_coil_type,baseboard_type)
          end

          def self.assign_zones_sys2(model, zones, boiler_fueltype,chiller_type,mua_cooling_type)
            self.add_sys2_FPFC_sys5_TPFC(model, zones, boiler_fueltype,chiller_type,"FPFC",mua_cooling_type)
          end

          def self.assign_zones_sys3(model, zones, boiler_fueltype,  heating_coil_type, baseboard_type)
            self.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating( model, zones, boiler_fueltype,  heating_coil_type, baseboard_type)
          end
          
          def self.assign_zones_sys4( model, zones, boiler_fueltype, heating_coil_type, baseboard_type)
            self.add_sys4_single_zone_make_up_air_unit_with_baseboard_heating( model, zones, boiler_fueltype, heating_coil_type, baseboard_type)
            return model
          end
          
          def self.assign_zones_sys5(model, zones, boiler_fueltype,chiller_type,mua_cooling_type)
            self.add_sys2_FPFC_sys5_TPFC(model, zones, boiler_fueltype,chiller_type,"TPFC",mua_cooling_type)
          end
          
          #To do: must unravel story vav assignment. 
          def self.assign_zones_sys6( model ,zones,  boiler_fueltype, heating_coil_type, baseboard_type, chiller_type, fan_type )
            self.add_sys6_multi_zone_built_up_system_with_baseboard_heating( model ,zones,  boiler_fueltype, heating_coil_type, baseboard_type, chiller_type, fan_type )
          end
          
          def self.assign_zones_sys7(model, zones, boiler_fueltype,chiller_type,mua_cooling_type)
            #System 7 
            self.add_sys2_FPFC_sys5_TPFC(model, zones, boiler_fueltype,chiller_type,"FPFC",mua_cooling_type)
          end
          
    

          def self.add_sys1_unitary_ac_baseboard_heating(model,zones, boiler_fueltype, mau ,mau_heating_coil_type,baseboard_type)

            # System Type 1: PTAC with no heating (unitary AC) 
            # Zone baseboards, electric or hot water depending on argument baseboard_type
            # baseboard_type choices are "Hot Water" or "Electric" 
            # PSZ to represent make-up air unit (if present)
            # This measure creates:
            # a PTAC  unit for each zone in the building; DX cooling coil
            # and heating coil that is always off
            # Baseboards ("Hot Water or "Electric") in zones connected to hot water loop
            # MAU is present if argument mau == true, not present if argument mau == false
            # MAU is PSZ; DX cooling 
            # MAU heating coil: hot water coil or electric, depending on argument mau_heating_coil_type
            # mau_heating_coil_type choices are "Hot Water", "Electric"
            # boiler_fueltype choices match OS choices for Boiler component fuel type, i.e.
            # "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"
            
            # Some system parameters are set after system is set up; by applying method 'applyHVACEfficiencyStandard'


            always_on = model.alwaysOnDiscreteSchedule
            
            # define always off schedule for ptac heating coil
            always_off = BTAP::Resources::Schedules::StandardSchedules::ON_OFF::always_off(model)

            # Create a hot water loop; MAU hydronic heating coil and hot water baseboards will be
            # connected to this loop (if MAU and its heating coil is hydronic or if baseboard type is hydronic)

            if ( (mau == true and mau_heating_coil_type == "Hot Water") or baseboard_type == "Hot Water" ) then

              hw_loop = BTAP::Resources::HVAC::Plant::add_water_loop(model)
              BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model,hw_loop,boiler_fueltype, always_on)

            end  #of if statement
            
             #Create MAU 
             # TO DO: MAU sizing, characteristics (fan operation schedules, temperature setpoints, outdoor air, etc)
           
            if ( mau == true) then
              
              mau_air_loop = BTAP::Resources::HVAC::Plant::add_air_loop(model)


              mau_air_loop.setName("Make-up air unit")

              # When an air_loop is constructed, its constructor creates a sizing:system object
              # the default sizing:system constructor makes a system:sizing object
              # appropriate for a multizone VAV system
              # this systems is a constant volume system with no VAV terminals,
              # and therfore needs different default settings
              air_loop_sizing = mau_air_loop.sizingSystem # TODO units
              air_loop_sizing.setTypeofLoadtoSizeOn("Sensible")
              air_loop_sizing.autosizeDesignOutdoorAirFlowRate
              air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
              air_loop_sizing.setPreheatDesignTemperature(7.0)
              air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
              air_loop_sizing.setPrecoolDesignTemperature(12.8)
              air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
              air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(12.8)
              air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(40.0)
              air_loop_sizing.setSizingOption("NonCoincident")
              air_loop_sizing.setAllOutdoorAirinCooling(false)
              air_loop_sizing.setAllOutdoorAirinHeating(false)
              air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
              air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
              air_loop_sizing.setCoolingDesignAirFlowMethod("DesignDay")
              air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
              air_loop_sizing.setHeatingDesignAirFlowMethod("DesignDay")
              air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
              air_loop_sizing.setSystemOutdoorAirMethod("ZoneSum")

              mau_fan = BTAP::Resources::HVAC::Plant::add_const_fan(model, always_on)
                            

              if ( mau_heating_coil_type == "Electric") then           # electric coil
                mau_htg_coil = BTAP::Resources::HVAC::Plant::add_elec_heating_coil(model,always_on)
              end

              if ( mau_heating_coil_type == "Hot Water") then
                mau_htg_coil = BTAP::Resources::HVAC::Plant::add_hydronic_heating_coil(model, always_on)
                hw_loop.addDemandBranchForComponent(mau_htg_coil)
              end


            # Set up DX coil with default curves (set to NECB);

              mau_clg_coil = BTAP::Resources::HVAC::Plant::add_onespeed_DX_coil(model,always_on)

              #oa_controller 
              oa_controller = BTAP::Resources::HVAC::Plant::add_oa_controller(model)
              #oa_controller.setEconomizerControlType("DifferentialEnthalpy")


              #oa_system 
              oa_system = BTAP::Resources::HVAC::Plant::add_OA_system(model, oa_controller)

              # Add the components to the air loop
              # in order from closest to zone to furthest from zone
              supply_inlet_node = mau_air_loop.supplyInletNode
              mau_fan.addToNode(supply_inlet_node)
              mau_htg_coil.addToNode(supply_inlet_node)
              mau_clg_coil.addToNode(supply_inlet_node)
              oa_system.addToNode(supply_inlet_node)

              # Add a setpoint manager single zone reheat to control the
              # supply air temperature 
              setpoint_mgr_single_zone_reheat = BTAP::Resources::HVAC::Plant::add_sz_reheat_setpoint(model)
              setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(13.0)
              setpoint_mgr_single_zone_reheat.addToNode(mau_air_loop.supplyOutletNode)
              
              # TO DO: Which zone is the control zone? 
              #setpoint_mgr_single_zone_reheat.setControlZone(zone)             

             
            end # Create MAU
            

            # Create a PTAC for each zone:
            # PTAC DX Cooling with electric heating coil; electric heating coil is always off 
            
            
            # TO DO: need to apply this system to space types:
            #(1) data processing area: control room, data centre
            # when cooling capacity <= 20kW and
            #(2) residential/accommodation: murb, hotel/motel guest room
            # when building/space heated only (this as per NECB; apply to
            # all for initial work? CAN-QUEST limitation)

            #TO DO: PTAC characteristics: sizing, fan schedules, temperature setpoints, interaction with MAU
            
            
            zones.each do |zone|
            
              # Set up PTAC heating coil; apply always off schedule            
 
              # htg_coil_elec = OpenStudio::Model::CoilHeatingElectric.new(model,always_on)
              htg_coil = BTAP::Resources::HVAC::Plant::add_elec_heating_coil(model,always_off)
            
              
              
              # Set up PTAC DX coil with NECB performance curve characteristics;
              clg_coil = BTAP::Resources::HVAC::Plant::add_onespeed_DX_coil(model,always_on)
              
              
              # Set up PTAC constant volume supply fan
              fan = BTAP::Resources::HVAC::Plant::add_const_fan(model, always_on)         
              fan.setPressureRise(640)
                        
              

              ptac = OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner.new(model,
                always_on,
                fan,
                htg_coil,
                clg_coil)
              ptac.setName("#{zone.name} PTAC")
              ptac.addToThermalZone(zone)
              
              # add zone baseboards
              if ( baseboard_type == "Electric") then

                #  zone_elec_baseboard = OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(model)
                zone_elec_baseboard = BTAP::Resources::HVAC::Plant::add_elec_baseboard(model)
                zone_elec_baseboard.addToThermalZone(zone)

              end

              if ( baseboard_type == "Hot Water") then
                baseboard_coil = BTAP::Resources::HVAC::Plant::add_hw_baseboard_coil(model)
                #Connect baseboard coil to hot water loop
                hw_loop.addDemandBranchForComponent(baseboard_coil)


                zone_baseboard = BTAP::Resources::HVAC::ZoneEquipment::add_zone_baseboard_convective_water(model, always_on, baseboard_coil)
                #add zone_baseboard to zone
                zone_baseboard.addToThermalZone(zone)
                
              end
              
              
              #  # Create a diffuser and attach the zone/diffuser pair to the MAU air loop, if applicable
              if (mau == true) then
          
                diffuser = BTAP::Resources::HVAC::Plant::add_diffuser(model, always_on)
                mau_air_loop.addBranchForZone(zone,diffuser.to_StraightComponent)
                 
              end #components for MAU
                          
           end # of zone loop
            

            return true
            
          end #sys1_unitary_ac_baseboard_heating
		  
          def self.add_sys2_FPFC_sys5_TPFC( model,zones, boiler_fueltype,chiller_type,fan_coil_type,mua_cooling_type )

            # System Type 2: FPFC or System 5: TPFC
            # This measure creates:
            # -a four pipe or a two pipe fan coil unit for each zone in the building;
            # -a make up air-unit to provide ventilation to each zone;
            # -a heating loop, cooling loop and condenser loop to serve four pipe fan coil units
            # Arguments:
            #   boiler_fueltype: "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"
            #   chiller_type: "Scroll";"Centrifugal";"Rotary Screw";"Reciprocating"
            #   mua_cooling_type: make-up air unit cooling type "DX";"Hydronic"
            #   fan_coil_type options are "TPFC" or "FPFC"

            # TODO: Add arguments as needed when the sizing routine is finalized. For example we will need to know the 
            # required size of the boilers to decide on how many units are needed based on NECB rules.

            always_on = model.alwaysOnDiscreteSchedule

            # schedule for two-pipe fan coil operation

            twenty_four_hrs = OpenStudio::Time.new(0,24,0,0)
            
            # Heating coil availability schedule for tpfc
            tpfc_htg_availability_sch = OpenStudio::Model::ScheduleRuleset.new(model)
            tpfc_htg_availability_sch.setName("tpfc_htg_availability")
            # Cooling coil availability schedule for tpfc
            tpfc_clg_availability_sch = OpenStudio::Model::ScheduleRuleset.new(model)
            tpfc_clg_availability_sch.setName("tpfc_clg_availability")
            istart_month = [1,7,11]
            istart_day = [1,1,1]
            iend_month = [6,10,12]
            iend_day = [30,31,31]
            sch_htg_value = [1,0,1]
            sch_clg_value = [0,1,0]
            for i in 0..2 
              tpfc_htg_availability_sch_rule = OpenStudio::Model::ScheduleRule.new(tpfc_htg_availability_sch)
              tpfc_htg_availability_sch_rule.setName("tpfc_htg_availability_sch_rule")
              tpfc_htg_availability_sch_rule.setStartDate(model.getYearDescription.makeDate(istart_month[i],istart_day[i]))
              tpfc_htg_availability_sch_rule.setEndDate(model.getYearDescription.makeDate(iend_month[i],iend_day[i]))
              tpfc_htg_availability_sch_rule.setApplySunday(true)
              tpfc_htg_availability_sch_rule.setApplyMonday(true)
              tpfc_htg_availability_sch_rule.setApplyTuesday(true)
              tpfc_htg_availability_sch_rule.setApplyWednesday(true)
              tpfc_htg_availability_sch_rule.setApplyThursday(true)
              tpfc_htg_availability_sch_rule.setApplyFriday(true)
              tpfc_htg_availability_sch_rule.setApplySaturday(true)           
              day_schedule = tpfc_htg_availability_sch_rule.daySchedule
              day_schedule.setName("tpfc_htg_availability_sch_rule_day")
              day_schedule.addValue(twenty_four_hrs,sch_htg_value[i])
              
              tpfc_clg_availability_sch_rule = OpenStudio::Model::ScheduleRule.new(tpfc_clg_availability_sch)
              tpfc_clg_availability_sch_rule.setName("tpfc_clg_availability_sch_rule")
              tpfc_clg_availability_sch_rule.setStartDate(model.getYearDescription.makeDate(istart_month[i],istart_day[i]))
              tpfc_clg_availability_sch_rule.setEndDate(model.getYearDescription.makeDate(iend_month[i],iend_day[i]))
              tpfc_clg_availability_sch_rule.setApplySunday(true)
              tpfc_clg_availability_sch_rule.setApplyMonday(true)
              tpfc_clg_availability_sch_rule.setApplyTuesday(true)
              tpfc_clg_availability_sch_rule.setApplyWednesday(true)
              tpfc_clg_availability_sch_rule.setApplyThursday(true)
              tpfc_clg_availability_sch_rule.setApplyFriday(true)
              tpfc_clg_availability_sch_rule.setApplySaturday(true)           
              day_schedule = tpfc_clg_availability_sch_rule.daySchedule
              day_schedule.setName("tpfc_clg_availability_sch_rule_day")
              day_schedule.addValue(twenty_four_hrs,sch_clg_value[i])

            end

            # Create a hot water loop

            hw_loop = BTAP::Resources::HVAC::Plant::add_water_loop(model)
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model,hw_loop,boiler_fueltype,tpfc_htg_availability_sch)

            # Create a chilled water loop

            chw_loop = BTAP::Resources::HVAC::Plant::add_water_loop(model)
            chiller = BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_chw_loop_with_components(model,chw_loop,chiller_type)

            # Create a condenser Loop

            cw_loop = BTAP::Resources::HVAC::Plant::add_water_loop(model)
            ctower = BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_cw_loop_with_components(model,cw_loop,chiller)

            # Set up make-up air unit for ventilation
            # TO DO: Need to investigate characteristics of make-up air unit for NECB reference
            # and define them here

            air_loop = BTAP::Resources::HVAC::Plant::add_air_loop(model)

            air_loop.setName("Make-up air unit")

            # When an air_loop is contructed, its constructor creates a sizing:system object
            # the default sizing:system constructor makes a system:sizing object
            # appropriate for a multizone VAV system
            # this systems is a constant volume system with no VAV terminals,
            # and therfore needs different default settings
            air_loop_sizing = air_loop.sizingSystem # TODO units
            air_loop_sizing.setTypeofLoadtoSizeOn("Sensible")
            air_loop_sizing.autosizeDesignOutdoorAirFlowRate
            air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
            air_loop_sizing.setPreheatDesignTemperature(7.0)
            air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
            air_loop_sizing.setPrecoolDesignTemperature(12.8)
            air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
            air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(13.0)
            air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(12.8)
            air_loop_sizing.setSizingOption("NonCoincident")
            air_loop_sizing.setAllOutdoorAirinCooling(false)
            air_loop_sizing.setAllOutdoorAirinHeating(false)
            air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.008)
            air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.008)
            air_loop_sizing.setCoolingDesignAirFlowMethod("DesignDay")
            air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
            air_loop_sizing.setHeatingDesignAirFlowMethod("DesignDay")
            air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
            air_loop_sizing.setSystemOutdoorAirMethod("ZoneSum")

            fan = BTAP::Resources::HVAC::Plant::add_const_fan(model, always_on)
            fan.setPressureRise(640)
            fan.setFanEfficiency(0.4)

            # Assume direct-fired gas heating coil for now; need to add logic
            # to set up hydronic or electric coil depending on proposed?

            htg_coil = BTAP::Resources::HVAC::Plant::add_gas_heating_coil(model, always_on)

            # Add DX or hydronic cooling coil
            # TODO: set proper cooling DX COP when sizing data is available
            if(mua_cooling_type == "DX")
              clg_coil = BTAP::Resources::HVAC::Plant::add_onespeed_DX_coil(model,always_on)
            elsif(mua_cooling_type == "Hydronic")
              if(fan_coil_type == "FPFC")
                clg_coil = BTAP::Resources::HVAC::Plant::add_hydronic_cool_coil(model, always_on)
              elsif(fan_coil_type == "TPFC")
                clg_coil = BTAP::Resources::HVAC::Plant::add_hydronic_cool_coil(model, tpfc_clg_availability_sch)
              end
              chw_loop.addDemandBranchForComponent(clg_coil)
            end

            # does MAU have an economizer?

            oa_controller = BTAP::Resources::HVAC::Plant::add_oa_controller(model)
            oa_controller.setEconomizerControlType("DifferentialEnthalpy")

            #oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model,oa_controller)
            oa_system = BTAP::Resources::HVAC::Plant::add_OA_system(model, oa_controller)

            #TODO: add logic for whether an HRV is needed depending on recoverable heat (NECB 5.2.10.1)  
            #Create sensible heat exchanger.
            heat_exchanger = BTAP::Resources::HVAC::Plant::add_hrv(model)
            heat_exchanger.setSensibleEffectivenessat100HeatingAirFlow(0.5)
            heat_exchanger.setSensibleEffectivenessat75HeatingAirFlow(0.5)
            heat_exchanger.setSensibleEffectivenessat100CoolingAirFlow(0.5)
            heat_exchanger.setSensibleEffectivenessat75CoolingAirFlow(0.5)
            heat_exchanger.setLatentEffectivenessat100HeatingAirFlow(0.0)
            heat_exchanger.setLatentEffectivenessat75HeatingAirFlow(0.0)
            heat_exchanger.setLatentEffectivenessat100CoolingAirFlow(0.0)
            heat_exchanger.setLatentEffectivenessat75CoolingAirFlow(0.0)
            heat_exchanger.setSupplyAirOutletTemperatureControl(false)

            # Add the components to the air loop 
            # in order from closest to zone to furthest from zone
            supply_inlet_node = air_loop.supplyInletNode
            fan.addToNode(supply_inlet_node)
            htg_coil.addToNode(supply_inlet_node)
            clg_coil.addToNode(supply_inlet_node)
            oa_system.addToNode(supply_inlet_node)
            oa_node = oa_system.outboardOANode
            heat_exchanger.addToNode(oa_node.get)

            # Add a setpoint manager single zone reheat to control the
            # supply air temperature based on the needs of default zone (OpenStudio picks one)
            # TO DO: need to have method to pick appropriate control zone?

            setpoint_mgr_single_zone_reheat = BTAP::Resources::HVAC::Plant::add_sz_reheat_setpoint(model)
            setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(12.8)
            setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(13.0)
            setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)

            # Set up FC (ZoneHVAC,cooling coil, heating coil, fan) in each zone

            zones.each do |zone| 

              # fc supply fan
              fc_fan = BTAP::Resources::HVAC::Plant::add_const_fan(model, always_on)

              if(fan_coil_type == "FPFC")
                # heating coil
                fc_htg_coil = BTAP::Resources::HVAC::Plant::add_hydronic_heating_coil(model, always_on)

                # cooling coil
                fc_clg_coil = BTAP::Resources::HVAC::Plant::add_hydronic_cool_coil(model, always_on)
              elsif(fan_coil_type == "TPFC")
                # heating coil
                fc_htg_coil = BTAP::Resources::HVAC::Plant::add_hydronic_heating_coil(model, tpfc_htg_availability_sch)

                # cooling coil
                fc_clg_coil = BTAP::Resources::HVAC::Plant::add_hydronic_cool_coil(model, tpfc_clg_availability_sch)
              end
          
              # connect heating coil to hot water loop
              hw_loop.addDemandBranchForComponent(fc_htg_coil)
              # connect cooling coil to chilled water loop
              chw_loop.addDemandBranchForComponent(fc_clg_coil)

              zone_fc = BTAP::Resources::HVAC::ZoneEquipment::add_zoneHVAC_fpfc(model, always_on, fc_fan, fc_clg_coil, fc_htg_coil)
              zone_fc.addToThermalZone(zone)

              # Create a diffuser and attach the zone/diffuser pair to the air loop (make-up air unit)
              diffuser = BTAP::Resources::HVAC::Plant::add_diffuser(model, always_on)
              air_loop.addBranchForZone(zone,diffuser.to_StraightComponent)

            end #zone loop

          end  # add_sys2_FPFC_sys5_TPFC

          def self.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating( model, zones, boiler_fueltype,  heating_coil_type, baseboard_type)
            # System Type 3: PSZ-AC
            # This measure creates:
            # -a constant volume packaged single-zone A/C unit
            # for each zone in the building; DX cooling with
            # heating coil: fuel-fired or electric, depending on argument heating_coil_type
            # heating_coil_type choices are "Electric", "Gas", "DX"
            # zone baseboards: hot water or electric, depending on argument baseboard_type
            # baseboard_type choices are "Hot Water" or "Electric"
            # boiler_fueltype choices match OS choices for Boiler component fuel type, i.e.
            # "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"


            always_on = model.alwaysOnDiscreteSchedule

            # Create a hot water loop (if baseboard type is hydronic); hot water baseboards will be connected to this loop

            if ( baseboard_type == "Hot Water" ) then

              hw_loop = BTAP::Resources::HVAC::Plant::add_water_loop(model)
              BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model,hw_loop,boiler_fueltype, always_on)

            end  #of if statement

            zones.each do |zone|

              air_loop = BTAP::Resources::HVAC::Plant::add_air_loop(model)


              air_loop.setName("#{zone.name} NECB System 3 PSZ")

              # When an air_loop is constructed, its constructor creates a sizing:system object
              # the default sizing:system constructor makes a system:sizing object
              # appropriate for a multizone VAV system
              # this systems is a constant volume system with no VAV terminals,
              # and therfore needs different default settings
              air_loop_sizing = air_loop.sizingSystem # TODO units
              air_loop_sizing.setTypeofLoadtoSizeOn("Sensible")
              air_loop_sizing.autosizeDesignOutdoorAirFlowRate
              air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
              air_loop_sizing.setPreheatDesignTemperature(7.0)
              air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
              air_loop_sizing.setPrecoolDesignTemperature(12.8)
              air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
              air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(12.8)
              air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(40.0)
              air_loop_sizing.setSizingOption("NonCoincident")
              air_loop_sizing.setAllOutdoorAirinCooling(false)
              air_loop_sizing.setAllOutdoorAirinHeating(false)
              air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
              air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
              air_loop_sizing.setCoolingDesignAirFlowMethod("DesignDay")
              air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
              air_loop_sizing.setHeatingDesignAirFlowMethod("DesignDay")
              air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
              air_loop_sizing.setSystemOutdoorAirMethod("ZoneSum")

              fan = BTAP::Resources::HVAC::Plant::add_const_fan(model, always_on)
                           

              case heating_coil_type
              when "Electric"           # electric coil
                htg_coil = BTAP::Resources::HVAC::Plant::add_elec_heating_coil(model,always_on)
              

              when "Gas"
                htg_coil = BTAP::Resources::HVAC::Plant::add_gas_heating_coil(model, always_on)
            

              when "DX"
                htg_coil = BTAP::Resources::HVAC::Plant::add_onespeed_DX_coil_heating(model, always_on)  
                supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model,always_on)
              else
                raise("#{heating_coil_type} is not a valid heating coil type.)")
              end

              #TO DO: other fuel-fired heating coil types? (not available in OpenStudio/E+ - may need to play with efficiency to mimic other fuel types)


            # Set up DX coil with NECB performance curve characteristics;

              clg_coil = BTAP::Resources::HVAC::Plant::add_onespeed_DX_coil(model,always_on)

              #oa_controller 
              oa_controller = BTAP::Resources::HVAC::Plant::add_oa_controller(model)
             

              #oa_system 
              oa_system = BTAP::Resources::HVAC::Plant::add_OA_system(model, oa_controller)

              # Add the components to the air loop
              # in order from closest to zone to furthest from zone
              supply_inlet_node = air_loop.supplyInletNode
              fan.addToNode(supply_inlet_node)
              supplemental_htg_coil.addToNode(supply_inlet_node) if heating_coil_type == "DX" 
              htg_coil.addToNode(supply_inlet_node)
              clg_coil.addToNode(supply_inlet_node)
              oa_system.addToNode(supply_inlet_node)

              # Add a setpoint manager single zone reheat to control the
              # supply air temperature based on the needs of this zone
              setpoint_mgr_single_zone_reheat = BTAP::Resources::HVAC::Plant::add_sz_reheat_setpoint(model)
              setpoint_mgr_single_zone_reheat.setControlZone(zone)
              setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(13.0)
              setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)


              #Create sensible heat exchanger
#              heat_exchanger = BTAP::Resources::HVAC::Plant::add_hrv(model)
#              heat_exchanger.setSensibleEffectivenessat100HeatingAirFlow(0.5)
#              heat_exchanger.setSensibleEffectivenessat75HeatingAirFlow(0.5)
#              heat_exchanger.setSensibleEffectivenessat100CoolingAirFlow(0.5)
#              heat_exchanger.setSensibleEffectivenessat75CoolingAirFlow(0.5)
#              heat_exchanger.setLatentEffectivenessat100HeatingAirFlow(0.0)
#              heat_exchanger.setLatentEffectivenessat75HeatingAirFlow(0.0)
#              heat_exchanger.setLatentEffectivenessat100CoolingAirFlow(0.0)
#              heat_exchanger.setLatentEffectivenessat75CoolingAirFlow(0.0)
#              heat_exchanger.setSupplyAirOutletTemperatureControl(false)
#
#              #Connect heat exchanger
#              oa_node = oa_system.outboardOANode
#              heat_exchanger.addToNode(oa_node.get)


              # Create a diffuser and attach the zone/diffuser pair to the air loop
              #diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model,always_on)
              diffuser = BTAP::Resources::HVAC::Plant::add_diffuser(model, always_on)
              air_loop.addBranchForZone(zone,diffuser.to_StraightComponent)

              if ( baseboard_type == "Electric") then

                #  zone_elec_baseboard = OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(model)
                zone_elec_baseboard = BTAP::Resources::HVAC::Plant::add_elec_baseboard(model)
                zone_elec_baseboard.addToThermalZone(zone)

              end

              if ( baseboard_type == "Hot Water") then
                baseboard_coil = BTAP::Resources::HVAC::Plant::add_hw_baseboard_coil(model)
                #Connect baseboard coil to hot water loop
                hw_loop.addDemandBranchForComponent(baseboard_coil)


                zone_baseboard = BTAP::Resources::HVAC::ZoneEquipment::add_zone_baseboard_convective_water(model, always_on, baseboard_coil)
                #add zone_baseboard to zone
                zone_baseboard.addToThermalZone(zone)
              end

            end  #zone loop


            return true
          end  #end add_sys3_single_zone_packaged_rooftop_unit_with_baseboard_heating

          def self.add_sys4_single_zone_make_up_air_unit_with_baseboard_heating( model, zones, boiler_fueltype, heating_coil_type, baseboard_type)
            # System Type 4: PSZ-AC
            # This measure creates:
            # -a constant volume packaged single-zone A/C unit
            # for each zone in the building; DX cooling with
            # heating coil: fuel-fired or electric, depending on argument heating_coil_type
            # heating_coil_type choices are "Electric", "Gas"
            # zone baseboards: hot water or electric, depending on argument baseboard_type
            # baseboard_type choices are "Hot Water" or "Electric"
            # boiler_fueltype choices match OS choices for Boiler component fuel type, i.e.
            # "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"
            # NOTE: This is the same as system type 3 (single zone make-up air unit and single zone rooftop unit are both PSZ systems)
            # SHOULD WE COMBINE sys3 and sys4 into one script?


            always_on = model.alwaysOnDiscreteSchedule

            # Create a hot water loop; hot water baseboards will be connected to this loop

            #TO DO: Include logic to determine whether baseboards should be hydronic or electric

            #Create hot water loop if baseboard type is hydronic

            if ( baseboard_type == "Hot Water" ) then

              hw_loop = BTAP::Resources::HVAC::Plant::add_water_loop(model)
              BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model,hw_loop,boiler_fueltype, always_on)

            end  #of if statement

            # Create a PSZ for each zone
            # TO DO: need to apply this system to space types:
            #(1) automotive area: repair/parking garage, fire engine room, indoor truck bay
            #(2) supermarket/food service: food preparation with kitchen hood/vented appliance
            #(3) warehouse area (non-refrigerated spaces)
          

            zones.each do |zone|

              air_loop = BTAP::Resources::HVAC::Plant::add_air_loop(model)


              air_loop.setName("#{zone.name} NECB System 4 PSZ")

              # When an air_loop is constructed, its constructor creates a sizing:system object
              # the default sizing:system constructor makes a system:sizing object
              # appropriate for a multizone VAV system
              # this systems is a constant volume system with no VAV terminals,
              # and therfore needs different default settings
              air_loop_sizing = air_loop.sizingSystem # TODO units
              air_loop_sizing.setTypeofLoadtoSizeOn("Sensible")
              air_loop_sizing.autosizeDesignOutdoorAirFlowRate
              air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
              air_loop_sizing.setPreheatDesignTemperature(7.0)
              air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
              air_loop_sizing.setPrecoolDesignTemperature(12.8)
              air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
              air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(12.8)
              air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(40.0)
              air_loop_sizing.setSizingOption("NonCoincident")
              air_loop_sizing.setAllOutdoorAirinCooling(false)
              air_loop_sizing.setAllOutdoorAirinHeating(false)
              air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
              air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
              air_loop_sizing.setCoolingDesignAirFlowMethod("DesignDay")
              air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
              air_loop_sizing.setHeatingDesignAirFlowMethod("DesignDay")
              air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
              air_loop_sizing.setSystemOutdoorAirMethod("ZoneSum")

              fan = BTAP::Resources::HVAC::Plant::add_const_fan(model, always_on)
                            

              if ( heating_coil_type == "Electric") then           # electric coil
                htg_coil = BTAP::Resources::HVAC::Plant::add_elec_heating_coil(model,always_on)
              end

              if ( heating_coil_type == "Gas") then
                htg_coil = BTAP::Resources::HVAC::Plant::add_gas_heating_coil(model, always_on)
              end

              #TO DO: other fuel-fired heating coil types? (not available in OpenStudio/E+ - may need to play with efficiency to mimic other fuel types)


            # Set up DX coil with NECB performance curve characteristics;

              clg_coil = BTAP::Resources::HVAC::Plant::add_onespeed_DX_coil(model,always_on)

              #oa_controller 
              oa_controller = BTAP::Resources::HVAC::Plant::add_oa_controller(model)
              


              #oa_system 
              oa_system = BTAP::Resources::HVAC::Plant::add_OA_system(model, oa_controller)

              # Add the components to the air loop
              # in order from closest to zone to furthest from zone
              supply_inlet_node = air_loop.supplyInletNode
              fan.addToNode(supply_inlet_node)
              htg_coil.addToNode(supply_inlet_node)
              clg_coil.addToNode(supply_inlet_node)
              oa_system.addToNode(supply_inlet_node)

              # Add a setpoint manager single zone reheat to control the
              # supply air temperature based on the needs of this zone
              setpoint_mgr_single_zone_reheat = BTAP::Resources::HVAC::Plant::add_sz_reheat_setpoint(model)
              setpoint_mgr_single_zone_reheat.setControlZone(zone)
              setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(13.0)
              setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)


              #Create sensible heat exchanger
#              heat_exchanger = BTAP::Resources::HVAC::Plant::add_hrv(model)
#              heat_exchanger.setSensibleEffectivenessat100HeatingAirFlow(0.5)
#              heat_exchanger.setSensibleEffectivenessat75HeatingAirFlow(0.5)
#              heat_exchanger.setSensibleEffectivenessat100CoolingAirFlow(0.5)
#              heat_exchanger.setSensibleEffectivenessat75CoolingAirFlow(0.5)
#              heat_exchanger.setLatentEffectivenessat100HeatingAirFlow(0.0)
#              heat_exchanger.setLatentEffectivenessat75HeatingAirFlow(0.0)
#              heat_exchanger.setLatentEffectivenessat100CoolingAirFlow(0.0)
#              heat_exchanger.setLatentEffectivenessat75CoolingAirFlow(0.0)
#              heat_exchanger.setSupplyAirOutletTemperatureControl(false)
#
#              Connect heat exchanger
#              oa_node = oa_system.outboardOANode
#              heat_exchanger.addToNode(oa_node.get)


              # Create a diffuser and attach the zone/diffuser pair to the air loop
              #diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model,always_on)
              diffuser = BTAP::Resources::HVAC::Plant::add_diffuser(model, always_on)
              air_loop.addBranchForZone(zone,diffuser.to_StraightComponent)

              if ( baseboard_type == "Electric") then

                #  zone_elec_baseboard = OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(model)
                zone_elec_baseboard = BTAP::Resources::HVAC::Plant::add_elec_baseboard(model)
                zone_elec_baseboard.addToThermalZone(zone)

              end

              if ( baseboard_type == "Hot Water") then
                baseboard_coil = BTAP::Resources::HVAC::Plant::add_hw_baseboard_coil(model)
                #Connect baseboard coil to hot water loop
                hw_loop.addDemandBranchForComponent(baseboard_coil)


                zone_baseboard = BTAP::Resources::HVAC::ZoneEquipment::add_zone_baseboard_convective_water(model, always_on, baseboard_coil)
                #add zone_baseboard to zone
                zone_baseboard.addToThermalZone(zone)
              end

            end  #zone loop


            return true
          end  #end add_sys4_single_zone_make_up_air_unit_with_baseboard_heating

          def self.add_sys6_multi_zone_built_up_system_with_baseboard_heating( model ,zones,  boiler_fueltype, heating_coil_type, baseboard_type, chiller_type, fan_type )

            # System Type 6: VAV w/ Reheat
            # This measure creates:
            # a single hot water loop with a natural gas or electric boiler or for the building
            # a single chilled water loop with water cooled chiller for the building
            # a single condenser water loop for heat rejection from the chiller
            # a VAV system w/ hot water or electric heating, chilled water cooling, and
            # hot water or electric reheat for each story of the building
            # Arguments:
            # "boiler_fueltype" choices match OS choices for boiler fuel type: 
            # "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"
            # "heating_coil_type": "Electric" or "Hot Water"
            # "baseboard_type": "Electric" and "Hot Water"
            # "chiller_type": "Scroll";"Centrifugal";""Screw";"Reciprocating"
            # "fan_type": "AF_or_BI_rdg_fancurve";"AF_or_BI_inletvanes";"fc_inletvanes";"var_speed_drive"  

            always_on = model.alwaysOnDiscreteSchedule

            #Create hot water loop if baseboard or heating coil type is hydronic

            if ( baseboard_type == "Hot Water" ) || ( heating_coil_type == "Hot Water") then

              hw_loop = BTAP::Resources::HVAC::Plant::add_water_loop(model)
              BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model,hw_loop,boiler_fueltype, always_on)

            end  #of if statement

            # Chilled Water Plant

            chw_loop = BTAP::Resources::HVAC::Plant::add_water_loop(model)
            chiller = BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_chw_loop_with_components(model,chw_loop,chiller_type)

            # Condenser System

            cw_loop = BTAP::Resources::HVAC::Plant::add_water_loop(model)
            ctower = BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_cw_loop_with_components(model,cw_loop,chiller)
            
            # Make a Packaged VAV w/ PFP Boxes for each story of the building
            model.getBuildingStorys.sort.each do |story|
              if not ( BTAP::Geometry::BuildingStoreys::get_zones_from_storey(story) & zones).empty?

              air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
              air_loop.setName("VAV with Reheat")
              sizingSystem = air_loop.sizingSystem
              sizingSystem.setCentralCoolingDesignSupplyAirTemperature(13.0)
              sizingSystem.setCentralHeatingDesignSupplyAirTemperature(13.0)

              fan = OpenStudio::Model::FanVariableVolume.new(model,always_on)
              fan.setPressureRise(1000)
              fan.setFanEfficiency(0.55)
              fan.setFanPowerMinimumFlowRateInputMethod("Fraction")
              fan.setFanPowerCoefficient4(0.0)
              fan.setFanPowerCoefficient5(0.0)
              if(fan_type == "AF_or_BI_rdg_fancurve")
                fan.setFanPowerMinimumFlowFraction(0.47)
                fan.setFanPowerCoefficient1(0.227143)
                fan.setFanPowerCoefficient2(1.178929)
                fan.setFanPowerCoefficient3(-0.41071)
              elsif(fan_type == "AF_or_BI_inletvanes")
                fan.setFanPowerMinimumFlowFraction(0.35)
                fan.setFanPowerCoefficient1(0.584345)
                fan.setFanPowerCoefficient2(-0.57917)
                fan.setFanPowerCoefficient3(0.970238)
              elsif(fan_type == "fc_inletvanes")
                fan.setFanPowerMinimumFlowFraction(0.25)
                fan.setFanPowerCoefficient1(0.339619)
                fan.setFanPowerCoefficient2(-0.84814)
                fan.setFanPowerCoefficient3(1.495671)
              elsif(fan_type == "var_speed_drive")
                fan.setFanPowerMinimumFlowFraction(0.20)
                fan.setFanPowerCoefficient1(0.00153028)
                fan.setFanPowerCoefficient2(0.00520806)
                fan.setFanPowerCoefficient3(1.0086242)
              end
              htg_coil = OpenStudio::Model::CoilHeatingWater.new(model,always_on)
              hw_loop.addDemandBranchForComponent(htg_coil)

              clg_coil = OpenStudio::Model::CoilCoolingWater.new(model,always_on)
              chw_loop.addDemandBranchForComponent(clg_coil)

              oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)

              oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model,oa_controller)

              # Add the components to the air loop
              # in order from closest to zone to furthest from zone
              # TODO: still need to define the return fan (tried to access the air loop "returnAirNode" without success)
              # TODO: The OS sdk indicates that this keyword should be active but I get a "Not implemented" error when I
              # TODO: try to access it through "air_loop.returnAirNode"
              supply_inlet_node = air_loop.supplyInletNode
              supply_outlet_node = air_loop.supplyOutletNode
              fan.addToNode(supply_inlet_node)
              htg_coil.addToNode(supply_inlet_node)
              clg_coil.addToNode(supply_inlet_node)
              oa_system.addToNode(supply_inlet_node)
              
#              return_inlet_node = air_loop.returnAirNode

              # Add a setpoint manager to control the
              # supply air to a constant temperature
              sat_c = 13.0
              sat_sch = OpenStudio::Model::ScheduleRuleset.new(model)
              sat_sch.setName("Supply Air Temp")
              sat_sch.defaultDaySchedule().setName("Supply Air Temp Default")
              sat_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),sat_c)
              sat_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model,sat_sch)
              sat_stpt_manager.addToNode(supply_outlet_node)

              # TO-do ask Kamel about zonal assignments per storey. 

              # Make a VAV terminal with HW reheat for each zone on this story that is in instersection with the zones array. 
              # and hook the reheat coil to the HW loop
              ( BTAP::Geometry::BuildingStoreys::get_zones_from_storey(story) & zones).each do |zone|
                if(heating_coil_type == "Hot Water")
                  reheat_coil = OpenStudio::Model::CoilHeatingWater.new(model,always_on)
                elsif(heating_coil_type == "Electric")
                  reheat_coil = OpenStudio::Model::CoilHeatingElectric.new(model,always_on)
                end
                hw_loop.addDemandBranchForComponent(reheat_coil)
                vav_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model,always_on,reheat_coil)
                air_loop.addBranchForZone(zone,vav_terminal.to_StraightComponent)
                vav_terminal.setZoneMinimumAirFlowMethod("FixedFlowRate")
                #TODO: currently the minimum flow rate is set to 2 L/s-m2. In fact we need to create a minimum flow rate
                #TODO: schedule based on whether the zone is occupied or not as stipulated in 8.4.4.22 of NECB2011
                min_flow_rate = 0.002*zone.floorArea
                vav_terminal.setFixedMinimumAirFlowRate(min_flow_rate) 
              end
            end
            end # next story

            return true

          end

          def self.setup_hw_loop_with_components(model,hw_loop,boiler_fueltype,pump_flow_sch)

            hw_loop.setName("Hot Water Loop")
            sizing_plant = hw_loop.sizingPlant
            sizing_plant.setLoopType("Heating")
            sizing_plant.setDesignLoopExitTemperature(82.0) #TODO units
            sizing_plant.setLoopDesignTemperatureDifference(16.0)

            #pump 
            pump = BTAP::Resources::HVAC::Plant::add_pump_const_speed(model)
            #TODO: the keyword "setPumpFlowRateSchedule" does not seem to work. A message
            #was sent to NREL to let them know about this. Once there is a fix for this,
            #use the proper pump schedule depending on whether we have two-pipe or four-pipe
            #fan coils.
#            pump.resetPumpFlowRateSchedule()
#            pump.setPumpFlowRateSchedule(pump_flow_sch)

            #boiler 
            boiler = BTAP::Resources::HVAC::Plant::add_hw_boiler(model)                     
            boiler.setFuelType(boiler_fueltype)

            #boiler_bypass_pipe 
            boiler_bypass_pipe = BTAP::Resources::HVAC::Plant::add_adiabatic_pipe(model)

            #supply_outlet_pipe 
            supply_outlet_pipe = BTAP::Resources::HVAC::Plant::add_adiabatic_pipe(model)

            # Add the components to the hot water loop
            hw_supply_inlet_node = hw_loop.supplyInletNode
            hw_supply_outlet_node = hw_loop.supplyOutletNode
            pump.addToNode(hw_supply_inlet_node)

            hw_loop.addSupplyBranchForComponent(boiler)
            hw_loop.addSupplyBranchForComponent(boiler_bypass_pipe)
            supply_outlet_pipe.addToNode(hw_supply_outlet_node)

            # Add a setpoint manager to control the
            # hot water based on outdoor temperature
            hw_oareset_stpt_manager = BTAP::Resources::HVAC::Plant::add_oareset_setpoint_mgr(model)
            hw_oareset_stpt_manager.setControlVariable("Temperature")
            hw_oareset_stpt_manager.setSetpointatOutdoorLowTemperature(82.0)
            hw_oareset_stpt_manager.setOutdoorLowTemperature(-16.0)
            hw_oareset_stpt_manager.setSetpointatOutdoorHighTemperature(60.0)
            hw_oareset_stpt_manager.setOutdoorHighTemperature(0.0)
            hw_oareset_stpt_manager.addToNode(hw_supply_outlet_node)

          end  #of setup_hw_loop_with_components

          def self.setup_chw_loop_with_components(model,chw_loop,chiller_type)

            chw_loop.setName("Chilled Water Loop")
            sizing_plant = chw_loop.sizingPlant
            sizing_plant.setLoopType("Cooling")
            sizing_plant.setDesignLoopExitTemperature(7.0)
            sizing_plant.setLoopDesignTemperatureDifference(6.0)       

            #pump = OpenStudio::Model::PumpConstantSpeed.new(model)
            chw_pump = BTAP::Resources::HVAC::Plant::add_pump_const_speed(model)

            clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
            eir_f_of_avail_to_nom_cap = OpenStudio::Model::CurveBiquadratic.new(model)
            eir_f_of_plr = OpenStudio::Model::CurveQuadratic.new(model)

            chiller = BTAP::Resources::HVAC::Plant::add_elec_chiller(model,
            clg_cap_f_of_temp,eir_f_of_avail_to_nom_cap,eir_f_of_plr)
            # update name so it's in agreement with method used in Standards file
            chiller.setCondenserType("WaterCooled")
            chiller_name = chiller.name.to_s + " WaterCooled #{chiller_type}"
            chiller.setName(chiller_name)

            chiller_bypass_pipe = BTAP::Resources::HVAC::Plant::add_adiabatic_pipe(model)

            chw_supply_outlet_pipe = BTAP::Resources::HVAC::Plant::add_adiabatic_pipe(model)

            # Add the components to the chilled water loop
            chw_supply_inlet_node = chw_loop.supplyInletNode
            chw_supply_outlet_node = chw_loop.supplyOutletNode
            chw_pump.addToNode(chw_supply_inlet_node)
            chw_loop.addSupplyBranchForComponent(chiller)
            chw_loop.addSupplyBranchForComponent(chiller_bypass_pipe)
            chw_supply_outlet_pipe.addToNode(chw_supply_outlet_node)

            # Add a setpoint manager to control the
            # chilled water to a constant temperature
            chw_t_c = 7.0
            chw_t_sch = BTAP::Resources::Schedules::create_annual_constant_ruleset_schedule(model, "CHW Temp", "Temperature", chw_t_c)
            chw_t_stpt_manager = BTAP::Resources::HVAC::Plant::add_sched_setpoint_mgr(model,chw_t_sch)
            chw_t_stpt_manager.addToNode(chw_supply_outlet_node)

            return chiller

          end #of setup_chw_loop_with_components

          def self.setup_cw_loop_with_components(model,cw_loop,chiller)

            cw_loop.setName("Condenser Water Loop")
            cw_sizing_plant = cw_loop.sizingPlant
            cw_sizing_plant.setLoopType("Condenser")
            cw_sizing_plant.setDesignLoopExitTemperature(29.0)
            cw_sizing_plant.setLoopDesignTemperatureDifference(6.0)

            cw_pump = BTAP::Resources::HVAC::Plant::add_pump_const_speed(model)

            clg_tower = BTAP::Resources::HVAC::Plant::add_1speed_cooling_tower(model)

            # TO DO: Need to define and set cooling tower curves

            clg_tower_bypass_pipe = BTAP::Resources::HVAC::Plant::add_adiabatic_pipe(model)

            cw_supply_outlet_pipe = BTAP::Resources::HVAC::Plant::add_adiabatic_pipe(model)

            # Add the components to the condenser water loop
            cw_supply_inlet_node = cw_loop.supplyInletNode
            cw_supply_outlet_node = cw_loop.supplyOutletNode
            cw_pump.addToNode(cw_supply_inlet_node)
            cw_loop.addSupplyBranchForComponent(clg_tower)
            cw_loop.addSupplyBranchForComponent(clg_tower_bypass_pipe)
            cw_supply_outlet_pipe.addToNode(cw_supply_outlet_node)
            cw_loop.addDemandBranchForComponent(chiller)

            # Add a setpoint manager to control the
            # condenser water to constant temperature
            cw_t_c = 29.0
            cw_t_sch = BTAP::Resources::Schedules::create_annual_constant_ruleset_schedule(model, "CW Temp", "Temperature", cw_t_c)
            cw_t_stpt_manager = BTAP::Resources::HVAC::Plant::add_sched_setpoint_mgr(model, cw_t_sch)
            cw_t_stpt_manager.addToNode(cw_supply_outlet_node)

            return clg_tower

          end

        end

      end # module HVACTemplates
      
    end #module HVAC

  end #module Resources
end
