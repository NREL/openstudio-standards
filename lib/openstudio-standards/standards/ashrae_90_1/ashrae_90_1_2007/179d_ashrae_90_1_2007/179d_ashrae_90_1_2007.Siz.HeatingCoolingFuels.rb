
class OpenStudio::Model::Model

  # Get the heating fuel type of a plant loop
  # @todo If no heating equipment is found, check if there's a heat exchanger,
  # or a WaterHeater:Mixed or stratified that is connected to a heating source on the demand side
  def plant_loop_heating_fuels(plant_loop)
    fuels = []
    # Get the heating fuels for all supply components
    # on this plant loop.
    plant_loop.supplyComponents.each do |component|
       # Get the object type
      obj_type = component.iddObjectType.valueName.to_s
      case obj_type
      when 'OS_Boiler_HotWater'
        component = component.to_BoilerHotWater.get
        fuels << component.fuelType
      when 'OS_Boiler_Steam'
        component = component.to_BoilerHotWater.get
        fuels << component.fuelType
      when 'OS_DistrictHeating'
        fuels << 'DistrictHeating'
      when 'OS_HeatPump_WaterToWater_EquationFit_Heating'
        fuels << 'Electricity'
      when 'OS_SolarCollector_FlatPlate_PhotovoltaicThermal'
        fuels << 'SolarEnergy'
      when 'OS_SolarCollector_FlatPlate_Water'
        fuels << 'SolarEnergy'
      when 'OS_SolarCollector_IntegralCollectorStorage'
        fuels << 'SolarEnergy'
      when 'OS_WaterHeater_HeatPump'
        fuels << 'Electricity'
      when 'OS_WaterHeater_Mixed'
        component = component.to_WaterHeaterMixed.get

        # Check if the heater actually has a capacity (otherwise it's simply a Storage Tank)
        if component.heaterMaximumCapacity.empty? || component.heaterMaximumCapacity.get != 0
          # If it does, we add the heater Fuel Type
          fuels << component.heaterFuelType
        end
        # @todo not sure about whether it should be an elsif or not
        # Check the plant loop connection on the source side
        if component.secondaryPlantLoop.is_initialized
          fuels += self.plant_loop_heating_fuels(component.secondaryPlantLoop.get)
        end
      when 'OS_WaterHeater_Stratified'
        component = component.to_WaterHeaterStratified.get

        # Check if the heater actually has a capacity (otherwise it's simply a Storage Tank)
        if component.heaterMaximumCapacity.empty? || component.heaterMaximumCapacity.get != 0
          # If it does, we add the heater Fuel Type
          fuels << component.heaterFuelType
        end
        # @todo not sure about whether it should be an elsif or not
        # Check the plant loop connection on the source side
        if component.secondaryPlantLoop.is_initialized
          fuels += self.plant_loop_heating_fuels(component.secondaryPlantLoop.get)
        end
      when 'OS_HeatExchanger_FluidToFluid'
        hx = component.to_HeatExchangerFluidToFluid.get
        cooling_hx_control_types = ['CoolingSetpointModulated', 'CoolingSetpointOnOff', 'CoolingDifferentialOnOff', 'CoolingSetpointOnOffWithComponentOverride']
        cooling_hx_control_types.each {|x| x.downcase!}
        if !cooling_hx_control_types.include?(hx.controlType.downcase) && hx.secondaryPlantLoop.is_initialized
          fuels += self.plant_loop_heating_fuels(hx.secondaryPlantLoop.get)
        end
      when 'OS_Node', 'OS_Pump_ConstantSpeed', 'OS_Pump_VariableSpeed', 'OS_Connector_Splitter', 'OS_Connector_Mixer', 'OS_Pipe_Adiabatic'
        # To avoid extraneous debug messages
      else
        #OpenStudio::logFree(OpenStudio::Debug, 'openstudio.sizing.Model', "No heating fuel types found for #{obj_type}")
      end
    end

    return fuels.uniq.sort

  end
end
