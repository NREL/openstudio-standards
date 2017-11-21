
# Custom changes for the RetailStandalone prototype.
# These are changes that are inconsistent with other prototype
# building types.
module RetailStandalone
  # TODO: The ElectricEquipment schedules are wrong in OpenStudio Standards... It needs to be 'RetailStandalone BLDG_EQUIP_SCH' for 90.1-2010 at least but probably all
  # TODO: There is an OpenStudio bug where two heat exchangers are on the equipment list and it references the same single heat exchanger for both. This doubles the heat recovery energy.
  # TODO: The HeatExchangerAirToAir is not calculating correctly. It does not equal the legacy IDF and has higher energy usage due to that.
  # TODO: Need to determine if WaterHeater can be alone or if we need to 'fake' it.

  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # Add the door infiltration for template 2004,2007,2010,2013
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        entry_space = model.getSpaceByName('Front_Entry').get
        infiltration_entry = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
        infiltration_entry.setName('Entry door Infiltration')
        infiltration_per_zone = 1.418672682
        infiltration_entry.setDesignFlowRate(infiltration_per_zone)
        infiltration_entry.setSchedule(model_add_schedule(model, 'RetailStandalone INFIL_Door_Opening_SCH'))
        infiltration_entry.setSpace(entry_space)
    end

    # Update the zone sizing SAT
    if template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      model.getSizingZones.each do |sizing_zone|
        sizing_zone.setZoneCoolingDesignSupplyAirTemperature(14)
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

  def update_waterheater_loss_coefficient(model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(4.10807252)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(4.10807252)
        end
    end
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    update_waterheater_loss_coefficient(model)

    return true
  end
end
