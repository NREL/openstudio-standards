
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::FanZoneExhaust

  # Sets the fan motor efficiency based on the standard.
  # Assumes 55% fan efficiency and 4-pole, enclosed motor.
  #
  # @return [Bool] true if successful, false if not
  def setStandardEfficiency(template, standards)
    
    motors = standards["motors"]
    
    # Get the max flow rate from the fan.
    maximum_flow_rate_m3_per_s = nil
    if self.maximumFlowRate.is_initialized
      maximum_flow_rate_m3_per_s = self.maximumFlowRate.get
    else
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.FanZoneExhaust", "For #{self.name} max flow rate is not available, cannot apply efficiency standard.")
      return false
    end
    
    # Convert max flow rate to cfm
    maximum_flow_rate_cfm = OpenStudio.convert(maximum_flow_rate_m3_per_s, "m^3/s", "cfm").get
    
    # Get the pressure rise from the fan
    pressure_rise_pa = self.pressureRise
    pressure_rise_in_h2o = OpenStudio.convert(pressure_rise_pa, "Pa","inH_{2}O").get
    
    # Assume that the fan efficiency is 55% based on
    # PNNL Enhancements # TODO reference
    fan_eff = 0.55
    
    # Calculate the Brake Horsepower
    brake_hp = (pressure_rise_in_h2o * maximum_flow_rate_cfm)/(fan_eff * 6356) 
    allowed_hp = brake_hp * 1.1 # Per PNNL document #TODO add reference

    # Find the motor that meets these size criteria
    search_criteria = {
    "template" => template,
    "number_of_poles" => 4.0,
    "type" => "Enclosed",
    }
    
    motor_properties = self.model.find_object(motors, search_criteria, allowed_hp)
  
    # Get the nominal motor efficiency
    motor_eff = motor_properties["nominal_full_load_efficiency"]
  
    # Calculate the total fan efficiency
    total_fan_eff = fan_eff * motor_eff
    
    # Set the total fan efficiency
    self.setFanEfficiency(total_fan_eff)

    OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.FanZoneExhaust", "For #{template}: #{self.name}: allowed_hp = #{allowed_hp.round(2)}HP; motor eff = #{(motor_eff*100).round(2)}%; total fan eff = #{(total_fan_eff*100).round}%")
    
    return true
    
  end

  # Determines the fan power (W) based on 
  # flow rate, pressure rise, and total fan efficiency(impeller eff * motor eff) 
  # 
  # @return [Double] fan power
  #   @units Watts (W)
  def fanPower()
  
    # Get the max flow rate from the fan
    dsn_air_flow_m3_per_s = 0
    if self.maximumFlowRate.is_initialized
      dsn_air_flow_m3_per_s = self.maximumFlowRate.get
    else
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.FanZoneExhaust", "For #{self.name} max flow rate is not available, cannot apply efficiency standard.")
      return false
    end  

    # Get the total fan efficiency
    fan_total_eff = fan.fanEfficiency
    
    # Get the pressure rise (Pa)
    pressure_rise_pa = fan.pressureRise
    
    # Calculate the fan power (W)
    fan_power_w = pressure_rise_pa * dsn_air_flow_m3_per_s / fan_total_eff
    
    return fan_power_w
  
  end

  # Determines the brake horsepower of the fan
  # based on fan power and fan motor efficiency.
  # 
  # @return [Double] brake horsepower
  #   @units horsepower (hp)
  # @todo This method isn't setup for zone exhaust fans because
  #  motor efficiency isn't broken out explicitly.
  def brakeHorsepower()
  
    # Get the fan motor efficiency
    fan_motor_eff = fan.motorEfficiency
  
    # Get the fan power (W)
    fan_power_w = self.fanPower
    
    # Calculate the brake horsepower (bhp)
    fan_bhp = fan_power_w * fan_motor_eff / 746
    
    return fan_bhp

  end

  # Changes the fan motor efficiency and also the fan total efficiency
  # at the same time, preserving the impeller efficiency.
  #
  # @param motor_eff [Double] motor efficiency (0.0 to 1.0)
  def changeMotorEfficiency(motor_eff)
    
    # Calculate the existing impeller efficiency
    existing_motor_eff = self.motorEfficiency
    existing_total_eff = self.fanEfficiency
    existing_impeller_eff = existing_total_eff / existing_motor_eff
    
    # Calculate the new total efficiency
    new_total_eff = motor_eff * existing_impeller_eff
    
    # Set the revised motor and total fan efficiencies
    self.setMotorEfficiency(motor_eff)
    self.setFanEfficiency(new_total_eff)
  
  end

  # Changes the fan impeller efficiency and also the fan total efficiency
  # at the same time, preserving the motor efficiency.
  #
  # @param impeller_eff [Double] impeller efficiency (0.0 to 1.0) 
  def changeImpellerEfficiency(impeller_eff)
    
    # Get the existing motor efficiency
    existing_motor_eff = self.motorEfficiency

    # Calculate the new total efficiency
    new_total_eff = existing_motor_eff * impeller_eff
    
    # Set the revised motor and total fan efficiencies
    self.setFanEfficiency(new_total_eff)
  
  end
  
  # Determines the baseline fan impeller efficiency
  # based on the specified fan type.  
  # Currently always returns 65% impeller efficiency.
  #
  # @return [Double] impeller efficiency (0.0 to 1.0)
  # @todo Add fan type to data model and modify this method
  def baselineImpellerEfficiency(template)
  
    # Assume that the fan efficiency is 65% based on
    # TODO need reference
    # TODO add fan type to fan data model
    # and infer impeller efficiency from that?
    # or do we always assume a certain type of
    # fan impeller for the baseline system?
    # TODO check COMNET and T24 ACM and PNNL 90.1 doc
    fan_impeller_eff = 0.65
  
    return fan_impeller_eff
  
  end
  
  # Determines the minimum fan motor efficiency 
  # for a given motor bhp
  #
  # @param motor_bhp [Double] motor brake horsepower (hp)
  # @return [Double] minimum motor efficiency (0.0 to 1.0)
  def standardMinimumMotorEfficiency(template, standards, motor_bhp)
  
    # Lookup the minimum motor efficiency
    motors = standards["motors"]
    
    # Assuming all fan motors are 4-pole Enclosed
    search_criteria = {
      "template" => template,
      "number_of_poles" => 4.0,
      "type" => "Enclosed",
    }
    
    motor_properties = self.model.find_object(motors, search_criteria, motor_bhp)
 
    fan_motor_eff = motor_properties["nominal_full_load_efficiency"]  

    return fan_motor_eff
  
  end
  
end
