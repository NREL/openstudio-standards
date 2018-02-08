
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
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        door_infiltration_map = { ['LGstore1', 'LGstore2'] => 0.388884328,
                                  ['SMstore1', 'SMstore2', 'SMstore3', 'SMstore4', 'SMstore5', 'SMstore6', 'SMstore7', 'SMstore8'] => 0.222287037 }

        door_infiltration_map.each_pair do |space_names, infiltration_design_flowrate|
          space_names.each do |space_name|
            space = model.getSpaceByName(space_name).get
            # Create the infiltration object and hook it up to the space type
            infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
            infiltration.setName("#{space_name} Door Open Infiltration")
            infiltration.setSpace(space)
            infiltration.setDesignFlowRate(infiltration_design_flowrate)
            infiltration_schedule = model_add_schedule(model, 'RetailStripmall INFIL_Door_Opening_SCH')
            if infiltration_schedule.nil?
              OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Can't find schedule (RetailStripmall INFIL_Door_Opening_SCH).")
              return false
            else
              infiltration.setSchedule(infiltration_schedule)
            end
          end
        end
    end

    # Add economizer max fraction schedules
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NREL ZNE Ready 2017'
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

  def update_waterheater_loss_coefficient(model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.205980747)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.205980747)
        end
    end
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    update_waterheater_loss_coefficient(model)

    return true
  end
end
