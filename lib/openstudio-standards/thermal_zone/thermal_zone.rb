# Methods to obtain information about model spaces
module OpenstudioStandards
  module ThermalZone
    # Determine if the thermal zone is a plenum based on whether a majority of the spaces in the zone are plenums or not.
    #
    # @param thermal_zone [OpenStudio::Model::ThermalZone] OpenStudio ThermalZone object
    # @return [Boolean] returns true if majority plenum, false if not
    def self.thermal_zone_plenum?(thermal_zone)
      plenum_status = false

      area_plenum = 0
      area_non_plenum = 0
      thermal_zone.spaces.each do |space|
        if OpenstudioStandards::Space.space_plenum?(space)
          area_plenum += space.floorArea
        else
          area_non_plenum += space.floorArea
        end
      end

      # Majority
      if area_plenum > area_non_plenum
        plenum_status = true
      end

      return plenum_status
    end

    # Determine if the thermal zone is residential based on the space type properties for the spaces in the zone.
    # If there are both residential and nonresidential spaces in the zone,
    # the result will be whichever type has more floor area.
    # In the event that they are equal, it will be assumed nonresidential.
    #
    # @param thermal_zone [OpenStudio::Model::ThermalZone] OpenStudio ThermalZone object
    # return [Boolean] true if residential, false if nonresidential
    def self.thermal_zone_residential?(thermal_zone)
      # Determine the respective areas
      res_area_m2 = 0
      nonres_area_m2 = 0
      thermal_zone.spaces.each do |space|
        # Ignore space if not part of total area
        next unless space.partofTotalFloorArea

        if OpenstudioStandards::Space.space_residential?(space)
          res_area_m2 += space.floorArea
        else
          nonres_area_m2 += space.floorArea
        end
      end

      # Determine which is larger
      is_res = false
      if res_area_m2 > nonres_area_m2
        is_res = true
      end

      return is_res
    end

    # Determines heating status.
    # If the zone has a thermostat with a maximum heating setpoint above 5C (41F), counts as heated.
    # Plenums are also assumed to be heated.
    #
    # @author Andrew Parker, Julien Marrec
    # @param thermal_zone [OpenStudio::Model::ThermalZone] OpenStudio ThermalZone object
    # @return [Boolean] returns true if heated, false if not
    def self.thermal_zone_heated?(thermal_zone)
      temp_f = 41.0
      temp_c = OpenStudio.convert(temp_f, 'F', 'C').get
      htd = false

      # Consider plenum zones heated
      area_plenum = 0
      area_non_plenum = 0
      thermal_zone.spaces.each do |space|
        if OpenstudioStandards::Space.space_plenum?(space)
          area_plenum += space.floorArea
        else
          area_non_plenum += space.floorArea
        end
      end

      # Majority
      if area_plenum > area_non_plenum
        htd = true
        return htd
      end

      # Check if the zone has radiant heating,
      # and if it does, get heating setpoint schedule
      # directly from the radiant system to check.
      thermal_zone.equipment.each do |equip|
        htg_sch = nil
        if equip.to_ZoneHVACHighTemperatureRadiant.is_initialized
          equip = equip.to_ZoneHVACHighTemperatureRadiant.get
          if equip.heatingSetpointTemperatureSchedule.is_initialized
            htg_sch = equip.heatingSetpointTemperatureSchedule.get
          end
        elsif equip.to_ZoneHVACLowTemperatureRadiantElectric.is_initialized
          equip = equip.to_ZoneHVACLowTemperatureRadiantElectric.get
          htg_sch = equip.heatingSetpointTemperatureSchedule
        elsif equip.to_ZoneHVACLowTempRadiantConstFlow.is_initialized
          equip = equip.to_ZoneHVACLowTempRadiantConstFlow.get
          htg_coil = equip.heatingCoil
          if htg_coil.to_CoilHeatingLowTempRadiantConstFlow.is_initialized
            htg_coil = htg_coil.to_CoilHeatingLowTempRadiantConstFlow.get
            if htg_coil.heatingHighControlTemperatureSchedule.is_initialized
              htg_sch = htg_coil.heatingHighControlTemperatureSchedule.get
            end
          end
        elsif equip.to_ZoneHVACLowTempRadiantVarFlow.is_initialized
          equip = equip.to_ZoneHVACLowTempRadiantVarFlow.get
          htg_coil = equip.heatingCoil
          if equip.model.version > OpenStudio::VersionString.new('3.1.0')
            if htg_coil.is_initialized
              htg_coil = htg_coil.get
            else
              htg_coil = nil
            end
          end
          if !htg_coil.nil? && htg_coil.to_CoilHeatingLowTempRadiantVarFlow.is_initialized
            htg_coil = htg_coil.to_CoilHeatingLowTempRadiantVarFlow.get
            if htg_coil.heatingControlTemperatureSchedule.is_initialized
              htg_sch = htg_coil.heatingControlTemperatureSchedule.get
            end
          end
        end
        # Move on if no heating schedule was found
        next if htg_sch.nil?

        # Get the setpoint from the schedule
        if htg_sch.to_ScheduleRuleset.is_initialized
          htg_sch = htg_sch.to_ScheduleRuleset.get
          max_c = OpenstudioStandards::Schedules.schedule_ruleset_get_min_max(htg_sch)['max']
          if max_c > temp_c
            htd = true
          end
        elsif htg_sch.to_ScheduleConstant.is_initialized
          htg_sch = htg_sch.to_ScheduleConstant.get
          max_c = OpenstudioStandards::Schedules.schedule_constant_get_min_max(htg_sch)['max']
          if max_c > temp_c
            htd = true
          end
        elsif htg_sch.to_ScheduleCompact.is_initialized
          htg_sch = htg_sch.to_ScheduleCompact.get
          max_c = OpenstudioStandards::Schedules.schedule_compact_get_min_max(htg_sch)['max']
          if max_c > temp_c
            htd = true
          end
        else
          OpenStudio.logFree(OpenStudio::Debug, 'OpenstudioStandards::ThermalZone', "Zone #{thermal_zone.name} used an unknown schedule type for the heating setpoint; assuming heated.")
          htd = true
        end
      end

      # Unheated if no thermostat present
      if thermal_zone.thermostat.empty?
        return htd
      end

      # Check the heating setpoint
      tstat = thermal_zone.thermostat.get
      if tstat.to_ThermostatSetpointDualSetpoint
        tstat = tstat.to_ThermostatSetpointDualSetpoint.get
        htg_sch = tstat.getHeatingSchedule
        if htg_sch.is_initialized
          htg_sch = htg_sch.get
          if htg_sch.to_ScheduleRuleset.is_initialized
            htg_sch = htg_sch.to_ScheduleRuleset.get
            max_c = OpenstudioStandards::Schedules.schedule_ruleset_get_min_max(htg_sch)['max']
            if max_c > temp_c
              htd = true
            end
          elsif htg_sch.to_ScheduleConstant.is_initialized
            htg_sch = htg_sch.to_ScheduleConstant.get
            max_c = OpenstudioStandards::Schedules.schedule_constant_get_min_max(htg_sch)['max']
            if max_c > temp_c
              htd = true
            end
          elsif htg_sch.to_ScheduleCompact.is_initialized
            htg_sch = htg_sch.to_ScheduleCompact.get
            max_c = OpenstudioStandards::Schedules.schedule_compact_get_min_max(htg_sch)['max']
            if max_c > temp_c
              htd = true
            end
          else
            OpenStudio.logFree(OpenStudio::Debug, 'OpenstudioStandards::ThermalZone', "Zone #{thermal_zone.name} used an unknown schedule type for the heating setpoint; assuming heated.")
            htd = true
          end
        end
      elsif tstat.to_ZoneControlThermostatStagedDualSetpoint
        tstat = tstat.to_ZoneControlThermostatStagedDualSetpoint.get
        htg_sch = tstat.heatingTemperatureSetpointSchedule
        if htg_sch.is_initialized
          htg_sch = htg_sch.get
          if htg_sch.to_ScheduleRuleset.is_initialized
            htg_sch = htg_sch.to_ScheduleRuleset.get
            max_c = OpenstudioStandards::Schedules.schedule_ruleset_get_min_max(htg_sch)['max']
            if max_c > temp_c
              htd = true
            end
          end
        end
      end

      return htd
    end

    # Determines cooling status.
    # If the zone has a thermostat with a minimum cooling setpoint below 33C (91F), counts as cooled.
    # Plenums are also assumed to be cooled.
    #
    # @author Andrew Parker, Julien Marrec
    # @param thermal_zone [OpenStudio::Model::ThermalZone] OpenStudio ThermalZone object
    # @return [Boolean] returns true if cooled, false if not
    def self.thermal_zone_cooled?(thermal_zone)
      temp_f = 91.0
      temp_c = OpenStudio.convert(temp_f, 'F', 'C').get
      cld = false

      # Consider plenum zones cooled
      area_plenum = 0
      area_non_plenum = 0
      thermal_zone.spaces.each do |space|
        if OpenstudioStandards::Space.space_plenum?(space)
          area_plenum += space.floorArea
        else
          area_non_plenum += space.floorArea
        end
      end

      # Majority
      if area_plenum > area_non_plenum
        cld = true
        return cld
      end

      # Check if the zone has radiant cooling,
      # and if it does, get cooling setpoint schedule
      # directly from the radiant system to check.
      thermal_zone.equipment.each do |equip|
        clg_sch = nil
        if equip.to_ZoneHVACLowTempRadiantConstFlow.is_initialized
          equip = equip.to_ZoneHVACLowTempRadiantConstFlow.get
          clg_coil = equip.coolingCoil
          if clg_coil.to_CoilCoolingLowTempRadiantConstFlow.is_initialized
            clg_coil = clg_coil.to_CoilCoolingLowTempRadiantConstFlow.get
            if clg_coil.coolingLowControlTemperatureSchedule.is_initialized
              clg_sch = clg_coil.coolingLowControlTemperatureSchedule.get
            end
          end
        elsif equip.to_ZoneHVACLowTempRadiantVarFlow.is_initialized
          equip = equip.to_ZoneHVACLowTempRadiantVarFlow.get
          clg_coil = equip.coolingCoil
          if equip.model.version > OpenStudio::VersionString.new('3.1.0')
            if clg_coil.is_initialized
              clg_coil = clg_coil.get
            else
              clg_coil = nil
            end
          end
          if !clg_coil.nil? && clg_coil.to_CoilCoolingLowTempRadiantVarFlow.is_initialized
            clg_coil = clg_coil.to_CoilCoolingLowTempRadiantVarFlow.get
            if clg_coil.coolingControlTemperatureSchedule.is_initialized
              clg_sch = clg_coil.coolingControlTemperatureSchedule.get
            end
          end
        end
        # Move on if no cooling schedule was found
        next if clg_sch.nil?

        # Get the setpoint from the schedule
        if clg_sch.to_ScheduleRuleset.is_initialized
          clg_sch = clg_sch.to_ScheduleRuleset.get
          min_c = OpenstudioStandards::Schedules.schedule_ruleset_get_min_max(clg_sch)['min']
          if min_c < temp_c
            cld = true
          end
        elsif clg_sch.to_ScheduleConstant.is_initialized
          clg_sch = clg_sch.to_ScheduleConstant.get
          min_c = OpenstudioStandards::Schedules.schedule_constant_get_min_max(clg_sch)['min']
          if min_c < temp_c
            cld = true
          end
        elsif clg_sch.to_ScheduleCompact.is_initialized
          clg_sch = clg_sch.to_ScheduleCompact.get
          min_c = OpenstudioStandards::Schedules.schedule_compact_get_min_max(clg_sch)['min']
          if min_c < temp_c
            cld = true
          end
        else
          OpenStudio.logFree(OpenStudio::Debug, 'OpenstudioStandards::ThermalZone', "Zone #{thermal_zone.name} used an unknown schedule type for the cooling setpoint; assuming cooled.")
          cld = true
        end
      end

      # Unheated if no thermostat present
      if thermal_zone.thermostat.empty?
        return cld
      end

      # Check the cooling setpoint
      tstat = thermal_zone.thermostat.get
      if tstat.to_ThermostatSetpointDualSetpoint
        tstat = tstat.to_ThermostatSetpointDualSetpoint.get
        clg_sch = tstat.getCoolingSchedule
        if clg_sch.is_initialized
          clg_sch = clg_sch.get
          if clg_sch.to_ScheduleRuleset.is_initialized
            clg_sch = clg_sch.to_ScheduleRuleset.get
            min_c = OpenstudioStandards::Schedules.schedule_ruleset_get_min_max(clg_sch)['min']
            if min_c < temp_c
              cld = true
            end
          elsif clg_sch.to_ScheduleConstant.is_initialized
            clg_sch = clg_sch.to_ScheduleConstant.get
            min_c = OpenstudioStandards::Schedules.schedule_constant_get_min_max(clg_sch)['min']
            if min_c < temp_c
              cld = true
            end
          elsif clg_sch.to_ScheduleCompact.is_initialized
            clg_sch = clg_sch.to_ScheduleCompact.get
            min_c = OpenstudioStandards::Schedules.schedule_compact_get_min_max(clg_sch)['min']
            if min_c < temp_c
              cld = true
            end
          else
            OpenStudio.logFree(OpenStudio::Debug, 'OpenstudioStandards::ThermalZone', "Zone #{thermal_zone.name} used an unknown schedule type for the cooling setpoint; assuming cooled.")
            cld = true
          end
        end
      elsif tstat.to_ZoneControlThermostatStagedDualSetpoint
        tstat = tstat.to_ZoneControlThermostatStagedDualSetpoint.get
        clg_sch = tstat.coolingTemperatureSetpointSchedule
        if clg_sch.is_initialized
          clg_sch = clg_sch.get
          if clg_sch.to_ScheduleRuleset.is_initialized
            clg_sch = clg_sch.to_ScheduleRuleset.get
            min_c = OpenstudioStandards::Schedules.schedule_ruleset_get_min_max(clg_sch)['min']
            if min_c < temp_c
              cld = true
            end
          end
        end
      elsif tstat.to_ThermostatSetpointSingleHeating
        cld = false
      end

      return cld
    end

    # Determine the design internal load (W) for this zone without space multipliers.
    # This include People, Lights, Electric Equipment, and Gas Equipment in all spaces in this zone.
    # It assumes 100% of the wattage is converted to heat, and that the design peak schedule value is 1 (100%).
    #
    # @param thermal_zone [OpenStudio::Model::ThermalZone] OpenStudio ThermalZone object
    # @return [Double] the design internal load, in watts
    def self.thermal_zone_get_design_internal_load(thermal_zone)
      load_w = 0.0

      thermal_zone.spaces.each do |space|
        load_w += OpenstudioStandards::Space.space_get_design_internal_load(space)
      end

      return load_w
    end
  end
end