class ASHRAE9012007 < ASHRAE901
  # @!group AirLoopHVAC

  # Determines the OA flow rates above which an economizer is required.
  # Two separate rates, one for systems with an economizer and another
  # for systems without.
  # are zero for both types.
  # @return [Array<Double>] [min_oa_without_economizer_cfm, min_oa_with_economizer_cfm]
  def air_loop_hvac_demand_control_ventilation_limits(air_loop_hvac)
    min_oa_without_economizer_cfm = 3000
    min_oa_with_economizer_cfm = 1200
    return [min_oa_without_economizer_cfm, min_oa_with_economizer_cfm]
  end

  # Determine the air flow and number of story limits
  # for whether motorized OA damper is required.
  # @return [Array<Double>] [minimum_oa_flow_cfm, maximum_stories]
  def air_loop_hvac_motorized_oa_damper_limits(air_loop_hvac, climate_zone)
    case climate_zone
    when 'ASHRAE 169-2006-0A',
         'ASHRAE 169-2006-1A',
         'ASHRAE 169-2006-0B',
         'ASHRAE 169-2006-1B',
         'ASHRAE 169-2006-2A',
         'ASHRAE 169-2006-2B',
         'ASHRAE 169-2006-3A',
         'ASHRAE 169-2006-3B',
         'ASHRAE 169-2006-3C',
         'ASHRAE 169-2013-0A',
         'ASHRAE 169-2013-1A',
         'ASHRAE 169-2013-0B',
         'ASHRAE 169-2013-1B',
         'ASHRAE 169-2013-2A',
         'ASHRAE 169-2013-2B',
         'ASHRAE 169-2013-3A',
         'ASHRAE 169-2013-3B',
         'ASHRAE 169-2013-3C'
      minimum_oa_flow_cfm = 0
      maximum_stories = 999 # Any number of stories
    else
      minimum_oa_flow_cfm = 0
      maximum_stories = 3
    end

    return [minimum_oa_flow_cfm, maximum_stories]
  end

  # Determine the number of stages that should be used as controls
  # for single zone DX systems.  90.1-2007 requires 1 stage.
  #
  # @return [Integer] the number of stages: 0, 1, 2
  def air_loop_hvac_single_zone_controls_num_stages(air_loop_hvac, climate_zone)
    num_stages = 1
    return num_stages
  end

  # Determine the airflow limits that govern whether or not
  # an ERV is required.  Based on climate zone and % OA.
  # @return [Double] the flow rate above which an ERV is required.
  # if nil, ERV is never required.
  def air_loop_hvac_energy_recovery_ventilator_flow_limit(air_loop_hvac, climate_zone, pct_oa)
    erv_cfm = if pct_oa < 0.7
                nil
              else
                # @Todo: Add exceptions (eg: e. cooling systems in climate zones 3C, 4C, 5B, 5C, 6B, 7 and 8 | d. Heating systems in climate zones 1 to 3)
                5000
              end

    return erv_cfm
  end
end
