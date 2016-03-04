
# A variety of fan calculation methods that are the same regardless of fan type.
# These methods are available to FanConstantVolume, FanOnOff, FanVariableVolume, and FanZoneExhaust
module Pump




  def set_pump_head_and_motor_eff(target_w_per_gpm, template)
    # Todo: @jmarrec's implementation. I tested it and it does work unlike set_pump_power_per_flow
    # Eplus assumes an impeller efficiency of 0.78 to determine the total efficiency
    # http://bigladdersoftware.com/epx/docs/8-4/engineering-reference/component-sizing.html#pump-sizing
    # Rated_Power_Use = Rated_Volume_Flow_Rate * Rated_Pump_Head / Total_Efficiency
    # Rated_Power_Use / Rated_Volume_Flow_Rate =  Rated_Pump_Head / Total_Efficiency
    # Total_Efficiency = Motor_Efficiency * Impeler_Efficiency

    impeller_efficiency = 0.78

    # Get the horsepower
    hp = self.horsepower

    # Find the motor efficiency
    motor_efficiency = standard_minimum_motor_efficiency(template, hp)

    # Change the motor efficiency
    self.setMotorEfficiency(motor_efficiency)

    total_efficiency = impeller_efficiency * motor_efficiency

    desired_power_per_m3_s = OpenStudio::convert(target_w_per_gpm,'W*min/gal', 'W*s/m^3').get

    pressure_rise_pa = desired_power_per_m3_s * total_efficiency
    pressure_rise_ft_h2O = OpenStudio::convert(pressure_rise_pa,'Pa','ftH_{2}O').get

    # Change pressure rise
    self.setRatedPumpHead(pressure_rise_pa)

    # Report
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Pump', "For #{self.name}: allowed hp = #{hp.round(2)}HP; motor eff = #{(motor_efficiency*100).round(2)}%; Pressure drop = #{pressure_rise_pa.round(0)} Pa // #{pressure_rise_ft_h2O.round(2)} ftH_{2}O")

    return true

  end

  # Set the pressure rise that cooresponds to the
  # target power per flow number, given a specified 
  # pump efficiency and optionally a water type (to determine density).
  #
  # @param target_w_per_gpm [Double] the target power per flow, in W/gpm
  # @param pump_eff [Double] the pump efficieny as a decimal
  # @param water_type [String] valid choices are Cooling, Heating, Condenser.
  #   This argument modifies the density of the water, changing the result slightly.
  # @return [Bool] return true if successful, false if not
  def set_pump_power_per_flow(target_w_per_gpm, pump_eff, water_type='Cooling')
    
    # Get the pressure rise
    pressure_rise_pa = self.pressure_for_target_power_per_flow(target_w_per_gpm, pump_eff, water_type)

    # Set the pressure rise
    self.setRatedPumpHead(pressure_rise_pa)

    return true
    
  end

  # Determine the pressure rise that cooresponds to the
  # target power per flow number, given a specified 
  # pump efficiency and optionally a water type (to determine density).
  #
  # @param target_w_per_gpm [Double] the target power per flow, in W/gpm
  # @param pump_eff [Double] the pump efficieny as a decimal
  # @param water_type [String] valid choices are Cooling, Heating, Condenser.
  #   This argument modifies the density of the water, changing the result slightly.
  # @return [Double] the pressure rise, in Pa
  # Todo: this implementation doesn't appear correct to me, and rated W/GPM outputed for my test model seems to confirm that
  def pressure_for_target_power_per_flow(target_w_per_gpm, pump_eff, water_type='Cooling')
    
    # Determine the density of water in lb/gal
    density_water_lb_per_gal = nil
    case water_type
    when 'Cooling'
      density_water_lb_per_gal = 8.345 # at 44F
    when 'Condenser'
      density_water_lb_per_gal = 8.31 # at 85F
    when 'Heating'
      density_water_lb_per_gal = 8.098 # at 180F
    end

    # Calculate the pressure rise that achieves the
    # target power per flow.
    pressure_rise_ft = target_w_per_gpm * (33000.0 * pump_eff)/(745.7 * density_water_lb_per_gal)

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Pump', "For #{self.name}: #{target_w_per_gpm.round} W/gpm translates to a pressure rise of #{pressure_rise_ft.round} ft of water at pump eff = #{(pump_eff*100).round(2)}% .")
    
    pressure_rise_pa = OpenStudio.convert(pressure_rise_ft, 'ftH_{2}O', 'Pa').get
    
    return pressure_rise_pa

  end
  
  def set_standard_minimum_motor_efficiency(template)
    
    # Get the horsepower
    hp = self.horsepower
    
    # Find the motor efficiency
    motor_eff = standard_minimum_motor_efficiency(template, hp)

    # Change the motor efficiency
    self.setMotorEfficiency(motor_eff)
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Pump', "For #{self.name}: allowed hp = #{hp.round(2)}HP; motor eff = #{(motor_eff*100).round(2)}%.")
    
    return true    
  
  end

  # Determines the minimum pump motor efficiency 
  # for a given motor bhp.  This should be the total brake horsepower with
  # any desired safety factor already included.
  #
  # @param motor_bhp [Double] motor brake horsepower (hp)
  # @return [Double] minimum motor efficiency (0.0 to 1.0)
  def standard_minimum_motor_efficiency(template, motor_bhp)
  
    motor_eff = 0.85
  
    # Lookup the minimum motor efficiency
    motors = $os_standards["motors"]
    
    # Assuming all fan motors are 4-pole ODP
    search_criteria = {
      "template" => template,
      "number_of_poles" => 4.0,
      "type" => "Enclosed",
    }
    
    motor_properties = self.model.find_object(motors, search_criteria, motor_bhp)
    if motor_properties.nil?
      OpenStudio::logFree(OpenStudio::Error, "openstudio.standards.Pump", "For #{self.name}, could not find motor properties using search criteria: #{search_criteria}, motor_bhp = #{motor_bhp} hp.")
      return motor_eff
    end
 
    motor_eff = motor_properties["nominal_full_load_efficiency"]
    
    return motor_eff
  
  end 
 
  # Determines the horsepower of the pump
  # based on fan power and fan motor efficiency.
  # 
  # @return [Double] brake horsepower
  #   @units horsepower (hp)  
  def horsepower()
  
    # Get design power (whether autosized or hard-sized)
    rated_power_w = 0
    if self.autosizedRatedPowerConsumption.is_initialized
      rated_power_w = self.autosizedRatedPowerConsumption.get
    elsif self.ratedPowerConsumption.is_initialized
      rated_power_w = self.ratedPowerConsumption.get
    else
      OpenStudio::logFree(OpenStudio::Error, "openstudio.standards.Pump", "For #{self.name}, could not find rated pump power consumption, cannot determine horsepower correctly.")
      return 0.0
    end
    
    # Convert to horsepower (bhp)
    hp = rated_power_w / 745.7
    
    return hp

  end

  # Determines the rated watts per GPM of the pump
  #
  # @return [Double] rated power consumption per flow
  #   @units Watts per GPM (W*min/gal)
  def rated_w_per_gpm()

    # Get design power (whether autosized or hard-sized)
    rated_power_w = 0
    if self.autosizedRatedPowerConsumption.is_initialized
      rated_power_w = self.autosizedRatedPowerConsumption.get
    elsif self.ratedPowerConsumption.is_initialized
      rated_power_w = self.ratedPowerConsumption.get
    else
      OpenStudio::logFree(OpenStudio::Error, "openstudio.standards.Pump", "For #{self.name}, could not find rated pump power consumption, cannot determine w per gpm correctly.")
      return 0.0
    end

    rated_m3_per_s = 0
    if self.autosizedRatedFlowRate.is_initialized
      rated_m3_per_s = self.autosizedRatedFlowRate.get
    elsif self.ratedFlowRate.is_initialized
      rated_m3_per_s = self.ratedFlowRate.get
    else
      OpenStudio::logFree(OpenStudio::Error, "openstudio.standards.Pump", "For #{self.name}, could not find rated pump Flow Rate, cannot determine w per gpm correctly.")
      return 0.0
    end

    rated_w_per_m3s = rated_power_w / rated_m3_per_s

    rated_w_per_gpm = OpenStudio::convert(rated_w_per_m3s, 'W*s/m^3', 'W*min/gal').get

    return rated_w_per_gpm

  end


  # Reporting methods, once SQL file is initialized
  # Will look in the TabularDataWithStrings

  def report_head()
    x = self.model.getAutosizedValueFromEquipmentSummary(self, 'Pumps', 'Head', 'pa')
    if x.is_initialized
      return x.get
    else
      return false
    end
  end

  def report_head_ip()
    head_pa = self.model.getAutosizedValueFromEquipmentSummary(self, 'Pumps', 'Head', 'pa')
    if head_pa.is_initialized
      head_pa = head_pa.get
      return OpenStudio::convert(head_pa, 'Pa', 'ftH_{2}O').get
    else
      return false
    end
  end

  def report_water_flow_rate()
    x = self.model.getAutosizedValueFromEquipmentSummary(self, 'Pumps', 'Water Flow', 'm3/s')
    if x.is_initialized
      return x.get
    else
      return false
    end
  end

  def report_rated_electric_power()
    x = self.model.getAutosizedValueFromEquipmentSummary(self, 'Pumps', 'Electric Power', 'W')
    if x.is_initialized
      return x.get
    else
      return false
    end
  end

  def report_power_per_water_flow_rate()
    x = self.model.getAutosizedValueFromEquipmentSummary(self, 'Pumps', 'Power Per Water Flow Rate', 'W-s/m3')
    if x.is_initialized
      return x.get
    else
      return false
    end
  end

  def report_motor_efficiency()
    x = self.model.getAutosizedValueFromEquipmentSummary(self, 'Fans', 'Motor Efficiency', 'W/W')
    if x.is_initialized
      return x.get
    else
      return false
    end
  end

end
