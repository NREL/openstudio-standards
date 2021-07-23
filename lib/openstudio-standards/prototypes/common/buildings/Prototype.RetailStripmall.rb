# Custom changes for the RetailStripmall prototype.
# These are changes that are inconsistent with other prototype
# building types.
module RetailStripmall
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    system_to_space_map = define_hvac_system_map(building_type, climate_zone)

    # Add infiltration door opening
    # Spaces names to design infiltration rates (m3/s)
    case template
    when '90.1-2004'
      door_infiltration_map = { ['LGstore1', 'LGstore2'] => 0.388884328,
                                ['SMstore1', 'SMstore2', 'SMstore3', 'SMstore4', 'SMstore5', 'SMstore6', 'SMstore7', 'SMstore8'] => 0.222287037 }
      infiltration_schedule = model_add_schedule(model, 'RetailStripmall INFIL_Door_Opening_SCH')
    when '90.1-2007', '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019'
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
        door_infiltration_map = { ['LGstore1', 'LGstore2'] => 0.388884328,
                                  ['SMstore1', 'SMstore2', 'SMstore3', 'SMstore4', 'SMstore5', 'SMstore6', 'SMstore7', 'SMstore8'] => 0.222287037 }
        infiltration_schedule = model_add_schedule(model, 'RetailStripmall INFIL_Door_Opening_SCH')
      else
        door_infiltration_map = { ['LGstore1', 'LGstore2'] => 0.2411649,
                                  ['SMstore1', 'SMstore2', 'SMstore3', 'SMstore4', 'SMstore5', 'SMstore6', 'SMstore7', 'SMstore8'] => 0.1345049 }
        infiltration_schedule = model_add_schedule(model, 'RetailStripmall INFIL_Door_Opening_SCH_2013')
      end
    else
      door_infiltration_map = {}
    end

    door_infiltration_map.each_pair do |space_names, infiltration_design_flowrate|
      space_names.each do |space_name|
        space = model.getSpaceByName(space_name).get
        # Create the infiltration object and hook it up to the space type
        infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
        infiltration.setName("#{space_name} Door Open Infiltration")
        infiltration.setSpace(space)
        infiltration.setDesignFlowRate(infiltration_design_flowrate)
        infiltration.setConstantTermCoefficient(1.0)
        infiltration.setTemperatureTermCoefficient(0.0)
        infiltration.setVelocityTermCoefficient(0.0)
        infiltration.setVelocitySquaredTermCoefficient(0.0)
        if infiltration_schedule.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Can't find infiltration schedule for #{space_name}.")
          return false
        else
          infiltration.setSchedule(infiltration_schedule)
        end
      end
    end

    # Add economizer max fraction schedules
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019', 'NREL ZNE Ready 2017'
      econ_eff_sch = model_add_schedule(model, 'RetailStandalone PSZ_Econ_MaxOAFrac_Sch')
      model.getAirLoopHVACs.each do |air_loop|
        oa_sys = air_loop.airLoopHVACOutdoorAirSystem
        if oa_sys.is_initialized
          oa_sys = oa_sys.get
          oa_controller = oa_sys.getControllerOutdoorAir
          oa_controller.setMaximumFractionofOutdoorAirSchedule(econ_eff_sch)
        end
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')
    return true
  end

  # add hvac

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    return true
  end

  def model_custom_geometry_tweaks(building_type, climate_zone, prototype_input, model)
    # Set original building North axis
    model_set_building_north_axis(model, 0.0)

    return true
  end
end
