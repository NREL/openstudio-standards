require_relative 'minitest_helper'
require_relative 'create_doe_prototype_helper'
require 'json'

$LOAD_PATH.unshift File.expand_path('../../../../openstudio-standards/lib', __FILE__)
def run_dir(test_name)
  # always generate test output in specially named 'output' directory so result files are not made part of the measure
  "#{File.dirname(__FILE__)}/output/#{test_name}"
end

def model_out_path(test_name)
  "#{run_dir(test_name)}/ExampleModel.osm"
end

def workspace_path(test_name)
  "#{run_dir(test_name)}/ModelToIdf/in.idf"
end

def sql_path(test_name)
  "#{run_dir(test_name)}/ModelToIdf/EnergyPlusPreProcess-0/EnergyPlus-0/eplusout.sql"
end

def report_path(test_name)
  "#{run_dir(test_name)}/report.html"
end

def calculate_max_delta_t(adj_DaySchedule, cur_DaySchedule)
  max = -999
  #  #if either one of schedule does not exist then it will return the max of the existing schedule
  #  if adj_DaySchedule.nil?
  #    0.upto(23) do |hour|
  #      time = OpenStudio::Time.new(0,hour,0,0)
  #      max = cur_DaySchedule.getValue(time) if cur_DaySchedule.getValue(time) > max
  #    end
  #  elsif cur_DaySchedule.nil?
  #    0.upto(23) do |hour|
  #      time = OpenStudio::Time.new(0,hour,0,0)
  #      max = adj_DaySchedule.getValue(time) if adj_DaySchedule.getValue(time) > max
  #    end
  #  elsif (cur_DaySchedule.nil? and cur_DaySchedule.nil?)
  #    return nil
  #  end
  if (cur_DaySchedule.nil? or adj_DaySchedule.nil?)
    raise ("cur_DaySchedule or adj_DaySchedule is nil")
    return nil
  end
  
  0.upto(23) do |hour|
    time = OpenStudio::Time.new(0,hour,0,0)
    difference = (cur_DaySchedule.getValue(time) - adj_DaySchedule.getValue(time)).abs
    max = difference if difference > max
  end
  return max

end

#returns -999 if current surface does not have heating OR cooling schedule
#returns -997 if all adjacent surfaces does not have BOTH heating AND cooling
#returns nil if the surface does not have adjacent surface
def get_schedule_max_delta_t(model, surface)
  #find spaces that share that surface. 
  #load the schedules for every day type of the year. for both spaces. If the space is does not have a heating schedule..assume the temperature is the -10C always for now. 
  #iterate through every hour. and determine delta T
  # Store the max delta T. 
  # end iteration
  #return max deltaT
  cur_space = nil
  delta_t = -998
  adjacent_surface_found = false
  atleast_one_adjacent_surface_has_schedule = false
  model.getSpaces.each do |space|
    if space == surface.space.get
      cur_space = space
    end
  end
  if cur_space.nil?
    raise ("Surface: [#{surface.name}] does not belong to any space")
  end
  model.getSpaces.each do |space|
    if space == surface.space.get
      next
    end
    surf = BTAP::Geometry::Surfaces::get_surfaces_from_spaces([space])
    surf.each do |surf|
      unless surf.adjacentSurface.empty?
        adj_surface = surf.adjacentSurface.get
        if adj_surface == surface
          adjacent_surface_found = true
          unless space.thermalZone().empty?
            adj_surface_thermal_zone = space.thermalZone().get
            cur_surface_thermal_zone = cur_space.thermalZone().get
            unless adj_surface_thermal_zone.thermostatSetpointDualSetpoint.empty?
              adj_thermostat = adj_surface_thermal_zone.thermostatSetpointDualSetpoint.get
              cur_thermostat = cur_surface_thermal_zone.thermostatSetpointDualSetpoint.get
              #if current surface does not have a thermostat schedule, then it will return -999 instead of nil because nil is reserved for surfaces without adjacent surface
              if (cur_thermostat.getHeatingSchedule().empty? or cur_thermostat.getCoolingSchedule().empty?)
                return -999
              end
              #after this point current surface should have BOTH heating and cooling schedule
              #if adjacent surface does not have a heating OR cooling schedule it will be skipped
              if (adj_thermostat.getHeatingSchedule().empty? or adj_thermostat.getCoolingSchedule().empty?)
                next
              else
                atleast_one_adjacent_surface_has_schedule = true
              end
                
              startDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(1), 1,2009)
              endDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(1), 7,2009)
              
              adj_surface_heating_day_schedule_array = adj_thermostat.getHeatingSchedule().get.to_ScheduleRuleset.get.getDaySchedules(startDate,endDate) unless adj_thermostat.getHeatingSchedule().empty?
              adj_surface_cooling_day_schedule_array = adj_thermostat.getCoolingSchedule().get.to_ScheduleRuleset.get.getDaySchedules(startDate,endDate) unless adj_thermostat.getCoolingSchedule().empty?
              cur_surface_heating_day_schedule_array = cur_thermostat.getHeatingSchedule().get.to_ScheduleRuleset.get.getDaySchedules(startDate,endDate) unless cur_thermostat.getHeatingSchedule().empty?
              cur_surface_cooling_day_schedule_array = cur_thermostat.getCoolingSchedule().get.to_ScheduleRuleset.get.getDaySchedules(startDate,endDate) unless cur_thermostat.getCoolingSchedule().empty?
              delta_t = -998
              heating_delta_t =  []
              cooling_delta_t = []
              1.upto(7) { |i|
                puts "mee mee mee"
                puts calculate_max_delta_t(adj_surface_heating_day_schedule_array[i-1],cur_surface_heating_day_schedule_array[i-1])
                heating_delta_t << calculate_max_delta_t(adj_surface_heating_day_schedule_array[i-1],cur_surface_heating_day_schedule_array[i-1])
                cooling_delta_t << calculate_max_delta_t(adj_surface_cooling_day_schedule_array[i-1],cur_surface_cooling_day_schedule_array[i-1])
              }
              delta_t = [heating_delta_t.max, cooling_delta_t.max].max
              puts "delta_t: #{delta_t}"
            end
          end
        end
      end
    end
  end
  #adjacent_surface_found ? (atleast_one_adjacent_surface_has_schedule ? (return delta_t) : (return -997)) : (return nil)
  if adjacent_surface_found
    if atleast_one_adjacent_surface_has_schedule
      return delta_t
    else
      return -997
    end
  else
    return nil
  end
end
#LargeOffice
class TestNECBSurfaces8426Custom < CreateDOEPrototypeBuildingTest
  building_types = [
    'LargeOffice',
    'LargeHotel',
    'FullServiceRestaurant',
    'Outpatient',
    'PrimarySchool'
  ]

  templates = [ 'NECB 2011']
  climate_zones = ['NECB HDD Method']
  epw_files = [
    #  'CAN_BC_Vancouver.718920_CWEC.epw',#  CZ 5 - Gas HDD = 3019 
    #  'CAN_ON_Toronto.716240_CWEC.epw', #CZ 6 - Gas HDD = 4088
    #  'CAN_PQ_Sherbrooke.716100_CWEC.epw', #CZ 7a - Electric HDD = 5068
    #  'CAN_YT_Whitehorse.719640_CWEC.epw', #CZ 7b - FuelOil1 HDD = 6946
    #  'CAN_NU_Resolute.719240_CWEC.epw', # CZ 8  -FuelOil2 HDD = 12570
    'CAN_BC_Prince.George.718960_CWEC.epw'
  ]
  building_types.each do |building|
    epw_files.each do |weather|
      hash = {}
      test_name = "#{building}_#{weather}"
      unless File.exist?(run_dir(test_name))
        FileUtils.mkdir_p(run_dir(test_name))
      end
      #assert(File.exist?(run_dir(test_name)))

      if File.exist?(report_path(test_name))
        FileUtils.rm(report_path(test_name))
      end

      #assert(File.exist?(model_in_path))

      if File.exist?(model_out_path(test_name))
        FileUtils.rm(model_out_path(test_name))
      end
      output_folder = "#{File.dirname(__FILE__)}/output/#{test_name}"
      model = OpenStudio::Model::Model.new
      model.create_prototype_building(building,'NECB 2011','NECB HDD Method',weather,output_folder)
      BTAP::Environment::WeatherFile.new(weather).set_weather_file(model)
      model.getSpaces.each do |space|
        #puts space.name
        hash[:"Space: #{space.name}"] = {}
        hash[:"Space: #{space.name}"][:"With Adjacent Surface"] = {}
        hash[:"Space: #{space.name}"][:"No Adjacent surface"] = []
        surfaces = BTAP::Geometry::Surfaces::get_surfaces_from_spaces([space])
        surfaces.each do |surface|
          max_delta_t = get_schedule_max_delta_t(model, surface)
          unless max_delta_t.nil?
            hash[:"Space: #{space.name}"][:"With Adjacent Surface"][:"#{surface.name}"] = max_delta_t
          else
            hash[:"Space: #{space.name}"][:"No Adjacent surface"] << surface.name
          end
        end
      end
      #model.save(model_out_path(test_name), true)
      File.open("#{output_folder}/max_delta_t.json", 'w') {|f| f.write(JSON.pretty_generate(hash)) }
    end
  end
    
end
