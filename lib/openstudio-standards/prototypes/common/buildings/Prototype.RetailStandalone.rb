# Custom changes for the RetailStandalone prototype.
# These are changes that are inconsistent with other prototype
# building types.
module RetailStandalone
  # @todo The ElectricEquipment schedules are wrong in OpenStudio Standards... It needs to be 'RetailStandalone BLDG_EQUIP_SCH' for 90.1-2010 at least but probably all
  # @todo There is an OpenStudio bug where two heat exchangers are on the equipment list and it references the same single heat exchanger for both. This doubles the heat recovery energy.
  # @todo The HeatExchangerAirToAir is not calculating correctly. It does not equal the legacy IDF and has higher energy usage due to that.
  # @todo Need to determine if WaterHeater can be alone or if we need to 'fake' it.

  # hvac adjustments specific to the prototype model
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param building_type [String the building type
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param prototype_input [Hash] hash of prototype inputs
  # @return [Boolean] returns true if successful, false if not
  def model_custom_hvac_tweaks(model, building_type, climate_zone, prototype_input)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # Add the door infiltration for template 2004,2007,2010,2013,2016,2019
    case template
    when '90.1-2004'
      entry_space = model.getSpaceByName('Front_Entry').get
      infiltration_entry = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_entry.setName('Entry door Infiltration')
      infiltration_per_zone = 1.418672682
      infiltration_entry.setDesignFlowRate(infiltration_per_zone)
      infiltration_entry.setSchedule(model_add_schedule(model, 'RetailStandalone INFIL_Door_Opening_SCH'))
      infiltration_entry.setSpace(entry_space)

      # temporal solution for CZ dependent door infiltration rate.  In fact other standards need similar change as well
    when '90.1-2007', '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019'
      entry_space = model.getSpaceByName('Front_Entry').get
      infiltration_entry = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_entry.setName('Entry door Infiltration')
      case climate_zone
      when 'ASHRAE 169-2006-0A',
          'ASHRAE 169-2006-1A',
          'ASHRAE 169-2006-0B',
          'ASHRAE 169-2006-1B',
          'ASHRAE 169-2006-2A',
          'ASHRAE 169-2006-2B',
          'ASHRAE 169-2013-0A',
          'ASHRAE 169-2013-1A',
          'ASHRAE 169-2013-0B',
          'ASHRAE 169-2013-1B',
          'ASHRAE 169-2013-2A',
          'ASHRAE 169-2013-2B'
        infiltration_per_zone = 1.418672682
        infiltration_entry.setSchedule(model_add_schedule(model, 'RetailStandalone INFIL_Door_Opening_SCH'))
      else
        infiltration_per_zone = 0.937286742
        infiltration_entry.setSchedule(model_add_schedule(model, 'RetailStandalone INFIL_Door_Opening_SCH_2013'))
      end
      infiltration_entry.setDesignFlowRate(infiltration_per_zone)
      infiltration_entry.setSpace(entry_space)
    end

    # add these additional coefficient inputs
    if infiltration_entry
      infiltration_entry.setConstantTermCoefficient(1.0)
      infiltration_entry.setTemperatureTermCoefficient(0.0)
      infiltration_entry.setVelocityTermCoefficient(0.0)
      infiltration_entry.setVelocitySquaredTermCoefficient(0.0)
    end

    case template
    when '90.1-2013', '90.1-2016', '90.1-2019'
      # Add EMS for controlling the system serving the front entry zone
      oa_sens = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Outdoor Air Drybulb Temperature')
      oa_sens.setName('OAT_F')
      oa_sens.setKeyName('Environment')

      model.getFanConstantVolumes.each do |fan|
        if fan.name.to_s.include?('Front') && fan.name.to_s.include?('Entry')
          frt_entry_avail_fan_sch = fan.availabilitySchedule
          frt_entry_fan = OpenStudio::Model::EnergyManagementSystemActuator.new(frt_entry_avail_fan_sch, 'Schedule:Year', 'Schedule Value')
          frt_entry_fan.setName('FrontEntry_Fan')
        end
      end

      model.getCoilHeatingGass.each do |coil|
        if coil.name.to_s.include?('Front') && coil.name.to_s.include?('Entry')
          frt_entry_avail_coil_sch = coil.availabilitySchedule
          frt_entry_coil = OpenStudio::Model::EnergyManagementSystemActuator.new(frt_entry_avail_coil_sch, 'Schedule:Year', 'Schedule Value')
          frt_entry_coil.setName('FrontEntry_Coil')
        end
      end

      frt_entry_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
      frt_entry_prg.setName('FrontEntry_HeaterControl')
      frt_entry_prg_body = <<-EMS
      SET OAT_F = (OAT_F*1.8)+32
      IF OAT_F > 45
        SET FrontEntry_Coil = 0
        SET FrontEntry_Fan = 0
      ELSE
      SET FrontEntry_Coil = 1
      SET FrontEntry_Fan = 1
      ENDIF
      EMS
      frt_entry_prg.setBody(frt_entry_prg_body)

      prg_mgr = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
      prg_mgr.setName('FrontEntry_HeaterManager')
      prg_mgr.setCallingPoint('BeginTimestepBeforePredictor')
      prg_mgr.addProgram(frt_entry_prg)
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  def model_custom_daylighting_tweaks(building_type, climate_zone, prototype_input, model)
    return true
  end

  # swh adjustments specific to the prototype model
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param building_type [String the building type
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param prototype_input [Hash] hash of prototype inputs
  # @return [Boolean] returns true if successful, false if not
  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    return true
  end

  # geometry adjustments specific to the prototype model
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param building_type [String the building type
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param prototype_input [Hash] hash of prototype inputs
  # @return [Boolean] returns true if successful, false if not
  def model_custom_geometry_tweaks(model, building_type, climate_zone, prototype_input)
    # Set original building North axis
    OpenstudioStandards::Geometry.model_set_building_north_axis(model, 0.0)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Adjusting geometry input')
    case template
    when '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019'
      case climate_zone
      when 'ASHRAE 169-2006-6A',
          'ASHRAE 169-2006-6B',
          'ASHRAE 169-2006-7A',
          'ASHRAE 169-2006-8A',
          'ASHRAE 169-2013-6A',
          'ASHRAE 169-2013-6B',
          'ASHRAE 169-2013-7A',
          'ASHRAE 169-2013-8A'
        # Remove existing skylights
        model.getSubSurfaces.each do |subsurf|
          if subsurf.subSurfaceType.to_s == 'Skylight'
            subsurf.remove
          end
        end
        # Load older geometry corresponding to older code versions
        old_geo = load_geometry_osm('geometry/ASHRAE90120042007RetailStandalone.osm')
        # Clone the skylights from the older geometry
        old_geo.getSubSurfaces.each do |subsurf|
          if subsurf.subSurfaceType.to_s == 'Skylight'
            new_skylight = subsurf.clone(model).to_SubSurface.get
            old_roof = subsurf.surface.get
            # Assign surfaces to skylights
            model.getSurfaces.each do |model_surf|
              if model_surf.name.to_s == old_roof.name.to_s
                new_skylight.setSurface(model_surf)
              end
            end
          end
        end
      end
    end
    return true
  end
end
