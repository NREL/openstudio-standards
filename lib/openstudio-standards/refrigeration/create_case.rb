module OpenstudioStandards
  # The Refrigeration module provides methods to create, modify, and get information about refrigeration
  module Refrigeration
    # @!group Create Case
    # Methods to add refrigerated cases

    # Adds a refrigerated case to the model.
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param template [String] Technology or standards level, either 'old', 'new', or 'advanced'
    # @param case_type [String] The case type. See refrigeration_cases data for valid options under case_name.
    # @param case_length [String] The case length in meters.
    # @param thermal_zone [OpenStudio::Model::ThermalZone] Thermal zone with the case. If nil, will look up from the model.
    # @return [OpenStudio::Model::RefrigerationCase] the refrigeration case
    def self.create_case(model,
                         template: 'new',
                         case_type: 'Vertical Open - All',
                         case_length: nil,
                         thermal_zone: nil)
      # get thermal zone if not provided
      if thermal_zone.nil?
        # Find the thermal zones most suited for holding the display cases
        thermal_zone = OpenstudioStandards::Refrigeration.refrigeration_case_zone(model)
        if thermal_zone.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Refrigeration', 'Attempted to add display cases to the model, but could find no thermal zone to put them into.')
          return nil
        end
      end

      # load refrigeration cases data
      cases_csv = "#{__dir__}/data/refrigerated_cases.csv"
      unless File.exist?(cases_csv)
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Refrigeration', "Unable to find file: #{cases_csv}")
        return nil
      end
      cases_tbl = CSV.table(cases_csv, encoding: 'ISO8859-1:utf-8')
      cases_hsh = cases_tbl.map(&:to_hash)

      # get case properties
      case_properties = cases_hsh.select { |r| (r[:template] == template) && (r[:case_name] == case_type) }[0]

      if case_properties.nil?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Refrigeration', "Unable to find case data for template #{template} case type #{case_type}.")
        return nil
      end

      # add case
      ref_case = OpenStudio::Model::RefrigerationCase.new(model, model.alwaysOnDiscreteSchedule)
      ref_case.setName(case_type)
      case_length_m = case_length.nil? ? case_properties[:unit_length] : case_length
      ref_case.setCaseLength(case_length_m)
      ref_case.setRatedTotalCoolingCapacityperUnitLength(case_properties[:rated_capacity])
      ref_case.setCaseOperatingTemperature(case_properties[:case_operating_temperature])
      ref_case.setDesignEvaporatorTemperatureorBrineInletTemperature(case_properties[:evaporator_temperature])
      ref_case.setRatedLatentHeatRatio(case_properties[:rated_latent_heat_ratio])
      ref_case.setRatedRuntimeFraction(case_properties[:rated_runtime_fraction])
      ref_case.setLatentCaseCreditCurveType(case_properties[:latent_case_credit_curve_type])
      # TODO: replace once curves are standardized
      std = Standard.build('90.1-2013')
      latent_case_credit_curve = std.model_add_curve(model, case_properties[:latent_case_credit_curve_name])
      ref_case.setLatentCaseCreditCurve(latent_case_credit_curve)
      ref_case.setStandardCaseFanPowerperUnitLength(case_properties[:fan_power])
      ref_case.setOperatingCaseFanPowerperUnitLength(case_properties[:fan_power])
      ref_case.setStandardCaseLightingPowerperUnitLength(case_properties[:lighting_power])
      ref_case.setInstalledCaseLightingPowerperUnitLength(case_properties[:lighting_power])
      ref_case.setCaseLightingSchedule(model.alwaysOnDiscreteSchedule)
      ref_case.setFractionofLightingEnergytoCase(case_properties[:fraction_of_lighting_energy_to_case]) unless case_properties[:fraction_of_lighting_energy_to_case].nil?
      ref_case.setCaseAntiSweatHeaterPowerperUnitLength(case_properties[:anti_sweat_power]) unless case_properties[:anti_sweat_power].nil?
      ref_case.setMinimumAntiSweatHeaterPowerperUnitLength(0.0)
      ref_case.setHumidityatZeroAntiSweatHeaterEnergy(0.0)
      ref_case.setAntiSweatHeaterControlType(case_properties[:anti_sweat_heater_control_type])
      ref_case.setFractionofAntiSweatHeaterEnergytoCase(case_properties[:fraction_of_anti_sweat_heater_energy_to_cases]) unless case_properties[:fraction_of_anti_sweat_heater_energy_to_cases].nil?
      ref_case.setCaseDefrostPowerperUnitLength(case_properties[:defrost_power]) unless case_properties[:defrost_power].nil?
      ref_case.setCaseDefrostType(case_properties[:defrost_type])
      ref_case.setDefrostEnergyCorrectionCurveType(case_properties[:defrost_energy_correction_curve_type]) unless case_properties[:defrost_energy_correction_curve_type].nil?
      unless case_properties[:defrost_energy_correction_curve_name].nil?
        # TODO: replace once curves are standardized
        defrost_correction_curve_name = std.model_add_curve(model, case_properties[:defrost_energy_correction_curve_name])
        ref_case.setDefrostEnergyCorrectionCurve(defrost_correction_curve_name)
      end
      ref_case.setUnderCaseHVACReturnAirFraction(0.0)
      ref_case.resetRefrigeratedCaseRestockingSchedule
      ref_case.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      ref_case.setThermalZone(thermal_zone)
      ref_case.setRatedAmbientTemperature(OpenStudio.convert(75.0, 'F', 'C').get)

      # place holders for schedules until data provided from ORNL
      i = 0
      # Defrost schedule
      defrost_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      defrost_sch.setName("#{ref_case.name} Defrost")
      defrost_sch.defaultDaySchedule.setName("#{ref_case.name} Defrost Default")
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i, 0, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i, 59, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)

      # Dripdown schedule
      dripdown_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      dripdown_sch.setName("#{ref_case.name} Defrost")
      dripdown_sch.defaultDaySchedule.setName("#{ref_case.name} Defrost Default")
      dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i, 0, 0), 0)
      dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, i, 59, 0), 1)
      dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)

      # Case Credit Schedule
      case_credit_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      case_credit_sch.setName("#{ref_case.name} Case Credit")
      case_credit_sch.defaultDaySchedule.setName("#{ref_case.name} Case Credit Default")
      case_credit_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 7, 0, 0), 0.2)
      case_credit_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 21, 0, 0), 0.4)
      case_credit_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.2)
      ref_case.setCaseDefrostSchedule(defrost_sch)
      ref_case.setCaseDefrostDripDownSchedule(dripdown_sch)
      ref_case.setCaseCreditFractionSchedule(case_credit_sch)

      # reporting
      length_ft = OpenStudio.convert(ref_case.caseLength, 'm', 'ft').get
      cooling_capacity_w = ref_case.caseLength * ref_case.ratedTotalCoolingCapacityperUnitLength
      cooling_capacity_btu_per_hr = OpenStudio.convert(cooling_capacity_w, 'W', 'Btu/hr').get
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Refrigeration', "Added #{length_ft.round} ft display case called #{case_type} with a cooling capacity of #{cooling_capacity_btu_per_hr.round} Btu/hr to #{thermal_zone&.name}.")

      return ref_case
    end
  end
end
