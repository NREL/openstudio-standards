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
    sub_category = ''

    # heating coil
    if coil_dx.iddObjectType.valueName.to_s.include? 'OS_Coil_Heating_DX'
      if sys_type == 'PTHP'
        sub_category = 'PTHP'
      elsif capacity < 65000
        sub_category = 'Single Package'
      else
        sub_category = '47F db/43F wb outdoor air'
      end
    end

    # cooling coil
    if coil_dx.iddObjectType.valueName.to_s.include? 'OS_Coil_Cooling_DX'
      case sys_type
      when 'PTHP'
        sub_category = 'PTHP'
      when 'PTAC'
        sub_category = 'PTAC'
      when 'PSZ_HP'
        if capacity < 65000
          sub_category = 'Single Package'
        else
          sub_category = 'Split-system and single package'
        end
      else
        sub_category = 'Split-system and single package'
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
    if subcategory != ''
      search_criteria['subcategory'] = subcategory
    end

    if coil_dx.iddObjectType.valueName.to_s != 'OS_Coil_Heating_DX_SingleSpeed'
      search_criteria['heating_type'] = 'All Other'
    end

    return search_criteria
  end
end
