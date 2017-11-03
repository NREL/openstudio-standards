class NECB_2011_Model < StandardsModel
  def model_add_hvac(model, building_type, climate_zone, prototype_input, epw_file)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')
    boiler_fueltype, baseboard_type, mau_type, mau_heating_coil_type, mua_cooling_type, chiller_type, heating_coil_types_sys3, heating_coil_types_sys4, heating_coil_types_sys6, fan_type, swh_fueltype = BTAP::Environment.get_canadian_system_defaults_by_weatherfile_name(epw_file)
    BTAP::Compliance::NECB2011.necb_autozone_and_autosystem(model, runner = nil, use_ideal_air_loads = false, boiler_fueltype, mau_type, mau_heating_coil_type, baseboard_type, chiller_type, mua_cooling_type, heating_coil_types_sys3, heating_coil_types_sys4, heating_coil_types_sys6, fan_type, swh_fueltype, building_type)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')

    return true
  end # add hvac
  
  # Determine whether or not water fixtures are attached to spaces
  def model_attach_water_fixtures_to_spaces?(model)
    return true
  end
end
  