class BTAPPRE1980

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
      # Set the SHGC of the default glazing material before making new constructions based on it and changing U-values.
      assign_SHGC_to_windows(model: model, default_construction_set: set)
      set_construction_set_to_necb!(model: model,
                                    default_surface_construction_set: set,
                                    runner: nil,
                                    properties: properties)
    end
    # sets all surfaces to use default constructions sets except adiabatic, where it does a hard assignment of the interior wall construction type.
    model.getPlanarSurfaces.sort.each(&:resetConstruction)
    # if the default construction set is defined..try to assign the interior wall to the adiabatic surfaces
    BTAP::Resources::Envelope.assign_interior_surface_construction_to_adiabatic_surfaces(model, nil)
  end

  def assign_SHGC_to_windows(model:, default_construction_set:)
    # Get HDD to determine which SHGC to use
    hdd = self.get_necb_hdd18(model)
    # Determine the solar heat gain coefficient from the standards data
    shgc_table = @standards_data['SHGC']
    shgc = eval(shgc_table[0]['formula'])
    # Find the default window construction material
    sub_surf_consts = default_construction_set.defaultExteriorSubSurfaceConstructions.get
    fixed_window_material = OpenStudio::Model::getConstructionByName(model, sub_surf_consts.fixedWindowConstruction.get.name.to_s).get.getLayer(0).to_SimpleGlazing.get
    # Reset the SHGC for the window material.  When I wrote this all of the windows, doors etc. used the same window
    # material.  So I set the SHGC for that material expecting it will be modified for all of the other constructions
    # too.
    fixed_window_material.setSolarHeatGainCoefficient(shgc.to_f)
  end
end