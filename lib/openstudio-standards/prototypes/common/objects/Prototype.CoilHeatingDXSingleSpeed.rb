class Standard
  # @!group CoilHeatingDXSingleSpeed

  # Prototype CoilHeatingDXSingleSpeed object
  # Enters in default curves for coil by type of coil
  # @param name [String] the name of the system, or nil in which case it will be defaulted
  # @param schedule [String] name of the availability schedule, or [Schedule] Schedule object, or nil in which case default to always on
  # @param type [String] the type of single speed DX coil to reference the correct curve set
  # @param cop [Double] rated heating coefficient of performance
  def create_coil_heating_dx_single_speed(model, name: "1spd DX Htg Coil", schedule: nil, type: nil, cop: nil)

    htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model)

    # set coil name
    htg_coil.setName(name)

    # set coil availability schedule
    coil_availability_schedule = nil
    if schedule.nil?
      # default always on
      coil_availability_schedule = model.alwaysOnDiscreteSchedule
    elsif schedule.class == String
      coil_availability_schedule = model_add_schedule(model, schedule)

      if coil_availability_schedule.nil? && schedule == "alwaysOffDiscreteSchedule"
        coil_availability_schedule = model.alwaysOffDiscreteSchedule
      elsif coil_availability_schedule.nil?
        coil_availability_schedule = model.alwaysOnDiscreteSchedule
      end
    elsif !schedule.to_Schedule.empty?
      coil_availability_schedule = schedule
    else
      coil_availability_schedule = model.alwaysOnDiscreteSchedule
    end
    htg_coil.setAvailabilitySchedule(coil_availability_schedule)

    # set coil cop
    if !cop.nil?
      htg_coil.setRatedCOP(cop)
    end

    htg_cap_f_of_temp = nil
    htg_cap_f_of_flow = nil
    htg_energy_input_ratio_f_of_temp = nil
    htg_energy_input_ratio_f_of_flow = nil
    htg_part_load_fraction = nil
    defrost_eir_curve = nil

    # curve sets
    if type == 'OS default'

      # use OS defaults

    elsif  type == 'Residential Central Air Source HP'

      # Performance curves
      # These coefficients are in IP UNITS
      heat_cap_ft_coeffs_ip = [0.566333415, -0.000744164, -0.0000103, 0.009414634, 0.0000506, -0.00000675]
      heat_eir_ft_coeffs_ip = [0.718398423, 0.003498178, 0.000142202, -0.005724331, 0.00014085, -0.000215321]
      heat_cap_fflow_coeffs = [0.694045465, 0.474207981, -0.168253446]
      heat_eir_fflow_coeffs = [2.185418751, -1.942827919, 0.757409168]
      heat_plf_fplr_coeffs = [0.8, 0.2, 0]
      defrost_eir_coeffs = [0.1528, 0, 0, 0, 0, 0]

      # Convert coefficients from IP to SI
      heat_cap_ft_coeffs_si = convert_curve_biquadratic(heat_cap_ft_coeffs_ip)
      heat_eir_ft_coeffs_si = convert_curve_biquadratic(heat_eir_ft_coeffs_ip)

      htg_cap_f_of_temp = create_curve_biquadratic(heat_cap_ft_coeffs_si, 'Heat-Cap-fT', 0, 100, 0, 100, nil, nil)
      htg_cap_f_of_flow = create_curve_quadratic(heat_cap_fflow_coeffs, 'Heat-Cap-fFF', 0, 2, 0, 2, is_dimensionless = true)
      htg_energy_input_ratio_f_of_temp = create_curve_biquadratic(heat_eir_ft_coeffs_si, 'Heat-EIR-fT', 0, 100, 0, 100, nil, nil)
      htg_energy_input_ratio_f_of_flow = create_curve_quadratic(heat_eir_fflow_coeffs, 'Heat-EIR-fFF', 0, 2, 0, 2, is_dimensionless = true)
      htg_part_load_fraction = create_curve_quadratic(heat_plf_fplr_coeffs, 'Heat-PLF-fPLR', 0, 1, 0, 1, is_dimensionless = true)

      # Heating defrost curve for reverse cycle
      defrost_eir_curve = create_curve_biquadratic(defrost_eir_coeffs, 'DefrostEIR', -100, 100, -100, 100, nil, nil)

    else # default curve set

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
      htg_part_load_fraction.setCoefficient1Constant(0.85)
      htg_part_load_fraction.setCoefficient2x(0.15)
      htg_part_load_fraction.setCoefficient3xPOW2(0.0)
      htg_part_load_fraction.setMinimumValueofx(0.0)
      htg_part_load_fraction.setMaximumValueofx(1.0)
    end

    htg_coil.setTotalHeatingCapacityFunctionofTemperatureCurve(htg_cap_f_of_temp) if !htg_cap_f_of_temp.nil?
    htg_coil.setTotalHeatingCapacityFunctionofFlowFractionCurve(htg_cap_f_of_flow) if !htg_cap_f_of_flow.nil?
    htg_coil.setEnergyInputRatioFunctionofTemperatureCurve(htg_energy_input_ratio_f_of_temp) if !htg_energy_input_ratio_f_of_temp.nil?
    htg_coil.setEnergyInputRatioFunctionofFlowFractionCurve(htg_energy_input_ratio_f_of_flow) if !htg_energy_input_ratio_f_of_flow.nil?
    htg_coil.setPartLoadFractionCorrelationCurve(htg_part_load_fraction) if !htg_part_load_fraction.nil?
    htg_coil.setDefrostEnergyInputRatioFunctionofTemperatureCurve(defrost_eir_curve) if !defrost_eir_curve.nil?

    return htg_coil
  end
end