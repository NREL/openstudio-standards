require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)


class NECB_2015PumpPower_Test < Minitest::Test

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # NECB2015 rules for cooling tower
  # power = 0.013 x capacity in kW
  # Note that most of the code was copied from 2015 part of test_necb_coolingtower_rules.rb because it creates a building
  # with a heating, cooling, and heat rejection loop.  This was necessary to test the NECB2015 pump power rules.  The test
  # creates the building with HVAC, applies another sizing run, and runs the apply_maximum_loop_pump_power(model) method.
  # The test then calculates what the pump power adjustment should be and compares that to what was applied to the model.
  # If the answer is close then the test passes.  I did not take the time to write the code to create a model with headered
  # pumps or with a water source heat pump.  So, those aspects of test_necb_coolingtower_rules.rb will not be exercised.
  # Until further testing is done test_necb_coolingtower_rules.rb should not be used with models containing headered pumps
  # or water source heat pumps.
  def test_NECB2015_pumppower

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template = 'NECB2015'
    standard = get_standard(template)
    save_intermediate_models = false

    tol = 1.0e-3
    # Generate the osm files for all relevant cases to generate the test data for system 6
    boiler_fueltype = 'Electricity'
    baseboard_type = 'Hot Water'
    chiller_types = ['Scroll']
    heating_coil_type = 'Hot Water'
    fan_type = 'AF_or_BI_rdg_fancurve'
    chiller_cap = 1000000.0

    clgtowerFanPowerFr = 0.013
    chiller_types.each do |chiller_type|
      name = "sys6_#{template}_ChillerType_#{chiller_type}-#{chiller_cap}watts"
      name.gsub!(/\s+/, "-")
      puts "***************#{name}***************\n"

      # Load model and set climate file.
      model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
      weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
      OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models
      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
      standard.add_sys6_multi_zone_built_up_system_with_baseboard_heating(
          model: model,
          zones: model.getThermalZones,
          heating_coil_type: heating_coil_type,
          baseboard_type: baseboard_type,
          chiller_type: chiller_type,
          fan_type: fan_type,
          hw_loop: hw_loop)
      model.getChillerElectricEIRs.each { |ichiller| ichiller.setReferenceCapacity(chiller_cap) }

      # Run sizing.
      run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models)

      # Apply the NECB 2015 pump power rules to the model.
      standard.apply_maximum_loop_pump_power(model)

      # From here to the end of the method the expected pump power is calculated and is compared to what was applied to the model.
      plant_loops = model.getPlantLoops
      plant_loops.each do |plantloop|
        pumps = []
        max_powertoload = 0
        total_pump_power = 0
        # This cycles through the plant loop supply side components to determine if there is a heat pump present or a pump
        # If a heat pump is present the pump power to total demand ratio is set to what NECB 2015 table 5.2.6.3. say it should be.
        # If a pump is present, this is a handy time to grab it for modification later.  Also, it adds the pump power consumption
        # to a total which will be used to determine how much to modify the pump power consumption later.
        plantloop.supplyComponents.each do |supplycomp|
          case supplycomp.iddObjectType.valueName.to_s
            when 'OS_CentralHeatPumpSystem'
              max_powertoload = 22
            when 'OS_Coil_Heating_WaterToAirHeatPump_EquationFit'
              max_powertoload = 22
            when 'OS_Coil_Heating_WaterToAirHeatPump_VariableSpeedEquationFit'
              max_powertoload = 22
            when 'OS_Coil_Heating_WaterToAirHeatPump_VariableSpeedEquationFit_SpeedData'
              max_powertoload = 22
            when 'OS_HeatPump_WaterToWater_EquationFit_Cooling'
              max_powertoload = 22
            when 'OS_HeatPump_WaterToWater_EquationFit_Heating'
              max_powertoload = 22
            when 'OS_Pump_VariableSpeed'
              pump = supplycomp.to_PumpVariableSpeed.get
              pumps << pump
              total_pump_power += pump.autosizedRatedPowerConsumption.get
            when 'OS_Pump_ConstantSpeed'
              pump = supplycomp.to_PumpConstantSpeed.get
              pumps << pump
              total_pump_power += pump.autosizedRatedPowerConsumption.get
            when 'OS_HeaderedPumps_ConstantSpeed'
              pump = supplycomp.to_HeaderedPumpsConstantSpeed.get
              pumps << pump
              total_pump_power += pump.autosizedRatedPowerConsumption.get
            when 'OS_HeaderedPumps_VariableSpeed'
              pump = supplycomp.to_HeaderedPumpsVariableSpeed.get
              pumps << pump
              total_pump_power += pump.autosizedRatedPowerConsumption.get
          end
        end
        # If no pumps were found then there is nothing to set so go to the next plant loop
        next if pumps.length == 0
        # If a heat pump was found then the pump power to total demand ratio should have been set to what NECB 2015 table 5.2.6.3 says.
        # If the pump power to total demand ratio was not set then no heat pump was present so set according to if the plant loop is
        # used for heating, cooling, or heat rejection (condeser as OpenStudio calls it).
        unless max_powertoload > 0
          case plantloop.sizingPlant.loopType
            when 'Heating'
              max_powertoload = 4.5
            when 'Cooling'
              max_powertoload = 14
            when 'Condenser'
              max_powertoload = 12
          end
        end
        # If nothing was found then do nothing (though by this point if nothing was found then an error should have been thrown).
        next if max_powertoload == 0
        # Get the capacity of the loop (using the more general method of calculating via maxflow*temp diff*density*heat capacity)
        # This is more general than the other method in Standards.PlantLoop.rb which only looks at heat and cooling.  Also,
        # that method looks for spceific equipment and would be thrown if other equipment was present.  However my method
        # only works for water for now.
        plantloop_maxflowrate = plantloop.autosizedMaximumLoopFlowRate.get.to_f
#        plantloop_maxflowrate = model.getAutosizedValue(plantloop, 'Maximum Loop Flow Rate', 'm3/s').to_f
        plantloop_dt = plantloop.sizingPlant.loopDesignTemperatureDifference.to_f
        # Plant loop capacity = temperature difference across plant loop * maximum plant loop flow rate * density of water (1000 kg/m^3) * see next line
        # Heat capacity of water (4180 J/(kg*K))
        plantloop_capacity = plantloop_dt*plantloop_maxflowrate*1000*4180
        # Sizing factor is pump power (W)/ zone demand (in kW, as approximated using plant loop capacity).
        necb_pump_power_cap = plantloop_capacity*max_powertoload/1000
        pump_power_adjustment = necb_pump_power_cap/total_pump_power
        error_value = 0
        run_check = false
        # The following divides the current either pump power per flow per pressure or power per flow value by what the above
        # calculations say it should be.  If the result is very close to 1 then the test passed.  If not then something is amiss
        # and an error is thrown.
        pumps.each do |pump|
          case pump.designPowerSizingMethod
            when 'PowerPerFlowPerPressure'
              # The default rated pump head is 179352.0 Pa
              error_value += ((pump.ratedPumpHead/(pump_power_adjustment*179352.0)) - 1).abs
              run_check = true
            when 'PowerPerFlow'
              # The default Default Design Electric Power Per Unit Flow Rate is 348701.1
              error_value += ((pump.designElectricPowerPerUnitFlowRate / (pump_power_adjustment*348701.1)) - 1).abs
              run_check = true
          end
        end
        if error_value >= 0.0001 && run_check == true
          assert(false, "The size of the pump(s) in plantloop #{plantloop.name.to_s} is incorrect by the following amount: #{error_value}")
        end
      end
    end
  end
end
