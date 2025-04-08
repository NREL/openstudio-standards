module OpenstudioStandards
  # The Refrigeration module provides methods to create, modify, and get information about refrigeration
  module Refrigeration
    # @!group Create Walkin
    # Methods to add refrigerated walkins

    # Adds a refrigerated walkin to the model.
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param template [String] Technology or standards level, either 'old', 'new', or 'advanced'
    # @param walkin_type [String] The walkin type. See refrigeration_walkins data for valid options under walkin_type.
    # @param thermal_zone [OpenStudio::Model::ThermalZone] OpenStudio ThermalZone object
    # @return [OpenStudio::Model::RefrigerationWalkIn] the refrigeration walkin
    def self.create_walkin(model,
                           template: 'new',
                           walkin_type: 'Walk-in Cooler - 120SF with no glass door',
                           thermal_zone: nil)
      # load refrigeration walkin data
      walkins_csv = "#{__dir__}/data/refrigerated_walkins.csv"
      unless File.exist?(walkins_csv)
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Refrigeration', "Unable to find file: #{walkins_csv}")
        return false
      end
      walkins_tbl = CSV.table(walkins_csv, encoding: 'ISO8859-1:utf-8')
      walkins_hsh = walkins_tbl.map(&:to_hash)

      # get walkin properties
      walkins_properties = walkins_hsh.select { |r| (r[:template] == template) && (r[:walkin_name] == walkin_type) }
      if walkins_properties.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Refrigeration', "Unable to find walkin properties for walkin #{template} #{walkin_type}.")
        return false
      end
      walkins_properties = walkins_properties[0]

      # add walkin
      ref_walkin = OpenStudio::Model::RefrigerationWalkIn.new(model, model.alwaysOnDiscreteSchedule)
      ref_walkin.setName(walkin_type)
      ref_walkin.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      ref_walkin.setRatedCoilCoolingCapacity(walkins_properties[:rated_capacity])
      ref_walkin.setOperatingTemperature(walkins_properties[:operating_temperature])
      ref_walkin.setRatedCoolingSourceTemperature(walkins_properties[:rated_cooling_source_temperature])
      ref_walkin.setRatedTotalHeatingPower(walkins_properties[:rated_total_heating_power])
      ref_walkin.setRatedCirculationFanPower(0.0)
      ref_walkin.setRatedCoolingCoilFanPower(walkins_properties[:rated_cooling_fan_power])
      ref_walkin.setRatedTotalLightingPower(walkins_properties[:lighting_power])
      ref_walkin.setLightingSchedule(model.alwaysOnDiscreteSchedule)
      ref_walkin.setDefrostType(walkins_properties[:defrost_type])
      ref_walkin.setDefrostControlType(walkins_properties[:defrost_control_type])
      ref_walkin.setDefrostPower(walkins_properties[:defrost_power])
      ref_walkin.setTemperatureTerminationDefrostFractiontoIce(walkins_properties[:temperature_termination_defrost_fraction_to_ice])
      ref_walkin.setInsulatedFloorSurfaceArea(walkins_properties[:insulated_floor_area])
      ref_walkin.setInsulatedFloorUValue(walkins_properties[:insulated_floor_uvalue])
      ref_walkin.setZoneBoundaryTotalInsulatedSurfaceAreaFacingZone(walkins_properties[:total_insulatedsurface_area_facing_zone])
      ref_walkin.setZoneBoundaryInsulatedSurfaceUValueFacingZone(walkins_properties[:insulated_surface_uvalue_facing_zone])
      ref_walkin.setZoneBoundaryAreaofGlassReachInDoorsFacingZone(walkins_properties[:area_of_glass_reachin_doors_facing_zone])
      ref_walkin.setZoneBoundaryGlassReachInDoorUValueFacingZone(walkins_properties[:reachin_door_uvalue]) unless walkins_properties[:reachin_door_uvalue].nil?
      ref_walkin.setZoneBoundaryAreaofStockingDoorsFacingZone(walkins_properties[:area_of_stocking_doors_facing_zone])
      ref_walkin.setZoneBoundaryHeightofStockingDoorsFacingZone(walkins_properties[:height_of_stocking_doors_facing_zone])
      # replace with glass height property when added
      ref_walkin.setZoneBoundaryHeightofGlassReachInDoorsFacingZone(walkins_properties[:height_of_stocking_doors_facing_zone])
      ref_walkin.setZoneBoundaryStockingDoorUValueFacingZone(walkins_properties[:stocking_door_u])
      ref_walkin.zoneBoundaries.each { |zb| zb.setStockingDoorOpeningProtectionTypeFacingZone(walkins_properties[:stocking_door_opening_protection]) }
      ref_walkin.setZoneBoundaryThermalZone(thermal_zone) unless thermal_zone.nil?

      # place holders for schedules until data provided from ORNL
      i = 0
      # Defrost schedule
      defrost_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      defrost_sch.setName("#{ref_walkin.name} Defrost")
      defrost_sch.defaultDaySchedule.setName("#{ref_walkin.name} Defrost Default")
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i, 0, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i, 59, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i + 10, 0, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i + 10, 59, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)

      # Dripdown schedule
      dripdown_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      dripdown_sch.setName("#{ref_walkin.name} Defrost")
      dripdown_sch.defaultDaySchedule.setName("#{ref_walkin.name} Defrost Default")
      dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i, 0, 0), 0)
      dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i, 59, 0), 1)
      dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i + 10, 0, 0), 0)
      dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i + 10, 59, 0), 1)
      dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
      ref_walkin.setDefrostSchedule(defrost_sch)
      ref_walkin.setDefrostDripDownSchedule(dripdown_sch)

      # stocking schedule
      # ref_walkin.setRestockingSchedule(model.alwaysOffDiscreteSchedule)
      ref_walkin.setZoneBoundaryStockingDoorOpeningScheduleFacingZone(model.alwaysOffDiscreteSchedule)

      insulated_floor_area_ft2 = OpenStudio.convert(walkins_properties[:insulated_floor_area], 'm^2', 'ft^2').get
      rated_cooling_capacity_btu_per_hr = OpenStudio.convert(walkins_properties[:rated_capacity], 'W', 'Btu/hr').get
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Refrigeration', "Added #{insulated_floor_area_ft2.round} ft2 walkin called #{walkin_type} with a capacity of #{rated_cooling_capacity_btu_per_hr.round} Btu/hr to #{thermal_zone&.name}.")

      return ref_walkin
    end
  end
end
