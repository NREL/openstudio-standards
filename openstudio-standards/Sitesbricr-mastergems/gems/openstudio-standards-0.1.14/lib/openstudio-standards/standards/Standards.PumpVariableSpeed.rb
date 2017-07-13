
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::PumpVariableSpeed
  include Pump

  # Set the pump curve coefficients based
  # on the specified control type.
  #
  # @param control_type [String] valid choices
  # are Riding Curve, VSD No Reset, VSD DP Reset
  def set_control_type(control_type)
    # Determine the coefficients
    coeff_a = nil
    coeff_b = nil
    coeff_c = nil
    coeff_d = nil
    case control_type
    when 'Constant Flow'
      coeff_a = 0.0
      coeff_b = 1.0
      coeff_c = 0.0
      coeff_d = 0.0
    when 'Riding Curve'
      coeff_a = 0.0
      coeff_b = 3.2485
      coeff_c = -4.7443
      coeff_d = 2.5294
    when 'VSD No Reset'
      coeff_a = 0.0
      coeff_b = 0.5726
      coeff_c = -0.301
      coeff_d = 0.7347
    when 'VSD DP Reset'
      coeff_a = 0.0
      coeff_b = 0.0205
      coeff_c = 0.4101
      coeff_d = 0.5753
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.PumpVariableSpeed', "Pump control type '#{control_type}' not recognized, pump coefficients will not be changed.")
      return false
    end

    # Set the coefficients
    setCoefficient1ofthePartLoadPerformanceCurve(coeff_a)
    setCoefficient2ofthePartLoadPerformanceCurve(coeff_b)
    setCoefficient3ofthePartLoadPerformanceCurve(coeff_c)
    setCoefficient4ofthePartLoadPerformanceCurve(coeff_d)
    setPumpControlType('Intermittent')

    # Append the control type to the pump name
    # self.setName("#{self.name} #{control_type}")

    return true
  end
end
