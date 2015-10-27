# *********************************************************************
# *  Copyright (c) 2008-2015, Natural Resources Canada
# *  All rights reserved.
# *
# *  This library is free software; you can redistribute it and/or
# *  modify it under the terms of the GNU Lesser General Public
# *  License as published by the Free Software Foundation; either
# *  version 2.1 of the License, or (at your option) any later version.
# *
# *  This library is distributed in the hope that it will be useful,
# *  but WITHOUT ANY WARRANTY; without even the implied warranty of
# *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# *  Lesser General Public License for more details.
# *
# *  You should have received a copy of the GNU Lesser General Public
# *  License along with this library; if not, write to the Free Software
# *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
# **********************************************************************/


module BTAP
  module MPC
    class MPC

      #set hourly setpoint values
      #"E:\\Montreal2\\ZonalLevel\\", #analysis folder
      #"C:\\osruby\\lib\\basic_ideal_loads.osm", #model file.
      #"Z:\\MPC Chipmunk Model\\Weather Files\\CAN_PQ_Montreal.Intl.AP.716270_CWEC\\CAN_PQ_Montreal.Intl.AP.716270_CWEC.epw" #standard_weather_file

      #This method initializes.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model_file [OpenStudio::model::Model] A model object
      #@params weather_file [String] path to a weather file
      #@params analysis_folder [String] path to analysis folder
      def initialize (
          model_file,
          weather_file,
          analysis_folder)

        @model_file, @weather_file, @analysis_folder = model_file, weather_file, analysis_folder


        self.miso_zonal_analysis(@analysis_folder, #analysis folder
          @model_file, #model file.
          @weather_file #standard_weather_file
        )

        self.miso_building_analysis(@analysis_folder, #analysis folder
          @model_file, #model file.
          @weather_file #standard_weather_file
        )


      end

      #This method creates the schedules.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model [OpenStudio::model::Model] A model object
      def create_schedules(model)

        #Create cooling temperature schedule

        cool_sched_ruleset = BTAP::Resources::Schedules::create_annual_ruleset_schedule_detailed(model, "mpc_cooling_day", "TEMPERATURE",[
            [
              ["Jan-01","Dec-31"],["M","T","W","TH","F","S","SN"],
              [
                [ "5:00",  18.0 ],
                [ "9:00",  21.0 ],
                [ "15:00", 23.0 ],
                [ "18:00", 21.0 ],
                [ "24:00", 18.0 ]
              ]
            ]
          ]
        )

        #Create cooling temperature schedule
        heat_sched_ruleset = BTAP::Resources::Schedules::create_annual_ruleset_schedule_detailed(model, "mpc_cooling_day", "TEMPERATURE",[
            [
              ["Jan-01","Dec-31"],["M","T","W","TH","F","S","SN"],
              [
                [ "5:00",  18.0 ],
                [ "9:00", 21.0 ],
                [ "15:00", 23.0 ],
                [ "18:00", 21.0 ],
                [ "24:00", 18.0 ]
              ]
            ]
          ]
        )

        heat_sched_ruleset21 = BTAP::Resources::Schedules::create_annual_constant_ruleset_schedule(model, "mpc_cooling_day21","TEMPERATURE",21.0)
        cool_sched_ruleset21 = BTAP::Resources::Schedules::create_annual_constant_ruleset_schedule(model, "mpc_heating_day21","TEMPERATURE",21.0)

        @hourlyArrayValues21 =
          [
          Array.new(24){21}, #Weekday
          Array.new(24){21}, #Sat
          Array.new(24){21}, #Sun
        ]

        @hourly_noheatingArrayValues =
          [
          Array.new(24){-60}, #Weekday
          Array.new(24){-60}, #Sat
          Array.new(24){-60}, #Sun
        ]

        @hourly_nocoolingArrayValues =
          [
          Array.new(24){200}, #Weekday
          Array.new(24){200}, #Sat
          Array.new(24){200}, #Sun
        ]
        #model.add_standard_schedules()

        no_cool_sched_ruleset = BTAP::Resources::Schedules::create_annual_ruleset_schedule(model,"mpc_no_cooling_day","TEMPERATURE",@hourly_nocoolingArrayValues)
        no_heat_sched_ruleset = BTAP::Resources::Schedules::create_annual_ruleset_schedule(model,"mpc_no_heating_day","TEMPERATURE",@hourly_noheatingArrayValues)

        @mpc_heat_cool = BTAP::Resources::Schedules::create_annual_thermostat_setpoint_dual_setpoint(model,"mpc_heat_cool_set",heat_sched_ruleset,cool_sched_ruleset)
        @mpc_no_cooling = BTAP::Resources::Schedules::create_annual_thermostat_setpoint_dual_setpoint(model,"mpc_no_cooling_set",heat_sched_ruleset,no_cool_sched_ruleset)
        @mpc_no_heating = BTAP::Resources::Schedules::create_annual_thermostat_setpoint_dual_setpoint(model,"mpc_no_heating_set",no_heat_sched_ruleset,cool_sched_ruleset)
        @mpc_no_heat_cool = BTAP::Resources::Schedules::create_annual_thermostat_setpoint_dual_setpoint(model,"mpc_no_heat_cool_set",no_heat_sched_ruleset,no_cool_sched_ruleset)
        @mpc_21C_setpoint = BTAP::Resources::Schedules::create_annual_thermostat_setpoint_dual_setpoint(model,"mpc_21C_setpoint",heat_sched_ruleset21,cool_sched_ruleset21)
      end

      #This method sets the output variables.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model [OpenStudio::model::Model] A model object
      def set_output_variables(model)
        output_variable_array =
          [

          "Site Outdoor Air Drybulb Temperature",
          "Site Outdoor Air Dewpoint Temperature",
          "Site Outdoor Air Wetbulb Temperature",
          "Site Outdoor Air Humidity Ratio",
          "Site Outdoor Air Relative Humidity",
          "Site Outdoor Air Barometric Pressure",
          "Site Wind Speed",
          "Site Wind Direction",
          "Site Sky Temperature",
          "Site Horizontal Infrared Radiation Rate per Area",
          "Site Diffuse Solar Radiation Rate per Area",
          "Site Direct Solar Radiation Rate per Area",
          "Site Precipitation Depth",
          "Site Ground Reflected Solar Radiation Rate per Area",
          "Site Ground Temperature",
          "Site Surface Ground Temperature",
          "Site Deep Ground Temperature",
          "Site Simple Factor Model Ground Temperature",
          "Site Outdoor Air Enthalpy",
          "Site Outdoor Air Density",
          "Site Solar Azimuth Angle",
          "Site Solar Altitude Angle",
          "Site Solar Hour Angle",
          "Site Rain Status",
          "Site Snow on Ground Status",
          "Site Exterior Horizontal Sky Illuminance",
          "Site Exterior Horizontal Beam Illuminance",
          "Site Exterior Beam Normal Illuminance",
          "Site Sky Diffuse Solar Radiation Luminous Efficacy",
          "Site Beam Solar Radiation Luminous Efficacy",
          "Site Daylighting Model Sky Clearness",
          "Site Daylighting Model Sky Brightness",
          "Site Daylight Saving Time Status",
          "Site Day Type Index",
          "Site Mains Water Temperature",
          "Zone Operative Temperature",
          "Zone Windows Total Transmitted Solar Radiation Energy",
          "Zone Ideal Loads Zone Total Heating Energy",
          "Zone Ideal Loads Zone Total Cooling Energy",
          "Zone Total Internal Total Heating Energy",
          "Zone Total Internal Total Heating Rate",
          "Zone List Sensible Heating Energy",
          "Zone List Sensible Cooling Energy",
          "Zone List Sensible Heating Rate",
          "Zone List Sensible Cooling Rate",
          "Cooling Coil Total Cooling Rate",
          "Cooling Coil Total Cooling Energy",
          "Cooling Coil Sensible Cooling Rate",
          "Cooling Coil Sensible Cooling Energy",
          "Cooling Coil Latent Cooling Rate",
          "Cooling Coil Latent Cooling Energy",
          "Cooling Coil Electric Power",
          "Cooling Coil Electric Energy",
          "Cooling Coil Runtime Fraction",
          "Air System Cooling Coil Total Cooling Energy",
          "Air System Total Cooling Energy"

        ]
        BTAP::Reports::clear_output_variables(model)
        BTAP::Reports::set_output_variables(model, "Timestep", output_variable_array)
      end

      #This method creates the weather file.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params weather_file [String] path to a weather file
      def create_weather_files(weather_file)
        #no solar file.
        @solar_radiation_off_temp_normal = @analysis_folder + "/solar_radiation_off_temp_normal.epw"
        @radiation_off_temp_normal = @analysis_folder + "/no_solar.epw"
        @solar_radiation_only_temp_constant = @analysis_folder + "/const_temp.epw"
        @all_off = @analysis_folder + "/all_off.epw"
        @original_file = @analysis_folder + "/orig.epw"
        @solar_radiation_off_temp_minus_10C = @analysis_folder + "/solar_radiation_off_temp_minus_10C.epw"

        BTAP::Environment::WeatherFile.new(weather_file).writetofile(@original_file)

        BTAP::Environment::WeatherFile.new(weather_file).
          eliminate_percipitation().
          eliminate_wind().
          eliminate_only_solar_radiation().
          writetofile(@solar_radiation_off_temp_normal)

        BTAP::Environment::WeatherFile.new(weather_file).setConstantDryandDewPointTemperatureHumidityAndPressure("-10.0","-17.9","49","102590").
          eliminate_percipitation().
          eliminate_wind().
          eliminate_only_solar_radiation().
          writetofile(@solar_radiation_off_temp_minus_10C)

        BTAP::Environment::WeatherFile.new(weather_file).eliminate_all_radiation().
          eliminate_percipitation().
          eliminate_wind().
          writetofile(@radiation_off_temp_normal)

        BTAP::Environment::WeatherFile.new(weather_file).setConstantDryandDewPointTemperatureHumidityAndPressure().
          eliminate_percipitation().
          eliminate_all_radiation_except_solar().
          eliminate_wind.writetofile(@solar_radiation_only_temp_constant)

        BTAP::Environment::WeatherFile.new(weather_file).eliminate_all_radiation().
          eliminate_percipitation().
          eliminate_wind.setConstantDryandDewPointTemperatureHumidityAndPressure().
          writetofile(@all_off)
      end

      #This method miso building generation and returns a model array.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model [OpenStudio::model::Model] A model object
      #@params standard_weather_file [String] path to a weather file
      #@return [model_array<String>]
      def miso_building_generation(model,standard_weather_file)
        self.set_output_variables(model)
        self.create_weather_files(standard_weather_file)
        self.create_schedules(model)
        model_array = Array.new()


        #Set global charecteristics.
        model.getSimulationControl.setMaximumNumberofWarmupDays(100)
        model.getSimulationControl.setMinimumNumberofWarmupDays(100)

        # GBase no hvac
        gbaseModel = BTAP::FileIO::deep_copy(model)
        gbaseModel.building.get.setAttribute("name","Gbase")
        BTAP::Site::set_weather_file(gbaseModel, @original_file)
        BTAP::Resources::HVAC::clear_all_hvac_from_model(gbaseModel)
        gbaseModel.getThermalZones.each  do |thermalzone| 
          thermalzone.setUseIdealAirLoads(true)
        end
        ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition( gbaseModel.getSurfaces, ["Ground"] )
        BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gbaseModel , ground_surfaces, "Adiabatic")
        model_array.push(gbaseModel)


        # Gfloating
        gfloatModel = BTAP::FileIO::deep_copy(model)
        gfloatModel.building.get.setAttribute("name","Gfloating")
        BTAP::Site::set_weather_file(gfloatModel, @original_file)
        BTAP::Resources::HVAC::clear_all_hvac_from_model(gfloatModel)
        gfloatModel.getThermalZones.each  do |thermalzone| 
          thermalzone.setThermostatSetpointDualSetpoint(@mpc_no_heat_cool)
          thermalzone.setUseIdealAirLoads(true)
        end
        ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition( gfloatModel.getSurfaces, ["Ground"] )
        BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gfloatModel , ground_surfaces, "Adiabatic")
        model_array.push(gfloatModel)




        #        # Gideal
        #        gidealModel = BTAP::FileIO::deep_copy(model)
        #        gidealModel.building.get.setAttribute("name","Gideal")
        #        BTAP::Site::set_weather_file(gidealModel, @original_file)
        #        gidealModel.getThermalZones.each do |thermalzone|
        #          thermalzone.setThermostatSetpointDualSetpoint(@mpc_21C_setpoint)
        #        end
        #        ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition( gidealModel.getSurfaces, ["Ground"] )
        #        BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gidealModel , ground_surfaces, "Adiabatic")
        #        model_array.push(gidealModel)

        #
        #
        #        # Gadiabatic
        #        gadiabaticModel = BTAP::FileIO::deep_copy(model)
        #        gadiabaticModel.building.get.setAttribute("name","Gadiabatic")
        #        BTAP::Site::set_weather_file(gadiabaticModel, @original_file)
        #        gadiabaticModel.getThermalZones.each { |thermalzone| thermalzone.setThermostatSetpointDualSetpoint(@mpc_21C_setpoint)}
        #        self.set_internal_gains_to_zero(gadiabaticModel)
        #        outdoor_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(gadiabaticModel.getSurfaces, ["Outdoors"])
        #        BTAP::Geometry::Surfaces::set_surfaces_construction_conductance(outdoor_surfaces, 1/200)
        #        ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition( gadiabaticModel.getSurfaces, ["Ground"] )
        #        BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gadiabaticModel , ground_surfaces, "Adiabatic")
        #        model_array.push(gadiabaticModel)
        #
        #
        #        # Gsteadystate
        #        gsteadystateModel = BTAP::FileIO::deep_copy(model)
        #        gsteadystateModel.building.get.setAttribute("name","Gsteadystate")
        #        BTAP::Site::set_weather_file(gsteadystateModel, @all_off)
        #        self.set_internal_gains_to_zero(gsteadystateModel)
        #        gsteadystateModel.getThermalZones.each { |thermalzone| thermalzone.setThermostatSetpointDualSetpoint(@mpc_21C_setpoint)}
        #        ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition( gsteadystateModel.getSurfaces, ["Ground"] )
        #        BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gsteadystateModel , ground_surfaces, "Adiabatic")
        #        model_array.push(gsteadystateModel)
        #
        #
        #        # Gig
        #        gigModel = BTAP::FileIO::deep_copy(model)
        #        gigModel.building.get.setAttribute("name","Gig")
        #        BTAP::Site::set_weather_file(gigModel, @all_off)
        #        gigModel.getThermalZones.each { |thermalzone| thermalzone.setThermostatSetpointDualSetpoint(@mpc_no_heat_cool)}
        #        ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition( gigModel.getSurfaces, ["Ground"] )
        #        BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gigModel , ground_surfaces, "Adiabatic")
        #        model_array.push(gigModel)
        #
        #
        #        # Gsg
        #        gsgModel = BTAP::FileIO::deep_copy(model)
        #        gsgModel.building.get.setAttribute("name","Gsg")
        #        BTAP::Site::set_weather_file( gsgModel,@solar_radiation_only_temp_constant)
        #        self.set_internal_gains_to_zero(gsgModel)
        #        gsgModel.getThermalZones.each { |thermalzone| thermalzone.setThermostatSetpointDualSetpoint(@mpc_no_heat_cool)}
        #        ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition( gsgModel.getSurfaces, ["Ground"] )
        #        BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gsgModel , ground_surfaces, "Adiabatic")
        #        model_array.push(gsgModel)
        #
        #
        #        # Gext
        #        gextModel = BTAP::FileIO::deep_copy(model)
        #        gextModel.building.get.setAttribute("name","Gext")
        #        BTAP::Site::set_weather_file( gextModel,@solar_radiation_off_temp_normal )
        #        self.set_internal_gains_to_zero(gextModel)
        #        gextModel.getThermalZones.each { |thermalzone| thermalzone.setThermostatSetpointDualSetpoint(@mpc_no_heat_cool)}
        #        ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition( gextModel.getSurfaces, ["Ground"] )
        #        BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gextModel , ground_surfaces, "Adiabatic")
        #        model_array.push(gextModel)
        #
        #        # Gh
        #        ghModel = BTAP::FileIO::deep_copy(model)
        #        ghModel.building.get.setAttribute("name","Gh")
        #        BTAP::Site::set_weather_file(ghModel,@all_off )
        #        self.set_internal_gains_to_zero(ghModel)
        #        ghModel.getThermalZones.each { |thermalzone| thermalzone.setThermostatSetpointDualSetpoint(@mpc_no_cooling)}
        #        ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition( ghModel.getSurfaces, ["Ground"] )
        #        BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( ghModel , ground_surfaces, "Adiabatic")
        #        model_array.push(ghModel)
        #
        #        # Gc
        #        gcModel = BTAP::FileIO::deep_copy(model)
        #        gcModel.building.get.setAttribute("name","Gc")
        #        BTAP::Site::set_weather_file(gcModel,@solar_radiation_off_temp_normal)
        #        self.set_internal_gains_to_zero(gcModel)
        #        gcModel.getThermalZones.each { |thermalzone| thermalzone.setThermostatSetpointDualSetpoint(@mpc_no_heating)}
        #        ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition( gcModel.getSurfaces, ["Ground"] )
        #        BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gcModel , ground_surfaces, "Adiabatic")
        #        model_array.push(gcModel)
        #
        #        # Goff
        #        goffModel = BTAP::FileIO::deep_copy(model)
        #        goffModel.building.get.setAttribute("name","Goff")
        #        BTAP::Site::set_weather_file(goffModel,@all_off)
        #        self.set_internal_gains_to_zero(goffModel)
        #        BTAP::Resources::SpaceLoads::ScaleLoads::scale_inflitration_loads(goffModel, 0.0)
        #        ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition( goffModel.getSurfaces, ["Ground"] )
        #        BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( goffModel , ground_surfaces, "Adiabatic")
        #        goffModel.getThermalZones.each { |thermalzone| thermalzone.setThermostatSetpointDualSetpoint(@mpc_no_heat_cool)}
        #        model_array.push(goffModel)


        return model_array
      end

      #This method miso building analysis.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model_file [OpenStudio::model::Model] A model object
      #@params folder_name [String] path to a folder
      #@params standard_weather_file [String] path to a weather file
      def miso_building_analysis(folder_name,model_file,standard_weather_file)
        model = BTAP::FileIO::load_osm(model_file)
        BTAP::Geometry::enumerate_spaces_model(model)
        BTAP::Geometry::rename_zones_based_on_spaces(model)
        BTAP::Geometry::prefix_equipment_with_zone_name(model)
        #since this is a one to one relationship of space to zone.Name them the same
        model.getSpaces.each do |space|
          space.thermalZone.get.setName(space.name.get)
        end
        #set run period to a week
        BTAP::SimulationSettings::set_run_period(model,1,1,12,31)
        #create models
        miso_building_generation(model,standard_weather_file).each do |new_model|
          BTAP::FileIO::get_name(new_model)
          save_file_name = "#{folder_name}/#{BTAP::FileIO::get_name(new_model)}.osm"
          BTAP::FileIO::save_osm(new_model, save_file_name)
        end
      end

      #This method miso zonal analysis.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model_file [OpenStudio::model::Model] A model object
      #@params folder_name [String] path to a folder
      #@params standard_weather_file [String] path to a weather file
      def miso_zonal_analysis(folder_name,model_file,standard_weather_file)

        model = BTAP::FileIO::load_osm(model_file)
        BTAP::Geometry::enumerate_spaces_model(model)
        BTAP::Geometry::rename_zones_based_on_spaces(model)
        BTAP::Geometry::prefix_equipment_with_zone_name(model)
        #since this is a one to one relationship of space to zone.Name them the same
        model.getSpaces.each do |space|
          space.thermalZone.get.setName(space.name.get)
        end
        #set run period to a week
        BTAP::SimulationSettings::set_run_period(model,1,1,12,31)
        miso_zonal_generation(model,standard_weather_file).each do |new_model|
          BTAP::FileIO::get_name(new_model)
          save_file_name = "#{folder_name}/#{BTAP::FileIO::get_name(new_model)}.osm"
          BTAP::FileIO::save_osm(new_model, save_file_name)
        end
      end

      #This method miso zonal generation and returns a model array.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model_file [OpenStudio::model::Model] A model object
      #@params folder_name [String] path to a folder
      #@params standard_weather_file [String] path to a weather file
      #@return [model_array<String>]
      def miso_zonal_generation(model,standard_weather_file)
        self.create_weather_files(standard_weather_file)
        self.create_schedules(model)
        model_array = Array.new()

        #model.clear_output_variables()
        self.set_output_variables(model)
        model.getSimulationControl.setMaximumNumberofWarmupDays(100)
        model.getSimulationControl.setMinimumNumberofWarmupDays(100)
        #create the array of models to run.
        model_array = Array.new()
        #get the number of thermal zones in the model
        num_of_thermal_zones = model.getThermalZones.size

        #change ground surfaces to adiabatic
        ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition( model.getSurfaces, ["Ground"] )
        BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( model , ground_surfaces, "Adiabatic")



        #iterate through each zone.
        (0..num_of_thermal_zones-1).each do |zone_number|
          #
          #          # Gsg Solar gains
          #          gsgModel = BTAP::FileIO::deep_copy(model)
          #          thermal_zones = gsgModel.getThermalZones
          #          gsgModel.building.get.setAttribute("name","Gsg-" + thermal_zones[zone_number].name.get)
          #          BTAP::Site::set_weather_file(gsgModel,@solar_radiation_only_temp_constant )
          #          self.set_internal_gains_to_zero(gsgModel)
          #          thermal_zones[zone_number].setThermostatSetpointDualSetpoint(@mpc_no_heat_cool)
          #          zone_surfaces = BTAP::Geometry::Surfaces::get_surfaces_from_thermal_zones([thermal_zones[zone_number]])
          #          BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gsgModel ,BTAP::Geometry::Surfaces::filter_by_boundary_condition( zone_surfaces, ["Surface"] ) , "Adiabatic")
          #          BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gsgModel , BTAP::Geometry::Surfaces::filter_by_boundary_condition( gsgModel.getSurfaces, ["Ground"] ) , "Adiabatic")
          #          model_array.push(gsgModel)
          #
          #
          #          # Gig - internal gains
          #          gigModel = BTAP::FileIO::deep_copy(model)
          #          thermal_zones = gigModel.getThermalZones
          #          gigModel.building.get.setAttribute("name","Gig-" + thermal_zones[zone_number].name.get)
          #          BTAP::Site::set_weather_file(gigModel,@all_off )
          #          thermal_zones[zone_number].setThermostatSetpointDualSetpoint(@mpc_no_heat_cool)
          #          zone_surfaces = BTAP::Geometry::Surfaces::get_surfaces_from_thermal_zones([thermal_zones[zone_number]])
          #          BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gigModel ,BTAP::Geometry::Surfaces::filter_by_boundary_condition( zone_surfaces, ["Surface"] ) , "Adiabatic")
          #          BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gigModel , BTAP::Geometry::Surfaces::filter_by_boundary_condition( gigModel.getSurfaces, ["Ground"] ) , "Adiabatic")
          #          model_array.push(gigModel)
          #
          #
          #          # Gext external gains
          #          gextModel = BTAP::FileIO::deep_copy(model)
          #          thermal_zones = gextModel.getThermalZones
          #          gextModel.building.get.setAttribute("name","Gext-" + thermal_zones[zone_number].name.get)
          #          BTAP::Site::set_weather_file(gextModel,@solar_radiation_off_temp_normal )
          #          self.set_internal_gains_to_zero(gextModel)
          #          thermal_zones[zone_number].setThermostatSetpointDualSetpoint(@mpc_no_heat_cool)
          #          zone_surfaces = BTAP::Geometry::Surfaces::get_surfaces_from_thermal_zones([thermal_zones[zone_number]])
          #          BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gextModel ,BTAP::Geometry::Surfaces::filter_by_boundary_condition( zone_surfaces, ["Surface"] ) , "Adiabatic")
          #          BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gextModel , BTAP::Geometry::Surfaces::filter_by_boundary_condition( gextModel.getSurfaces, ["Ground"] ) , "Adiabatic")
          #          model_array.push(gextModel)
          #
          #          # Gh - no cooling
          #          ghModel = BTAP::FileIO::deep_copy(model)
          #          thermal_zones = ghModel.getThermalZones
          #          ghModel.building.get.setAttribute("name","Gh-"  + thermal_zones[zone_number].name.get)
          #          BTAP::Site::set_weather_file(ghModel,@all_off )
          #          self.set_internal_gains_to_zero(ghModel)
          #          thermal_zones[zone_number].setThermostatSetpointDualSetpoint(@mpc_no_cooling)
          #          zone_surfaces = BTAP::Geometry::Surfaces::get_surfaces_from_thermal_zones([thermal_zones[zone_number]])
          #          BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( ghModel ,BTAP::Geometry::Surfaces::filter_by_boundary_condition( zone_surfaces, ["Surface"] ) , "Adiabatic")
          #          BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( ghModel , BTAP::Geometry::Surfaces::filter_by_boundary_condition( ghModel.getSurfaces, ["Ground"] ) , "Adiabatic")
          #          model_array.push(ghModel)
          #
          #          # Gc no heating
          #          gcModel = BTAP::FileIO::deep_copy(model)
          #          thermal_zones = gcModel.getThermalZones
          #          gcModel.building.get.setAttribute("name","Gc-" + thermal_zones[zone_number].name.get)
          #          BTAP::Site::set_weather_file(gcModel, @solar_radiation_off_temp_normal)
          #          self.set_internal_gains_to_zero(gcModel)
          #          thermal_zones[zone_number].setThermostatSetpointDualSetpoint(@mpc_no_heating)
          #          zone_surfaces = BTAP::Geometry::Surfaces::get_surfaces_from_thermal_zones([thermal_zones[zone_number]])
          #          BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gcModel ,BTAP::Geometry::Surfaces::filter_by_boundary_condition( zone_surfaces, ["Surface"] ) , "Adiabatic")
          #          BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gcModel , BTAP::Geometry::Surfaces::filter_by_boundary_condition( gcModel.getSurfaces, ["Ground"] ) , "Adiabatic")
          #          model_array.push(gcModel)

          #          # Gideal
          #          gidealModel = BTAP::FileIO::deep_copy(model)
          #          thermal_zones = gidealModel.getThermalZones
          #          gidealModel.building.get.setAttribute("name","Gideal-" + thermal_zones[zone_number].name.get)
          #          BTAP::Site::set_weather_file( gidealModel, @original_file )
          #          thermal_zones[zone_number].setThermostatSetpointDualSetpoint(@mpc_21C_setpoint)
          #          zone_surfaces = BTAP::Geometry::Surfaces::get_surfaces_from_thermal_zones([thermal_zones[zone_number]])
          #          BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gidealModel ,BTAP::Geometry::Surfaces::filter_by_boundary_condition( zone_surfaces, ["Surface"] ) , "Adiabatic")
          #          BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gidealModel , BTAP::Geometry::Surfaces::filter_by_boundary_condition( gidealModel.getSurfaces, ["Ground"] ) , "Adiabatic")
          #          model_array.push(gidealModel)
          #          
          #          # Gfloating
          #          gfloatModel = BTAP::FileIO::deep_copy(model)
          #          thermal_zones = gfloatModel.getThermalZones
          #          gfloatModel.building.get.setAttribute("name","Gfloating-" + thermal_zones[zone_number].name.get)
          #          BTAP::Site::set_weather_file(gfloatModel, @original_file)
          #          thermal_zones[zone_number].setThermostatSetpointDualSetpoint(@mpc_no_heat_cool)
          #          ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition( gfloatModel.getSurfaces, ["Ground"] )
          #          BTAP::Geometry::Surfaces::set_surfaces_boundary_condition( gfloatModel , ground_surfaces, "Adiabatic")
          #          model_array.push(gfloatModel)
          
        end
        return model_array
      end

      def set_internal_gains_to_zero(model)
        BTAP::Resources::SpaceLoads::remove_all_casual_loads(model)
      end
    end

  end
end