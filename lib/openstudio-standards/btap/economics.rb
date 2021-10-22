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


require "#{File.dirname(__FILE__)}/btap"

module BTAP
  module Resources #Resources
    # This module contains methods that relate to Materials, Constructions and Construction Sets
    module Economics

      #This method removes all costs from model
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@param runner [String]
      def self.remove_all_costs(model,runner = nil)
        #Remove all cost items.
        model.getLifeCycleCosts.sort.each  { |cost_item| cost_item.remove }
        #log change
        message = "Removed all cost objects from model"
        runner.nil? ? puts(message) : runner.registerInfo(message)
      end

      #This method will add the costs.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@param name [String]
      #@param cost [Float]
      #@param unittype [String]
      #return cost_object [OpenStudio::model::Model] A model object
      def self.object_cost(model,name,cost,unittype)
        unless cost.nil? or cost == 0.0
          #add total construction cost if used in place of each construction.
          cost_object = OpenStudio::Model::LifeCycleCost.new(model)
          cost_object.setName(name)
          cost_object.setCost(cost)
          cost_object.setCostUnits(unittype)
        end
        return cost_object
      end
      
      #This method will add the cost per building.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@param name [String]
      #@param cost [Float]
      #@param runner [Float]
      def self.add_cost_per_building(model,name,cost,runner = nil)
        #cost per building and building area
        unless cost.nil? or cost == 0.0
          cost_obj = BTAP::Resources::Economics::object_cost(model.building.get,name,cost,"CostPerEach")
          #log change
          message = "Added cost of per building named: #{name} with cost/bldg = #{cost} and handle UI =#{cost_obj.handle()}"
          runner.nil? ? puts(message) : runner.registerInfo(message)
        end
      end
      
      #This method will add the cost per total area.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@param name [String]
      #@param cost [Float]
      #@param runner [Float]
      def self.add_cost_per_total_area(model,name,cost,runner = nil)
        #cost per building and building area
        unless cost.nil? or cost == 0.0
          cost_obj = BTAP::Resources::Economics::object_cost(model.building.get,name,cost,"CostPerArea")
          #log change
          message = "Added cost of per building total area named: #{name} with cost/area = #{cost} and handle UI =#{cost_obj.handle()}"
          runner.nil? ? puts(message) : runner.registerInfo(message)
        end
      end

      #This method will set the ecm envelope.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@param library_file_path [String]
      #@param default_construction_set_name [String]
      #@param ext_wall_rsi [Float]
      #@param ext_floor_rsi [Float]
      #@param ext_roof_rsi [Float]
      #@param ground_wall_rsi [Float]
      #@param ground_floor_rsi [Float]
      #@param ground_roof_rsi [Float]
      #@param fixed_window_rsi [Float]
      #@param fixed_wind_solar_trans [Float]
      #@param fixed_wind_vis_trans [Float]
      #@param operable_window_rsi [Float]
      #@param operable_wind_solar_trans [Float]
      #@param operable_wind_vis_trans [Float]
      #@param door_construction_rsi [Float]
      #@param glass_door_rsi [Float]
      #@param glass_door_solar_trans [Float]
      #@param glass_door_vis_trans [Float]
      #@param overhead_door_rsi [Float]
      #@param skylight_rsi [Float]
      #@param skylight_solar_trans [Float]
      #@param skylight_vis_trans [Float]
      #@param tubular_daylight_dome_rsi [Float]
      #@param tubular_daylight_dome_solar_trans [Float]
      #@param tubular_daylight_dome_vis_trans [Float]
      #@param tubular_daylight_diffuser_rsi [Float]
      #@param tubular_daylight_diffuser_solar_trans [Float]
      #@param tubular_daylight_diffuser_vis_trans [Float]
      #@param ext_wall_cost_m2 [Float]
      #@param ext_floor_cost_m2 [Float]
      #@param ext_roof_cost_m2 [Float]
      #@param ground_wall_cost_m2 [Float]
      #@param ground_floor_cost_m2 [Float]
      #@param ground_roof_cost_m2 [Float]
      #@param fixed_window_cost_m2 [Float]
      #@param operable_window_cost_m2 [Float]
      #@param door_construction_cost_m2 [Float]
      #@param glass_door_cost_m2 [Float]
      #@param overhead_door_cost_m2 [Float]
      #@param skylight_cost_m2 [Float]
      #@param tubular_daylight_dome_cost_m2 [Float]
      #@param tubular_daylight_diffuser_cost_m2 [Float]
      #@param total_building_construction_set_cost [Float]
      #@param runner [Float]
      #@return [Boolean]
      def ecm_envelope( model,
          library_file_path,
          default_construction_set_name,
          ext_wall_rsi,
          ext_floor_rsi,
          ext_roof_rsi,
          ground_wall_rsi,
          ground_floor_rsi,
          ground_roof_rsi,
          fixed_window_rsi,
          fixed_wind_solar_trans,
          fixed_wind_vis_trans,
          operable_window_rsi,
          operable_wind_solar_trans,
          operable_wind_vis_trans,
          door_construction_rsi,
          glass_door_rsi,
          glass_door_solar_trans,
          glass_door_vis_trans,
          overhead_door_rsi,
          skylight_rsi,
          skylight_solar_trans,
          skylight_vis_trans,
          tubular_daylight_dome_rsi,
          tubular_daylight_dome_solar_trans,
          tubular_daylight_dome_vis_trans,
          tubular_daylight_diffuser_rsi,
          tubular_daylight_diffuser_solar_trans,
          tubular_daylight_diffuser_vis_trans,
          ext_wall_cost_m2,
          ext_floor_cost_m2,
          ext_roof_cost_m2,
          ground_wall_cost_m2,
          ground_floor_cost_m2,
          ground_roof_cost_m2,
          fixed_window_cost_m2,
          operable_window_cost_m2,
          door_construction_cost_m2,
          glass_door_cost_m2,
          overhead_door_cost_m2,
          skylight_cost_m2,
          tubular_daylight_dome_cost_m2,
          tubular_daylight_diffuser_cost_m2,
          total_building_construction_set_cost,
          runner = nil)

        unless default_construction_set_name.nil? or library_file_path.nil?

          #    #Remove all existing constructions from model.
          BTAP::Resources::Envelope::remove_all_envelope_information( model )

          #    #Load Contruction osm library.
          construction_lib = BTAP::FileIO::load_osm("#{library_file_path}")

          #Get construction set.. I/O expensive so doing it here.
          vintage_construction_set = construction_lib.getDefaultConstructionSetByName(default_construction_set_name)
          if vintage_construction_set.empty?
            #log change
            message = "Could not load contructions #{default_construction_set_name} from #{library_file_path} "
            runner.nil? ? puts(message) : runner.registerError(message)
            return false
          else
            vintage_construction_set = construction_lib.getDefaultConstructionSetByName(default_construction_set_name).get
          end

          new_construction_set =vintage_construction_set.clone(model).to_DefaultConstructionSet.get
          #Set conductances to needed values in construction set if possible.
          BTAP::Resources::Envelope::ConstructionSets::customize_default_surface_construction_set_rsi!(
              model: model,
              name: "#{default_construction_set_name}-modified",
              default_surface_construction_set: new_construction_set,
              ext_wall_rsi: ext_wall_rsi, ext_floor_rsi: ext_floor_rsi, ext_roof_rsi: ext_roof_rsi,
              ground_wall_rsi: ground_wall_rsi, ground_floor_rsi: ground_floor_rsi, ground_roof_rsi: ground_roof_rsi,
              fixed_window_rsi: fixed_window_rsi, fixed_wind_solar_trans: fixed_wind_solar_trans, fixed_wind_vis_trans: fixed_wind_vis_trans,
              operable_window_rsi: operable_window_rsi, operable_wind_solar_trans: operable_wind_solar_trans, operable_wind_vis_trans: operable_wind_vis_trans,
              door_construction_rsi: door_construction_rsi,
              glass_door_rsi: glass_door_rsi,  glass_door_solar_trans: glass_door_solar_trans, glass_door_vis_trans: glass_door_vis_trans,
              overhead_door_rsi: overhead_door_rsi,
              skylight_rsi: skylight_rsi,  skylight_solar_trans: skylight_solar_trans, skylight_vis_trans: skylight_vis_trans,
              tubular_daylight_dome_rsi: tubular_daylight_dome_rsi,  tubular_daylight_dome_solar_trans: tubular_daylight_dome_solar_trans, tubular_daylight_dome_vis_trans: tubular_daylight_dome_vis_trans,
              tubular_daylight_diffuser_rsi: tubular_daylight_diffuser_rsi, tubular_daylight_diffuser_solar_trans: tubular_daylight_diffuser_solar_trans, tubular_daylight_diffuser_vis_trans: tubular_daylight_diffuser_vis_trans
          )


          #Set as default to model.
          model.building.get.setDefaultConstructionSet( new_construction_set )

          #Set cost information.
          BTAP::Resources::Envelope::ConstructionSets::customize_default_surface_construction_set_costs(new_construction_set,
            ext_wall_cost_m2,
            ext_floor_cost_m2,
            ext_roof_cost_m2,
            ground_wall_cost_m2,
            ground_floor_cost_m2,
            ground_roof_cost_m2,
            fixed_window_cost_m2,
            operable_window_cost_m2,
            door_construction_cost_m2,
            glass_door_cost_m2,
            overhead_door_cost_m2,
            skylight_cost_m2,
            tubular_daylight_dome_cost_m2,
            tubular_daylight_diffuser_cost_m2,
            total_building_construction_set_cost
          )
          #Give adiabatic surfaces a construction. Does not matter what. This is a bug in Openstudio that leave these surfaces unassigned by the default construction set.
          all_adiabatic_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(model.getSurfaces, "Adiabatic")
          unless all_adiabatic_surfaces.empty?
            BTAP::Geometry::Surfaces::set_surfaces_construction( all_adiabatic_surfaces, model.building.get.defaultConstructionSet.get.defaultInteriorSurfaceConstructions.get.wallConstruction.get)
          end
          #log change
          message = "Changed Contructions : #{BTAP::Resources::Envelope::ConstructionSets::get_construction_set_info( new_construction_set )}"
          runner.nil? ? puts(message) : runner.registerInfo(message)
          return true
        else
          #log change
          message = "Could not load contructions #{default_construction_set_name} from #{library_file_path} "
          runner.nil? ? puts(message) : runner.registerError(message)
          return false
        end
      end
      
      #This method will set the ecm infiltration.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@param infiltration_design_flow_rate [Float]
      #@param infiltration_flow_per_space [Float]
      #@param infiltration_flow_per_exterior_area [Float]
      #@param infiltration_air_changes_per_hour [Float]
      #@param cost_per_building [Float]
      #@param cost_per_exterior_area_m2 [Float]
      #@param runner [Float]
      #@return [Boolean]
      def ecm_infiltration( model,
          infiltration_design_flow_rate,
          infiltration_flow_per_space,
          infiltration_flow_per_exterior_area,
          infiltration_air_changes_per_hour,
          cost_per_building,
          cost_per_exterior_area_m2,
          runner = nil
        )
        default_surface_construction_set = model.building.get.defaultConstructionSet.get 
        log = BTAP::Resources::SpaceLoads::ScaleLoads::set_inflitration_magnitude(
          model,
          infiltration_design_flow_rate,
          infiltration_flow_per_space,
          infiltration_flow_per_exterior_area,
          infiltration_air_changes_per_hour
        )
        #log change
        message = log 
        runner.nil? ? puts(message) : runner.registerinfo(message)
        #set costs based on all external surface type constructions. 
        constructions_and_cost = [
          ["infiltration_ext_wall_cost_m3",cost_per_exterior_area_m2, default_surface_construction_set.defaultExteriorSurfaceConstructions.get.wallConstruction.get],
          ["infiltration_ext_floor_cost_m3", cost_per_exterior_area_m2, default_surface_construction_set.defaultExteriorSurfaceConstructions.get.floorConstruction.get],
          ["infiltration_ext_roof_cost_m3",cost_per_exterior_area_m2, default_surface_construction_set.defaultExteriorSurfaceConstructions.get.roofCeilingConstruction.get],
          ["infiltration_fixed_window_cost_m3",cost_per_exterior_area_m2, default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.fixedWindowConstruction.get],
          ["infiltration_operable_window_cost_m3",cost_per_exterior_area_m2, default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.operableWindowConstruction.get],
          ["infiltration_door_construction_cost_m3",cost_per_exterior_area_m2, default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.doorConstruction.get],
          ["infiltration_glass_door_cost_m3",cost_per_exterior_area_m2, default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.glassDoorConstruction.get],
          ["infiltration_overhead_door_cost_m3",cost_per_exterior_area_m2, default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.overheadDoorConstruction.get],
          ["infiltration_skylight_cost_m3",cost_per_exterior_area_m2, default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.skylightConstruction.get],
          ["infiltration_tubular_daylight_dome_cost_m3",cost_per_exterior_area_m2, default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.tubularDaylightDomeConstruction.get],
          ["infiltration_tubular_daylight_diffuser_cost_m3" ,cost_per_exterior_area_m2 , default_surface_construction_set.defaultExteriorSubSurfaceConstructions.get.tubularDaylightDiffuserConstruction.get]
        ]
        #Assign cost to each construction.
        constructions_and_cost.each do |item|
          unless item[1].nil?
            item[2].removeLifeCycleCosts()
            raise("Could not remove LCC info from construction #{item[2]}") unless item[2].lifeCycleCosts.size == 0
            construction_cost_object = OpenStudio::Model::LifeCycleCost.new(item[2])
            construction_cost_object.setName(item[0])
            construction_cost_object.setCost(item[1])
            construction_cost_object.setCostUnits("CostPerArea")
          end
        end
        #create building total construction cost if needed.
        building = default_surface_construction_set.model.building.get
        BTAP::Resources::Economics::object_cost(building, "Infiltration Cost per building.", cost_per_building, "CostPerEach")
        return true
      end
      
      #This method will set the ecm fans.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@return [String] log
      def ecm_fans( model )
        measure_values =
          [
          "fan_total_eff",
          "fan_motor_eff",
          "fan_volume_type"
        ]
        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)
        log = ""
        unless model.getFanVariableVolumes.empty?
          log = "fan_variable_volume_name,fan_total_eff,fan_motor_eff\n"
          model.getFanVariableVolumes.sort.each do |fan|
            fan.setFanEfficiency( @fan_total_eff  ) unless @fan_total_eff.nil?
            fan.setMotorEfficiency( @fan_motor_eff  ) unless @fan_motor_eff.nil?
            log  << fan.name.get.to_s << ",#{fan.fanEfficiency},#{fan.motorEfficiency}\n"
          end
        end

        unless model.getFanConstantVolumes.empty?
          log = "fan_constant_volume_name,fan_total_eff,fan_motor_eff\n"
          model.getFanConstantVolumes.sort.each do |fan|
            fan.setFanEfficiency(  @fan_total_eff ) unless @fan_total_eff.nil?
            fan.setMotorEfficiency( @fan_motor_eff ) unless @fan_motor_eff.nil?
            log  << fan.name.get.to_s << ",#{fan.fanEfficiency},#{fan.motorEfficiency}\n"
          end
          
        end

        case @fan_volume_type

        when "VariableVolume"
          model.getFanConstantVolumes.sort.each do |fan_const|
            #check that this is indeed connected to an airloop.
            log << "Found Const Vol Fan #{fan_const.name.get.to_s}"
            unless fan_const.loop.empty?
              fan_variable = OpenStudio::Model::FanVariableVolume.new(model,fan_const.availabilitySchedule)
              #pass information from old fan as much as possible.
              fan_variable.setFanEfficiency(fan_const.fanEfficiency)
              fan_variable.setPressureRise( fan_const.pressureRise() )
              fan_variable.autosizeMaximumFlowRate
              fan_variable.setFanPowerMinimumFlowRateInputMethod("FixedFlowRate")
              fan_variable.setFanPowerMinimumFlowFraction(0.25)
              fan_variable.setMotorInAirstreamFraction( fan_const.motorInAirstreamFraction() )
              fan_variable.setFanPowerCoefficient1(0.35071223)
              fan_variable.setFanPowerCoefficient2(0.30850535)
              fan_variable.setFanPowerCoefficient3(-0.54137364)
              fan_variable.setFanPowerCoefficient4(0.87198823)

              #get the airloop.
              air_loop = fan_const.loop.get
              #add the FanVariableVolume
              fan_variable.addToNode(air_loop.supplyOutletNode())
              #Remove FanConstantVolume
              fan_const.remove()
              log << "Replaced by Variable Vol Fan #{fan_variable.name.get.to_s}"
            end
          end
        when "ConstantVolume"
          model.getFanVariableVolumes.sort.each do |fan|
            #check that this is indeed connected to an airloop.
            log << "Found Const Vol Fan #{fan.name.get.to_s}"
            unless fan.loop.empty?
              new_fan = OpenStudio::Model::FanConstantVolume.new(model,fan.availabilitySchedule)
              #pass information from constant speed fan as much as possible.
              new_fan.setFanEfficiency(fan.fanEfficiency)
              new_fan.setPressureRise( fan.pressureRise() )
              new_fan.setMotorEfficiency(fan.motorEfficiency)
              new_fan.setMotorInAirstreamFraction( fan.motorInAirstreamFraction() )
              new_fan.autosizeMaximumFlowRate
              #get the airloop.
              air_loop = fan.loop.get
              #add the FanVariableVolume
              new_fan.addToNode(air_loop.supplyOutletNode())
              #Remove FanConstantVolume
              fan.remove()
              log << "Replaced by Constant Vol Fan #{new_fan.name.get.to_s}"
            end
          end
        when nil
          log << "No changes to Fan."
        else
          raise("fan_volume_type should be ConstantVolume or VariableVolume")
        end
        return log
      end
      
      
      #This method will set the ecm pumps.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@return [String] log
      def ecm_pumps( model )
        measure_values =
          [
          "pump_motor_eff",
          "pump_control_type",
          "pump_speed_type"
        ]
        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)
        log = ""
        unless model.getPumpVariableSpeeds.empty?
          log = "pump_variable_speed_name,@pump_motor_eff\n"
          model.getPumpVariableSpeeds.sort.each do |pump|
            pump.setMotorEfficiency( @pump_motor_eff.to_f ) unless @pump_motor_eff.nil?
            pump.setPumpControlType( @pump_control_type ) unless @pump_control_type.nil?
            log  << pump.name.get.to_s << ",#{pump.motorEfficiency}\n"
          end
        end
        unless model.getPumpConstantSpeeds.empty?
          log << "pump_variable_speed_name,@pump_motor_eff\n"
          model.getPumpConstantSpeeds.sort.each do |pump|
            pump.setMotorEfficiency( @pump_motor_eff.to_f  ) unless @pump_motor_eff.nil?
            pump.setPumpControlType( @pump_control_type ) unless @pump_control_type.nil?
            log  << pump.name.get.to_s << ",#{pump.motorEfficiency}\n"
          end
        end

        #set pump speed type based on existing pump.
        case @pump_speed_type
        when "VariableSpeed"
          model.getPumpConstantSpeeds.sort.each do |pump_const|
            log << "Found Const Vol Fan #{pump_const.name.get.to_s}"
            #check that this is indeed connected to an plant loop.
            unless pump_const.plantLoop.empty?
              pump_variable = OpenStudio::Model::PumpVariableSpeed.new(model)
              #pass information from constant speed fan as much as possible.
              pump_variable.setRatedFlowRate(pump_const.ratedFlowRate.get)
              pump_variable.setRatedPumpHead(pump_const.ratedPumpHead)
              pump_variable.setRatedPowerConsumption(pump_const.ratedPowerConsumption.to_f)
              pump_variable.setMotorEfficiency(pump_const.motorEfficiency.to_f)
              pump_variable.setPumpControlType(pump_const.pumpControlType)
              pump_variable.setFractionofMotorInefficienciestoFluidStream(pump_const.fractionofMotorInefficienciestoFluidStream.to_f)
              pump_variable.autosizeRatedFlowRate if pump_const.isRatedFlowRateAutosized
              pump_variable.autosizeRatedPowerConsumption if pump_const.isRatedPowerConsumptionAutosized

              #get the hot water loop.
              hw_loop = pump_const.plantLoop.get
              #Remove PumpConstantSpeed
              pump_const.remove()
              #add
              pump_variable.addToNode(hw_loop.supplyInletNode)
              log << "Replaced by Variable Vol Pump #{pump_variable.name.get.to_s}"
            end
          end #end loop PumpConstantSpeeds
        when "ConstantSpeed"
          model.getPumpVariableSpeeds.sort.each do |pump|
            log << "Found Variable Speed Pump #{pump.name.get.to_s}"
            #check that this is indeed connected to an plant loop.
            unless pump.plantLoop.empty?
              new_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
              #pass information from constant speed fan as much as possible.

              new_pump.setRatedFlowRate(pump.ratedFlowRate.get)
              new_pump.setRatedPumpHead(pump.ratedPumpHead)
              new_pump.setRatedPowerConsumption(pump.ratedPowerConsumption.to_f)
              new_pump.setMotorEfficiency(pump.motorEfficiency.to_f)
              new_pump.setFractionofMotorInefficienciestoFluidStream(pump.fractionofMotorInefficienciestoFluidStream.to_f)
              new_pump.setPumpControlType(pump.pumpControlType)
              new_pump.autosizeRatedFlowRate if pump.isRatedFlowRateAutosized
              new_pump.autosizeRatedPowerConsumption if pump.isRatedPowerConsumptionAutosized
              #get the hot water loop.
              hw_loop = pump.plantLoop.get
              #Remove PumpVariableSpeed
              pump.remove()
              #add the pump to loop.
              new_pump.addToNode(hw_loop.supplyInletNode)

              log << "Replaced by constant speed Pump #{new_pump.name.get.to_s}"
            end
          end #end loop Pump variable Speeds
        when nil
          log << "No changes"
        else
          raise( "pump_speed_type field is not ConstantSpeed or VariableSpeed" )
        end

        #Create sample csv file.
        CSV.open("#{@script_root_folder_path}/sample_pump_eff_ecm.csv", 'w') { |csv| csv << measure_values.unshift("measure_id") }
        return log
      end
      
      #This method will set the ecm cooling COP.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      def ecm_cooling_cop( model )
        log = ""
        measure_values =[
          "cop"
        ]

        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)

        unless model.getCoilCoolingDXSingleSpeeds.empty?
          log = "coil_cooling_dx_single_speed_name,cop\n"
          model.getCoilCoolingDXSingleSpeeds.sort.each do |cooling_coil|
            cooling_coil.setRatedCOP( OpenStudio::OptionalDouble.new( @cop ) ) unless @cop.nil?
            cop = "NA"
            cop = cooling_coil.ratedCOP.get unless cooling_coil.ratedCOP.empty?
            log  << cooling_coil.name.get.to_s << ",#{cop}\n"

          end
        end

        unless model.getCoilCoolingDXTwoSpeeds.empty?
          log << "coil_cooling_dx_two_speed_name,cop\n"
          model.getCoilCoolingDXTwoSpeeds.sort.each do |cooling_coil|
            cooling_coil.setRatedHighSpeedCOP( @cop  ) unless @cop.nil?
            cooling_coil.setRatedLowSpeedCOP(  @cop  ) unless @cop.nil?
            cop_high = "NA"
            cop_high = cooling_coil.ratedHighSpeedCOP.get unless cooling_coil.ratedHighSpeedCOP.empty?
            cop_low = "NA"
            cop_low = cooling_coil.ratedLowSpeedCOP.get unless cooling_coil.ratedLowSpeedCOP.empty?
            log  << cooling_coil.name.get.to_s << ",#{cop_high},#{cop_low}\n"
          end
        end
        return log
      end
      
      #This method will set the ecm economizers.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@return [String] log
      def ecm_economizers( model )

        measure_values =[
          "economizer_control_type",
          "economizer_control_action_type",
          "economizer_maximum_limit_dry_bulb_temperature",
          "economizer_maximum_limit_enthalpy",
          "economizer_maximum_limit_dewpoint_temperature",
          "economizer_minimum_limit_dry_bulb_temperature"        ]

        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)
        log = ""
        unless @economizer_control_type.nil?
          log << BTAP::Resources::HVAC::enable_economizer(
            model,
            @economizer_control_type,
            @economizer_control_action_type,
            @economizer_maximum_limit_dry_bulb_temperature,
            @economizer_maximum_limit_enthalpy,
            @economizer_maximum_limit_dewpoint_temperature,
            @economizer_minimum_limit_dry_bulb_temperature
          )

        end
        return log
      end
      #This method will set the ecm sizing.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@return [String] table
      def ecm_sizing( model)
        measure_values =[
          "heating_sizing_factor",
          "cooling_sizing_factor",
          "zone_heating_sizing_factor",
          "zone_cooling_sizing_factor"
        ]

        table = "*Sizing Factor Measure*"
        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)
        table = "handle,heating_sizing_factor,cooling_sizing_factor\n"
        #Sizing Parameters

        model.getSizingParameters.setHeatingSizingFactor(@heating_sizing_factor) unless @heating_sizing_factor.nil?
        model.getSizingParameters.setCoolingSizingFactor(@cooling_sizing_factor) unless @cooling_sizing_factor.nil?


        #SizingZone
        table << "handle,zone_heating_sizing_factor,zone_cooling_sizing_factor\n"
        model.getSizingZones.sort.each do |item|
          item.setZoneHeatingSizingFactor(@zone_heating_sizing_factor) unless @zone_heating_sizing_factor.nil?
          item.setZoneCoolingSizingFactor(@zone_cooling_sizing_factor) unless @zone_cooling_sizing_factor.nil?
          table  << "#{item.handle},#{item.zoneHeatingSizingFactor.get},#{item.zoneCoolingSizingFactor.get}\n"
        end
        #Create sample csv file.
        CSV.open("#{@script_root_folder_path}/sample_sizing_param_ecm.csv", 'w') { |csv| csv << measure_values.unshift("measure_id") }
        return table
      end
      
      #This method will set the ecm domestic hot water.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@return [String] log
      def ecm_dhw( model )
        log = "shw_setpoint_sched,shw_heater_fuel_type,shw_thermal_eff\n"
        measure_values =[
          "shw_setpoint_sched_name",
          "shw_heater_fuel_type",
          "shw_thermal_eff"
        ]
        log = "*SHW Measures*\n"
        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)

        #Create Schedule
        #schedule = BTAP::Resources::Schedules::create_annual_ruleset_schedule_detailed_json(model, @shw_setpoint_sched) unless @shw_setpoint_sched_name.nil? or @shw_setpoint_sched.nil?

        #iterate through water heaters.
        model.getWaterHeaterMixeds.sort.each do |item|
          unless @shw_setpoint_sched_name.nil? or @shw_setpoint_sched.nil?
            item.setSetpointTemperatureSchedule(schedule)
          end
          item.setHeaterFuelType(@shw_heater_fuel_type) unless @shw_heater_fuel_type.nil?
          item.setHeaterThermalEfficiency(@shw_thermal_eff) unless @shw_thermal_eff.nil?
          log  << item.name.get.to_s << ",#{item.setpointTemperatureSchedule},#{item.heaterFuelType},#{item.heaterThermalEfficiency}\n"
        end
        return log
      end
      
      #This method will set the ecm chotwater boilers.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@return [String] table
      def ecm_hotwater_boilers( model )
        measure_values = [
          "hw_boiler_design_water_outlet_temperature",
          "hw_boiler_fuel_type",
          "hw_boiler_thermal_eff",
          "hw_boiler_curve",
          "hw_boiler_flow_mode",#
          "hw_boiler_eff_curve_temp_eval_var",#
          "hw_boiler_reset_highsupplytemp" ,
          "hw_boiler_reset_outsidehighsupplytemp" ,
          "hw_boiler_reset_lowsupplytemp" ,
          "hw_boiler_reset_outsidelowsupplytemp" ,
        ]

        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)
        table = "name,boiler_design_water_outlet_temperature,boiler_fuel_type,boiler_thermal_eff\n"

        model.getPlantLoops.sort.each do |iplantloop|
          iplantloop.components.each do |icomponent|
            if icomponent.to_BoilerHotWater.is_initialized
              boiler = icomponent.to_BoilerHotWater.get

              #set design outlet temp
              if model.version < OpenStudio::VersionString.new('3.0.0')
                boiler.setDesignWaterOutletTemperature(@hw_boiler_design_water_outlet_temperature) unless @hw_boiler_design_water_outlet_temperature.nil?
              end
              #set fuel type
              boiler.setFuelType(@hw_boiler_fuel_type) unless @hw_boiler_fuel_type.nil?
              #set thermal eff
              boiler.setNominalThermalEfficiency(@hw_boiler_thermal_eff) unless @hw_boiler_thermal_eff.nil?
              #set boiler flow mode
              unless @hw_boiler_flow_mode.nil?
                ["ConstantFlow","LeavingSetpointModulated","NotModulated"].include?(@hw_boiler_flow_mode) ? boiler.setBoilerFlowMode(@hw_boiler_flow_mode) : raise("Boiler flow mode #{@hw_boiler_flow_mode} invalid.")
              end
              #set setDesignWaterOutletTemperature
              if model.version < OpenStudio::VersionString.new('3.0.0')
                boiler.setDesignWaterOutletTemperature(@hotwaterboiler_reset_highsupplytemp) unless @hotwaterboiler_reset_highsupplytemp.nil?
              end
              #set EfficiencyCurveTemperatureEvaluationVariable
              unless @hw_boiler_eff_curve_temp_eval_var.nil?
                ["LeavingBoiler","EnteringBoiler"].include?(@hw_boiler_eff_curve_temp_eval_var) ? boiler.setEfficiencyCurveTemperatureEvaluationVariable(@hw_boiler_eff_curve_temp_eval_var) : raise("EfficiencyCurveTemperatureEvaluationVariable  #{@hw_boiler_eff_curve_temp_eval_var} invalid.")
              end


              #Set boiler curve
              curve = boiler.normalizedBoilerEfficiencyCurve
              if not @hw_boiler_curve.nil? and curve.is_initialized and curve.get.to_CurveBiquadratic.is_initialized
                case @hw_boiler_curve.downcase
                when  "atmospheric"
                  biqcurve = curve.get.to_CurveBiquadratic.get
                  biqcurve.setCoefficient1Constant(1.057059)
                  biqcurve.setCoefficient1Constant(1.057059)
                  biqcurve.setCoefficient2x(-0.0774177)
                  biqcurve.setCoefficient3xPOW2(0.07875142)
                  biqcurve.setCoefficient4y(0.0003943856)
                  biqcurve.setCoefficient5yPOW2(-0.000004074629)
                  biqcurve.setCoefficient6xTIMESY(-0.002202606)
                  biqcurve.setMinimumValueofx(0.3)
                  biqcurve.setMaximumValueofx(1.0)
                  biqcurve.setMinimumValueofy(40.0)
                  biqcurve.setMaximumValueofy(90.0)
                  biqcurve.setMinimumCurveOutput(0.0)
                  biqcurve.setMaximumCurveOutput(1.1)
                  biqcurve.setInputUnitTypeforX("Dimensionless")
                  biqcurve.setInputUnitTypeforY("Temperature")
                  biqcurve.setOutputUnitType("Dimensionless")
                when  "condensing"
                  biqcurve = curve.get.to_CurveBiquadratic.get
                  biqcurve.setCoefficient1Constant(0.4873)
                  biqcurve.setCoefficient2x(1.1322)
                  biqcurve.setCoefficient3xPOW2(-0.6425)
                  biqcurve.setCoefficient4y(0.0)
                  biqcurve.setCoefficient5yPOW2(0.0)
                  biqcurve.setCoefficient6xTIMESY(0.0)
                  biqcurve.setMinimumValueofx(0.1)
                  biqcurve.setMaximumValueofx(1.0)
                  biqcurve.setMinimumValueofy(0.0)
                  biqcurve.setMaximumValueofy(0.0)
                  biqcurve.setMinimumCurveOutput(0.0)
                  biqcurve.setMaximumCurveOutput(1.0)
                  biqcurve.setInputUnitTypeforX("Dimensionless")
                  biqcurve.setInputUnitTypeforY("Temperature")
                  biqcurve.setOutputUnitType("Dimensionless")
                else
                  raise("#{@hotwaterboiler_curve} is not a valid boiler curve name (condensing_boiler_curve,atmospheric_boiler_curve")
                end
              end

              #boiler reset setpoint manager
              unless @hotwaterboiler_reset_lowsupplytemp.nil? and @hotwaterboiler_reset_outsidelowsupplytemp.nil? and @hotwaterboiler_reset_highsupplytemp.nil? and @hotwaterboiler_reset_outsidehighsupplytemp.nil?
                #check if setpoint manager is present at supply outlet
                #Find any setpoint manager if it exists and outlet node and remove it.
                iplantloop.supplyOutletNode.setpointManagers.each {|sm| sm.disconnect}

                #Add new setpoint manager
                oar_stpt_manager = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
                oar_stpt_manager.addToNode(iplantloop.supplyOutletNode)
                oar_stpt_manager.setSetpointatOutdoorHighTemperature(@hw_boiler_reset_lowsupplytemp) unless @hw_boiler_reset_lowsupplytemp.nil?
                oar_stpt_manager.setOutdoorHighTemperature(@hotwaterboiler_reset_outsidelowsupplytemp) unless @hw_boiler_reset_outsidelowsupplytemp.nil?
                oar_stpt_manager.setSetpointatOutdoorLowTemperature(@hw_boiler_reset_highsupplytemp) unless @hw_boiler_reset_highsupplytemp.nil?
                oar_stpt_manager.setOutdoorLowTemperature(@hw_boiler_reset_outsidehighsupplytemp) unless @hw_boiler_reset_outsidehighsupplytemp.nil?
              end
              table  << boiler.name.get.to_s << ","
              boiler.designWaterOutletTemperature.empty? ? dowt = "NA" : dowt = boiler.designWaterOutletTemperature.get
              table << "#{dowt},#{boiler.fuelType},#{boiler.nominalThermalEfficiency}\n"
            end
          end
        end #end boilers loop
        return table
      end
      
      #This method will set the ecm dcv.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@return [String] log
      def ecm_dcv( model )
        log = ""
        measure_values =[
          "dcv_enabled"
        ]
        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)
        unless @dcv_enabled.nil?
          log = BTAP::Resources::HVAC::enable_demand_control_ventilation(model,@dcv_enabled.to_bool)
        end
        return log
      end
      
      #This method will set the ecm heating and cooling setpoints.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@return [String] log
      def ecm_heating_cooling_setpoints(model)

        log = ""
        measure_values =[
          "library_file",
          "heating_schedule_name",
          "cooling_schedule_name"
        ]
        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)

        library_file = @library_file
        heating_schedule_name = @heating_schedule_name
        cooling_schedule_name = @cooling_schedule_name

        unless @heating_schedule_name.nil? and @cooling_schedule_name.nil?
          #Load Contruction osm library.
          lib = BTAP::FileIO::load_osm("#{@script_root_folder_path}/#{library_file}")

          unless heating_schedule_name.nil?
            #Get heating schedule from library and clone it.
            heating_schedule = lib.getScheduleRulesetByName(heating_schedule_name)
            if heating_schedule.empty?
              raise("#{heating_schedule_name} does not exist in #{library_file} library ")
            else
              heating_schedule =  lib.getScheduleRulesetByName(heating_schedule_name).get.clone(model).to_ScheduleRuleset.get
            end
          end

          unless cooling_schedule_name.nil?
            #Get cooling schedule from library and clone it.
            cooling_schedule = lib.getScheduleRulesetByName(cooling_schedule_name)
            if cooling_schedule.empty?
              raise("#{cooling_schedule_name} does not exist in #{library_file} library ")
            else
              cooling_schedule =  lib.getScheduleRulesetByName(cooling_schedule_name).get.clone(model).to_ScheduleRuleset.get
            end
          end
          model.getThermostatSetpointDualSetpoints.sort.each do |dual_setpoint|
            unless heating_schedule_name.nil?
              raise ("Could not set heating Schedule") unless dual_setpoint.setHeatingSetpointTemperatureSchedule(heating_schedule)
            end
            unless cooling_schedule_name.nil?
              raise ("Could not set cooling Schedule") unless dual_setpoint.setCoolingSetpointTemperatureSchedule(cooling_schedule)
            end
          end
        end
        return log
      end
      
      #This method will set the ecm erv.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@return [String] log
      def ecm_erv( model )
        log = ""
        measure_values =[
          "erv_enabled",
          "erv_autosizeNominalSupplyAirFlowRate",
          "erv_NominalSupplyAirFlowRate",
          "erv_HeatExchangerType",
          "erv_SensibleEffectivenessat100CoolingAirFlow",
          "erv_SensibleEffectivenessat75CoolingAirFlow",
          "erv_LatentEffectiveness100Cooling",
          "erv_LatentEffectiveness75Cooling",
          "erv_SensibleEffectiveness100Heating",
          "erv_SensibleEffectiveness75Heating",
          "erv_LatentEffectiveness100Heating",
          "erv_LatentEffectiveness75Heating",
          "erv_SupplyAirOutletTemperatureControl",
          "erv_setFrostControlType",
          "erv_ThresholdTemperature",
          "erv_InitialDefrostTimeFraction",
          "erv_nominal_electric_power",
          "erv_economizer_lockout"
        ]

        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)


        unless  @erv_enabled.nil? or @erv_enabled.to_bool == false
          BTAP::Resources::HVAC::enable_erv(
            model,
            @erv_autosizeNominalSupplyAirFlowRate,
            @erv_NominalSupplyAirFlowRate,
            @erv_HeatExchangerType,
            @erv_SensibleEffectivenessat100CoolingAirFlow,
            @erv_SensibleEffectivenessat75CoolingAirFlow,
            @erv_LatentEffectiveness100Cooling,
            @erv_LatentEffectiveness75Cooling,
            @erv_SensibleEffectiveness100Heating,
            @erv_SensibleEffectiveness75Heating,
            @erv_LatentEffectiveness100Heating,
            @erv_LatentEffectiveness75Heating,
            @erv_SupplyAirOutletTemperatureControl.to_bool,
            @erv_setFrostControlType,
            @erv_ThresholdTemperature,
            @erv_InitialDefrostTimeFraction,
            @erv_nominal_electric_power,
            @erv_economizer_lockout.to_bool
          ).each { |erv| log << erv.to_s }
          
          
          #Add setpoint manager to all OA object in airloops.
          model.getHeatExchangerAirToAirSensibleAndLatents.sort.each do |erv|

            #needed to get the supply outlet node from the erv to place the setpoint manager.
            node =  erv.primaryAirOutletModelObject.get.to_Node.get if erv.primaryAirOutletModelObject.is_initialized
            new_set_point_manager = OpenStudio::Model::SetpointManagerWarmest.new(model)
            raise ("Could not add setpoint manager") unless new_set_point_manager.addToNode(node)
            log << "added warmest control to node #{node}"
            new_set_point_manager.setMaximumSetpointTemperature(16.0)
            new_set_point_manager.setMinimumSetpointTemperature(5.0)
            new_set_point_manager.setStrategy("MaximumTemperature")
            new_set_point_manager.setControlVariable("Temperature")
          end
          log << "ERV have been modified.\n"
        else
          log << "ERV not changed."
        end
        return log
      end
      
      #This method will set the ecm cexhaust fans.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@return [String] log
      def ecm_exhaust_fans( model )
        log = ""
        #Exhaust ECM
        measure_values =[
          "exhaust_fans_occ_control_enabled"
        ]
        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)
        unless @exhaust_fans_occ_control_enabled.nil? or @exhaust_fans_occ_control_enabled.to_bool == false
          fans = BTAP::Resources::Schedules::set_exhaust_fans_availability_to_building_default_occ_schedule(model)
          fans.each { |fan| log << fan.to_s}
        else
          log << "No changes to exhaust fans."
        end
        return log
      end
      
      #This method will set the ecm lighting.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@return [String] log
      def ecm_lighting( model )
        log = ""
        #Lighting ECM
        measure_values =[
          "lighting_scaling_factor",
          "lighting_fraction_radiant",
          "lighting_fraction_visible",
          "lighting_return_air_fraction"
        ]
        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)
        BTAP::Resources::SpaceLoads::ScaleLoads::scale_lighting_loads(
          model,
          @lighting_scaling_factor ) unless @lighting_scaling_factor.nil?
        #Set lighting variables
        model.getLightsDefinitions.sort.each do |lightsdef|
          lightsdef.setFractionRadiant(@lighting_fraction_radiant.to_f)
          lightsdef.setFractionVisible(@lighting_fraction_visible.to_f)
          lightsdef.setReturnAirFraction(@lighting_return_air_fraction.to_f)
        end
        return log
      end
      
      #This method will set the ecm temperature setback.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@return [String] log
      def ecm_plugs( model )
        log = ""
        #Plug loads ECM
        measure_values = [
          "elec_equipment_scaling_factor",
          "elec_equipment_fraction_radiant",
          "elec_equipment_fraction_latent",
          "elec_equipment_fraction_lost"
        ]
        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)

        BTAP::Resources::SpaceLoads::ScaleLoads::scale_electrical_loads(
          model,
          @elec_equipment_scaling_factor) unless @elec_equipment_scaling_factor.nil?

        #Set plug loads variables
        model.getElectricEquipmentDefinitions.sort.each do |elec_equip_def|
          elec_equip_def.setFractionRadiant(@elec_equipment_fraction_radiant.to_f)
          elec_equip_def.setFractionLatent(@elec_equipment_fraction_latent.to_f)
          elec_equip_def.setFractionLost(@elec_equipment_fraction_lost.to_f)
        end

        CSV.open("#{@script_root_folder_path}/sample_scale_plug_loads_ecm.csv", 'w') { |csv| csv << measure_values.unshift("measure_id") }
        return log
      end
      
      #This method will set the ecm cold deck reset control.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@return [String] log
      def ecm_cold_deck_reset_control( model )
        log = ""
        measure_values = [
          "cold_deck_reset_enabled",
          "cold_deck_reset_max_supply_air_temp",
          "cold_deck_reset_min_supply_air_temp",
        ]
        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)

        if @cold_deck_reset_enabled.to_bool == true

          model.getAirLoopHVACs.sort.each do |iairloop|
            cooling_present = false
            set_point_manager = nil
            iairloop.components.each do |icomponent|
              if icomponent.to_CoilCoolingDXSingleSpeed.is_initialized or
                  icomponent.to_CoilCoolingDXTwoSpeed.is_initialized   or
                  icomponent.to_CoilCoolingWater.is_initialized or
                  icomponent.to_CoilCoolingCooledBeam.is_initialized  or
                  icomponent.to_CoilCoolingDXMultiSpeed.is_initialized  or
                  icomponent.to_CoilCoolingDXVariableRefrigerantFlow.is_initialized  or
                  icomponent.to_CoilCoolingLowTempRadiantConstFlow.is_initialized  or
                  icomponent.to_CoilCoolingLowTempRadiantVarFlow.is_initialized
                cooling_present = true
                log << "found cooling."
              end
            end
            #check if setpoint manager is present at supply outlet.
            model.getSetpointManagerSingleZoneReheats.sort.each do |manager|
              if iairloop.supplyOutletNode == manager.setpointNode.get
                set_point_manager = manager
              end
            end

            if set_point_manager.nil? and cooling_present == true
              set_point_manager = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
              set_point_manager.addToNode(iairloop.supplyOutletNode)
            end



            if cooling_present == true and not set_point_manager.nil?
              set_point_manager.setMaximumSupplyAirTemperature(@cold_deck_reset_max_supply_air_temp)
              set_point_manager.setMinimumSupplyAirTemperature(@cold_deck_reset_min_supply_air_temp)
              log << "to_SetpointManagerSingleZoneReheat set to 20.0 and 13.0"
            end
          end
        end
        return log
      end
      
      #This method will reset the sat ecm.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@return [String] log
      def ecm_sat_reset( model )
        log = ""
        measure_values = [
          "sat_reset_enabled",
          "sat_reset_outdoor_high_temperature",
          "sat_reset_outdoor_low_temperature",
          "sat_reset_setpoint_at_outdoor_high_temperature",
          "sat_reset_setpoint_at_outdoor_low_temperature"
        ]


        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)
        if @sat_reset_enabled.to_bool == true
          model.getAirLoopHVACs.sort.each do |iairloop|

            #check if setpoint manager is present at supply outlet
            model.getSetpointManagerSingleZoneReheats.sort.each do |manager|
              if iairloop.supplyOutletNode == manager.setpointNode.get
                manager.disconnect
              end
            end

            new_set_point_manager = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
            new_set_point_manager.addToNode(iairloop.supplyOutletNode)
            new_set_point_manager.setOutdoorHighTemperature(@sat_reset_outdoor_high_temperature)
            new_set_point_manager.setOutdoorLowTemperature(@sat_reset_outdoor_low_temperature)
            new_set_point_manager.setSetpointatOutdoorHighTemperature(@sat_reset_setpoint_at_outdoor_high_temperature)
            new_set_point_manager.setSetpointatOutdoorLowTemperature(@sat_reset_setpoint_at_outdoor_low_temperature)
            new_set_point_manager.setControlVariable("Temperature")
            log << "Replaced SingleZoneReheat with OA reset control."
          end
        end
        return log
      end
      
      #This method will set the ecm temperature setback.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@return [String] log
      def ecm_temp_setback( model )
        log = ""
        measure_values = [
          "occ_stbck_enabled",
          "occ_stbck_tolerance",
          "occ_stbck_heat_setback",
          "occ_stbck_heat_setpoint",
          "occ_stbck_cool_setback",
          "occ_stbck_cool_setpoint"
        ]
        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)
        # get occupancy schedule if possible.
        unless @occ_stbck_enabled.nil? or @occ_stbck_enabled == false
          if  model.building.get.defaultScheduleSet.is_initialized and
              model.building.get.defaultScheduleSet.get.numberofPeopleSchedule.is_initialized and
              model.building.get.defaultScheduleSet.get.numberofPeopleSchedule.get.to_ScheduleRuleset.is_initialized
            occupancy_schedule = model.building.get.defaultScheduleSet.get.numberofPeopleSchedule.get
            heating_schedule,cooling_schedule  = BTAP::Resources::Schedules::create_setback_schedule_based_on_another_schedule(
              model,
              occupancy_schedule,
              @occ_stbck_tolerance.to_f,
              @occ_stbck_heat_setpoint.to_f,
              @occ_stbck_heat_setback.to_f,
              @occ_stbck_cool_setpoint.to_f,
              @occ_stbck_cool_setback.to_f)
            model.getThermostatSetpointDualSetpoints.sort.each do |dual_setpoint|
              raise ("Could not set setback heating Schedule") unless dual_setpoint.setHeatingSetpointTemperatureSchedule(heating_schedule)
              raise ("Could not set setback cooling Schedule") unless dual_setpoint.setCoolingSetpointTemperatureSchedule(cooling_schedule)
              log << "modified....#{dual_setpoint}"
            end
          end
        else
          log << "no change to setbacks."
        end
        return log
      end  
    end
  end #module Resources
end #module BTAP




#"Construction"
#  "CostPerArea"
#"Building"
#  "CostPerEach"
#  "CostPerArea"
#  "CostPerThermalZone"
#"Space
#"CostPerEach"
#"CostPerArea"
#"ThermalZone"
#"CostPerEach"
#"CostPerArea"
#"AirLoop"
#"CostPerEach"
#"CostPerThermalZone"
#"PlantLoop"
#"CostPerEach"
#"ZoneHVAC"
#"CostPerEach"
#"Lights
#  "CostPerEach"
#  "CostPerArea"
#"Luminaire
#"CostPerEach"
#"Equipment
#  "CostPerEach"
#  "CostPerArea"
#"HVACComponent
#"CostPerEach"
#"ZoneHVACComponent
#  "CostPerEach"
#All others
#"CostPerEach"