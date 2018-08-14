require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'


class NECB_HVAC_Tests < MiniTest::Test
  #set to true to run the standards in the test.
  PERFORM_STANDARDS = true
  #set to true to run the simulations.
  FULL_SIMULATIONS = false

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
    output_folder = "#{File.dirname(__FILE__)}/output/pumppower"
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    template = 'NECB2015'
    standard = Standard.build(template)

    tol = 1.0e-3
    # Generate the osm files for all relevant cases to generate the test data for system 6
    boiler_fueltype = 'Electricity'
    baseboard_type = 'Hot Water'
    chiller_types = ['Scroll']
    heating_coil_type = 'Hot Water'
    fan_type = 'AF_or_BI_rdg_fancurve'
    chiller_cap = 1000000.0
    model = BTAP::FileIO.load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    clgtowerFanPowerFr = 0.013
    chiller_types.each do |chiller_type|
      name = "sys6_#{template}_ChillerType_#{chiller_type}~#{chiller_cap}watts"
      puts "***************************************#{name}*******************************************************\n"
      model = BTAP::FileIO.load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
      BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
      standard.add_sys6_multi_zone_built_up_system_with_baseboard_heating(
        model,
        model.getThermalZones,
        boiler_fueltype,
        heating_coil_type,
        baseboard_type,
        chiller_type,
        fan_type,
        hw_loop)
      # Save the model after btap hvac.
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
      model.getChillerElectricEIRs.each { |ichiller| ichiller.setReferenceCapacity(chiller_cap) }
      # run the standards
      result = run_the_measure(model, template, "#{output_folder}/#{name}/sizing")
      # Save the model
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
      assert_equal(true, result, "Failure in Standards for #{name}")
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
              pumps << supplycomp.to_PumpVariableSpeed.get
              total_pump_power += model.getAutosizedValue(supplycomp, 'Design Power Consumption', 'W').to_f
            when 'OS_Pump_ConstantSpeed'
              pumps << supplycomp.to_PumpConstantSpeed.get
              total_pump_power += model.getAutosizedValue(supplycomp, 'Design Power Consumption', 'W').to_f
            when 'OS_HeaderedPumps_ConstantSpeed'
              pumps << supplycomp.to_HeaderedPumpsConstantSpeed.get
              total_pump_power += model.getAutosizedValue(supplycomp, 'Design Power Consumption', 'W').to_f
            when 'OS_HeaderedPumps_VariableSpeed'
              pumps << supplycomp.to_HeaderedPumpsVariableSpeed.get
              total_pump_power += model.getAutosizedValue(supplycomp, 'Design Power Consumption', 'W').to_f
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
              # The default Design Shaft Power Per Unit Flow Rate Per Unit Head is 1.282051282
              error_value += ((pump.designShaftPowerPerUnitFlowRatePerUnitHead/(pump_power_adjustment*1.282051282)) - 1).abs
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

  def run_the_measure(model, template, sizing_dir)
    if PERFORM_STANDARDS
      # Hard-code the building vintage
      building_vintage = template
      building_type = 'NECB'
      climate_zone = 'NECB'
      standard = Standard.build(building_vintage)

      # Make a directory to run the sizing run in
      unless Dir.exist? sizing_dir
        FileUtils.mkdir_p(sizing_dir)
      end

      # Perform a sizing run
      if standard.model_run_sizing_run(model, "#{sizing_dir}/SizingRun1") == false
        puts "could not find sizing run #{sizing_dir}/SizingRun1"
        raise("could not find sizing run #{sizing_dir}/SizingRun1")
        return false
      else
        puts "found sizing run #{sizing_dir}/SizingRun1"
      end

      BTAP::FileIO.save_osm(model, "#{File.dirname(__FILE__)}/before.osm")

      # need to set prototype assumptions so that HRV added
      standard.model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)
      # Apply the HVAC efficiency standard
      standard.model_apply_hvac_efficiency_standard(model, climate_zone)
      # self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}

      # Do another sizing run after applying the hvac assumptions and efficiency standars to properly apply the pump rules.
      if standard.model_run_sizing_run(model, "#{sizing_dir}/SizingRun2") == false
        puts "could not find sizing run #{sizing_dir}/SizingRun2"
        raise ("could not find sizing run #{sizing_dir}/SizingRun2")
      else
        puts "found sizing run #{sizing_dir}/SizingRun2"
      end
      # Apply the pump power rules to the model
      standard.apply_maximum_loop_pump_power(model)

      BTAP::FileIO.save_osm(model, "#{File.dirname(__FILE__)}/after.osm")

      return true
    end
  end
end