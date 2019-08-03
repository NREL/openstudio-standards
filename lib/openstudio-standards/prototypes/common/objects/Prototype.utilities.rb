class Standard
  # @!group utilities

  # load a model into OS & version translates, exiting and erroring if a problem is found
  def safe_load_model(model_path_string)
    model_path = OpenStudio::Path.new(model_path_string)
    if OpenStudio.exists(model_path)
      version_translator = OpenStudio::OSVersion::VersionTranslator.new
      model = version_translator.loadModel(model_path)
      if model.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Version translation failed for #{model_path_string}")
        return false
      else
        model = model.get
      end
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "#{model_path_string} couldn't be found")
      return false
    end
    return model
  end

  # load a sql file, exiting and erroring if a problem is found
  def safe_load_sql(sql_path_string)
    sql_path = OpenStudio::Path.new(sql_path_string)
    if OpenStudio.exists(sql_path)
      sql = OpenStudio::SqlFile.new(sql_path)
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "#{sql_path} couldn't be found")
      return false
    end
    return sql
  end

  def strip_model(model)
    # remove all materials
    model.getMaterials.each(&:remove)

    # remove all constructions
    model.getConstructions.each(&:remove)

    # remove performance curves
    model.getCurves.each do |curve|
      model.removeObject(curve.handle)
    end

    # remove all zone equipment
    model.getThermalZones.sort.each do |zone|
      zone.equipment.each(&:remove)
    end

    # remove all thermostats
    model.getThermostatSetpointDualSetpoints.each(&:remove)

    # remove all people
    model.getPeoples.each(&:remove)
    model.getPeopleDefinitions.each(&:remove)

    # remove all lights
    model.getLightss.each(&:remove)
    model.getLightsDefinitions.each(&:remove)

    # remove all electric equipment
    model.getElectricEquipments.each(&:remove)
    model.getElectricEquipmentDefinitions.each(&:remove)

    # remove all gas equipment
    model.getGasEquipments.each(&:remove)
    model.getGasEquipmentDefinitions.each(&:remove)

    # remove all outdoor air
    model.getDesignSpecificationOutdoorAirs.each(&:remove)

    # remove all infiltration
    model.getSpaceInfiltrationDesignFlowRates.each(&:remove)

    # Remove all internal mass
    model.getInternalMasss.each(&:remove)

    # Remove all internal mass defs
    model.getInternalMassDefinitions.each(&:remove)

    # Remove all thermal zones
    model.getThermalZones.each(&:remove)

    # Remove all schedules
    model.getSchedules.each(&:remove)

    # Remove all schedule type limits
    model.getScheduleTypeLimitss.each(&:remove)

    # Remove the sizing parameters
    model.getSizingParameters.remove

    # Remove the design days
    model.getDesignDays.each(&:remove)

    # Remove the rendering colors
    model.getRenderingColors.each(&:remove)

    # Remove the daylight controls
    model.getDaylightingControls.each(&:remove)

    return model
  end

  # Remove all air loops in model
  def remove_air_loops(model)
    model.getAirLoopHVACs.each(&:remove)
    return model
  end

  # Remove plant loops in model except those used for service hot water
  def remove_plant_loops(model)
    plant_loops = model.getPlantLoops
    plant_loops.each do |plant_loop|
      shw_use = false
      plant_loop.demandComponents.each do |component|
        if component.to_WaterUseConnections.is_initialized || component.to_CoilWaterHeatingDesuperheater.is_initialized
          shw_use = true
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "#{plant_loop.name} is used for SHW or refrigeration heat reclaim and will not be removed.")
          break
        end
      end
      plant_loop.remove unless shw_use
    end
    return model
  end

  # Remove all plant loops in model including those used for service hot water
  def remove_all_plant_loops(model)
    model.getPlantLoops.each(&:remove)
    return model
  end

  # Remove VRF units
  def remove_vrf(model)
    model.getAirConditionerVariableRefrigerantFlows.each(&:remove)
    model.getZoneHVACTerminalUnitVariableRefrigerantFlows.each(&:remove)
    return model
  end

  # Remove zone equipment except for exhaust fans
  def remove_zone_equipment(model)
    model.getThermalZones.each do |zone|
      zone.equipment.each do |equipment|
        if equipment.to_FanZoneExhaust.is_initialized
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "#{equipment.name} is a zone exhaust fan and will not be removed.")
        else
          equipment.remove
        end
      end
    end
    return model
  end

  # Remove all zone equipment including exhaust fans
  def remove_all_zone_equipment(model)
    model.getThermalZones.each do |zone|
      zone.equipment.each(&:remove)
    end
    return model
  end

  # Remove unused performance curves
  def remove_unused_curves(model)
    model.getCurves.each do |curve|
      if curve.directUseCount == 0
        model.removeObject(curve.handle)
      end
    end
    return model
  end

  # Remove HVAC equipment except for service hot water loops and zone exhaust fans
  def remove_HVAC(model)
    remove_air_loops(model)
    remove_plant_loops(model)
    remove_vrf(model)
    remove_zone_equipment(model)
    remove_unused_curves(model)
    return model
  end

  # Remove all HVAC equipment including service hot water loops and zone exhaust fans
  def remove_all_HVAC(model)
    remove_air_loops(model)
    remove_all_plant_loops(model)
    remove_vrf(model)
    remove_all_zone_equipment(model)
    remove_unused_curves(model)
    return model
  end

  # Loads a JSON file containing the space type map into a hash
  #
  # @param hvac_map_file [String] path to JSON file, relative to the /data folder
  # @return [Hash] returns a hash that contains the space type map
  def load_hvac_map(hvac_map_file)
    # Load the geometry .osm from relative to the data folder
    rel_path_to_hvac_map = "../../../../../data/#{hvac_map_file}"

    # Load the JSON depending on whether running from normal gem location
    # or from the embedded location in the OpenStudio CLI
    if File.dirname(__FILE__)[0] == ':'
      # running from embedded location in OpenStudio CLI
      hvac_map_string = load_resource_relative(rel_path_to_hvac_map)
      hvac_map = JSON.parse(hvac_map_string)
    else
      abs_path = File.join(File.dirname(__FILE__), rel_path_to_hvac_map)
      hvac_map = JSON.parse(File.read(abs_path)) if File.exist?(abs_path)
    end

    return hvac_map
  end

  # Convert from SEER to COP (no fan) for cooling coils
  # @ref [References::ASHRAE9012013] Appendix G
  #
  # @param seer [Double] seasonal energy efficiency ratio (SEER)
  # @return [Double] Coefficient of Performance (COP)
  def seer_to_cop_cooling_no_fan(seer)
    cop = -0.0076 * seer * seer + 0.3796 * seer

    return cop
  end

  # Convert from SEER to COP (with fan) for cooling coils
  # per the method specified in 90.1-2013 Appendix G
  #
  # @param seer [Double] seasonal energy efficiency ratio (SEER)
  # @return [Double] Coefficient of Performance (COP)
  def seer_to_cop_cooling_with_fan(seer)
    eer = -0.0182 * seer * seer + 1.1088 * seer
    cop = (eer / 3.413 + 0.12) / (1 - 0.12)

    return cop
  end

  # Convert from COP_H to COP (no fan) for heat pump heating coils
  # @ref [References::ASHRAE9012013] Appendix G
  #
  # @param coph47 [Double] coefficient of performance at 47F Tdb, 42F Twb
  # @param capacity_w [Double] the heating capacity at AHRI rating conditions, in W
  # @return [Double] Coefficient of Performance (COP)
  def cop_heating_to_cop_heating_no_fan(coph47, capacity_w)
    # Convert the capacity to Btu/hr
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get

    cop = 1.48E-7 * coph47 * capacity_btu_per_hr + 1.062 * coph47

    return cop
  end

  # Convert from HSPF to COP (no fan) for heat pump heating coils
  # @ref [References::ASHRAE9012013] Appendix G
  #
  # @param hspf [Double] heating seasonal performance factor (HSPF)
  # @return [Double] Coefficient of Performance (COP)
  def hspf_to_cop_heating_no_fan(hspf)
    cop = -0.0296 * hspf * hspf + 0.7134 * hspf

    return cop
  end

  # Convert from HSPF to COP (with fan) for heat pump heating coils
  # @ref [References::ASHRAE9012013] Appendix G
  #
  # @param hspf [Double] heating seasonal performance factor (HSPF)
  # @return [Double] Coefficient of Performance (COP)
  def hspf_to_cop_heating_with_fan(hspf)
    cop = -0.0255 * hspf * hspf + 0.6239 * hspf

    return cop
  end

  # Convert from COP to SEER
  # @ref [References::USDOEPrototypeBuildings]
  #
  # @param cop [Double] COP
  # @return [Double] Seasonal Energy Efficiency Ratio
  def cop_to_seer(cop)
    delta = 0.3796**2 - 4.0 * 0.0076 * cop
    seer = (-delta**0.5 + 0.3796) / (2.0 * 0.0076)

    return seer
  end

  # Convert from EER to COP
  # @ref [References::USDOEPrototypeBuildings] If capacity is not supplied, use DOE Prototype Building method.
  # @ref [References::ASHRAE9012013] If capacity is supplied, use the 90.1-2013 method
  #
  # @param eer [Double] Energy Efficiency Ratio (EER)
  # @param capacity_w [Double] the heating capacity at AHRI rating conditions, in W
  # @return [Double] Coefficient of Performance (COP)
  def eer_to_cop(eer, capacity_w = nil)
    if capacity_w.nil?
      # The PNNL Method.
      # r is the ratio of supply fan power to total equipment power at the rating condition,
      # assumed to be 0.12 for the reference buildings per PNNL.
      r = 0.12
      cop = (eer / 3.413 + r) / (1 - r)
    else
      # The 90.1-2013 method
      # Convert the capacity to Btu/hr
      capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
      cop = 7.84E-8 * eer * capacity_btu_per_hr + 0.338 * eer
    end

    return cop
  end

  # Convert from COP to EER
  # @ref [References::USDOEPrototypeBuildings]
  #
  # @param cop [Double] COP
  # @return [Double] Energy Efficiency Ratio (EER)
  def cop_to_eer(cop, capacity_w = nil)
    if capacity_w.nil?
      # The PNNL Method.
      # r is the ratio of supply fan power to total equipment power at the rating condition,
      # assumed to be 0.12 for the reference buildngs per PNNL.
      r = 0.12
      eer = 3.413 * (cop * (1 - r) - r)
    else
      # The 90.1-2013 method
      # Convert the capacity to Btu/hr
      capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
      eer = cop / (7.84E-8 * capacity_btu_per_hr + 0.338)
    end

    return eer
  end

  # Convert from COP to kW/ton
  #
  # @param cop [Double] Coefficient of Performance (COP)
  # @return [Double] kW of input power per ton of cooling
  def cop_to_kw_per_ton(cop)
    return 3.517 / cop
  end

  # A helper method to convert from kW/ton to COP
  #
  # @param kw_per_ton [Double] kW of input power per ton of cooling
  # @return [Double] Coefficient of Performance (COP)
  def kw_per_ton_to_cop(kw_per_ton)
    return 3.517 / kw_per_ton
  end

  # A helper method to convert from AFUE to thermal efficiency
  # @ref [References::USDOEPrototypeBuildings] Boiler Addendum 90.1-04an
  #
  # @param afue [Double] Annual Fuel Utilization Efficiency
  # @return [Double] Thermal efficiency (%)
  def afue_to_thermal_eff(afue)
    return afue
  end

  # A helper method to convert from thermal efficiency to AFUE
  # @ref [References::USDOEPrototypeBuildings] Boiler Addendum 90.1-04an
  #
  # @param teff [Double] Thermal Efficiency
  # @return [Double] AFUE
  def thermal_eff_to_afue(teff)
    return teff
  end

  # A helper method to convert from combustion efficiency to thermal efficiency
  # @ref [References::USDOEPrototypeBuildings] Boiler Addendum 90.1-04an
  #
  # @param combustion_eff [Double] Combustion efficiency (%)
  # @return [Double] Thermal efficiency (%)
  def combustion_eff_to_thermal_eff(combustion_eff)
    return combustion_eff - 0.007
  end

  # A helper method to convert from thermal efficiency to combustion efficiency
  # @ref [References::USDOEPrototypeBuildings] Boiler Addendum 90.1-04an
  #
  # @param thermal_eff [Double] Thermal efficiency
  # @return [Double] Combustion efficiency
  def thermal_eff_to_comb_eff(thermal_eff)
    return thermal_eff + 0.007
  end

  # Convert one infiltration rate at a given pressure
  # to an infiltration rate at another pressure
  # per method described here:  http://www.taskair.net/knowledge/Infiltration%20Modeling%20Guidelines%20for%20Commercial%20Building%20Energy%20Analysis.pdf
  # where the infiltration coefficient is 0.65
  #
  # @param initial_infiltration_rate_m3_per_s [Double] initial infiltration rate in m^3/s
  # @param intial_pressure_pa [Double] pressure rise at which initial infiltration rate was determined in Pa
  # @param final_pressure_pa [Double] desired pressure rise to adjust infiltration rate to in Pa
  # @param infiltration_coefficient [Double] infiltration coeffiecient
  def adjust_infiltration_to_lower_pressure(initial_infiltration_rate_m3_per_s, intial_pressure_pa, final_pressure_pa, infiltration_coefficient = 0.65)
    adjusted_infiltration_rate_m3_per_s = initial_infiltration_rate_m3_per_s * (final_pressure_pa / intial_pressure_pa)**infiltration_coefficient

    return adjusted_infiltration_rate_m3_per_s
  end

  # Convert the infiltration rate at a 75 Pa
  # to an infiltration rate at the typical value for the prototype buildings
  # per method described here:  http://www.pnl.gov/main/publications/external/technical_reports/PNNL-18898.pdf
  # Gowri K, DW Winiarski, and RE Jarnagin. 2009.
  # Infiltration modeling guidelines for commercial building energy analysis.
  # PNNL-18898, Pacific Northwest National Laboratory, Richland, WA.
  #
  # @param initial_infiltration_rate_m3_per_s [Double] initial infiltration rate in m^3/s
  # @return [Double]
  def adjust_infiltration_to_prototype_building_conditions(initial_infiltration_rate_m3_per_s)
    # Details of these coefficients can be found in paper
    alpha = 0.22 # unitless - terrain adjustment factor
    intial_pressure_pa = 75.0 # 75 Pa
    uh = 4.47 # m/s - wind speed
    rho = 1.18 # kg/m^3 - air density
    cs = 0.1617 # unitless - positive surface pressure coefficient
    n = 0.65 # unitless - infiltration coefficient

    # Calculate the typical pressure - same for all building types
    final_pressure_pa = 0.5 * cs * rho * uh**2

    # OpenStudio::logFree(OpenStudio::Debug, "openstudio.Standards.Space", "Final pressure PA = #{final_pressure_pa.round(3)} Pa.")

    adjusted_infiltration_rate_m3_per_s = (1.0 + alpha) * initial_infiltration_rate_m3_per_s * (final_pressure_pa / intial_pressure_pa)**n

    return adjusted_infiltration_rate_m3_per_s
  end

  # Convert biquadratic curves that are a function of temperature
  # from IP (F) to SI (C) or vice-versa.  The curve is of the form
  # z = C1 + C2*x + C3*x^2 + C4*y + C5*y^2 + C6*x*y
  # where C1, C2, ... are the coefficients,
  # x is the first independent variable (in F or C)
  # y is the second independent variable (in F or C)
  # and z is the resulting value
  #
  # @author Scott Horowitz, NREL
  # @param coeffs [Array<Double>] an array of 6 coefficients, in order
  # @return [Array<Double>] the revised coefficients in the new unit system
  def convert_curve_biquadratic(coeffs, ip_to_si = true)
    if ip_to_si
      # Convert IP curves to SI curves
      si_coeffs = []
      si_coeffs << coeffs[0] + 32.0 * (coeffs[1] + coeffs[3]) + 1024.0 * (coeffs[2] + coeffs[4] + coeffs[5])
      si_coeffs << 9.0 / 5.0 * coeffs[1] + 576.0 / 5.0 * coeffs[2] + 288.0 / 5.0 * coeffs[5]
      si_coeffs << 81.0 / 25.0 * coeffs[2]
      si_coeffs << 9.0 / 5.0 * coeffs[3] + 576.0 / 5.0 * coeffs[4] + 288.0 / 5.0 * coeffs[5]
      si_coeffs << 81.0 / 25.0 * coeffs[4]
      si_coeffs << 81.0 / 25.0 * coeffs[5]
      return si_coeffs
    else
      # Convert SI curves to IP curves
      ip_coeffs = []
      ip_coeffs << coeffs[0] - 160.0 / 9.0 * (coeffs[1] + coeffs[3]) + 25_600.0 / 81.0 * (coeffs[2] + coeffs[4] + coeffs[5])
      ip_coeffs << 5.0 / 9.0 * (coeffs[1] - 320.0 / 9.0 * coeffs[2] - 160.0 / 9.0 * coeffs[5])
      ip_coeffs << 25.0 / 81.0 * coeffs[2]
      ip_coeffs << 5.0 / 9.0 * (coeffs[3] - 320.0 / 9.0 * coeffs[4] - 160.0 / 9.0 * coeffs[5])
      ip_coeffs << 25.0 / 81.0 * coeffs[4]
      ip_coeffs << 25.0 / 81.0 * coeffs[5]
      return ip_coeffs
    end
  end

  # Create a biquadratic curve of the form
  # z = C1 + C2*x + C3*x^2 + C4*y + C5*y^2 + C6*x*y
  #
  # @author Scott Horowitz, NREL
  # @param coeffs [Array<Double>] an array of 6 coefficients, in order
  # @param crv_name [String] the name of the curve
  # @param min_x [Double] the minimum value of independent variable X that will be used
  # @param max_x [Double] the maximum value of independent variable X that will be used
  # @param min_y [Double] the minimum value of independent variable Y that will be used
  # @param max_y [Double] the maximum value of independent variable Y that will be used
  # @param min_out [Double] the minimum value of dependent variable Z
  # @param max_out [Double] the maximum value of dependent variable Z
  def create_curve_biquadratic(model, coeffs, crv_name, min_x, max_x, min_y, max_y, min_out, max_out)
    curve = OpenStudio::Model::CurveBiquadratic.new(model)
    curve.setName(crv_name)
    curve.setCoefficient1Constant(coeffs[0])
    curve.setCoefficient2x(coeffs[1])
    curve.setCoefficient3xPOW2(coeffs[2])
    curve.setCoefficient4y(coeffs[3])
    curve.setCoefficient5yPOW2(coeffs[4])
    curve.setCoefficient6xTIMESY(coeffs[5])
    curve.setMinimumValueofx(min_x) unless min_x.nil?
    curve.setMaximumValueofx(max_x) unless max_x.nil?
    curve.setMinimumValueofy(min_y) unless min_y.nil?
    curve.setMaximumValueofy(max_y) unless max_y.nil?
    curve.setMinimumCurveOutput(min_out) unless min_out.nil?
    curve.setMaximumCurveOutput(max_out) unless max_out.nil?
    return curve
  end

  # Create a bicubic curve of the form
  # z = C1 + C2*x + C3*x^2 + C4*y + C5*y^2 + C6*x*y + C7*x^3 + C8*y^3 + C9*x^2*y + C10*x*y^2
  #
  # @author Scott Horowitz, NREL
  # @param coeffs [Array<Double>] an array of 10 coefficients, in order
  # @param crv_name [String] the name of the curve
  # @param min_x [Double] the minimum value of independent variable X that will be used
  # @param max_x [Double] the maximum value of independent variable X that will be used
  # @param min_y [Double] the minimum value of independent variable Y that will be used
  # @param max_y [Double] the maximum value of independent variable Y that will be used
  # @param min_out [Double] the minimum value of dependent variable Z
  # @param max_out [Double] the maximum value of dependent variable Z
  def create_curve_bicubic(model, coeffs, crv_name, min_x, max_x, min_y, max_y, min_out, max_out)
    curve = OpenStudio::Model::CurveBicubic.new(model)
    curve.setName(crv_name)
    curve.setCoefficient1Constant(coeffs[0])
    curve.setCoefficient2x(coeffs[1])
    curve.setCoefficient3xPOW2(coeffs[2])
    curve.setCoefficient4y(coeffs[3])
    curve.setCoefficient5yPOW2(coeffs[4])
    curve.setCoefficient6xTIMESY(coeffs[5])
    curve.setCoefficient7xPOW3(coeffs[6])
    curve.setCoefficient8yPOW3(coeffs[7])
    curve.setCoefficient9xPOW2TIMESY(coeffs[8])
    curve.setCoefficient10xTIMESYPOW2(coeffs[9])
    curve.setMinimumValueofx(min_x) unless min_x.nil?
    curve.setMaximumValueofx(max_x) unless max_x.nil?
    curve.setMinimumValueofy(min_y) unless min_y.nil?
    curve.setMaximumValueofy(max_y) unless max_y.nil?
    curve.setMinimumCurveOutput(min_out) unless min_out.nil?
    curve.setMaximumCurveOutput(max_out) unless max_out.nil?
    return curve
  end

  # Create a quadratic curve of the form
  # z = C1 + C2*x + C3*x^2
  #
  # @author Scott Horowitz, NREL
  # @param coeffs [Array<Double>] an array of 3 coefficients, in order
  # @param crv_name [String] the name of the curve
  # @param min_x [Double] the minimum value of independent variable X that will be used
  # @param max_x [Double] the maximum value of independent variable X that will be used
  # @param min_out [Double] the minimum value of dependent variable Z
  # @param max_out [Double] the maximum value of dependent variable Z
  # @param is_dimensionless [Bool] if true, the X independent variable is considered unitless
  # and the resulting output dependent variable is considered unitless
  def create_curve_quadratic(model, coeffs, crv_name, min_x, max_x, min_out, max_out, is_dimensionless = false)
    curve = OpenStudio::Model::CurveQuadratic.new(model)
    curve.setName(crv_name)
    curve.setCoefficient1Constant(coeffs[0])
    curve.setCoefficient2x(coeffs[1])
    curve.setCoefficient3xPOW2(coeffs[2])
    curve.setMinimumValueofx(min_x) unless min_x.nil?
    curve.setMaximumValueofx(max_x) unless max_x.nil?
    curve.setMinimumCurveOutput(min_out) unless min_out.nil?
    curve.setMaximumCurveOutput(max_out) unless max_out.nil?
    if is_dimensionless
      curve.setInputUnitTypeforX('Dimensionless')
      curve.setOutputUnitType('Dimensionless')
    end
    return curve
  end

  # Create a cubic curve of the form
  # z = C1 + C2*x + C3*x^2 + C4*x^3
  #
  # @author Scott Horowitz, NREL
  # @param coeffs [Array<Double>] an array of 4 coefficients, in order
  # @param crv_name [String] the name of the curve
  # @param min_x [Double] the minimum value of independent variable X that will be used
  # @param max_x [Double] the maximum value of independent variable X that will be used
  # @param min_out [Double] the minimum value of dependent variable Z
  # @param max_out [Double] the maximum value of dependent variable Z
  def create_curve_cubic(coeffs, crv_name, min_x, max_x, min_out, max_out)
    curve = OpenStudio::Model::CurveCubic.new(self)
    curve.setName(crv_name)
    curve.setCoefficient1Constant(coeffs[0])
    curve.setCoefficient2x(coeffs[1])
    curve.setCoefficient3xPOW2(coeffs[2])
    curve.setCoefficient4xPOW3(coeffs[3])
    curve.setMinimumValueofx(min_x) unless min_x.nil?
    curve.setMaximumValueofx(max_x) unless max_x.nil?
    curve.setMinimumCurveOutput(min_out) unless min_out.nil?
    curve.setMaximumCurveOutput(max_out) unless max_out.nil?
    return curve
  end

  # Create an exponential curve of the form
  # z = C1 + C2*x^C3
  #
  # @author Scott Horowitz, NREL
  # @param coeffs [Array<Double>] an array of 3 coefficients, in order
  # @param crv_name [String] the name of the curve
  # @param min_x [Double] the minimum value of independent variable X that will be used
  # @param max_x [Double] the maximum value of independent variable X that will be used
  # @param min_out [Double] the minimum value of dependent variable Z
  # @param max_out [Double] the maximum value of dependent variable Z
  def create_curve_exponent(coeffs, crv_name, min_x, max_x, min_out, max_out)
    curve = OpenStudio::Model::CurveExponent.new(self)
    curve.setName(crv_name)
    curve.setCoefficient1Constant(coeffs[0])
    curve.setCoefficient2Constant(coeffs[1])
    curve.setCoefficient3Constant(coeffs[2])
    curve.setMinimumValueofx(min_x) unless min_x.nil?
    curve.setMaximumValueofx(max_x) unless max_x.nil?
    curve.setMinimumCurveOutput(min_out) unless min_out.nil?
    curve.setMaximumCurveOutput(max_out) unless max_out.nil?
    return curve
  end

  # Gives the total R-value of the interior and exterior (if applicable)
  # film coefficients for a particular type of surface.
  #
  # @param intended_surface_type [String]
  #   Valid choices:  'AtticFloor', 'AtticWall', 'AtticRoof', 'DemisingFloor', 'InteriorFloor', 'InteriorCeiling',
  #   'DemisingWall', 'InteriorWall', 'InteriorPartition', 'InteriorWindow', 'InteriorDoor', 'DemisingRoof',
  #   'ExteriorRoof', 'Skylight', 'TubularDaylightDome', 'TubularDaylightDiffuser', 'ExteriorFloor',
  #   'ExteriorWall', 'ExteriorWindow', 'ExteriorDoor', 'GlassDoor', 'OverheadDoor', 'GroundContactFloor',
  #   'GroundContactWall', 'GroundContactRoof'
  # @param int_film [Bool] if true, interior film coefficient will be included in result
  # @param ext_film [Bool] if true, exterior film coefficient will be included in result
  # @return [Double] Returns the R-Value of the film coefficients [m^2*K/W]
  # @ref [References::ASHRAE9012010] A9.4.1 Air Films
  def film_coefficients_r_value(intended_surface_type, int_film, ext_film)
    # Return zero if both interior and exterior are false
    return 0.0 if !int_film && !ext_film

    # Film values from 90.1-2010 A9.4.1 Air Films
    film_ext_surf_r_ip = 0.17
    film_semi_ext_surf_r_ip = 0.46
    film_int_surf_ht_flow_up_r_ip = 0.61
    film_int_surf_ht_flow_dwn_r_ip = 0.92
    fil_int_surf_vertical_r_ip = 0.68

    film_ext_surf_r_si = OpenStudio.convert(film_ext_surf_r_ip, 'ft^2*hr*R/Btu', 'm^2*K/W').get
    film_semi_ext_surf_r_si = OpenStudio.convert(film_semi_ext_surf_r_ip, 'ft^2*hr*R/Btu', 'm^2*K/W').get
    film_int_surf_ht_flow_up_r_si = OpenStudio.convert(film_int_surf_ht_flow_up_r_ip, 'ft^2*hr*R/Btu', 'm^2*K/W').get
    film_int_surf_ht_flow_dwn_r_si = OpenStudio.convert(film_int_surf_ht_flow_dwn_r_ip, 'ft^2*hr*R/Btu', 'm^2*K/W').get
    fil_int_surf_vertical_r_si = OpenStudio.convert(fil_int_surf_vertical_r_ip, 'ft^2*hr*R/Btu', 'm^2*K/W').get

    film_r_si = 0.0
    case intended_surface_type
    when 'AtticFloor'
      film_r_si += film_int_surf_ht_flow_up_r_si if ext_film # Outside
      film_r_si += film_semi_ext_surf_r_si if int_film # Inside
    when 'AtticWall', 'AtticRoof'
      film_r_si += film_ext_surf_r_si if ext_film # Outside
      film_r_si += film_semi_ext_surf_r_si if int_film # Inside
    when 'DemisingFloor', 'InteriorFloor'
      film_r_si += film_int_surf_ht_flow_up_r_si if ext_film # Outside
      film_r_si += film_int_surf_ht_flow_dwn_r_si if int_film # Inside
    when 'InteriorCeiling'
      film_r_si += film_int_surf_ht_flow_dwn_r_si if ext_film # Outside
      film_r_si += film_int_surf_ht_flow_up_r_si if int_film # Inside
    when 'DemisingWall', 'InteriorWall', 'InteriorPartition', 'InteriorWindow', 'InteriorDoor'
      film_r_si += fil_int_surf_vertical_r_si if ext_film # Outside
      film_r_si += fil_int_surf_vertical_r_si if int_film # Inside
    when 'DemisingRoof', 'ExteriorRoof', 'Skylight', 'TubularDaylightDome', 'TubularDaylightDiffuser'
      film_r_si += film_ext_surf_r_si if ext_film # Outside
      film_r_si += film_int_surf_ht_flow_up_r_si if int_film # Inside
    when 'ExteriorFloor'
      film_r_si += film_ext_surf_r_si if ext_film # Outside
      film_r_si += film_int_surf_ht_flow_dwn_r_si if int_film # Inside
    when 'ExteriorWall', 'ExteriorWindow', 'ExteriorDoor', 'GlassDoor', 'OverheadDoor'
      film_r_si += film_ext_surf_r_si if ext_film # Outside
      film_r_si += fil_int_surf_vertical_r_si if int_film # Inside
    when 'GroundContactFloor'
      film_r_si += film_int_surf_ht_flow_dwn_r_si if int_film # Inside
    when 'GroundContactWall'
      film_r_si += fil_int_surf_vertical_r_si if int_film # Inside
    when 'GroundContactRoof'
      film_r_si += film_int_surf_ht_flow_up_r_si if int_film # Inside
    end
    return film_r_si
  end

  # Sets VAV reheat and VAV no reheat terminals on an air loop to control for outdoor air
  #
  # @param air_loop [<OpenStudio::Model::AirLoopHVAC>] air loop to enable DCV on.
  #   Default is nil, which will apply to all air loops
  def set_VAV_terminals_to_control_for_outdoor_air(model, air_loop: nil)
    vav_reheats = model.getAirTerminalSingleDuctVAVReheats
    vav_no_reheats = model.getAirTerminalSingleDuctVAVNoReheats

    if !air_loop.nil?
      vav_reheats.each do |vav_reheat|
        next if vav_reheat.airLoopHVAC.get.name.to_s != air_loop.name.to_s

        vav_reheat.setControlForOutdoorAir(true)
      end
      vav_no_reheats.each do |vav_no_reheat|
        next if vav_no_reheat.airLoopHVAC.get.name.to_s != air_loop.name.to_s

        vav_no_reheat.setControlForOutdoorAir(true)
      end
    else # all terminals
      vav_reheats.each do |vav_reheat|
        vav_reheat.setControlForOutdoorAir(true)
      end
      vav_no_reheats.each do |vav_no_reheat|
        vav_no_reheat.setControlForOutdoorAir(true)
      end
    end
    return model
  end

  # renames air loop nodes to readable values
  def rename_air_loop_nodes(model)
    # rename all hvac components on air loops
    model.getHVACComponents.sort.each do |component|
      next if component.to_Node.is_initialized # skip nodes

      unless component.airLoopHVAC.empty?
        # rename water to air component outlet nodes
        if component.to_WaterToAirComponent.is_initialized
          component = component.to_WaterToAirComponent.get
          unless component.airOutletModelObject.empty?
            component_outlet_object = component.airOutletModelObject.get
            next unless component_outlet_object.to_Node.is_initialized

            component_outlet_object.setName("#{component.name} Outlet Air Node")
          end
        end

        # rename air to air component nodes
        if component.to_AirToAirComponent.is_initialized
          component = component.to_AirToAirComponent.get
          unless component.primaryAirOutletModelObject.empty?
            component_outlet_object = component.primaryAirOutletModelObject.get
            next unless component_outlet_object.to_Node.is_initialized

            component_outlet_object.setName("#{component.name} Primary Outlet Air Node")
          end
          unless component.secondaryAirInletModelObject.empty?
            component_inlet_object = component.secondaryAirInletModelObject.get
            next unless component_inlet_object.to_Node.is_initialized

            component_inlet_object.setName("#{component.name} Secondary Inlet Air Node")
          end
        end

        # rename straight component outlet nodes
        if component.to_StraightComponent.is_initialized
          unless component.to_StraightComponent.get.outletModelObject.empty?
            component_outlet_object = component.to_StraightComponent.get.outletModelObject.get
            next unless component_outlet_object.to_Node.is_initialized

            component_outlet_object.setName("#{component.name} Outlet Air Node")
          end
        end
      end

      # rename zone hvac component nodes
      if component.to_ZoneHVACComponent.is_initialized
        component = component.to_ZoneHVACComponent.get
        unless component.airInletModelObject.empty?
          component_inlet_object = component.airInletModelObject.get
          next unless component_inlet_object.to_Node.is_initialized

          component_inlet_object.setName("#{component.name} Inlet Air Node")
        end
        unless component.airOutletModelObject.empty?
          component_outlet_object = component.airOutletModelObject.get
          next unless component_outlet_object.to_Node.is_initialized

          component_outlet_object.setName("#{component.name} Outlet Air Node")
        end
      end
    end

    # rename supply side nodes
    model.getAirLoopHVACs.sort.each do |air_loop|
      air_loop_name = air_loop.name.to_s
      air_loop.demandInletNode.setName("#{air_loop_name} Demand Inlet Node")
      air_loop.demandOutletNode.setName("#{air_loop_name} Demand Outlet Node")
      air_loop.supplyInletNode.setName("#{air_loop_name} Supply Inlet Node")
      air_loop.supplyOutletNode.setName("#{air_loop_name} Supply Outlet Node")

      unless air_loop.reliefAirNode.empty?
        relief_node = air_loop.reliefAirNode.get
        relief_node.setName("#{air_loop_name} Relief Air Node")
      end

      unless air_loop.mixedAirNode.empty?
        mixed_node = air_loop.mixedAirNode.get
        mixed_node.setName("#{air_loop_name} Mixed Air Node")
      end

      # rename outdoor air system and nodes
      unless air_loop.airLoopHVACOutdoorAirSystem.empty?
        oa_system = air_loop.airLoopHVACOutdoorAirSystem.get
        unless oa_system.outboardOANode.empty?
          oa_node = oa_system.outboardOANode.get
          oa_node.setName("#{air_loop_name} Outdoor Air Node")
        end
      end
    end

    # rename zone air and terminal nodes
    model.getThermalZones.sort.each do |zone|
      zone.zoneAirNode.setName("#{zone.name} Zone Air Node")

      unless zone.returnAirModelObject.empty?
        zone.returnAirModelObject.get.setName("#{zone.name} Return Air Node")
      end

      unless zone.airLoopHVACTerminal.empty?
        terminal_unit = zone.airLoopHVACTerminal.get
        if terminal_unit.to_StraightComponent.is_initialized
          component = terminal_unit.to_StraightComponent.get
          component.inletModelObject.get.setName("#{terminal_unit.name} Inlet Air Node")
        end
      end
    end

    # rename zone equipment list objects
    model.getZoneHVACEquipmentLists.sort.each do |obj|
      begin
        zone = obj.thermalZone
        obj.setName("#{zone.name} Zone HVAC Equipment List")
      rescue StandardError => e
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Removing ZoneHVACEquipmentList #{obj.name}; missing thermal zone.")
        obj.remove
      end
    end

    return model
  end

  # renames plant loop nodes to readable values
  def rename_plant_loop_nodes(model)
    # rename all hvac components on plant loops
    model.getHVACComponents.sort.each do |component|
      next if component.to_Node.is_initialized # skip nodes

      unless component.plantLoop.empty?
        # rename straight component nodes
        # some inlet or outlet nodes may get renamed again
        if component.to_StraightComponent.is_initialized
          unless component.to_StraightComponent.get.inletModelObject.empty?
            component_inlet_object = component.to_StraightComponent.get.inletModelObject.get
            next unless component_inlet_object.to_Node.is_initialized

            component_inlet_object.setName("#{component.name} Inlet Water Node")
          end
          unless component.to_StraightComponent.get.outletModelObject.empty?
            component_outlet_object = component.to_StraightComponent.get.outletModelObject.get
            next unless component_outlet_object.to_Node.is_initialized

            component_outlet_object.setName("#{component.name} Outlet Water Node")
          end
        end

        # rename water to air component nodes
        if component.to_WaterToAirComponent.is_initialized
          component = component.to_WaterToAirComponent.get
          unless component.waterInletModelObject.empty?
            component_inlet_object = component.waterInletModelObject.get
            next unless component_inlet_object.to_Node.is_initialized

            component_inlet_object.setName("#{component.name} Inlet Water Node")
          end
          unless component.waterOutletModelObject.empty?
            component_outlet_object = component.waterOutletModelObject.get
            next unless component_outlet_object.to_Node.is_initialized

            component_outlet_object.setName("#{component.name} Outlet Water Node")
          end
        end

        # rename water to water component nodes
        if component.to_WaterToWaterComponent.is_initialized
          component = component.to_WaterToWaterComponent.get
          unless component.demandInletModelObject.empty?
            demand_inlet_object = component.demandInletModelObject.get
            next unless demand_inlet_object.to_Node.is_initialized

            demand_inlet_object.setName("#{component.name} Demand Inlet Water Node")
          end
          unless component.demandOutletModelObject.empty?
            demand_outlet_object = component.demandOutletModelObject.get
            next unless demand_outlet_object.to_Node.is_initialized

            demand_outlet_object.setName("#{component.name} Demand Outlet Water Node")
          end
          unless component.supplyInletModelObject.empty?
            supply_inlet_object = component.supplyInletModelObject.get
            next unless supply_inlet_object.to_Node.is_initialized

            supply_inlet_object.setName("#{component.name} Supply Inlet Water Node")
          end
          unless component.supplyOutletModelObject .empty?
            supply_outlet_object = component.supplyOutletModelObject .get
            next unless supply_outlet_object.to_Node.is_initialized

            supply_outlet_object.setName("#{component.name} Supply Outlet Water Node")
          end
        end
      end
    end

    # rename plant nodes
    model.getPlantLoops.sort.each do |plant_loop|
      plant_loop_name = plant_loop.name.to_s
      plant_loop.demandInletNode.setName("#{plant_loop_name} Demand Inlet Node")
      plant_loop.demandOutletNode.setName("#{plant_loop_name} Demand Outlet Node")
      plant_loop.supplyInletNode.setName("#{plant_loop_name} Supply Inlet Node")
      plant_loop.supplyOutletNode.setName("#{plant_loop_name} Supply Outlet Node")
    end
  end
end
