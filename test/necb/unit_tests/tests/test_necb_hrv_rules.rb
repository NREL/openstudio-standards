require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)


class NECB_HVAC_HRV_Tests < Minitest::Test

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Test to validate the effectiveness of the hrv
  def test_NECB2011_hrv_eff

    # Set up remaining parameters for test.
    output_folder = method_output_folder
    template = 'NECB2011'
    standard = Standard.build(template)
    save_intermediate_models = false

    name = "hrv"
    name.gsub!(/\s+/, "-")
    puts "***************#{name}***************\n"

    # Load model and set climate file.
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
    OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

    # Add HVAC system.
    boiler_fueltype = 'Electricity'
    baseboard_type = 'Hot Water'
    heating_coil_type = 'DX'
    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule
    standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, boiler_fueltype, always_on)
    standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                                zones: model.getThermalZones,
                                                                                                heating_coil_type: heating_coil_type,
                                                                                                baseboard_type: baseboard_type,
                                                                                                hw_loop: hw_loop,
                                                                                                new_auto_zoner: false)
    systems = model.getAirLoopHVACs

    # Increase default outdoor air requirement so that some of the systems in the project would require an HRV.
    for isys in 0..0
      zones = systems[isys].thermalZones
      zones.each do |izone|
        spaces = izone.spaces
        spaces.each do |ispace|
          oa_objs = ispace.designSpecificationOutdoorAir.get
          oa_flow_p_person = oa_objs.outdoorAirFlowperPerson
          oa_objs.setOutdoorAirFlowperPerson(30.0*oa_flow_p_person) #l/s
        end
      end
    end

    # Run sizing.
    run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models)

    systems = model.getAirLoopHVACs
    tol = 1.0e-5
    necb_hrv_eff = 0.5
    systems.each do |isys|
      has_hrv = standard.air_loop_hvac_energy_recovery_ventilator_required?(isys, 'NECB')
      if has_hrv
        hrv_objs = model.getHeatExchangerAirToAirSensibleAndLatents
        diff1 = (hrv_objs[0].latentEffectivenessat100CoolingAirFlow.to_f - necb_hrv_eff) / necb_hrv_eff
        diff2 = (hrv_objs[0].latentEffectivenessat100HeatingAirFlow.to_f - necb_hrv_eff) / necb_hrv_eff
        diff3 = (hrv_objs[0].latentEffectivenessat75CoolingAirFlow.to_f - necb_hrv_eff) / necb_hrv_eff
        diff4 = (hrv_objs[0].latentEffectivenessat75HeatingAirFlow.to_f - necb_hrv_eff) / necb_hrv_eff
        diff5 = (hrv_objs[0].sensibleEffectivenessat100CoolingAirFlow.to_f - necb_hrv_eff) / necb_hrv_eff
        diff6 = (hrv_objs[0].sensibleEffectivenessat100HeatingAirFlow.to_f - necb_hrv_eff) / necb_hrv_eff
        diff7 = (hrv_objs[0].sensibleEffectivenessat75CoolingAirFlow.to_f - necb_hrv_eff) / necb_hrv_eff
        diff8 = (hrv_objs[0].sensibleEffectivenessat75HeatingAirFlow.to_f - necb_hrv_eff) / necb_hrv_eff
        hrv_eff_value_is_correct = false
        if diff1 && diff2 && diff3 && diff4 && diff5 && diff6 && diff7 && diff8 then hrv_eff_value_is_correct = true end
        assert(hrv_eff_value_is_correct,"HRV effectiveness test results do not match expected results!")
      end
    end
  end

end
