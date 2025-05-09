class Standard
  # @!group utilities

  # load a model into OS & version translates, exiting and erroring if a problem is found
  #
  # @param model_path_string [String] file path to OpenStudio model file
  # @return [OpenStudio::Model::Model] OpenStudio model object
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

  # Remove all resource objects in the model
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [OpenStudio::Model::Model] OpenStudio model object
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
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [OpenStudio::Model::Model] OpenStudio model object
  def remove_air_loops(model)
    model.getAirLoopHVACs.each(&:remove)
    return model
  end

  # Remove plant loops in model except those used for service hot water
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [OpenStudio::Model::Model] OpenStudio model object
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
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [OpenStudio::Model::Model] OpenStudio model object
  def remove_all_plant_loops(model)
    model.getPlantLoops.each(&:remove)
    return model
  end

  # Remove VRF units
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [OpenStudio::Model::Model] OpenStudio model object
  def remove_vrf(model)
    model.getAirConditionerVariableRefrigerantFlows.each(&:remove)
    model.getZoneHVACTerminalUnitVariableRefrigerantFlows.each(&:remove)
    return model
  end

  # Remove zone equipment except for exhaust fans
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [OpenStudio::Model::Model] OpenStudio model object
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
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [OpenStudio::Model::Model] OpenStudio model object
  def remove_all_zone_equipment(model)
    model.getThermalZones.each do |zone|
      zone.equipment.each(&:remove)
    end
    return model
  end

  # Remove unused performance curves
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [OpenStudio::Model::Model] OpenStudio model object
  def remove_unused_curves(model)
    model.getCurves.each do |curve|
      if curve.directUseCount == 0
        model.removeObject(curve.handle)
      end
    end
    return model
  end

  # Remove HVAC equipment except for service hot water loops and zone exhaust fans
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [OpenStudio::Model::Model] OpenStudio model object
  def remove_hvac(model)
    remove_air_loops(model)
    remove_plant_loops(model)
    remove_vrf(model)
    remove_zone_equipment(model)
    remove_unused_curves(model)
    return model
  end

  # Remove all HVAC equipment including service hot water loops and zone exhaust fans
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [OpenStudio::Model::Model] OpenStudio model object
  def remove_all_hvac(model)
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
      si_coeffs << (coeffs[0] + (32.0 * (coeffs[1] + coeffs[3])) + (1024.0 * (coeffs[2] + coeffs[4] + coeffs[5])))
      si_coeffs << ((9.0 / 5.0 * coeffs[1]) + (576.0 / 5.0 * coeffs[2]) + (288.0 / 5.0 * coeffs[5]))
      si_coeffs << (81.0 / 25.0 * coeffs[2])
      si_coeffs << ((9.0 / 5.0 * coeffs[3]) + (576.0 / 5.0 * coeffs[4]) + (288.0 / 5.0 * coeffs[5]))
      si_coeffs << (81.0 / 25.0 * coeffs[4])
      si_coeffs << (81.0 / 25.0 * coeffs[5])
      return si_coeffs
    else
      # Convert SI curves to IP curves
      ip_coeffs = []
      ip_coeffs << (coeffs[0] - (160.0 / 9.0 * (coeffs[1] + coeffs[3])) + (25_600.0 / 81.0 * (coeffs[2] + coeffs[4] + coeffs[5])))
      ip_coeffs << (5.0 / 9.0 * (coeffs[1] - (320.0 / 9.0 * coeffs[2]) - (160.0 / 9.0 * coeffs[5])))
      ip_coeffs << (25.0 / 81.0 * coeffs[2])
      ip_coeffs << (5.0 / 9.0 * (coeffs[3] - (320.0 / 9.0 * coeffs[4]) - (160.0 / 9.0 * coeffs[5])))
      ip_coeffs << (25.0 / 81.0 * coeffs[4])
      ip_coeffs << (25.0 / 81.0 * coeffs[5])
      return ip_coeffs
    end
  end

  # Create a biquadratic curve of the form
  # z = C1 + C2*x + C3*x^2 + C4*y + C5*y^2 + C6*x*y
  #
  # @author Scott Horowitz, NREL
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param coeffs [Array<Double>] an array of 6 coefficients, in order
  # @param crv_name [String] the name of the curve
  # @param min_x [Double] the minimum value of independent variable X that will be used
  # @param max_x [Double] the maximum value of independent variable X that will be used
  # @param min_y [Double] the minimum value of independent variable Y that will be used
  # @param max_y [Double] the maximum value of independent variable Y that will be used
  # @param min_out [Double] the minimum value of dependent variable Z
  # @param max_out [Double] the maximum value of dependent variable Z
  # @return [OpenStudio::Model::CurveBiquadratic] a biquadratic curve
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
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param coeffs [Array<Double>] an array of 10 coefficients, in order
  # @param crv_name [String] the name of the curve
  # @param min_x [Double] the minimum value of independent variable X that will be used
  # @param max_x [Double] the maximum value of independent variable X that will be used
  # @param min_y [Double] the minimum value of independent variable Y that will be used
  # @param max_y [Double] the maximum value of independent variable Y that will be used
  # @param min_out [Double] the minimum value of dependent variable Z
  # @param max_out [Double] the maximum value of dependent variable Z
  # @return [OpenStudio::Model::CurveBicubic] a bicubic curve
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
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param coeffs [Array<Double>] an array of 3 coefficients, in order
  # @param crv_name [String] the name of the curve
  # @param min_x [Double] the minimum value of independent variable X that will be used
  # @param max_x [Double] the maximum value of independent variable X that will be used
  # @param min_out [Double] the minimum value of dependent variable Z
  # @param max_out [Double] the maximum value of dependent variable Z
  # @param is_dimensionless [Boolean] if true, the X independent variable is considered unitless
  #   and the resulting output dependent variable is considered unitless
  # @return [OpenStudio::Model::CurveQuadratic] a quadratic curve
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
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param coeffs [Array<Double>] an array of 4 coefficients, in order
  # @param crv_name [String] the name of the curve
  # @param min_x [Double] the minimum value of independent variable X that will be used
  # @param max_x [Double] the maximum value of independent variable X that will be used
  # @param min_out [Double] the minimum value of dependent variable Z
  # @param max_out [Double] the maximum value of dependent variable Z
  # @return [OpenStudio::Model::CurveCubic] a cubic curve
  def create_curve_cubic(model, coeffs, crv_name, min_x, max_x, min_out, max_out)
    curve = OpenStudio::Model::CurveCubic.new(model)
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
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param coeffs [Array<Double>] an array of 3 coefficients, in order
  # @param crv_name [String] the name of the curve
  # @param min_x [Double] the minimum value of independent variable X that will be used
  # @param max_x [Double] the maximum value of independent variable X that will be used
  # @param min_out [Double] the minimum value of dependent variable Z
  # @param max_out [Double] the maximum value of dependent variable Z
  # @return [OpenStudio::Model::CurveExponent] an exponent curve
  def create_curve_exponent(model, coeffs, crv_name, min_x, max_x, min_out, max_out)
    curve = OpenStudio::Model::CurveExponent.new(model)
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

  # Sets VAV reheat and VAV no reheat terminals on an air loop to control for outdoor air
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param air_loop [<OpenStudio::Model::AirLoopHVAC>] air loop to enable DCV on.
  #   Default is nil, which will apply to all air loops
  # @return [OpenStudio::Model::Model] OpenStudio model object
  def model_set_vav_terminals_to_control_for_outdoor_air(model, air_loop: nil)
    vav_reheats = model.getAirTerminalSingleDuctVAVReheats
    vav_no_reheats = model.getAirTerminalSingleDuctVAVNoReheats

    if air_loop.nil?
      # all terminals
      vav_reheats.each do |vav_reheat|
        vav_reheat.setControlForOutdoorAir(true)
      end
      vav_no_reheats.each do |vav_no_reheat|
        vav_no_reheat.setControlForOutdoorAir(true)
      end
    else
      vav_reheats.each do |vav_reheat|
        next if vav_reheat.airLoopHVAC.get.name.to_s != air_loop.name.to_s

        vav_reheat.setControlForOutdoorAir(true)
      end
      vav_no_reheats.each do |vav_no_reheat|
        next if vav_no_reheat.airLoopHVAC.get.name.to_s != air_loop.name.to_s

        vav_no_reheat.setControlForOutdoorAir(true)
      end
    end
    return model
  end

  # renames air loop nodes to readable values
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [OpenStudio::Model::Model] OpenStudio model object
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
        if component.to_StraightComponent.is_initialized && !component.to_StraightComponent.get.outletModelObject.empty?
          component_outlet_object = component.to_StraightComponent.get.outletModelObject.get
          next unless component_outlet_object.to_Node.is_initialized

          component_outlet_object.setName("#{component.name} Outlet Air Node")
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
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [OpenStudio::Model::Model] OpenStudio model object
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
          unless component.supplyOutletModelObject.empty?
            supply_outlet_object = component.supplyOutletModelObject.get
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

    return model
  end

  # converts existing string to ems friendly string
  #
  # @param name [String] original name
  # @return [String] the resulting EMS friendly string
  def ems_friendly_name(name)
    # replace white space and special characters with underscore
    # \W is equivalent to [^a-zA-Z0-9_]
    new_name = name.to_s.gsub(/\W/, '_')

    # prepend ems_ in case the name starts with a number
    new_name = "ems_#{new_name}"

    return new_name
  end

  def true?(obj)
    obj.to_s.downcase == 'true'
  end
end
