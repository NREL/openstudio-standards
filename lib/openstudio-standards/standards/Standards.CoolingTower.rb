# A variety of cooling tower methods that are the same regardless of type.
# These methods are available to CoolingTowerSingleSpeed, CoolingTowerTwoSpeed, and CoolingTowerVariableSpeed
module CoolingTower
  # @!group CoolingTower

  # Set the cooling tower fan power such that the tower
  # hits the minimum performance (gpm/hp) specified by the standard.
  # Note that in this case hp is motor nameplate hp, per 90.1.
  # This method assumes that the fan brake horsepower is 90%
  # of the motor nameplate hp.
  # This method determines the minimum motor efficiency
  # for the nameplate motor hp and sets the actual
  # fan power by multiplying the brake horsepower
  # by the efficiency.  Thus the fan power used as
  # an input to the simulation divided by the design flow
  # rate will not (and should not)
  # exactly equal the minimum tower performance.
  #
  # @param cooling_tower [OpenStudio::Model::StraightComponent] cooling tower object, allowable types:
  #   CoolingTowerSingleSpeed, CoolingTowerTwoSpeed, and CoolingTowerVariableSpeed
  # @return [Bool] returns true if successful, false if not
  def cooling_tower_apply_minimum_power_per_flow(cooling_tower)
    # Get the design water flow rate
    design_water_flow_m3_per_s = nil
    if cooling_tower.designWaterFlowRate.is_initialized
      design_water_flow_m3_per_s = cooling_tower.designWaterFlowRate.get
    elsif cooling_tower.autosizedDesignWaterFlowRate.is_initialized
      design_water_flow_m3_per_s = cooling_tower.autosizedDesignWaterFlowRate.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoolingTower', "For #{cooling_tower.name} design water flow rate is not available, cannot apply efficiency standard.")
      return false
    end
    design_water_flow_gpm = OpenStudio.convert(design_water_flow_m3_per_s, 'm^3/s', 'gal/min').get

    # Get the table of cooling tower efficiencies
    heat_rejection = standards_data['heat_rejection']

    # Define the criteria to find the cooling tower properties
    # in the hvac standards data set.
    search_criteria = {}
    search_criteria['template'] = template

    # By definition cooling towers in E+ are open.
    # Closed cooling towers are the fluidcooler objects.
    search_criteria['equipment_type'] = 'Open Cooling Tower'

    # @todo Standards replace this with a mechanism to store this
    # data in the cooling tower object itself.
    # For now, retrieve the fan type from the name
    name = cooling_tower.name.get
    fan_type = nil
    if name.include?('Centrifugal')
      fan_type = 'Centrifugal'
    elsif name.include?('Propeller or Axial')
      fan_type = 'Propeller or Axial'
    end
    unless fan_type.nil?
      search_criteria['fan_type'] = fan_type
    end

    # Limit on Centrifugal Fan
    # Open Circuit Cooling Towers.
    if fan_type == 'Centrifugal'
      gpm_limit = cooling_tower_apply_minimum_power_per_flow_gpm_limit(cooling_tower)
      if gpm_limit
        if design_water_flow_gpm >= gpm_limit
          fan_type = 'Propeller or Axial'
          search_criteria['fan_type'] = fan_type
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoolingTower', "For #{cooling_tower.name}, the design flow rate of #{design_water_flow_gpm.round} gpm is higher than the limit of #{gpm_limit.round} gpm for open centrifugal towers.  This tower must meet the minimum performance of #{fan_type} instead.")
        end
      end
    end

    # Get the cooling tower properties
    ct_props = model_find_object(heat_rejection, search_criteria)
    unless ct_props
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoolingTower', "For #{cooling_tower.name}, cannot find heat rejection properties, cannot apply standard efficiencies or curves.")
      return false
    end

    # Get cooling tower efficiency
    min_gpm_per_hp = ct_props['minimum_performance']
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoolingTower', "For #{cooling_tower.name}, design water flow = #{design_water_flow_gpm.round} gpm, minimum performance = #{min_gpm_per_hp} gpm/hp (nameplate).")

    # Calculate the allowed fan brake horsepower
    # per method used in PNNL prototype buildings.
    # Assumes that the fan brake horsepower is 90%
    # of the fan nameplate rated motor power.
    fan_motor_nameplate_hp = design_water_flow_gpm / min_gpm_per_hp
    fan_bhp = 0.9 * fan_motor_nameplate_hp

    # Lookup the minimum motor efficiency
    fan_motor_eff = 0.85
    motors = standards_data['motors']

    # Assuming all fan motors are 4-pole Enclosed
    search_criteria = {
      'template' => template,
      'number_of_poles' => 4.0,
      'type' => 'Enclosed'
    }

    motor_properties = model_find_object(motors, search_criteria, fan_motor_nameplate_hp)
    if motor_properties.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CoolingTower', "For #{cooling_tower.name}, could not find motor properties using search criteria: #{search_criteria}, motor_hp = #{fan_motor_nameplate_hp} hp.")
      return false
    end

    fan_motor_eff = motor_properties['nominal_full_load_efficiency']
    nominal_hp = motor_properties['maximum_capacity'].to_f.round(1)
    # Round to nearest whole HP for niceness
    if nominal_hp >= 2
      nominal_hp = nominal_hp.round
    end

    # Calculate the fan motor power
    fan_motor_actual_power_hp = fan_bhp / fan_motor_eff
    # Convert to W
    fan_motor_actual_power_w = fan_motor_actual_power_hp * 745.7 # 745.7 W/HP

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoolingTower', "For #{cooling_tower.name}, allowed fan motor nameplate hp = #{fan_motor_nameplate_hp.round(1)} hp, fan brake horsepower = #{fan_bhp.round(1)}, and fan motor actual power = #{fan_motor_actual_power_hp.round(1)} hp (#{fan_motor_actual_power_w.round} W) at #{fan_motor_eff} motor efficiency.")

    # Append the efficiency to the name
    cooling_tower.setName("#{cooling_tower.name} #{min_gpm_per_hp.round(1)} gpm/hp")

    # Hard size the design fan power.
    # Leave the water flow and air flow autosized.
    if cooling_tower.to_CoolingTowerSingleSpeed.is_initialized
      cooling_tower.setFanPoweratDesignAirFlowRate(fan_motor_actual_power_w)
    elsif cooling_tower.to_CoolingTowerTwoSpeed.is_initialized
      cooling_tower.setHighFanSpeedFanPower(fan_motor_actual_power_w)
      cooling_tower.setLowFanSpeedFanPower(0.3 * fan_motor_actual_power_w)
    elsif cooling_tower.to_CoolingTowerVariableSpeed.is_initialized
      cooling_tower.setDesignFanPower(fan_motor_actual_power_w)
    end

    return true
  end

  # Above this point, centrifugal fan cooling towers must meet the limits of propeller or axial cooling towers instead.
  #
  # @param cooling_tower [OpenStudio::Model::StraightComponent] cooling tower object, allowable types:
  #   CoolingTowerSingleSpeed, CoolingTowerTwoSpeed, CoolingTowerVariableSpeed
  # @return [Double] the limit, in gallons per minute.  Return nil for no limit.
  def cooling_tower_apply_minimum_power_per_flow_gpm_limit(cooling_tower)
    gpm_limit = nil
    return gpm_limit
  end
end
