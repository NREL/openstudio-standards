module OpenstudioStandards
  # The ThermalZone module provides methods to set thermostats and get information about model thermal zones
  module ThermalZone

    # Adds a thermostat that heats the space to 0 F and cools to 120 F.
    # These numbers are outside of the threshold that is considered heated
    # or cooled by thermal_zone_cooled?() and thermal_zone_heated?()
    #
    # @param thermal_zone [OpenStudio::Model::ThermalZone] OpenStudio ThermalZone object
    # @return [Boolean] returns true if successful, false if not
    def self.thermal_zone_set_unconditioned_thermostat(thermal_zone)
      # Heated to 0F (below thermal_zone_heated?(thermal_zone)  threshold)
      htg_t_f = 0
      htg_t_c = OpenStudio.convert(htg_t_f, 'F', 'C').get
      htg_stpt_sch = OpenStudio::Model::ScheduleRuleset.new(thermal_zone.model)
      htg_stpt_sch.setName('Unconditioned Minimal Heating')
      htg_stpt_sch.defaultDaySchedule.setName('Unconditioned Minimal Heating Default')
      htg_stpt_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), htg_t_c)

      # Cooled to 120F (above thermal_zone_cooled?(thermal_zone)  threshold)
      clg_t_f = 120
      clg_t_c = OpenStudio.convert(clg_t_f, 'F', 'C').get
      clg_stpt_sch = OpenStudio::Model::ScheduleRuleset.new(thermal_zone.model)
      clg_stpt_sch.setName('Unconditioned Minimal Cooling')
      clg_stpt_sch.defaultDaySchedule.setName('Unconditioned Minimal Cooling Default')
      clg_stpt_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), clg_t_c)

      # Thermostat
      thermostat = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(thermal_zone.model)
      thermostat.setName("#{thermal_zone.name} Unconditioned Thermostat")
      thermostat.setHeatingSetpointTemperatureSchedule(htg_stpt_sch)
      thermostat.setCoolingSetpointTemperatureSchedule(clg_stpt_sch)
      thermal_zone.setThermostatSetpointDualSetpoint(thermostat)

      return true
    end
  end
end
