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

    module SpaceTypes # BTAP::Resources::SpaceTypes

      #Test SpaceType Module
      if __FILE__ == $0
        require 'test/unit'
        class SpaceLoadsTests < Test::Unit::TestCase
          #This method will take 0 variables and tests that the loads will be created correctly.
          #@author phylroy.lopez@nrcan.gc.ca
          def test_create_all_loads()
            model = OpenStudio::Model::Model.new()
            people_load =  BTAP::Resources::SpaceLoads::create_people_load(model,"people_load_test")
            lighting_load = BTAP::Resources::SpaceLoads::create_lighting_load(model,"lights_load_test")
            electric_load = BTAP::Resources::SpaceLoads::create_electric_load(model,"electric_load_test")
            hotwater_load = BTAP::Resources::SpaceLoads::create_hotwater_load(model,"hotwater_load_test")
            oa_load = BTAP::Resources::SpaceLoads::create_oa_load(model,"oa_load_test")
            infiltration_load = BTAP::Resources::SpaceLoads::create_infiltration_load(model,"infiltration_load_test")
            default_schedule_set = nil
            #Check to see if the objects were really created.
            space_type = BTAP::Resources::SpaceTypes::create_space_type(model,"space type test",default_schedule_set,people_load,lighting_load,electric_load,hotwater_load,oa_load,infiltration_load)
            assert( !(space_type.to_SpaceType.empty?))
          end
        end
      end # End Test SpaceType

      #This method will take 9 variables and returns the space type.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model [Object]
      #@params space_type_name [String]
      #@params default_schedule_set [Array]
      #@params people_load [Array]
      #@params lighting_load [Array]
      #@params electric_load [Array]
      #@params hotwater_load [Array]
      #@params oa_load [Array]
      #@params infiltration_load [Array]
      #@return spacetype [OpenStudio::Model::SpaceType]
      def self.create_space_type(model,space_type_name,default_schedule_set,people_load,lighting_load,electric_load,hotwater_load,oa_load,infiltration_load)
        raise("SpaceType #{space_type_name} already exists. Please use a different name") unless model.getSpaceTypeByName(space_type_name).empty?
        spacetype = OpenStudio::Model::SpaceType.new(model)
        spacetype.setName(space_type_name)
        spacetype.setDefaultScheduleSet(default_schedule_set) unless nil == default_schedule_set
        BTAP::Common::validate_array(model,people_load,"People").first.setSpaceType(spacetype) unless nil == people_load
        BTAP::Common::validate_array(model,lighting_load,"Lights").first.setSpaceType(spacetype) unless nil == lighting_load
        BTAP::Common::validate_array(model,electric_load,"ElectricEquipment").first.setSpaceType(spacetype) unless nil == electric_load
        BTAP::Common::validate_array(model,hotwater_load,"HotWaterEquipment").first.setSpaceType(spacetype) unless nil == hotwater_load
        spacetype.setDesignSpecificationOutdoorAir(BTAP::Common::validate_array(model,oa_load,"DesignSpecificationOutdoorAir").first) unless nil == oa_load
        BTAP::Common::validate_array(model,infiltration_load,"SpaceInfiltrationDesignFlowRate").first.setSpaceType(spacetype)  unless nil == infiltration_load
        #puts "Created spacetype #{spacetype.name} in model."
        return spacetype
      end

      #This method will take 2 variables and merge the space types.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model [Object]
      #@params spacetype_precentage_array [Array]
      def self.create_merged_space_type(model,spacetype_precentage_array)
        new_spacetype = OpenStudio::Model::SpaceType.new(model)
        spacetype_precentage_array.each do |spacetype_percentage|
          spacetype = BTAP::Common::validate_array(model,spacetype_percentage[0],"SpaceType").first
          spacetype.getDefaultSchedule()
          spacetype.internalMass()
          spacetype.people()
          spacetype.lights()
          spacetype.luminaires()
          spacetype.electricEquipment()
          spacetype.gasEquipment()
          spacetype.hotWaterEquipment()
          spacetype.steamEquipment()
          spacetype.otherEquipment()
          #A bit more tricky
          spacetype.designSpecificationOutdoorAir()
          spacetype.spaceInfiltrationDesignFlowRates()
        end
      end
      
      #This method will take 1 variable this method will attempt to find the dominant schedule of the surround spaces
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model [Object] (description)
      def self.set_wildcard_spacetype_schedules_to_dominant_schedule(model)
        #1.Find all spaces with wildcard spaces.
        #2.Iterate through spaces
        #2.1 Find all adjacent spaces
        #2.2 Determine dominant space type
        #2.2 Set the appropriate schedule for occ, lighting, plugs and
      end
    end #module SpaceTypes
  end #module Resources
end
