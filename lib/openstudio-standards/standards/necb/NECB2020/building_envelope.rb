
class NECB2020

  # Go through the default construction sets and hard-assigned
  # constructions. Clone the existing constructions and set their
  # intended surface type and standards construction type per
  # the PRM.  For some standards, this will involve making
  # modifications.  For others, it will not.
  #
  # 90.1-2007, 90.1-2010, 90.1-2013
  # @return [Boolean] returns true if successful, false if not

  def apply_standard_construction_properties(model:,
                                             necb_hdd: true,
                                             runner: nil,
                                             # ext surfaces
                                             ext_wall_cond: nil,
                                             ext_floor_cond: nil,
                                             ext_roof_cond: nil,
                                             # ground surfaces
                                             ground_wall_cond: nil,
                                             ground_floor_cond: nil,
                                             ground_roof_cond: nil,
                                             # fixed Windows
                                             fixed_window_cond: nil,
                                             fixed_wind_solar_trans: nil,
                                             fixed_wind_vis_trans: nil,
                                             # operable windows
                                             operable_wind_solar_trans: nil,
                                             operable_window_cond: nil,
                                             operable_wind_vis_trans: nil,
                                             # glass doors
                                             glass_door_cond: nil,
                                             glass_door_solar_trans: nil,
                                             glass_door_vis_trans: nil,
                                             # opaque doors
                                             door_construction_cond: nil,
                                             overhead_door_cond: nil,
                                             # skylights
                                             skylight_cond: nil,
                                             skylight_solar_trans: nil,
                                             skylight_vis_trans: nil,
                                             # tubular daylight dome
                                             tubular_daylight_dome_cond: nil,
                                             tubular_daylight_dome_solar_trans: nil,
                                             tubular_daylight_dome_vis_trans: nil,
                                             # tubular daylight diffuser
                                             tubular_daylight_diffuser_cond: nil,
                                             tubular_daylight_diffuser_solar_trans: nil,
                                             tubular_daylight_diffuser_vis_trans: nil)

    model.getDefaultConstructionSets.sort.each do |default_surface_construction_set|
      BTAP.runner_register('Info', 'apply_standard_construction_properties', runner)
      if model.weatherFile.empty? || model.weatherFile.get.path.empty? || !File.exist?(model.weatherFile.get.path.get.to_s)

        BTAP.runner_register('Error', 'Weather file is not defined. Please ensure the weather file is defined and exists.', runner)
        return false
      end

      # hdd required to get correct conductance values from the json file. 
      hdd = get_necb_hdd18(model: model, necb_hdd: necb_hdd)
	  
      # Lambdas are preferred over methods in methods for small utility methods.
      correct_cond = lambda do |conductivity, surface_type|
        return conductivity.nil? || conductivity.to_f <= 0.0 || conductivity == "NECB_Default" ? eval(model_find_objects(@standards_data['surface_thermal_transmittance'], surface_type)[0]['formula']) : conductivity.to_f
      end

      # Converts trans and vis to nil if requesting default.. or casts the string to a float.
      correct_vis_trans = lambda do |value|
        return value.nil? || value.to_f <= 0.0 || value == "NECB_Default" ? nil : value.to_f
      end

      BTAP::Resources::Envelope::ConstructionSets.customize_default_surface_construction_set!(model: model,
                                                                                              name: "#{default_surface_construction_set.name.get} at hdd = #{hdd}",
                                                                                              default_surface_construction_set: default_surface_construction_set,
                                                                                              # ext surfaces
                                                                                              ext_wall_cond: correct_cond.call(ext_wall_cond, {'boundary_condition' => 'Outdoors', 'surface' => 'Wall'}),
                                                                                              ext_floor_cond: correct_cond.call(ext_floor_cond, {'boundary_condition' => 'Outdoors', 'surface' => 'Floor'}),
                                                                                              ext_roof_cond: correct_cond.call(ext_roof_cond, {'boundary_condition' => 'Outdoors', 'surface' => 'RoofCeiling'}),
                                                                                              # ground surfaces
                                                                                              ground_wall_cond: correct_cond.call(ground_wall_cond, {'boundary_condition' => 'Ground', 'surface' => 'Wall'}),
                                                                                              ground_floor_cond: correct_cond.call(ground_floor_cond, {'boundary_condition' => 'Ground', 'surface' => 'Floor'}),
                                                                                              ground_roof_cond: correct_cond.call(ground_roof_cond, {'boundary_condition' => 'Ground', 'surface' => 'RoofCeiling'}),
                                                                                              # fixed Windows
                                                                                              fixed_window_cond: correct_cond.call(fixed_window_cond, {'boundary_condition' => 'Outdoors', 'surface' => 'Window'}),
                                                                                              fixed_wind_solar_trans: correct_vis_trans.call(fixed_wind_solar_trans),
                                                                                              fixed_wind_vis_trans: correct_vis_trans.call(fixed_wind_vis_trans),
                                                                                              # operable windows
                                                                                              operable_wind_solar_trans: correct_vis_trans.call(operable_wind_solar_trans),
                                                                                              operable_window_cond: correct_cond.call(fixed_window_cond, {'boundary_condition' => 'Outdoors', 'surface' => 'Window'}),
                                                                                              operable_wind_vis_trans: correct_vis_trans.call(operable_wind_vis_trans),
                                                                                              # glass doors
                                                                                              glass_door_cond: correct_cond.call(glass_door_cond, {'boundary_condition' => 'Outdoors', 'surface' => 'Window'}),
                                                                                              glass_door_solar_trans: correct_vis_trans.call(glass_door_solar_trans),
                                                                                              glass_door_vis_trans: correct_vis_trans.call(glass_door_vis_trans),
                                                                                              # opaque doors
                                                                                              door_construction_cond: correct_cond.call(door_construction_cond, {'boundary_condition' => 'Outdoors', 'surface' => 'Door'}),
                                                                                              overhead_door_cond: correct_cond.call(overhead_door_cond, {'boundary_condition' => 'Outdoors', 'surface' => 'Door'}),
                                                                                              # skylights
                                                                                              skylight_cond: correct_cond.call(skylight_cond, {'boundary_condition' => 'Outdoors', 'surface' => 'Skylight'}),
                                                                                              skylight_solar_trans: correct_vis_trans.call(skylight_solar_trans),
                                                                                              skylight_vis_trans: correct_vis_trans.call(skylight_vis_trans),
                                                                                              # tubular daylight dome
                                                                                              tubular_daylight_dome_cond: correct_cond.call(skylight_cond, {'boundary_condition' => 'Outdoors', 'surface' => 'Skylight'}),
                                                                                              tubular_daylight_dome_solar_trans: correct_vis_trans.call(tubular_daylight_dome_solar_trans),
                                                                                              tubular_daylight_dome_vis_trans: correct_vis_trans.call(tubular_daylight_dome_vis_trans),
                                                                                              # tubular daylight diffuser
                                                                                              tubular_daylight_diffuser_cond: correct_cond.call(skylight_cond, {'boundary_condition' => 'Outdoors', 'surface' => 'Skylight'}),
                                                                                              tubular_daylight_diffuser_solar_trans: correct_vis_trans.call(tubular_daylight_diffuser_solar_trans),
                                                                                              tubular_daylight_diffuser_vis_trans: correct_vis_trans.call(tubular_daylight_diffuser_vis_trans)
      )
    end
    # sets all surfaces to use default constructions sets except adiabatic, where it does a hard assignment of the interior wall construction type.
    model.getPlanarSurfaces.sort.each(&:resetConstruction)
    # if the default construction set is defined..try to assign the interior wall to the adiabatic surfaces
    BTAP::Resources::Envelope.assign_interior_surface_construction_to_adiabatic_surfaces(model, nil)
    BTAP.runner_register('Info', ' apply_standard_construction_properties was sucessful.', runner)
  end

  # Set all external subsurfaces (doors, windows, skylights) to NECB values.
  # @author phylroy.lopez@nrcan.gc.ca
  # @param subsurface [String]
  # @param hdd [Float]
  def set_necb_external_subsurface_conductance(subsurface, hdd)
    conductance_value = 0

    if subsurface.outsideBoundaryCondition.downcase.match('outdoors')
      case subsurface.subSurfaceType.downcase
      when /window/
        conductance_value = @standards_data['conductances']['Window'].find { |i| i['hdd'] > hdd }['thermal_transmittance'] * scaling_factor
      when /skylight/
        conductance_value = @standards_data['conductances']['Skylight'].find { |i| i['hdd'] > hdd }['thermal_transmittance'] * scaling_factor
      when /door/
        conductance_value = @standards_data['conductances']['Door'].find { |i| i['hdd'] > hdd }['thermal_transmittance'] * scaling_factor
      end
      subsurface.setRSI(1 / conductance_value)
    end
  end
end
