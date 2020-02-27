class NRELZNEReady2017 < ASHRAE901
  # @!group PlantLoop

  # But actually it's completely irrelevant... you could set at 0.9 and just calculate the pressurise rise to have your 19 W/GPM or whatever
  def plant_loop_apply_standard_pump_power(plant_loop)
    # Determine the pumping power per
    # flow based on loop type.
    pri_w_per_gpm = nil
    sec_w_per_gpm = nil

    sizing_plant = plant_loop.sizingPlant
    loop_type = sizing_plant.loopType

    case loop_type
    when 'Heating'

      has_district_heating = false
      plant_loop.supplyComponents.each do |sc|
        if sc.to_DistrictHeating.is_initialized
          has_district_heating = true
        end
      end

      pri_w_per_gpm = if has_district_heating # District HW
                        14.0
                      else # HW
                        19.0
                      end

    when 'Cooling'
      has_district_cooling = false
      plant_loop.supplyComponents.each do |sc|
        if sc.to_DistrictCooling.is_initialized
          has_district_cooling = true
        end
      end

      has_secondary_pump = false
      plant_loop.demandComponents.each do |sc|
        if sc.to_PumpConstantSpeed.is_initialized || sc.to_PumpVariableSpeed.is_initialized
          has_secondary_pump = true
        end
      end

      if has_district_cooling # District CHW
        pri_w_per_gpm = 16.0
      elsif has_secondary_pump # Primary/secondary CHW
        pri_w_per_gpm = 9.0
        sec_w_per_gpm = 13.0
      else # Primary only CHW
        pri_w_per_gpm = 22.0
      end

    when 'Condenser'
      pri_w_per_gpm = 19.0

    end

    # Modify all the primary pumps
    plant_loop.supplyComponents.each do |sc|
      if sc.to_PumpConstantSpeed.is_initialized
        pump = sc.to_PumpConstantSpeed.get
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, pri_w_per_gpm)
      elsif sc.to_PumpVariableSpeed.is_initialized
        pump = sc.to_PumpVariableSpeed.get
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, pri_w_per_gpm)
      elsif sc.to_HeaderedPumpsConstantSpeed.is_initialized
        pump = sc.to_HeaderedPumpsConstantSpeed.get
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, pri_w_per_gpm)
      elsif sc.to_HeaderedPumpsVariableSpeed.is_initialized
        pump = sc.to_HeaderedPumpsVariableSpeed.get
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, pri_w_per_gpm)
      end
    end

    # Modify all the secondary pumps
    plant_loop.demandComponents.each do |sc|
      if sc.to_PumpConstantSpeed.is_initialized
        pump = sc.to_PumpConstantSpeed.get
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, sec_w_per_gpm)
      elsif sc.to_PumpVariableSpeed.is_initialized
        pump = sc.to_PumpVariableSpeed.get
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, sec_w_per_gpm)
      elsif sc.to_HeaderedPumpsConstantSpeed.is_initialized
        pump = sc.to_HeaderedPumpsConstantSpeed.get
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, pri_w_per_gpm)
      elsif sc.to_HeaderedPumpsVariableSpeed.is_initialized
        pump = sc.to_HeaderedPumpsVariableSpeed.get
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, pri_w_per_gpm)
      end
    end

    return true
  end

end
