class ASHRAE901PRM < Standard
  # @!group CoilCoolingDXTwoSpeed

  include ASHRAEPRMCoilDX

  # Finds capacity in W
  #
  # @param coil_cooling_dx_two_speed [OpenStudio::Model::CoilCoolingDXTwoSpeed] coil cooling dx two speed object
  # @param sys_type [String] HVAC system type
  # @return [Double] capacity in W to be used for find object
  def coil_cooling_dx_two_speed_find_capacity(coil_cooling_dx_two_speed, sys_type)
    capacity_w = nil
    if coil_cooling_dx_two_speed.ratedHighSpeedTotalCoolingCapacity.is_initialized
      capacity_w = coil_cooling_dx_two_speed.ratedHighSpeedTotalCoolingCapacity.get
    elsif coil_cooling_dx_two_speed.autosizedRatedHighSpeedTotalCoolingCapacity.is_initialized
      capacity_w = coil_cooling_dx_two_speed.autosizedRatedHighSpeedTotalCoolingCapacity.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXTwoSpeed', "For #{coil_cooling_dx_two_speed.name} capacity is not available, cannot apply efficiency standard.")
      return 0.0
    end

    # If it's a PTAC or PTHP System, we need to divide the capacity by the potential zone multiplier
    # because the COP is dependent on capacity, and the capacity should be the capacity of a single zone, not all the zones
    if sys_type == 'PTAC' || sys_type == 'PTHP'
      mult = 1
      comp = coil_cooling_dx_two_speed.containingZoneHVACComponent
      if comp.is_initialized && comp.get.thermalZone.is_initialized
        mult = comp.get.thermalZone.get.multiplier
        if mult > 1
          total_cap = capacity_w
          capacity_w /= mult
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXTwoSpeed', "For #{coil_cooling_dx_single_speed.name}, total capacity of #{OpenStudio.convert(total_cap, 'W', 'kBtu/hr').get.round(2)}kBTU/hr was divided by the zone multiplier of #{mult} to give #{capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get.round(2)}kBTU/hr.")
        end
      end
    end

    return capacity_w
  end

  # Finds lookup object in standards and return efficiency
  #
  # @param coil_cooling_dx_two_speed [OpenStudio::Model::CoilCoolingDXTwoSpeed] coil cooling dx two speed object
  # @param sys_type [String] HVAC system type
  # @param rename [Boolean] if true, object will be renamed to include capacity and efficiency level
  # @return [Double] full load efficiency (COP)
  def coil_cooling_dx_two_speed_standard_minimum_cop(coil_cooling_dx_two_speed, sys_type, rename = false)
    # find properties
    capacity_w = coil_cooling_dx_two_speed_find_capacity(coil_cooling_dx_two_speed, sys_type)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    search_criteria = coil_dx_find_search_criteria(coil_cooling_dx_two_speed, capacity_btu_per_hr, sys_type)

    # Lookup efficiencies depending on whether it is a unitary AC or a heat pump
    ac_props = nil
    ac_props = if sys_type == 'PSZ_HP' || sys_type == 'PTHP'
                 model_find_object(standards_data['heat_pumps'], search_criteria, capacity_btu_per_hr, Date.today)
               else
                 model_find_object(standards_data['unitary_acs'], search_criteria, capacity_btu_per_hr, Date.today)
               end

    # Get the minimum efficiency standards
    cop = nil

    # Check to make sure properties were found
    if ac_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXTwoSpeed', "For #{coil_cooling_dx_two_speed.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      return cop # value of nil
    end

    cop = ac_props['copnfcooling']
    new_comp_name = "#{coil_cooling_dx_two_speed.name} #{capacity_btu_per_hr.round}Btu/hr #{cop}COP"

    # Rename
    if rename
      coil_cooling_dx_two_speed.setName(new_comp_name)
    end

    return cop
  end

  # Applies the standard efficiency ratings to this object.
  #
  # @param coil_cooling_dx_two_speed [OpenStudio::Model::CoilCoolingDXTwoSpeed] coil cooling dx two speed object
  # @param sql_db_vars_map [Hash] hash map
  # @param sys_type [String] HVAC system type
  # @return [Hash] hash of coil objects
  def coil_cooling_dx_two_speed_apply_efficiency_and_curves(coil_cooling_dx_two_speed, sql_db_vars_map, sys_type)
    # Preserve the original name
    orig_name = coil_cooling_dx_two_speed.name.to_s

    # Find the minimum COP and rename with efficiency rating
    cop = coil_cooling_dx_two_speed_standard_minimum_cop(coil_cooling_dx_two_speed, sys_type, true)

    # Map the original name to the new name
    sql_db_vars_map[coil_cooling_dx_two_speed.name.to_s] = orig_name

    # Set the efficiency values
    unless cop.nil?
      coil_cooling_dx_two_speed.setRatedHighSpeedCOP(cop)
      coil_cooling_dx_two_speed.setRatedLowSpeedCOP(cop)
    end

    return sql_db_vars_map
  end
end
