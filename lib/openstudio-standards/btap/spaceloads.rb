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

    module SpaceLoads # BTAP::Resources::SpaceLoads
      #Not sure if we need this.


      #Test SpaceLoads Module
      if __FILE__ == $0
        require 'test/unit'
        class SpaceLoadsTests < Test::Unit::TestCase

          #This method will test the creation of all loads.
          #@author phylroy.lopez@nrcan.gc.ca
          def test_create_all_loads()
            model = OpenStudio::Model::Model.new()
            people =  BTAP::Resources::SpaceLoads::create_people_load(model,"people_load_test")
            lights = BTAP::Resources::SpaceLoads::create_lighting_load(model,"lights_load_test")
            electric = BTAP::Resources::SpaceLoads::create_electric_load(model,"electric_load_test")
            hotwater = BTAP::Resources::SpaceLoads::create_hotwater_load(model,"hotwater_load_test")
            oa_load = BTAP::Resources::SpaceLoads::create_oa_load(model,"oa_load_test")
            infiltration_load = BTAP::Resources::SpaceLoads::create_infiltration_load(model,"infiltration_load_test")
            #Check to see if the objects were really created.
            assert( !(people.to_People.empty?))
            assert( !(lights.to_Lights.empty?))
            assert( !(electric.to_ElectricEquipment.empty?))
            assert( !(hotwater.to_HotWaterEquipment.empty?))
            assert( !(oa_load.to_DesignSpecificationOutdoorAir.empty?))
            assert( !(infiltration_load.to_SpaceInfiltrationDesignFlowRate.empty?))

          end
        end
      end # End Test SpaceLoads



      module ScaleLoads

        #This method will scale people loads.
        #@author phylroy.lopez@nrcan.gc.ca
        #@param model [OpenStudio::model::Model] A model object 
        #@param factor [Float]
        def self.scale_people_loads( model, factor )
          model.getPeoples.sort.each do |item|
            item.setMultiplier( item.multiplier * factor )
          end
        end
        
        #This method will scale people loads schedule.
        #@author phylroy.lopez@nrcan.gc.ca
        #@param model [OpenStudio::model::Model] A model object 
        #@param a_coef [Float]
        #@param b_coef [Float]
        #@param c_coef [Float]
        #@param time_shift [Float]
        #@param time_sign [Float]
        def self.scale_people_loads_schedule( model, a_coef, b_coef, c_coef,time_shift = nil, time_sign = nil  )
          model.getPeoples.sort.each do |item|
            #Do an in-place modification of the schedule. 
            BTAP::Resources::Schedules::modify_schedule!(model, item.schedule, a_coef, b_coef, c_coef, time_shift, time_sign )
          end
        end

        #This method will scale lighting loads.
        #@author phylroy.lopez@nrcan.gc.ca
        #@param model [OpenStudio::model::Model] A model object 
        #@param factor [Float]
        def self.scale_lighting_loads( model, factor )
          model.getLightss.sort.each do |item|
            item.setMultiplier( item.multiplier * factor )
          end
        end
        
        #This method will scale lighting loads schedule.
        #@author phylroy.lopez@nrcan.gc.ca
        #@param model [OpenStudio::model::Model] A model object 
        #@param a_coef [Float]
        #@param b_coef [Float]
        #@param c_coef [Float]
        #@param time_shift [Float]
        #@param time_sign [Float]
        def self.scale_lighting_loads_schedule( model, a_coef, b_coef, c_coef,time_shift = nil, time_sign = nil  )
          model.getLightss.sort.each do |item|
            #Do an in-place modification of the schedule. 
            BTAP::Resources::Schedules::modify_schedule!(model, item.schedule, a_coef, b_coef, c_coef, time_shift, time_sign)
          end
        end

        #This method will scale electrical loads.
        #@author phylroy.lopez@nrcan.gc.ca
        #@param model [OpenStudio::model::Model] A model object 
        #@param factor [Float]
        def self.scale_electrical_loads( model, factor )
          model.getElectricEquipments.sort.each do |item|
            item.setMultiplier( item.multiplier * factor )
          end
        end

        #This method will scale electrical loads schedule.
        #@author phylroy.lopez@nrcan.gc.ca
        #@param model [OpenStudio::model::Model] A model object 
        #@param a_coef [Float]
        #@param b_coef [Float]
        #@param c_coef [Float]
        #@param time_shift [Float]
        #@param time_sign [Float]
        def self.scale_electrical_loads_schedule( model, a_coef, b_coef, c_coef,time_shift = nil, time_sign = nil  )
          model.getElectricEquipments.sort.each do |item|
            BTAP::Resources::Schedules::modify_schedule!(model, item.schedule, a_coef, b_coef, c_coef, time_shift, time_sign )
          end
        end

        #This method will scale hotwater loads.
        #@author phylroy.lopez@nrcan.gc.ca
        #@param model [OpenStudio::model::Model] A model object 
        #@param factor [Float]
        def self.scale_hot_water_loads( model, factor )
          model.getHotWaterEquipments.sort.each do |item|
            item.setMultiplier( item.multiplier * factor )
          end
        end

        #This method will scale Outdoor Air loads.
        #@author phylroy.lopez@nrcan.gc.ca
        #@param model [OpenStudio::model::Model] A model object 
        #@param factor [Float]
        def self.scale_oa_loads( model, factor )
          model.getDesignSpecificationOutdoorAirs.sort.each do |oa_def|
            oa_def.setOutdoorAirFlowperPerson(oa_def.outdoorAirFlowperPerson * factor ) unless oa_def.isOutdoorAirFlowperPersonDefaulted
            oa_def.setOutdoorAirFlowperFloorArea(oa_def.outdoorAirFlowperFloorArea * factor) unless oa_def.isOutdoorAirFlowperFloorAreaDefaulted
            oa_def.setOutdoorAirFlowRate(oa_def.outdoorAirFlowRate * factor) unless oa_def.isOutdoorAirFlowRateDefaulted
            oa_def.setOutdoorAirFlowAirChangesperHour(oa_def.outdoorAirFlowAirChangesperHour * factor ) unless oa_def.isOutdoorAirFlowAirChangesperHourDefaulted
          end
        end

        #This method will scale infiltration loads.
        #@author phylroy.lopez@nrcan.gc.ca
        #@param model [OpenStudio::model::Model] A model object 
        #@param factor [Float]
        def self.scale_inflitration_loads( model, factor )
          model.getSpaceInfiltrationDesignFlowRates.sort.each do |infiltration_load|
            infiltration_load.setDesignFlowRate( infiltration_load.designFlowRate.get * factor ) unless infiltration_load.designFlowRate.empty?
            infiltration_load.setFlowperSpaceFloorArea( infiltration_load.flowperSpaceFloorArea.get * factor ) unless infiltration_load.flowperSpaceFloorArea.empty?
            infiltration_load.setFlowperExteriorSurfaceArea( infiltration_load.flowperExteriorSurfaceArea.get * factor ) unless infiltration_load.flowperExteriorSurfaceArea.empty?
            infiltration_load.setAirChangesperHour( infiltration_load.airChangesperHour.get * factor ) unless infiltration_load.airChangesperHour.empty?
          end
        end
  
        #This method will set the infiltration magnitude.
        #@author phylroy.lopez@nrcan.gc.ca
        #@param model [OpenStudio::model::Model] A model object 
        #@param setDesignFlowRate [Float]
        #@param setFlowperSpaceFloorArea [Float]
        #@param setFlowperExteriorSurfaceArea [Float]
        #@param setAirChangesperHour [Float]
        #@return [String] table
        def self.set_inflitration_magnitude( model, setDesignFlowRate,setFlowperSpaceFloorArea,setFlowperExteriorSurfaceArea,setAirChangesperHour )

          table = "name,infiltration_method,infiltration_design_flow_rate,infiltration_flow_per_space,infiltration_flow_per_exterior_area,infiltration_air_changes_per_hour\n"
          model.getSpaceInfiltrationDesignFlowRates.sort.each do |infiltration_load|
            infiltration_load.setAirChangesperHour(setAirChangesperHour ) unless setAirChangesperHour.nil?
            infiltration_load.setDesignFlowRate( setDesignFlowRate ) unless setDesignFlowRate.nil?
            infiltration_load.setFlowperSpaceFloorArea(setFlowperSpaceFloorArea ) unless setFlowperSpaceFloorArea.nil?
            infiltration_load.setFlowperExteriorSurfaceArea(setFlowperExteriorSurfaceArea ) unless setFlowperExteriorSurfaceArea.nil?
            table << infiltration_load.name.get.to_s << ","
            table << infiltration_load.designFlowRateCalculationMethod << ","
            infiltration_load.airChangesperHour.empty? ? ach = "NA" : ach = infiltration_load.airChangesperHour.get
            infiltration_load.designFlowRate.empty? ? dfr = "NA" :  dfr = infiltration_load.designFlowRate.get
            infiltration_load.flowperSpaceFloorArea.empty? ? fsfa = "NA" :  fsfa = infiltration_load.flowperSpaceFloorArea.get
            infiltration_load.flowperExteriorSurfaceArea.empty? ? fesa = "NA" :  fesa = infiltration_load.flowperExteriorSurfaceArea.get
            table << "#{ach},#{dfr},#{fsfa},#{fesa}\n"
          end
          return table
        end
      end


      #This method removes people loads from the model.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      def self.remove_all_people_loads(model)
        model.getPeoples.sort.each {|people| people.remove}
        model.getPeopleDefinitions.sort.each {|people| people.remove}
      end


      #This method created people loads from the model.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@param people_name [String]
      #@param floor_area_per_person [Float]
      #@param multiplier [Float]
      #@param schedule [Float]
      #@return [String] people
      def self.create_people_load(model,people_name,floor_area_per_person = 0.0, multiplier = 1.0 , schedule ="")
        raise("People \"#{people_name}\" already exists. Please use a different name") unless model.getPeopleByName(people_name).empty?
        peopledef = OpenStudio::Model::PeopleDefinition.new(model)
        peopledef.setName(people_name + "-def" )
        peopledef.setSpaceFloorAreaperPerson(floor_area_per_person)
        peopledef.setFractionRadiant(0.3000)
        people = OpenStudio::Model::People.new(peopledef)
        people.setName(people_name  )
        people.setMultiplier(multiplier)
        activity_sched = model.getScheduleRulesetByName("activity 120W")
        if activity_sched.empty?
          people.setActivityLevelSchedule(Resources::Schedules::create_annual_constant_ruleset_schedule(model,"activity 120W","ACTIVITY",120.0))
        else
          people.setActivityLevelSchedule( activity_sched.get)
        end
        #this will override default schedule if given.
        people.setNumberofPeopleSchedule( BTAP::Common::validate_array(model,schedule,"ScheduleRuleset").first )unless schedule == ""
        return people
      end

      #This method removes light loads from model.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      def self.remove_all_light_loads(model)
        model.getLightss.sort.each {|item| item.remove}
        model.getLightsDefinitions.sort.each {|item| item.remove}
      end

      #This method created people loads from the model.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@param light_name [String]
      #@param light_watts_per_floor_area [Float]
      #@param multiplier [Float]
      #@param schedule [Float]
      #@return [String] lights
      def self.create_lighting_load(model,light_name,light_watts_per_floor_area= 0.0, multiplier = 1.0 ,schedule ="" )
        raise("Light #{name} already exists. Please use a different name") unless model.getLightsByName(light_name).empty?
        lightsdef = OpenStudio::Model::LightsDefinition.new(model)
        lightsdef.setWattsperSpaceFloorArea(light_watts_per_floor_area)
        lightsdef.setName(light_name + "-def" )
        lights = OpenStudio::Model::Lights.new(lightsdef)
        lights.setName(light_name )
        lights.setMultiplier(multiplier)
        lights.setSchedule( BTAP::Common::validate_array(model,schedule,"ScheduleRuleset").first ) unless "" == schedule
        return lights
      end

      
      #This method removes elec loads from model.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      def self.remove_all_electric_loads(model)
        model.getElectricEquipments.sort.each {|item| item.remove}
        model.getElectricEquipmentDefinitions.sort.each {|item| item.remove}
      end


      #This method created people loads from the model.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@param elec_name [String]
      #@param elec_watts_per_floor_area [Float]
      #@param multiplier [Float]
      #@param schedule [Float]
      #@return [String] elec
      def self.create_electric_load(model,elec_name,elec_watts_per_floor_area = 0.0, multiplier = 1.0 ,schedule ="")
        raise("ElectricEquipment #{name} already exists. Please use a different name") unless model.getElectricEquipmentByName(elec_name).empty?
        elecdef = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
        elecdef.setWattsperSpaceFloorArea(elec_watts_per_floor_area)
        elecdef.setName(elec_name + "-def" )
        elec = OpenStudio::Model::ElectricEquipment.new(elecdef)
        elec.setName(elec_name )
        elec.setMultiplier(multiplier)
        elec.setSchedule( BTAP::Common::validate_array(model,people_schedule,"ScheduleRuleset").first ) unless schedule == ""
        return elec
      end

      #This method removes hot water loads from model.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object
      def self.remove_all_hot_water_loads(model)
        model.getHotWaterEquipments.sort.each {|item| item.remove}
        model.getHotWaterEquipmentDefinitions.sort.each {|item| item.remove}
      end

      #This method creats hot water load.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@param hot_water_name [String]
      #@param hot_water_watts_per_floor_area [Float]
      #@param multiplier [Float]
      #@param schedule [Float]
      #@return [String] hotwater
      def self.create_hotwater_load(model,hot_water_name,hot_water_watts_per_floor_area = 0.0,multiplier = 1.0 ,schedule ="")
        raise("HotWaterEquipment #{name} already exists. Please use a different name") unless model.getHotWaterEquipmentByName(hot_water_name).empty?
        hotwaterdef = OpenStudio::Model::HotWaterEquipmentDefinition.new(model)
        hotwaterdef.setWattsperSpaceFloorArea(hot_water_watts_per_floor_area)
        hotwaterdef.setName(hot_water_name + "-def")
        hotwater = OpenStudio::Model::HotWaterEquipment.new(hotwaterdef)
        hotwater.setName(hot_water_name )
        hotwater.setMultiplier(multiplier)
        hotwater.setSchedule( BTAP::Common::validate_array(model,schedule,"ScheduleRuleset").first ) unless schedule == ""
        return hotwater
      end

      
      #This method removes all design specification OA from model.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object
      def self.remove_all_DesignSpecificationOutdoorAir(model)
        model.getDesignSpecificationOutdoorAirs.sort.each { |item| item.remove }
      end

      
      #This method removes all space infiltration design flow rate OA from model.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object
      def self.remove_all_SpaceInfiltrationDesignFlowRate(model)
        OpenStudio::Model::SpaceInfiltrationDesignFlowRate
        model.getSpaceInfiltrationDesignFlowRates.sort.each { |item| item.remove }
      end

      #This method creats hot water load.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object 
      #@param oa_name [String]
      #@param oa_person [Fixnum]
      #@param oa_area [Fixnum]
      #@param oa_ach [Fixnum]
      #@param oa_flowrate [Fixnum]
      #@param method [String]
      #@param schedule [Float]
      #@return [OpenStudio::model::Model] oa_def
      def self.create_oa_load(model,oa_name,oa_person = 0 ,oa_area = 0, oa_ach = 0, oa_flowrate = 0, method = "Maximum",schedule = nil)
        raise("DesignSpecificationOutdoorAir #{name} already exists. Please use a different name") unless model.getDesignSpecificationOutdoorAirByName( oa_name ).empty?
        #units are in m3/s for flow and m2 for area.
        #The method must be either Flow/Person,Flow/Area,Flow/Zone,AirChanges/Hour,Sum,Maximum.
        #Defaults to the maximum calculated value
        raise ("outdoor air method argument #{method} is not valid") unless OpenStudio::Model::DesignSpecificationOutdoorAir::validOutdoorAirMethodValues.include?(method)
        #Find a DesignSpecificationOutdoorAir object if one of the same title is not found.  Then we will create it.
        oa_def = OpenStudio::Model::DesignSpecificationOutdoorAir.new(model)
        oa_def.setOutdoorAirMethod(method)
        oa_def.setOutdoorAirFlowperPerson(oa_person)
        oa_def.setOutdoorAirFlowperFloorArea(oa_area)
        oa_def.setOutdoorAirFlowRate(oa_flowrate)
        oa_def.setOutdoorAirFlowAirChangesperHour(oa_ach)
        oa_def.setName(oa_name )
        oa_def.setOutdoorAirFlowRateFractionSchedule( BTAP::Common::validate_array(model,schedule,"ScheduleRuleset").first ) unless schedule.nil?
        return oa_def
      end


      
      #This method removes infiltration from model..
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object
      def self.remove_all_SpaceInfiltrationDesignFlowRates(model)
        model.getSpaceInfiltrationDesignFlowRates.sort.each { |item| item.remove }
      end

      #This method creates infiltration load.
      #NECB infiltration rate is 0.25L/s/m2  or 0.00025 m3/s/m2
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object
      #@return [String] infiltration_load
      def self.create_infiltration_load(model,
          infil_name,
          value = 0.00025 ,
          method = "Flow/ExteriorArea" ,
          schedule = BTAP::Resources::Schedules::StandardSchedules::Fraction::always_on(model),
          setConstantTermCoefficient = 1.0,
          setTemperatureTermCoefficient = 0.0,
          setVelocityTermCoefficient = 0.0,
          setVelocitySquaredTermCoefficient = 0.0 )
        #units are in m3/s for flow and m2 for area.
        #The method must be either Flow/Person,Flow/Area,Flow/Zone,AirChanges/Hour,Sum,Maximum.
        #Defaults to the maximum calculated value
        #units are in m3/s for flow and m2 for area.
        #The method must be either Flow/Space, Flow/Area,Flow/ExteriorArea,AirChanges/Hour,Sum,Maximum.
        #Defaults to the maximum calculated value
        raise("SpaceInfiltrationDesignFlowRate #{name} already exists. Please use a different name") unless model.getSpaceInfiltrationDesignFlowRateByName( infil_name ).empty?
        raise("infiltration method #{method} is not a part of accepted values such as: #{OpenStudio::Model::SpaceInfiltrationDesignFlowRate::validDesignFlowRateCalculationMethodValues.join(",")}")  unless OpenStudio::Model::SpaceInfiltrationDesignFlowRate::validDesignFlowRateCalculationMethodValues.include?(method)

        infiltration_load = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
        infiltration_load.setName(infil_name )
        infiltration_load.setDesignFlowRate(value) if method == "Flow/Space"
        infiltration_load.setFlowperSpaceFloorArea(value) if method == "Flow/Area"
        infiltration_load.setFlowperExteriorWallArea(value) if method == "Flow/ExteriorWallArea"
        infiltration_load.setFlowperExteriorSurfaceArea(value) if method == "Flow/ExteriorArea"
        infiltration_load.setAirChangesperHour(value) if method == "AirChanges/Hour"
        infiltration_load.setConstantTermCoefficient(setConstantTermCoefficient)
        infiltration_load.setTemperatureTermCoefficient(setTemperatureTermCoefficient)
        infiltration_load.setVelocityTermCoefficient(setVelocityTermCoefficient)
        infiltration_load.setVelocitySquaredTermCoefficient(setVelocitySquaredTermCoefficient)
        infiltration_load.setSchedule( BTAP::Common::validate_array(model,schedule,"ScheduleRuleset").first )

        return infiltration_load
      end

      #This method removes all loads from model.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object
      def self.remove_all_casual_loads(model)
        self.remove_all_people_loads(model)
        self.remove_all_light_loads(model)
        self.remove_all_electric_loads(model)
        self.remove_all_hot_water_loads(model)
      end

      #This method removes all space loads from model.
      #@author phylroy.lopez@nrcan.gc.ca
      #@param model [OpenStudio::model::Model] A model object
      def self.remove_all_SpaceLoads(model)
        model.getSpaceLoads.sort.each { |item| item.remove }
        model.getSpaceLoadDefinitions.sort.each { |item| item.remove }
      end
    end #module SpaceLoads
  end #module Resources
end
