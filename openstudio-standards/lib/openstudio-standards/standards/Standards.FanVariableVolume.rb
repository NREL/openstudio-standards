
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::FanVariableVolume

  include Fan

  def set_control_type(control_type)
    
    # Determine the coefficients
    coeff_a = nil
    coeff_b = nil
    coeff_c = nil
    coeff_d = nil
    min_pct_pwr = nil
    case control_type
    when 'Multi Zone VAV with AF or BI Riding Curve'
      coeff_a = 0.1631
      coeff_b = 1.5901
      coeff_c = -0.8817
      coeff_d = 0.1281
      min_pct_pwr = 0.7
    when 'Multi Zone VAV with AF or BI with Inlet Vanes'
      coeff_a = 0.9977
      coeff_b = -0.659
      coeff_c = 0.9547
      coeff_d = -0.2936
      min_pct_pwr = 0.5
    when 'Multi Zone VAV with FC Riding Curve'
      coeff_a = 0.1224
      coeff_b = 0.612
      coeff_c = 0.5983
      coeff_d = -0.3334
      min_pct_pwr = 0.3
    when 'Multi Zone VAV with FC with Inlet Vanes'
      coeff_a = 0.3038
      coeff_b = -0.7608
      coeff_c = 2.2729
      coeff_d = -0.8169
      min_pct_pwr = 0.3
    when 'Multi Zone VAV with Vane-axial with Variable Pitch Blades'
      coeff_a = 0.1639
      coeff_b = -0.4016
      coeff_c = 1.9909
      coeff_d = -0.7541
      min_pct_pwr = 0.2
    when 'Multi Zone VAV with VSD and Fixed SP Setpoint'
      coeff_a = 0.0013
      coeff_b = 0.1470
      coeff_c = 0.9506
      coeff_d = -0.0998
      min_pct_pwr = 0.2
    when 'Multi Zone VAV with Static Pressure Reset'
      coeff_a = 0.04076
      coeff_b = 0.0881
      coeff_c = -0.0729
      coeff_d = 0.9437
      min_pct_pwr = 0.1
    when 'Single Zone VAV Fan'
      coeff_a = 0.027828
      coeff_b = 0.026583
      coeff_c = -0.087069
      coeff_d = 1.030920
      min_pct_pwr = 0.1
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.FanVariableVolume', "Fan control type '#{control_type}' not recognized, fan power coefficients will not be changed.")
      return false
    end
    
    # Set the coefficients
    self.setFanPowerCoefficient1(coeff_a)
    self.setFanPowerCoefficient2(coeff_b)
    self.setFanPowerCoefficient3(coeff_c)
    self.setFanPowerCoefficient4(coeff_d)
    
    # Set the fan minimum power
    self.setFanPowerMinimumFlowRateInputMethod('Fraction')
    self.setFanPowerMinimumFlowFraction(min_pct_pwr)

    # Append the control type to the fan name
    #self.setName("#{self.name} #{control_type}")
  
  end

end
