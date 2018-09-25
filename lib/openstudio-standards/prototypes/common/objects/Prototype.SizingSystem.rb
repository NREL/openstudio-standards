class Standard
  # @!group Sizing System

  # Prototype SizingSystem object
  #
  # @param air_loop_hvac [<OpenStudio::Model::AirLoopHVAC>] air loop to set sizing system properties
  # @param dsgn_temps [Hash] a hash of design temperature lookups from standard_design_sizing_temperatures
  def adjust_sizing_system(air_loop_hvac,
                           dsgn_temps,
                           type_of_load_sizing: 'Sensible',
                           min_sys_airflow_ratio: 0.3,
                           sizing_option: 'Coincident')

    # adjust sizing system defaults
    sizing_system = air_loop_hvac.sizingSystem
    sizing_system.setTypeofLoadtoSizeOn(type_of_load_sizing)
    sizing_system.autosizeDesignOutdoorAirFlowRate
    sizing_system.setPreheatDesignTemperature(dsgn_temps['prehtg_dsgn_sup_air_temp_c'])
    sizing_system.setPrecoolDesignTemperature(dsgn_temps['preclg_dsgn_sup_air_temp_c'])
    sizing_system.setCentralCoolingDesignSupplyAirTemperature(dsgn_temps['clg_dsgn_sup_air_temp_c'])
    sizing_system.setCentralHeatingDesignSupplyAirTemperature(dsgn_temps['htg_dsgn_sup_air_temp_c'])
    sizing_system.setPreheatDesignHumidityRatio(0.008)
    sizing_system.setPrecoolDesignHumidityRatio(0.008)
    sizing_system.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
    sizing_system.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
    sizing_system.setMinimumSystemAirFlowRatio(min_sys_airflow_ratio)
    sizing_system.setSizingOption(sizing_option)
    sizing_system.setAllOutdoorAirinCooling(false)
    sizing_system.setAllOutdoorAirinHeating(false)
    sizing_system.setSystemOutdoorAirMethod('ZoneSum')
    sizing_system.setCoolingDesignAirFlowMethod('DesignDay')
    sizing_system.setHeatingDesignAirFlowMethod('DesignDay')

    return sizing_system
  end
end