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

  model.save("#{run_dir}/final.osm", true)
end
