class BTAPPRE19880

  # Go through the default construction sets and hard-assigned
  # constructions. Clone the existing constructions and set their
  # intended surface type and standards construction type per
  # the PRM.  For some standards, this will involve making
  # modifications.  For others, it will not.
  #
  # 90.1-2007, 90.1-2010, 90.1-2013
  # @return [Bool] returns true if successful, false if not

  def apply_standard_construction_properties(model:,
                                             runner: nil,
                                             properties: {
                                                 'outdoors_wall_conductance' => nil,
                                                 'outdoors_floor_conductance' => nil,
                                                 'outdoors_roofceiling_conductance' => nil,
                                                 'ground_wall_conductance' => nil,
                                                 'ground_floor_conductance' => nil,
                                                 'ground_roofceiling_conductance' => nil,
                                                 'outdoors_door_conductance' => nil,
                                                 'outdoors_fixedwindow_conductance' => nil
                                             })

    model.getDefaultConstructionSets.sort.each do |set|
      set_construction_set_to_necb!(model: model,
                                    default_surface_construction_set: set,
                                    runner: nil,
                                    properties: properties)
      assign_SHGC_to_windows(model: model, default_surface_construction_set: set)
    end
    # sets all surfaces to use default constructions sets except adiabatic, where it does a hard assignment of the interior wall construction type.
    model.getPlanarSurfaces.sort.each(&:resetConstruction)
    # if the default construction set is defined..try to assign the interior wall to the adiabatic surfaces
    BTAP::Resources::Envelope.assign_interior_surface_construction_to_adiabatic_surfaces(model, nil)
  end

  def assign_SHGC_to_Windows(model:, default_surface_construction_set:)
    #surface_types_rsi["#{surface_type['boundary_condition'].downcase}_#{surface_type['surface'].downcase}_conductance"] = surface_type['conductance'].nil? ? 1.0 / (eval(self.model_find_objects(standards_table, surface_type)[0]['formula'])) : (1.0 / surface_type['conductance'])
    #puts 'hello'
  end
end