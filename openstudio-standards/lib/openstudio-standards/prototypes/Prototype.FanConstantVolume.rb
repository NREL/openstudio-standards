
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::FanConstantVolume

  # Sets the fan pressure rise based on the Prototype buildings inputs
  # which are governed by the flow rate coming through the fan
  # and whether the fan lives inside a unit heater, PTAC, etc.
  def setPrototypeFanPressureRise(building_vintage)
    
    return true if self.name.to_s.include?("UnitHeater Fan")
    if building_vintage == 'NECB 2011' then
      pressure_rise_pa = 640.0
      self.setPressureRise(pressure_rise_pa)
    else
    # Get the max flow rate from the fan.
    maximum_flow_rate_m3_per_s = nil
    if self.maximumFlowRate.is_initialized
      maximum_flow_rate_m3_per_s = self.maximumFlowRate.get
    elsif self.autosizedMaximumFlowRate.is_initialized
      maximum_flow_rate_m3_per_s = self.autosizedMaximumFlowRate.get
    else
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.prototype.FanConstantVolume", "For #{self.name} max flow rate is not available, cannot apply prototype assumptions.")
      return false
    end    
    
    # Convert max flow rate to cfm
    maximum_flow_rate_cfm = OpenStudio.convert(maximum_flow_rate_m3_per_s, 'm^3/s', 'cfm').get
    
    # Pressure rise will be determined based on the 
    # following logic.
    pressure_rise_in_h2o = 0.0
    
    # If the fan lives inside of a zone hvac equipment
    if self.containingZoneHVACComponent.is_initialized
      zone_hvac = self.containingZoneHVACComponent.get
      if zone_hvac.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized
        pressure_rise_in_h2o = 1.33
      elsif zone_hvac.to_ZoneHVACFourPipeFanCoil.is_initialized
        pressure_rise_in_h2o = 1.33
      elsif zone_hvac.to_ZoneHVACUnitHeater.is_initialized
        pressure_rise_in_h2o = 0.2
      else # This type of fan should not exist in the prototype models
        return false
      end
    end
    
    # If the fan lives on an airloop
    if self.airLoopHVAC.is_initialized
      if maximum_flow_rate_cfm < 7487
        pressure_rise_in_h2o = 2.5
      elsif maximum_flow_rate_cfm >= 7487 && maximum_flow_rate_cfm < 20000
        #pressure_rise_in_h2o = 4.46
        # TODO PTACs in prototypes have pressure rise
        # of 4.09 in w.c. even when well less than 20,000 cfm.
        # See secondary school model.  This contradicts documentation.
        pressure_rise_in_h2o = 4.09
      else # Over 20,000 cfm
        pressure_rise_in_h2o = 4.09
      end
    end
    
    # Set the fan pressure rise
    pressure_rise_pa = OpenStudio.convert(pressure_rise_in_h2o, 'inH_{2}O','Pa').get
    
     
    self.setPressureRise(pressure_rise_pa)  
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.FanConstantVolume', "For Prototype: #{self.name}: #{maximum_flow_rate_cfm.round}cfm; Pressure Rise = #{pressure_rise_in_h2o}in w.c.")
   
    end 
    return true
    
  end

end
