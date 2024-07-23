module OpenstudioStandards
  # The ServiceWaterHeating module provides methods to create, modify, and get information about service water heating
  module ServiceWaterHeating
    # @!group Create Component
    # Methods to add service water heating components

    # Creates a water heater and attaches it to the supplied service water heating loop.
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param water_heater_capacity [Double] water heater capacity, in W. Defaults to 58.6 kW / 200 kBtu/hr
    # @param water_heater_volume [Double] water heater volume, in m^3. Defaults to 0.378 m^3 / 100 gal
    # @param water_heater_fuel [String] water heating fuel. Valid choices are 'NaturalGas', 'Electricity', or 'HeatPump'
    # @param on_cycle_parasitic_fuel_consumption_rate [Double] water heater on cycle parasitic fuel consumption rate, in W
    # @param off_cycle_parasitic_fuel_consumption_rate [Double] water heater off cycle parasitic fuel consumption rate, in W
    # @param service_water_temperature [Double] water heater temperature, in degrees C. Default is 60 C / 140 F.
    # @param service_water_temperature_schedule [OpenStudio::Model::Schedule] the service water heating schedule.
    #   If nil, will be defaulted to a constant temperature schedule based on the service_water_temperature
    # @param set_peak_use_flowrate [Boolean] if true, the peak flow rate and flow rate schedule will be set.
    # @param peak_flowrate [Double] peak flow rate in m^3/s
    # @param flowrate_schedule [OpenStudio::Model::Schedule] the flow rate fraction scehdulename of the flow rate schedule
    # @param water_heater_thermal_zone [OpenStudio::Model::ThermalZone] Thermal zone for ambient heat loss.
    #   If nil, will assume 71.6 F / 22 C ambient air temperature.
    # @param number_water_heaters [Integer] the number of water heaters represented by the capacity and volume inputs.
    #   Used to modify efficiencies for water heaters based on individual component size while avoiding having to model
    #   lots of individual water heaters (for runtime sake).
    # @param service_water_loop [OpenStudio::Model::PlantLoop] if provided, add the water heater to this loop
    # @return [OpenStudio::Model::WaterHeaterMixed] OpenStudio WaterHeaterMixed object
    def self.model_add_water_heater(model,
                                    water_heater_capacity: nil,
                                    water_heater_volume: nil,
                                    water_heater_fuel: 'Electricity',
                                    on_cycle_parasitic_fuel_consumption_rate: 0.0,
                                    off_cycle_parasitic_fuel_consumption_rate: 0.0,
                                    service_water_temperature: 60.0,
                                    service_water_temperature_schedule: nil,
                                    set_peak_use_flowrate: false,
                                    peak_flowrate: nil,
                                    flowrate_schedule: nil,
                                    water_heater_thermal_zone: nil,
                                    number_water_heaters: 1,
                                    service_water_loop: nil)
      # create water heater object
      # @todo Standards - Change water heater methodology to follow 'Model Enhancements Appendix A.'
      water_heater = OpenStudio::Model::WaterHeaterMixed.new(model)

      # default water heater capacity if nil
      if water_heater_capacity.nil?
        water_heater_capacity = OpenStudio.convert(200.0, 'kBtu/hr', 'W').get
      end
      water_heater_capacity_kbtu_per_hr = OpenStudio.convert(water_heater_capacity, 'W', 'kBtu/hr').get
      water_heater.setHeaterMaximumCapacity(water_heater_capacity)

      # default water heater volume if nil
      if water_heater_volume.nil?
        water_heater_volume = OpenStudio.convert(100.0, 'gal', 'm^3').get
      end
      water_heater_volume_gal = OpenStudio.convert(water_heater_volume, 'm^3', 'gal').get
      water_heater.setTankVolume(water_heater_volume)

      # set the water heater fuel
      case water_heater_fuel
      when 'Natural Gas', 'NaturalGas', 'Gas'
        water_heater.setHeaterFuelType('Gas')
        water_heater.setHeaterThermalEfficiency(0.78)
        water_heater.setOnCycleParasiticFuelConsumptionRate(on_cycle_parasitic_fuel_consumption_rate)
        water_heater.setOffCycleParasiticFuelConsumptionRate(off_cycle_parasitic_fuel_consumption_rate)
        water_heater.setOnCycleParasiticFuelType('Gas')
        water_heater.setOffCycleParasiticFuelType('Gas')
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(6.0)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(6.0)
      when 'Electricity', 'Electric', 'Elec'
        water_heater.setHeaterFuelType('Electricity')
        water_heater.setHeaterThermalEfficiency(1.0)
        water_heater.setOnCycleParasiticFuelConsumptionRate(on_cycle_parasitic_fuel_consumption_rate)
        water_heater.setOffCycleParasiticFuelConsumptionRate(off_cycle_parasitic_fuel_consumption_rate)
        water_heater.setOnCycleParasiticFuelType('Electricity')
        water_heater.setOffCycleParasiticFuelType('Electricity')
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.053)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.053)
      when 'FuelOilNo2'
        water_heater.setHeaterFuelType('FuelOilNo2')
        water_heater.setHeaterThermalEfficiency(0.78)
        water_heater.setOnCycleParasiticFuelConsumptionRate(on_cycle_parasitic_fuel_consumption_rate)
        water_heater.setOffCycleParasiticFuelConsumptionRate(off_cycle_parasitic_fuel_consumption_rate)
        water_heater.setOnCycleParasiticFuelType('FuelOilNo2')
        water_heater.setOffCycleParasiticFuelType('FuelOilNo2')
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(6.0)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(6.0)
      when 'HeatPump', 'SimpleHeatPump'
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Model.Model', 'Simple workaround to represent heat pump water heaters without incurring significant runtime penalty associated with using correct objects.')
        # Make a part-load efficiency modifier curve with a value above 1, which is multiplied by the nominal efficiency of 100% to represent the COP of a HPWH.
        # @todo could make this workaround better by using EMS to modify this curve output in realtime based on the OA temperature.
        hpwh_cop = 2.8
        water_heater.setHeaterFuelType('Electricity')
        water_heater.setHeaterThermalEfficiency(1.0)
        eff_f_of_plr = OpenStudio::Model::CurveCubic.new(model)
        eff_f_of_plr.setName("HPWH_COP_#{hpwh_cop}")
        eff_f_of_plr.setCoefficient1Constant(hpwh_cop)
        eff_f_of_plr.setCoefficient2x(0.0)
        eff_f_of_plr.setCoefficient3xPOW2(0.0)
        eff_f_of_plr.setCoefficient4xPOW3(0.0)
        eff_f_of_plr.setMinimumValueofx(0.0)
        eff_f_of_plr.setMaximumValueofx(1.0)
        water_heater.setPartLoadFactorCurve(eff_f_of_plr)
        water_heater.setOnCycleParasiticFuelConsumptionRate(on_cycle_parasitic_fuel_consumption_rate)
        water_heater.setOffCycleParasiticFuelConsumptionRate(off_cycle_parasitic_fuel_consumption_rate)
        water_heater.setOnCycleParasiticFuelType('Electricity')
        water_heater.setOffCycleParasiticFuelType('Electricity')
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.053)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.053)
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "#{water_heater_fuel} is not a valid water heater fuel.  Valid choices are NaturalGas, Electricity, and HeatPump.")
      end

      # set water temperature properties
      water_heater.setDeadbandTemperatureDifference(2.0)
      water_heater.setDeadbandTemperatureDifference(OpenStudio.convert(3.6, 'R', 'K').get)
      water_heater.setHeaterControlType('Cycle')
      water_heater.setOffCycleParasiticHeatFractiontoTank(0.8)
      water_heater.setIndirectWaterHeatingRecoveryTime(1.5) # 1.5hrs

      # get or create temperature schedule type limits
      temp_sch_type_limits = OpenstudioStandards::Schedules.create_schedule_type_limits(model,
                                                                                        name: 'Temperature Schedule Type Limits',
                                                                                        lower_limit_value: 0.0,
                                                                                        upper_limit_value: 100.0,
                                                                                        numeric_type: 'Continuous',
                                                                                        unit_type: 'Temperature')

      # create service water temperature schedule based on the service_water_temperature if none provided
      if service_water_temperature_schedule.nil?
        swh_temp_c = service_water_temperature
        swh_temp_f = OpenStudio.convert(swh_temp_c, 'C', 'F').get
        service_water_temperature_schedule = OpenstudioStandards::Schedules.create_constant_schedule_ruleset(model,
                                                                                                             swh_temp_c,
                                                                                                             name: "Service Water Loop Temp - #{swh_temp_f.round}F",
                                                                                                             schedule_type_limit: 'Temperature')
        service_water_temperature_schedule.setScheduleTypeLimits(temp_sch_type_limits)
      end
      water_heater.setMaximumTemperatureLimit(service_water_temperature)
      water_heater.setSetpointTemperatureSchedule(service_water_temperature_schedule)

      # set peak flow rate characteristics
      if set_peak_use_flowrate
        water_heater.setPeakUseFlowRate(peak_flowrate) unless peak_flowrate.nil?
        water_heater.setUseFlowRateFractionSchedule(flowrate_schedule) unless flowrate_schedule.nil?
      end

      # set the water heater ambient conditions
      if water_heater_thermal_zone.nil?
        # assume the water heater is indoors at 71.6F / 22C
        indoor_temp_f = 71.6
        indoor_temp_c = OpenStudio.convert(indoor_temp_f, 'F', 'C').get
        default_water_heater_ambient_temp_sch = OpenstudioStandards::Schedules.create_constant_schedule_ruleset(model,
                                                                                                                indoor_temp_c,
                                                                                                                name: "Water Heater Ambient Temp Schedule - #{indoor_temp_f} F",
                                                                                                                schedule_type_limit: 'Temperature')
        default_water_heater_ambient_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)
        water_heater.setAmbientTemperatureIndicator('Schedule')
        water_heater.setAmbientTemperatureSchedule(default_water_heater_ambient_temp_sch)
        water_heater.resetAmbientTemperatureThermalZone
      else
        water_heater.setAmbientTemperatureIndicator('ThermalZone')
        water_heater.setAmbientTemperatureThermalZone(water_heater_thermal_zone)
        water_heater.resetAmbientTemperatureSchedule
      end

      # assign a quantity to the water heater if it represents multiple water heaters
      if number_water_heaters > 1
        water_heater.setName("#{number_water_heaters}X #{(water_heater_volume_gal / number_water_heaters).round}gal #{water_heater_fuel} Water Heater - #{(water_heater_capacity_kbtu_per_hr / number_water_heaters).round}kBtu/hr")
        water_heater.additionalProperties.setFeature('component_quantity', number_water_heaters)
      else
        water_heater.setName("#{water_heater_volume_gal.round}gal #{water_heater_fuel} Water Heater - #{water_heater_capacity_kbtu_per_hr.round}kBtu/hr")
      end

      # add the water heater to the service water loop if provided
      unless service_water_loop.nil?
        service_water_loop.addSupplyBranchForComponent(water_heater)
      end

      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ServiceWaterHeating.Create', "Added water heater called #{water_heater.name}")

      return water_heater
    end


    # @!endgroup Create Component
  end
end