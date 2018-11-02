
# Custom changes for the SmallHotel prototype.
# These are changes that are inconsistent with other prototype
# building types.
module SmallHotel
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # add elevator for the elevator coreflr1  (the elevator lift already added via standard spreadsheet)
    add_extra_equip_elevator_coreflr1(model)

    # add extra infiltration for corridor1 door
    corridor_space = model.getSpaceByName('CorridorFlr1')
    corridor_space = corridor_space.get
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      infiltration_corridor = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_corridor.setName('Corridor1 door Infiltration')
      infiltration_per_zone = 0
      infiltration_per_zone = if template == '90.1-2010' || template == '90.1-2007'
                                0.591821538
                              else
                                0.91557718
                              end
      infiltration_corridor.setDesignFlowRate(infiltration_per_zone)
      infiltration_corridor.setSchedule(model_add_schedule(model, 'HotelSmall INFIL_Door_Opening_SCH'))
      infiltration_corridor.setSpace(corridor_space)
    end

    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      # hardsize corridor1. put in standards in the future  #TODO
      model.getZoneHVACPackagedTerminalAirConditioners.sort.each do |ptac|
        zone = ptac.thermalZone.get
        if zone.spaces.include?(corridor_space)
          ptac.setSupplyAirFlowRateDuringCoolingOperation(0.13)
          ptac.setSupplyAirFlowRateDuringHeatingOperation(0.13)
          ptac.setSupplyAirFlowRateWhenNoCoolingorHeatingisNeeded(0.13)
          ccoil = ptac.coolingCoil
          if ccoil.to_CoilCoolingDXSingleSpeed.is_initialized
            ccoil.to_CoilCoolingDXSingleSpeed.get.setRatedTotalCoolingCapacity(2638) # Unit: W
            ccoil.to_CoilCoolingDXSingleSpeed.get.setRatedAirFlowRate(0.13)
          end
        end
      end

      # add HotelSmall SAC_Econ_MaxOAFrac_Sch
      oa_controller = model.getControllerOutdoorAirByName('ExerciseCenterFlr1 ZN - EmployeeLoungeFlr1 ZN - RestroomFlr1 ZN SAC OA System Controller').get
      oa_controller.setMaximumFractionofOutdoorAirSchedule(model_add_schedule(model, 'HotelSmall SAC_Econ_MaxOAFrac_Sch'))
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  # add this for elevator lights/fans (elevator lift is implemented through standard lookup)
  def add_extra_equip_elevator_coreflr1(model)
    elevator_coreflr1 = model.getSpaceByName('ElevatorCoreFlr1').get
    elec_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def.setName('Elevator CoreFlr1 Electric Equipment Definition')
    elec_equip_def.setFractionLatent(0)
    elec_equip_def.setFractionRadiant(0.5)
    elec_equip_def.setFractionLost(0.0)
    elec_equip_def.setDesignLevel(125)
    elec_equip = OpenStudio::Model::ElectricEquipment.new(elec_equip_def)
    elec_equip.setName('Elevator Coreflr1 Elevator Lights/Fans Equipment')
    elec_equip.setSpace(elevator_coreflr1)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        elec_equip.setSchedule(model_add_schedule(model, 'HotelSmall ELEV_LIGHT_FAN_SCH_ADD_DF'))
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        elec_equip.setSchedule(model_add_schedule(model, 'HotelSmall ELEV_LIGHT_FAN_SCH_ADD_DF'))
    end
    return true
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    return true
  end
end
