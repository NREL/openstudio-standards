
# Custom changes for the LargeOffice prototype.
# These are changes that are inconsistent with other prototype
# building types.
module LargeOffice
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    system_to_space_map = define_hvac_system_map(building_type, climate_zone)

    system_to_space_map.each do |system|
      # find all zones associated with these spaces
      thermal_zones = []
      system['space_names'].each do |space_name|
        space = model.getSpaceByName(space_name)
        if space.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{space_name} was found in the model")
          return false
        end
        space = space.get
        zone = space.thermalZone
        if zone.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{space_name}")
          return false
        end
        thermal_zones << zone.get
      end

      return_plenum = nil
      unless system['return_plenum'].nil?
        return_plenum_space = model.getSpaceByName(system['return_plenum'])
        if return_plenum_space.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{system['return_plenum']} was found in the model")
          return false
        end
        return_plenum_space = return_plenum_space.get
        return_plenum = return_plenum_space.thermalZone
        if return_plenum.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{system['return_plenum']}")
          return false
        end
        return_plenum = return_plenum.get
      end
    end

    # TODO: replace CoolingTowerTwoSpeed with a FluidCoolerTwoSpeed once the simulation failures are resolved

    # set infiltration schedule for plenums
    # @todo remove once infil_sch in Standards.Space pulls from default building infiltration schedule
    model.getSpaces.each do |space|
      next unless space.name.get.to_s.include? 'Plenum'
      # add infiltration if DOE Ref vintage
      if template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
        # Create an infiltration rate object for this space
        infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(space.model)
        infiltration.setName("#{space.name} Infiltration")
        all_ext_infil_m3_per_s_per_m2 = OpenStudio.convert(0.2232, 'ft^3/min*ft^2', 'm^3/s*m^2').get
        infiltration.setFlowperExteriorSurfaceArea(all_ext_infil_m3_per_s_per_m2)
        infiltration.setSchedule(model_add_schedule(model, 'Large Office Infil Quarter On'))
        infiltration.setConstantTermCoefficient(1.0)
        infiltration.setTemperatureTermCoefficient(0.0)
        infiltration.setVelocityTermCoefficient(0.0)
        infiltration.setVelocitySquaredTermCoefficient(0.0)
        infiltration.setSpace(space)
      else
        space.spaceInfiltrationDesignFlowRates.each do |infiltration_object|
          infiltration_object.setSchedule(model_add_schedule(model, 'OfficeLarge INFIL_SCH_PNNL'))
        end
      end
    end

    return true
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)

    return true
  end

  def model_custom_geometry_tweaks(building_type, climate_zone, prototype_input, model)

    return true
  end
end
