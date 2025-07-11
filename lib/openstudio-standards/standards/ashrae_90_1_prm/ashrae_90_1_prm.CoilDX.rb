# A variety of DX coil methods that are the same regardless of coil type.
# These methods are available to:
# CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilHeatingDXSingleSpeed
module ASHRAEPRMCoilDX
  # @!group CoilDX

  # Finds the subcategory.
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object
  # @param capacity [Double] capacity in btu/hr
  # @param sys_type [String] HVAC system type
  # @return [String] the coil_dx_subcategory(coil_dx)
  def coil_dx_subcategory(coil_dx, capacity, sys_type)
    sub_category = nil
    if coil_dx.iddObjectType.valueName.to_s.include? 'OS_Coil_Cooling_DX'
      case sys_type
      when 'PTHP'
        sub_category = nil
      when 'PTAC'
        sub_category = nil
      when 'PSZ_HP'
        if capacity < 65000
          sub_category = 'Single Package'
        end
      else
        sub_category = 'Single Package'
      end
    end

    return sub_category
  end

  # Finds the search criteria
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object
  # @param capacity [Double] capacity in btu/hr
  # @param sys_type [String] HVAC system type
  # @return [Hash] has for search criteria to be used for find object
  def coil_dx_find_search_criteria(coil_dx, capacity, sys_type)
    search_criteria = {}
    search_criteria['template'] = template

    search_criteria['cooling_type'] = 'AirCooled'

    # Get the coil_dx_subcategory(coil_dx)
    subcategory = coil_dx_subcategory(coil_dx, capacity, sys_type)
    unless subcategory.nil?
      search_criteria['subcategory'] = subcategory
    end

    if coil_dx.iddObjectType.valueName.to_s != 'OS_Coil_Heating_DX_SingleSpeed'
      search_criteria['heating_type'] = 'Any'
    end

    if sys_type == 'PTAC'
      search_criteria['equipment_type'] = sys_type
    elsif sys_type == 'PTHP'
      search_criteria['equipment_type'] = sys_type
    elsif sys_type == 'PSZ_AC'
      search_criteria['equipment_type'] = 'Air Conditioners'
    elsif sys_type == 'PSZ_HP'
      search_criteria['equipment_type'] = 'Heat Pumps'
    end

    return search_criteria
  end
end
