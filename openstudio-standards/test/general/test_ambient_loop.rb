require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'

require 'fileutils'

class TestAmbientLoop < CreateDOEPrototypeBuildingTest

  # test with Small office
  run_dir = File.join(File.dirname(__FILE__), 'output/small_office')
  FileUtils.rm_rf(run_dir) if Dir.exist? run_dir
  FileUtils.mkdir_p run_dir unless Dir.exist? run_dir

  model = OpenStudio::Model::Model.new
  model.create_prototype_building('SmallOffice', '90.1-2010', 'ASHRAE 169-2006-5B',
                                  'USA_CO_Golden-NREL.724666_TMY3.epw', run_dir, true)
  model.save("#{run_dir}/prototype.osm")

  puts "trying to remove HVAC equipment"
  model.remove_prm_hvac

  model.save("#{run_dir}/prototype-no-hvac.osm", true)

  # add in the ambient loop model -- this is definitely not right. This adds a water to air heat pump
  thermal_zones = []
  model.getThermalZones.each do |thermalzone|
    next if thermalzone.name.get =~ /Attic.*/i
    thermal_zones << thermalzone
  end
  model.add_energy_transfer_station("Water-to-water Heat Pump", thermal_zones)

  # add report variables
  ['District Heating Inlet Temperature',
   'District Heating Outlet Temperature',
   'District Cooling Inlet Temperature',
   'District Cooling Outlet Temperature',
   'Site Mains Water Temperature'].each do |var|
    output = OpenStudio::Model::OutputVariable.new(var, model)
    output.setKeyValue("*")
    output.setReportingFrequency('hourly')
  end

  ['Heating:Electricity',
   'Cooling:Electricity'].each do |var|
    output = OpenStudio::Model::OutputMeter.new(model)
    output.setName(var)
    output.setReportingFrequency('hourly')
  end

  # set hw_loop temperature to 140 deg F



  # set the mains temperature schedule
  # water_mains_f = 75
  # water_mains_c = OpenStudio.convert(water_mains_f, 'F', 'C').get
  # water_mains_sch = OpenStudio::Model::ScheduleRuleset.new(model)
  # water_mains_sch.setName("Water Mains Temp - #{water_mains_f}F")
  # water_mains_sch.defaultDaySchedule.setName("Water Mains Temp - #{water_mains_f}F Default")
  # water_mains_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), water_mains_c)
  #
  # remove water mains, then add it back in -- because why not
  # model.getSiteWaterMainsTemperature.remove
  # water_temp = model.getSiteWaterMainsTemperature
  # water_temp.setTemperatureSchedule(water_mains_sch)

  # try and set the temperature of the ambient loop - this includes setting the
  # plant loop min/max temperatures, the sizing plant objects, and the schedules
  # new_setpoint = 2.0
  # new_delta = 5.6666
  # plant_loop = model.getPlantLoopByName('Ambient Loop').get
  # plant_loop.setMinimumLoopTemperature(new_setpoint)
  # plant_loop.setMaximumLoopTemperature(new_setpoint)
  # loop_sizing = plant_loop.sizingPlant
  # loop_sizing.setDesignLoopExitTemperature(new_setpoint)
  # loop_sizing.setLoopDesignTemperatureDifference(new_delta)
  #
  # plant_loop.supplyOutletNode.setpointManagers.each {|sm| sm.remove}
  #
  # amb_loop_schedule = OpenStudio::Model::ScheduleRuleset.new(model)
  # amb_loop_schedule.setName("Ambient Loop Temp - #{new_setpoint*9/5+32}F")
  # amb_loop_schedule.defaultDaySchedule.setName("Ambient Loop Temp - #{new_setpoint*9/5+32}F Default")
  # amb_loop_schedule.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), new_setpoint)
  #
  # amb_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, amb_loop_schedule)
  # amb_stpt_manager.setName('Ambient Loop Setpoint Manager - Scheduled')
  # amb_stpt_manager.setControlVariable("Temperature")
  # amb_stpt_manager.addToNode(plant_loop.supplyOutletNode)

  model.save("#{run_dir}/final.osm", true)


  # test with Primary School
  # run_dir = File.join(File.dirname(__FILE__), 'output/secondary_school')
  # FileUtils.rm_rf(run_dir) if Dir.exist? run_dir
  # FileUtils.mkdir_p run_dir unless Dir.exist? run_dir
  #
  # model = OpenStudio::Model::Model.new
  # model.create_prototype_building('SecondarySchool', '90.1-2010', 'ASHRAE 169-2006-5B',
  #                                 'USA_CO_Golden-NREL.724666_TMY3.epw', run_dir, true)
  # model.save("#{run_dir}/prototype.osm")
  #
  # puts "trying to remove HVAC equipment"
  # model.remove_prm_hvac
  #
  # model.save("#{run_dir}/prototype-no-hvac.osm", true)
  #
  # # add in the ambient loop model -- this is definitely not right. This adds a water to air heat pump
  # model.add_energy_transfer_station("Water-to-Water Heat Pump",
  #                                   model.getThermalZones)
  # model.save("#{run_dir}/final.osm", true)
end
