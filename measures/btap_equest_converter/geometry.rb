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
  module Geometry

    def self.enumerate_spaces_model(model,prepend_name = false)
      #enumerate stories.
      BTAP::Geometry::BuildingStoreys::auto_assign_spaces_to_stories(model)
      #Enumerate spaces
      model.getBuildingStorys.each do |story|
        spaces = Array.new
        spaces.concat( story.spaces )
        spaces.sort! do |a, b|
          (a.xOrigin <=> b.xOrigin).nonzero? ||
            (a.yOrigin <=> b.yOrigin)
        end
        counter = 1
        spaces.each do |space|
          puts "old space name : #{space.name}"
          if prepend_name == true
            space.setName("#{story.name}-#{counter.to_s}:#{space.name}")
          else
            space.setName("#{story.name}-#{counter.to_s}")
          end
          counter = counter + 1
          puts "new space name : #{space.name}"
        end
      end
    end
    
    #this was a copy of the sketchup plugin method. 
    def self.rename_zones_based_on_spaces(model)

      # loop through thermal zones
      model.getThermalZones.each do |thermal_zone| # this is going through all, not just selection
        puts "old zone name : #{thermal_zone.name}"
        # reset the array of spaces to be empty
        spaces_in_thermal_zone = []
        # reset length of array of spaces
        number_of_spaces = 0
      
        # get list of spaces in thermal zone
        spaces = thermal_zone.spaces
        spaces.each do |space|

          # make an array instead of the puts statement
          spaces_in_thermal_zone.push space.name.to_s
 
        end
      
        # store length of array
        number_of_spaces = spaces_in_thermal_zone.size
      
        # sort the array
        spaces_in_thermal_zone = spaces_in_thermal_zone.sort
      
        # setup a suffix if the thermal zone contains more than one space
        if number_of_spaces > 1
          multi = " - Plus"
        else
          multi = ""
        end
      
        # rename thermal zone based on first space with prefix added e.g. ThermalZone 203
        if number_of_spaces > 0
          new_name = "ZN:" + spaces_in_thermal_zone[0] + multi
          thermal_zone.setName(new_name)
        else
          puts "#{thermal_zone.name.to_s} did not have any spaces, and will not be renamed." 
        end
        puts "new zone name : #{thermal_zone.name}"
      end
    end
    
    #This method will rename the zone equipment to have the zone name as a prefix for a model. 
    #It will also rename the hot water coils for: 
    #    AirTerminalSingleDuctVAVReheat
    #    ZoneHVACBaseboardConvectiveWater
    #    ZoneHVACUnitHeater
   
    def self.prefix_equipment_with_zone_name(model)
      puts "Renaming zone equipment."
      # get all thermal zones
      thermal_zones = model.getThermalZones

      # loop through thermal zones
      thermal_zones.each do |thermal_zone| # this is going through all, not just selection

        thermal_zone.equipment.each do |equip|

          #For the hydronic conditions below only, it will rename the zonal coils as well. 
          if not equip.to_AirTerminalSingleDuctVAVReheat.empty?

            equip.setName("#{thermal_zone.name}:AirTerminalSingleDuctVAVReheat")
            reheat_coil = equip.to_AirTerminalSingleDuctVAVReheat.get.reheatCoil
            reheat_coil.setName("#{thermal_zone.name}:ReheatCoil")
            puts reheat_coil.name
          elsif not equip.to_ZoneHVACBaseboardConvectiveWater.empty?
            equip.setName("#{thermal_zone.name}:ZoneHVACBaseboardConvectiveWater")
            heatingCoil = equip.to_ZoneHVACBaseboardConvectiveWater.get.heatingCoil
            heatingCoil.setName("#{thermal_zone.name}:Baseboard HW Htg Coil")
            puts heatingCoil.name
          elsif not equip.to_ZoneHVACUnitHeater.empty?
            equip.setName("#{thermal_zone.name}:ZoneHVACUnitHeater")
            heatingCoil = equip.to_ZoneHVACUnitHeater.get.heatingCoil
            heatingCoil.setName("#{thermal_zone.name}:Unit Heater Htg Coil")
            puts heatingCoil.name
            #Add more cases if you wish!!!!!
          else #if the equipment does not follow the above cases, rename
            # it generically and not touch the underlying coils, etc. 
            equip.setName("#{thermal_zone.name}:#{equip.name}")
          end
          
        end
      end
      puts "Done zone renaming equipment"
    end
      
      

    module Wizards
      def self.create_shape_courtyard(model,
          length = 50,
          width = 30,
          courtyard_length = 15,
          courtyard_width = 5 ,
          num_floors = 3,
          floor_to_floor_height = 3.8,
          plenum_height = 1,
          perimeter_zone_depth = 4.57)
        if length <= 1e-4
          raise("Length must be greater than 0.")
          return false
        end

        if width <= 1e-4
          raise("Width must be greater than 0.")
          return false
        end

        if courtyard_length <= 1e-4
          raise("Courtyard length must be greater than 0.")
          return false
        end

        if courtyard_width <= 1e-4
          raise("Courtyard width must be greater than 0.")
          return false
        end

        if num_floors <= 1e-4
          raise("Number of floors must be greater than 0.")
          return false
        end

        if floor_to_floor_height <= 1e-4
          raise("Floor to floor height must be greater than 0.")
          return false
        end

        if plenum_height < 0
          raise("Plenum height must be greater than or equal to 0.")
          return false
        end

        shortest_side = [length,width].min
        if perimeter_zone_depth < 0 or 4*perimeter_zone_depth >= (shortest_side - 1e-4)
          raise("Perimeter zone depth must be greater than or equal to 0 and less than #{shortest_side/4}m.")
          return false
        end

        if courtyard_length >= (length - 4*perimeter_zone_depth - 1e-4)
          raise("Courtyard length must be less than #{length - 4*perimeter_zone_depth}m.")
          return false
        end

        if courtyard_width >= (width - 4*perimeter_zone_depth - 1e-4)
          raise("Courtyard width must be less than #{width - 4*perimeter_zone_depth}m.")
          return false
        end


        # Loop through the number of floors
        for floor in (0..num_floors-1)

          z = floor_to_floor_height * floor

          #Create a new story within the building
          story = OpenStudio::Model::BuildingStory.new(model)
          story.setNominalFloortoFloorHeight(floor_to_floor_height)
          story.setName("Story #{floor+1}")


          nw_point = OpenStudio::Point3d.new(0,width,z)
          ne_point = OpenStudio::Point3d.new(length,width,z)
          se_point = OpenStudio::Point3d.new(length,0,z)
          sw_point = OpenStudio::Point3d.new(0,0,z)

          courtyard_nw_point = OpenStudio::Point3d.new((length-courtyard_length)/2,(width-courtyard_width)/2+courtyard_width,z)
          courtyard_ne_point = OpenStudio::Point3d.new((length-courtyard_length)/2+courtyard_length,(width-courtyard_width)/2+courtyard_width,z)
          courtyard_se_point = OpenStudio::Point3d.new((length-courtyard_length)/2+courtyard_length,(width-courtyard_width)/2,z)
          courtyard_sw_point = OpenStudio::Point3d.new((length-courtyard_length)/2,(width-courtyard_width)/2,z)

          # Identity matrix for setting space origins
          m = OpenStudio::Matrix.new(4,4,0)
          m[0,0] = 1
          m[1,1] = 1
          m[2,2] = 1
          m[3,3] = 1

          # Define polygons for a building with a courtyard
          if perimeter_zone_depth > 0
            outer_perimeter_nw_point = nw_point + OpenStudio::Vector3d.new(perimeter_zone_depth,-perimeter_zone_depth,0)
            outer_perimeter_ne_point = ne_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,-perimeter_zone_depth,0)
            outer_perimeter_se_point = se_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,perimeter_zone_depth,0)
            outer_perimeter_sw_point = sw_point + OpenStudio::Vector3d.new(perimeter_zone_depth,perimeter_zone_depth,0)
            inner_perimeter_nw_point = courtyard_nw_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,perimeter_zone_depth,0)
            inner_perimeter_ne_point = courtyard_ne_point + OpenStudio::Vector3d.new(perimeter_zone_depth,perimeter_zone_depth,0)
            inner_perimeter_se_point = courtyard_se_point + OpenStudio::Vector3d.new(perimeter_zone_depth,-perimeter_zone_depth,0)
            inner_perimeter_sw_point = courtyard_sw_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,-perimeter_zone_depth,0)

            west_outer_perimeter_polygon = OpenStudio::Point3dVector.new
            west_outer_perimeter_polygon << sw_point
            west_outer_perimeter_polygon << nw_point
            west_outer_perimeter_polygon << outer_perimeter_nw_point
            west_outer_perimeter_polygon << outer_perimeter_sw_point
            west_outer_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(west_outer_perimeter_polygon, floor_to_floor_height, model)
            west_outer_perimeter_space = west_outer_perimeter_space.get
            m[0,3] = sw_point.x
            m[1,3] = sw_point.y
            m[2,3] = sw_point.z
            west_outer_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            west_outer_perimeter_space.setBuildingStory(story)
            west_outer_perimeter_space.setName("Story #{floor+1} West Outer Perimeter Space")



            north_outer_perimeter_polygon = OpenStudio::Point3dVector.new
            north_outer_perimeter_polygon << nw_point
            north_outer_perimeter_polygon << ne_point
            north_outer_perimeter_polygon << outer_perimeter_ne_point
            north_outer_perimeter_polygon << outer_perimeter_nw_point
            north_outer_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(north_outer_perimeter_polygon, floor_to_floor_height, model)
            north_outer_perimeter_space = north_outer_perimeter_space.get
            m[0,3] = outer_perimeter_nw_point.x
            m[1,3] = outer_perimeter_nw_point.y
            m[2,3] = outer_perimeter_nw_point.z
            north_outer_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            north_outer_perimeter_space.setBuildingStory(story)
            north_outer_perimeter_space.setName("Story #{floor+1} North Outer Perimeter Space")



            east_outer_perimeter_polygon = OpenStudio::Point3dVector.new
            east_outer_perimeter_polygon << ne_point
            east_outer_perimeter_polygon << se_point
            east_outer_perimeter_polygon << outer_perimeter_se_point
            east_outer_perimeter_polygon << outer_perimeter_ne_point
            east_outer_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(east_outer_perimeter_polygon, floor_to_floor_height, model)
            east_outer_perimeter_space = east_outer_perimeter_space.get
            m[0,3] = outer_perimeter_se_point.x
            m[1,3] = outer_perimeter_se_point.y
            m[2,3] = outer_perimeter_se_point.z
            east_outer_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_outer_perimeter_space.setBuildingStory(story)
            east_outer_perimeter_space.setName("Story #{floor+1} East Outer Perimeter Space")



            south_outer_perimeter_polygon = OpenStudio::Point3dVector.new
            south_outer_perimeter_polygon << se_point
            south_outer_perimeter_polygon << sw_point
            south_outer_perimeter_polygon << outer_perimeter_sw_point
            south_outer_perimeter_polygon << outer_perimeter_se_point
            south_outer_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(south_outer_perimeter_polygon, floor_to_floor_height, model)
            south_outer_perimeter_space = south_outer_perimeter_space.get
            m[0,3] = sw_point.x
            m[1,3] = sw_point.y
            m[2,3] = sw_point.z
            south_outer_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            south_outer_perimeter_space.setBuildingStory(story)
            south_outer_perimeter_space.setName("Story #{floor+1} South Outer Perimeter Space")


            west_core_polygon = OpenStudio::Point3dVector.new
            west_core_polygon << outer_perimeter_sw_point
            west_core_polygon << outer_perimeter_nw_point
            west_core_polygon << inner_perimeter_nw_point
            west_core_polygon << inner_perimeter_sw_point
            west_core_space = OpenStudio::Model::Space::fromFloorPrint(west_core_polygon, floor_to_floor_height, model)
            west_core_space = west_core_space.get
            m[0,3] = outer_perimeter_sw_point.x
            m[1,3] = outer_perimeter_sw_point.y
            m[2,3] = outer_perimeter_sw_point.z
            west_core_space.changeTransformation(OpenStudio::Transformation.new(m))
            west_core_space.setBuildingStory(story)
            west_core_space.setName("Story #{floor+1} West Core Space")


            north_core_polygon = OpenStudio::Point3dVector.new
            north_core_polygon << outer_perimeter_nw_point
            north_core_polygon << outer_perimeter_ne_point
            north_core_polygon << inner_perimeter_ne_point
            north_core_polygon << inner_perimeter_nw_point
            north_core_space = OpenStudio::Model::Space::fromFloorPrint(north_core_polygon, floor_to_floor_height, model)
            north_core_space = north_core_space.get
            m[0,3] = inner_perimeter_nw_point.x
            m[1,3] = inner_perimeter_nw_point.y
            m[2,3] = inner_perimeter_nw_point.z
            north_core_space.changeTransformation(OpenStudio::Transformation.new(m))
            north_core_space.setBuildingStory(story)
            north_core_space.setName("Story #{floor+1} North Core Space")


            east_core_polygon = OpenStudio::Point3dVector.new
            east_core_polygon << outer_perimeter_ne_point
            east_core_polygon << outer_perimeter_se_point
            east_core_polygon << inner_perimeter_se_point
            east_core_polygon << inner_perimeter_ne_point
            east_core_space = OpenStudio::Model::Space::fromFloorPrint(east_core_polygon, floor_to_floor_height, model)
            east_core_space = east_core_space.get
            m[0,3] = inner_perimeter_se_point.x
            m[1,3] = inner_perimeter_se_point.y
            m[2,3] = inner_perimeter_se_point.z
            east_core_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_core_space.setBuildingStory(story)
            east_core_space.setName("Story #{floor+1} East Core Space")


            south_core_polygon = OpenStudio::Point3dVector.new
            south_core_polygon << outer_perimeter_se_point
            south_core_polygon << outer_perimeter_sw_point
            south_core_polygon << inner_perimeter_sw_point
            south_core_polygon << inner_perimeter_se_point
            south_core_space = OpenStudio::Model::Space::fromFloorPrint(south_core_polygon, floor_to_floor_height, model)
            south_core_space = south_core_space.get
            m[0,3] = outer_perimeter_sw_point.x
            m[1,3] = outer_perimeter_sw_point.y
            m[2,3] = outer_perimeter_sw_point.z
            south_core_space.changeTransformation(OpenStudio::Transformation.new(m))
            south_core_space.setBuildingStory(story)
            south_core_space.setName("Story #{floor+1} South Core Space")


            west_inner_perimeter_polygon  = OpenStudio::Point3dVector.new
            west_inner_perimeter_polygon << inner_perimeter_sw_point
            west_inner_perimeter_polygon << inner_perimeter_nw_point
            west_inner_perimeter_polygon << courtyard_nw_point
            west_inner_perimeter_polygon << courtyard_sw_point
            west_inner_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(west_inner_perimeter_polygon, floor_to_floor_height, model)
            west_inner_perimeter_space = west_inner_perimeter_space.get
            m[0,3] = inner_perimeter_sw_point.x
            m[1,3] = inner_perimeter_sw_point.y
            m[2,3] = inner_perimeter_sw_point.z
            west_inner_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            west_inner_perimeter_space.setBuildingStory(story)
            west_inner_perimeter_space.setName("Story #{floor+1} West Inner Perimeter Space")


            north_inner_perimeter_polygon  = OpenStudio::Point3dVector.new
            north_inner_perimeter_polygon << inner_perimeter_nw_point
            north_inner_perimeter_polygon << inner_perimeter_ne_point
            north_inner_perimeter_polygon << courtyard_ne_point
            north_inner_perimeter_polygon << courtyard_nw_point
            north_inner_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(north_inner_perimeter_polygon, floor_to_floor_height, model)
            north_inner_perimeter_space = north_inner_perimeter_space.get
            m[0,3] = courtyard_nw_point.x
            m[1,3] = courtyard_nw_point.y
            m[2,3] = courtyard_nw_point.z
            north_inner_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            north_inner_perimeter_space.setBuildingStory(story)
            north_inner_perimeter_space.setName("Story #{floor+1} North Inner Perimeter Space")


            east_inner_perimeter_polygon  = OpenStudio::Point3dVector.new
            east_inner_perimeter_polygon << inner_perimeter_ne_point
            east_inner_perimeter_polygon << inner_perimeter_se_point
            east_inner_perimeter_polygon << courtyard_se_point
            east_inner_perimeter_polygon << courtyard_ne_point
            east_inner_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(east_inner_perimeter_polygon, floor_to_floor_height, model)
            east_inner_perimeter_space = east_inner_perimeter_space.get
            m[0,3] = courtyard_se_point.x
            m[1,3] = courtyard_se_point.y
            m[2,3] = courtyard_se_point.z
            east_inner_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_inner_perimeter_space.setBuildingStory(story)
            east_inner_perimeter_space.setName("Story #{floor+1} East Inner Perimeter Space")


            south_inner_perimeter_polygon  = OpenStudio::Point3dVector.new
            south_inner_perimeter_polygon << inner_perimeter_se_point
            south_inner_perimeter_polygon << inner_perimeter_sw_point
            south_inner_perimeter_polygon << courtyard_sw_point
            south_inner_perimeter_polygon << courtyard_se_point
            south_inner_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(south_inner_perimeter_polygon, floor_to_floor_height, model)
            south_inner_perimeter_space = south_inner_perimeter_space.get
            m[0,3] = inner_perimeter_sw_point.x
            m[1,3] = inner_perimeter_sw_point.y
            m[2,3] = inner_perimeter_sw_point.z
            south_inner_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            south_inner_perimeter_space.setBuildingStory(story)
            south_inner_perimeter_space.setName("Story #{floor+1} South Inner Perimeter Space")


            # Minimal zones
          else
            west_polygon = OpenStudio::Point3dVector.new
            west_polygon << sw_point
            west_polygon << nw_point
            west_polygon << courtyard_nw_point
            west_polygon << courtyard_sw_point
            west_space = OpenStudio::Model::Space::fromFloorPrint(west_polygon, floor_to_floor_height, model)
            west_space = west_space.get
            m[0,3] = sw_point.x
            m[1,3] = sw_point.y
            m[2,3] = sw_point.z
            west_space.changeTransformation(OpenStudio::Transformation.new(m))
            west_space.setBuildingStory(story)
            west_space.setName("Story #{floor+1} West Space")


            north_polygon = OpenStudio::Point3dVector.new
            north_polygon << nw_point
            north_polygon << ne_point
            north_polygon << courtyard_ne_point
            north_polygon << courtyard_nw_point
            north_space = OpenStudio::Model::Space::fromFloorPrint(north_polygon, floor_to_floor_height, model)
            north_space = north_space.get
            m[0,3] = courtyard_nw_point.x
            m[1,3] = courtyard_nw_point.y
            m[2,3] = courtyard_nw_point.z
            north_space.changeTransformation(OpenStudio::Transformation.new(m))
            north_space.setBuildingStory(story)
            north_space.setName("Story #{floor+1} North Space")


            east_polygon = OpenStudio::Point3dVector.new
            east_polygon << ne_point
            east_polygon << se_point
            east_polygon << courtyard_se_point
            east_polygon << courtyard_ne_point
            east_space = OpenStudio::Model::Space::fromFloorPrint(east_polygon, floor_to_floor_height, model)
            east_space = east_space.get
            m[0,3] = courtyard_se_point.x
            m[1,3] = courtyard_se_point.y
            m[2,3] = courtyard_se_point.z
            east_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_space.setBuildingStory(story)
            east_space.setName("Story #{floor+1} East Space")


            south_polygon = OpenStudio::Point3dVector.new
            south_polygon << se_point
            south_polygon << sw_point
            south_polygon << courtyard_sw_point
            south_polygon << courtyard_se_point
            south_space = OpenStudio::Model::Space::fromFloorPrint(south_polygon, floor_to_floor_height, model)
            south_space = south_space.get
            m[0,3] = sw_point.x
            m[1,3] = sw_point.y
            m[2,3] = sw_point.z
            south_space.changeTransformation(OpenStudio::Transformation.new(m))
            south_space.setBuildingStory(story)
            south_space.setName("Story #{floor+1} South Space")
          end
          #Set vertical story position
          story.setNominalZCoordinate(z)
        end #End of floor loop
        BTAP::Geometry::match_surfaces(model)
        return model
      end

      def self.create_shape_h(model,
          length = 40.0,
          left_width = 40.0,
          center_width = 10.0,
          right_width = 40.0,
          left_end_length = 15.0,
          right_end_length = 15.0,
          left_upper_end_offset = 15.0,
          right_upper_end_offset = 15.0,
          num_floors = 3,
          floor_to_floor_height = 3.8,
          plenum_height = 1,
          perimeter_zone_depth = 4.57)


        if length <= 1e-4
          raise("Length must be greater than 0.")
          return false
        end

        if left_width <= 1e-4
          raise("Left width must be greater than 0.")
          return false
        end

        if right_width <= 1e-4
          raise("Right width must be greater than 0.")
          return false
        end

        if center_width <= 1e-4 or center_width >= ([left_width,right_width].min - 1e-4)
          raise("Center width must be greater than 0 and less than #{[left_width,right_width].min}m.")
          return false
        end

        if left_end_length <= 1e-4 or left_end_length >= (length - 1e-4)
          raise("Left end length must be greater than 0 and less than #{length}m.")
          return false
        end

        if right_end_length <= 1e-4 or right_end_length >= (length - left_end_length - 1e-4)
          raise("Right end length must be greater than 0 and less than #{length - left_end_length}m.")
          return false
        end

        if left_upper_end_offset <= 1e-4 or left_upper_end_offset >= (left_width - center_width - 1e-4)
          raise("Left upper end offset must be greater than 0 and less than #{left_width - center_width}m.")
          return false
        end

        if right_upper_end_offset <= 1e-4 or right_upper_end_offset >= (right_width - center_width - 1e-4)
          raise("Right upper end offset must be greater than 0 and less than #{right_width - center_width}m.")
          return false
        end

        if num_floors <= 1e-4
          raise("Number of floors must be greater than 0.")
          return false
        end

        if floor_to_floor_height <= 1e-4
          raise("Floor to floor height must be greater than 0.")
          return false
        end

        if plenum_height < 0
          raise("Plenum height must be greater than or equal to 0.")
          return false
        end

        shortest_side = [length/2,left_width,center_width,right_width,left_end_length,right_end_length].min
        if perimeter_zone_depth < 0 or 2*perimeter_zone_depth >= (shortest_side - 1e-4)
          raise("Perimeter zone depth must be greater than or equal to 0 and less than #{shortest_side/2}m.")
          return false
        end



        # Loop through the number of floors
        for floor in (0..num_floors-1)

          z = floor_to_floor_height * floor

          #Create a new story within the building
          story = OpenStudio::Model::BuildingStory.new(model)
          story.setNominalFloortoFloorHeight(floor_to_floor_height)
          story.setName("Story #{floor+1}")


          left_origin = (right_width - right_upper_end_offset) > (left_width - left_upper_end_offset) ? (right_width - right_upper_end_offset) - (left_width - left_upper_end_offset) : 0

          left_nw_point = OpenStudio::Point3d.new(0,left_width + left_origin,z)
          left_ne_point = OpenStudio::Point3d.new(left_end_length,left_width + left_origin,z)
          left_se_point = OpenStudio::Point3d.new(left_end_length,left_origin,z)
          left_sw_point = OpenStudio::Point3d.new(0,left_origin,z)
          center_nw_point = OpenStudio::Point3d.new(left_end_length,left_ne_point.y - left_upper_end_offset,z)
          center_ne_point = OpenStudio::Point3d.new(length - right_end_length,center_nw_point.y,z)
          center_se_point = OpenStudio::Point3d.new(length - right_end_length,center_nw_point.y - center_width,z)
          center_sw_point = OpenStudio::Point3d.new(left_end_length,center_se_point.y,z)
          right_nw_point = OpenStudio::Point3d.new(length - right_end_length,center_ne_point.y + right_upper_end_offset,z)
          right_ne_point = OpenStudio::Point3d.new(length,right_nw_point.y,z)
          right_se_point = OpenStudio::Point3d.new(length,right_ne_point.y-right_width,z)
          right_sw_point = OpenStudio::Point3d.new(length - right_end_length,right_se_point.y,z)

          # Identity matrix for setting space origins
          m = OpenStudio::Matrix.new(4,4,0)
          m[0,0] = 1
          m[1,1] = 1
          m[2,2] = 1
          m[3,3] = 1

          # Define polygons for a L-shape building with perimeter core zoning
          if perimeter_zone_depth > 0
            perimeter_left_nw_point = left_nw_point + OpenStudio::Vector3d.new(perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_left_ne_point = left_ne_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_left_se_point = left_se_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,perimeter_zone_depth,0)
            perimeter_left_sw_point = left_sw_point + OpenStudio::Vector3d.new(perimeter_zone_depth,perimeter_zone_depth,0)
            perimeter_center_nw_point = center_nw_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_center_ne_point = center_ne_point + OpenStudio::Vector3d.new(perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_center_se_point = center_se_point + OpenStudio::Vector3d.new(perimeter_zone_depth,perimeter_zone_depth,0)
            perimeter_center_sw_point = center_sw_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,perimeter_zone_depth,0)
            perimeter_right_nw_point = right_nw_point + OpenStudio::Vector3d.new(perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_right_ne_point = right_ne_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_right_se_point = right_se_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,perimeter_zone_depth,0)
            perimeter_right_sw_point = right_sw_point + OpenStudio::Vector3d.new(perimeter_zone_depth,perimeter_zone_depth,0)

            west_left_perimeter_polygon = OpenStudio::Point3dVector.new
            west_left_perimeter_polygon << left_sw_point
            west_left_perimeter_polygon << left_nw_point
            west_left_perimeter_polygon << perimeter_left_nw_point
            west_left_perimeter_polygon << perimeter_left_sw_point
            west_left_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(west_left_perimeter_polygon, floor_to_floor_height, model)
            west_left_perimeter_space = west_left_perimeter_space.get
            m[0,3] = left_sw_point.x
            m[1,3] = left_sw_point.y
            m[2,3] = left_sw_point.z
            west_left_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            west_left_perimeter_space.setBuildingStory(story)
            west_left_perimeter_space.setName("Story #{floor+1} West Left Perimeter Space")


            north_left_perimeter_polygon = OpenStudio::Point3dVector.new
            north_left_perimeter_polygon << left_nw_point
            north_left_perimeter_polygon << left_ne_point
            north_left_perimeter_polygon << perimeter_left_ne_point
            north_left_perimeter_polygon << perimeter_left_nw_point
            north_left_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(north_left_perimeter_polygon, floor_to_floor_height, model)
            north_left_perimeter_space = north_left_perimeter_space.get
            m[0,3] = perimeter_left_nw_point.x
            m[1,3] = perimeter_left_nw_point.y
            m[2,3] = perimeter_left_nw_point.z
            north_left_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            north_left_perimeter_space.setBuildingStory(story)
            north_left_perimeter_space.setName("Story #{floor+1} North Left Perimeter Space")


            east_upper_left_perimeter_polygon = OpenStudio::Point3dVector.new
            east_upper_left_perimeter_polygon << left_ne_point
            east_upper_left_perimeter_polygon << center_nw_point
            east_upper_left_perimeter_polygon << perimeter_center_nw_point
            east_upper_left_perimeter_polygon << perimeter_left_ne_point
            east_upper_left_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(east_upper_left_perimeter_polygon, floor_to_floor_height, model)
            east_upper_left_perimeter_space = east_upper_left_perimeter_space.get
            m[0,3] = perimeter_center_nw_point.x
            m[1,3] = perimeter_center_nw_point.y
            m[2,3] = perimeter_center_nw_point.z
            east_upper_left_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_upper_left_perimeter_space.setBuildingStory(story)
            east_upper_left_perimeter_space.setName("Story #{floor+1} East Upper Left Perimeter Space")


            north_center_perimeter_polygon = OpenStudio::Point3dVector.new
            north_center_perimeter_polygon << center_nw_point
            north_center_perimeter_polygon << center_ne_point
            north_center_perimeter_polygon << perimeter_center_ne_point
            north_center_perimeter_polygon << perimeter_center_nw_point
            north_center_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(north_center_perimeter_polygon, floor_to_floor_height, model)
            north_center_perimeter_space = north_center_perimeter_space.get
            m[0,3] = perimeter_center_nw_point.x
            m[1,3] = perimeter_center_nw_point.y
            m[2,3] = perimeter_center_nw_point.z
            north_center_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            north_center_perimeter_space.setBuildingStory(story)
            north_center_perimeter_space.setName("Story #{floor+1} North Center Perimeter Space")


            west_upper_right_perimeter_polygon = OpenStudio::Point3dVector.new
            west_upper_right_perimeter_polygon << center_ne_point
            west_upper_right_perimeter_polygon << right_nw_point
            west_upper_right_perimeter_polygon << perimeter_right_nw_point
            west_upper_right_perimeter_polygon << perimeter_center_ne_point
            west_upper_right_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(west_upper_right_perimeter_polygon, floor_to_floor_height, model)
            west_upper_right_perimeter_space = west_upper_right_perimeter_space.get
            m[0,3] = center_ne_point.x
            m[1,3] = center_ne_point.y
            m[2,3] = center_ne_point.z
            west_upper_right_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            west_upper_right_perimeter_space.setBuildingStory(story)
            west_upper_right_perimeter_space.setName("Story #{floor+1} West Upper Right Perimeter Space")


            north_right_perimeter_polygon = OpenStudio::Point3dVector.new
            north_right_perimeter_polygon << right_nw_point
            north_right_perimeter_polygon << right_ne_point
            north_right_perimeter_polygon << perimeter_right_ne_point
            north_right_perimeter_polygon << perimeter_right_nw_point
            north_right_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(north_right_perimeter_polygon, floor_to_floor_height, model)
            north_right_perimeter_space = north_right_perimeter_space.get
            m[0,3] = perimeter_right_nw_point.x
            m[1,3] = perimeter_right_nw_point.y
            m[2,3] = perimeter_right_nw_point.z
            north_right_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            north_right_perimeter_space.setBuildingStory(story)
            north_right_perimeter_space.setName("Story #{floor+1} North Right Perimeter Space")


            east_right_perimeter_polygon = OpenStudio::Point3dVector.new
            east_right_perimeter_polygon << right_ne_point
            east_right_perimeter_polygon << right_se_point
            east_right_perimeter_polygon << perimeter_right_se_point
            east_right_perimeter_polygon << perimeter_right_ne_point
            east_right_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(east_right_perimeter_polygon, floor_to_floor_height, model)
            east_right_perimeter_space = east_right_perimeter_space.get
            m[0,3] = perimeter_right_se_point.x
            m[1,3] = perimeter_right_se_point.y
            m[2,3] = perimeter_right_se_point.z
            east_right_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_right_perimeter_space.setBuildingStory(story)
            east_right_perimeter_space.setName("Story #{floor+1} East Right Perimeter Space")



            south_right_perimeter_polygon = OpenStudio::Point3dVector.new
            south_right_perimeter_polygon << right_se_point
            south_right_perimeter_polygon << right_sw_point
            south_right_perimeter_polygon << perimeter_right_sw_point
            south_right_perimeter_polygon << perimeter_right_se_point
            south_right_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(south_right_perimeter_polygon, floor_to_floor_height, model)
            south_right_perimeter_space = south_right_perimeter_space.get
            m[0,3] = right_sw_point.x
            m[1,3] = right_sw_point.y
            m[2,3] = right_sw_point.z
            south_right_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            south_right_perimeter_space.setBuildingStory(story)
            south_right_perimeter_space.setName("Story #{floor+1} South Right Perimeter Space")


            west_lower_right_perimeter_polygon = OpenStudio::Point3dVector.new
            west_lower_right_perimeter_polygon << right_sw_point
            west_lower_right_perimeter_polygon << center_se_point
            west_lower_right_perimeter_polygon << perimeter_center_se_point
            west_lower_right_perimeter_polygon << perimeter_right_sw_point
            west_lower_right_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(west_lower_right_perimeter_polygon, floor_to_floor_height, model)
            west_lower_right_perimeter_space = west_lower_right_perimeter_space.get
            m[0,3] = right_sw_point.x
            m[1,3] = right_sw_point.y
            m[2,3] = right_sw_point.z
            west_lower_right_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            west_lower_right_perimeter_space.setBuildingStory(story)
            west_lower_right_perimeter_space.setName("Story #{floor+1} West Lower Right Perimeter Space")


            south_center_perimeter_polygon = OpenStudio::Point3dVector.new
            south_center_perimeter_polygon << center_se_point
            south_center_perimeter_polygon << center_sw_point
            south_center_perimeter_polygon << perimeter_center_sw_point
            south_center_perimeter_polygon << perimeter_center_se_point
            south_center_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(south_center_perimeter_polygon, floor_to_floor_height, model)
            south_center_perimeter_space = south_center_perimeter_space.get
            m[0,3] = center_sw_point.x
            m[1,3] = center_sw_point.y
            m[2,3] = center_sw_point.z
            south_center_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            south_center_perimeter_space.setBuildingStory(story)
            south_center_perimeter_space.setName("Story #{floor+1} South Center Perimeter Space")


            east_lower_left_perimeter_polygon = OpenStudio::Point3dVector.new
            east_lower_left_perimeter_polygon << center_sw_point
            east_lower_left_perimeter_polygon << left_se_point
            east_lower_left_perimeter_polygon << perimeter_left_se_point
            east_lower_left_perimeter_polygon << perimeter_center_sw_point
            east_lower_left_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(east_lower_left_perimeter_polygon, floor_to_floor_height, model)
            east_lower_left_perimeter_space = east_lower_left_perimeter_space.get
            m[0,3] = perimeter_left_se_point.x
            m[1,3] = perimeter_left_se_point.y
            m[2,3] = perimeter_left_se_point.z
            east_lower_left_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_lower_left_perimeter_space.setBuildingStory(story)
            east_lower_left_perimeter_space.setName("Story #{floor+1} East Lower Left Perimeter Space")


            south_left_perimeter_polygon = OpenStudio::Point3dVector.new
            south_left_perimeter_polygon << left_se_point
            south_left_perimeter_polygon << left_sw_point
            south_left_perimeter_polygon << perimeter_left_sw_point
            south_left_perimeter_polygon << perimeter_left_se_point
            south_left_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(south_left_perimeter_polygon, floor_to_floor_height, model)
            south_left_perimeter_space = south_left_perimeter_space.get
            m[0,3] = left_sw_point.x
            m[1,3] = left_sw_point.y
            m[2,3] = left_sw_point.z
            south_left_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            south_left_perimeter_space.setBuildingStory(story)
            south_left_perimeter_space.setName("Story #{floor+1} South Left Perimeter Space")


            west_core_polygon = OpenStudio::Point3dVector.new
            west_core_polygon << perimeter_left_sw_point
            west_core_polygon << perimeter_left_nw_point
            west_core_polygon << perimeter_left_ne_point
            west_core_polygon << perimeter_center_nw_point
            west_core_polygon << perimeter_center_sw_point
            west_core_polygon << perimeter_left_se_point
            west_core_space = OpenStudio::Model::Space::fromFloorPrint(west_core_polygon, floor_to_floor_height, model)
            west_core_space = west_core_space.get
            m[0,3] = perimeter_left_sw_point.x
            m[1,3] = perimeter_left_sw_point.y
            m[2,3] = perimeter_left_sw_point.z
            west_core_space.changeTransformation(OpenStudio::Transformation.new(m))
            west_core_space.setBuildingStory(story)
            west_core_space.setName("Story #{floor+1} West Core Space")


            center_core_polygon = OpenStudio::Point3dVector.new
            center_core_polygon << perimeter_center_sw_point
            center_core_polygon << perimeter_center_nw_point
            center_core_polygon << perimeter_center_ne_point
            center_core_polygon << perimeter_center_se_point
            center_core_space = OpenStudio::Model::Space::fromFloorPrint(center_core_polygon, floor_to_floor_height, model)
            center_core_space = center_core_space.get
            m[0,3] = perimeter_center_sw_point.x
            m[1,3] = perimeter_center_sw_point.y
            m[2,3] = perimeter_center_sw_point.z
            center_core_space.changeTransformation(OpenStudio::Transformation.new(m))
            center_core_space.setBuildingStory(story)
            center_core_space.setName("Story #{floor+1} Center Core Space")


            east_core_polygon = OpenStudio::Point3dVector.new
            east_core_polygon << perimeter_right_sw_point
            east_core_polygon << perimeter_center_se_point
            east_core_polygon << perimeter_center_ne_point
            east_core_polygon << perimeter_right_nw_point
            east_core_polygon << perimeter_right_ne_point
            east_core_polygon << perimeter_right_se_point
            east_core_space = OpenStudio::Model::Space::fromFloorPrint(east_core_polygon, floor_to_floor_height, model)
            east_core_space = east_core_space.get
            m[0,3] = perimeter_right_sw_point.x
            m[1,3] = perimeter_right_sw_point.y
            m[2,3] = perimeter_right_sw_point.z
            east_core_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_core_space.setBuildingStory(story)
            east_core_space.setName("Story #{floor+1} East Core Space")


            # Minimal zones
          else
            west_polygon = OpenStudio::Point3dVector.new
            west_polygon << left_sw_point
            west_polygon << left_nw_point
            west_polygon << left_ne_point
            west_polygon << center_nw_point
            west_polygon << center_sw_point
            west_polygon << left_se_point
            west_space = OpenStudio::Model::Space::fromFloorPrint(west_polygon, floor_to_floor_height, model)
            west_space = west_space.get
            m[0,3] = left_sw_point.x
            m[1,3] = left_sw_point.y
            m[2,3] = left_sw_point.z
            west_space.changeTransformation(OpenStudio::Transformation.new(m))
            west_space.setBuildingStory(story)
            west_space.setName("Story #{floor+1} West Space")


            center_polygon = OpenStudio::Point3dVector.new
            center_polygon << center_sw_point
            center_polygon << center_nw_point
            center_polygon << center_ne_point
            center_polygon << center_se_point
            center_space = OpenStudio::Model::Space::fromFloorPrint(center_polygon, floor_to_floor_height, model)
            center_space = center_space.get
            m[0,3] = center_sw_point.x
            m[1,3] = center_sw_point.y
            m[2,3] = center_sw_point.z
            center_space.changeTransformation(OpenStudio::Transformation.new(m))
            center_space.setBuildingStory(story)
            center_space.setName("Story #{floor+1} Center Space")


            east_polygon = OpenStudio::Point3dVector.new
            east_polygon << right_sw_point
            east_polygon << center_se_point
            east_polygon << center_ne_point
            east_polygon << right_nw_point
            east_polygon << right_ne_point
            east_polygon << right_se_point
            east_space = OpenStudio::Model::Space::fromFloorPrint(east_polygon, floor_to_floor_height, model)
            east_space = east_space.get
            m[0,3] = right_sw_point.x
            m[1,3] = right_sw_point.y
            m[2,3] = right_sw_point.z
            east_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_space.setBuildingStory(story)
            east_space.setName("Story #{floor+1} East Space")


          end

          #Set vertical story position
          story.setNominalZCoordinate(z)

        end #End of floor loop
        BTAP::Geometry::match_surfaces(model)
        return model
      end

      def self.create_shape_l(
          model,
          length = 40.0,
          width = 40.0,
          lower_end_width = 20.0,
          upper_end_length = 20.0,
          num_floors = 3,
          floor_to_floor_height = 3.8,
          plenum_height = 1.0,
          perimeter_zone_depth = 4.57
        )

        if length <= 1e-4
          raise("Length must be greater than 0.")
          return false
        end

        if width <= 1e-4
          raise("Width must be greater than 0.")
          return false
        end

        if lower_end_width <= 1e-4 or lower_end_width >= (width - 1e-4)
          raise("Lower end width must be greater than 0 and less than #{width}m.")
          return false
        end

        if upper_end_length <= 1e-4 or upper_end_length >= (length - 1e-4)
          raise("Upper end length must be greater than 0 and less than #{length}m.")
          return false
        end

        if num_floors <= 1e-4
          raise("Number of floors must be greater than 0.")
          return false
        end

        if floor_to_floor_height <= 1e-4
          raise("Floor to floor height must be greater than 0.")
          return false
        end

        if plenum_height < 0
          raise("Plenum height must be greater than or equal to 0.")
          return false
        end

        shortest_side = [lower_end_width,upper_end_length].min
        if perimeter_zone_depth < 0 or 2*perimeter_zone_depth >= (shortest_side - 1e-4)
          raise("Perimeter zone depth must be greater than or equal to 0 and less than #{shortest_side/2}m.")
          return false
        end

        # Create progress bar
        #    runner.createProgressBar("Creating Spaces")
        #    num_total = perimeter_zone_depth>0 ? num_floors*8 : num_floors*2
        #    num_complete = 0

        # Loop through the number of floors
        for floor in (0..num_floors-1)

          z = floor_to_floor_height * floor

          #Create a new story within the building
          story = OpenStudio::Model::BuildingStory.new(model)
          story.setNominalFloortoFloorHeight(floor_to_floor_height)
          story.setName("Story #{floor+1}")


          nw_point = OpenStudio::Point3d.new(0,width,z)
          upper_ne_point = OpenStudio::Point3d.new(upper_end_length,width,z)
          upper_sw_point = OpenStudio::Point3d.new(upper_end_length,lower_end_width,z)
          lower_ne_point = OpenStudio::Point3d.new(length,lower_end_width,z)
          se_point = OpenStudio::Point3d.new(length,0,z)
          sw_point = OpenStudio::Point3d.new(0,0,z)

          # Identity matrix for setting space origins
          m = OpenStudio::Matrix.new(4,4,0)
          m[0,0] = 1
          m[1,1] = 1
          m[2,2] = 1
          m[3,3] = 1

          # Define polygons for a L-shape building with perimeter core zoning
          if perimeter_zone_depth > 0
            perimeter_nw_point = nw_point + OpenStudio::Vector3d.new(perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_upper_ne_point = upper_ne_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_upper_sw_point = upper_sw_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_lower_ne_point = lower_ne_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_se_point = se_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,perimeter_zone_depth,0)
            perimeter_lower_sw_point = sw_point + OpenStudio::Vector3d.new(perimeter_zone_depth,perimeter_zone_depth,0)

            west_perimeter_polygon  = OpenStudio::Point3dVector.new
            west_perimeter_polygon << sw_point
            west_perimeter_polygon << nw_point
            west_perimeter_polygon << perimeter_nw_point
            west_perimeter_polygon << perimeter_lower_sw_point
            west_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(west_perimeter_polygon, floor_to_floor_height, model)
            west_perimeter_space = west_perimeter_space.get
            m[0,3] = sw_point.x
            m[1,3] = sw_point.y
            m[2,3] = sw_point.z
            west_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            west_perimeter_space.setBuildingStory(story)
            west_perimeter_space.setName("Story #{floor+1} West Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            north_upper_perimeter_polygon = OpenStudio::Point3dVector.new
            north_upper_perimeter_polygon << nw_point
            north_upper_perimeter_polygon << upper_ne_point
            north_upper_perimeter_polygon << perimeter_upper_ne_point
            north_upper_perimeter_polygon << perimeter_nw_point
            north_upper_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(north_upper_perimeter_polygon, floor_to_floor_height, model)
            north_upper_perimeter_space = north_upper_perimeter_space.get
            m[0,3] = perimeter_nw_point.x
            m[1,3] = perimeter_nw_point.y
            m[2,3] = perimeter_nw_point.z
            north_upper_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            north_upper_perimeter_space.setBuildingStory(story)
            north_upper_perimeter_space.setName("Story #{floor+1} North Upper Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            east_upper_perimeter_polygon = OpenStudio::Point3dVector.new
            east_upper_perimeter_polygon << upper_ne_point
            east_upper_perimeter_polygon << upper_sw_point
            east_upper_perimeter_polygon << perimeter_upper_sw_point
            east_upper_perimeter_polygon << perimeter_upper_ne_point
            east_upper_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(east_upper_perimeter_polygon, floor_to_floor_height, model)
            east_upper_perimeter_space = east_upper_perimeter_space.get
            m[0,3] = perimeter_upper_sw_point.x
            m[1,3] = perimeter_upper_sw_point.y
            m[2,3] = perimeter_upper_sw_point.z
            east_upper_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_upper_perimeter_space.setBuildingStory(story)
            east_upper_perimeter_space.setName("Story #{floor+1} East Upper Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            north_lower_perimeter_polygon = OpenStudio::Point3dVector.new
            north_lower_perimeter_polygon << upper_sw_point
            north_lower_perimeter_polygon << lower_ne_point
            north_lower_perimeter_polygon << perimeter_lower_ne_point
            north_lower_perimeter_polygon << perimeter_upper_sw_point
            north_lower_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(north_lower_perimeter_polygon, floor_to_floor_height, model)
            north_lower_perimeter_space = north_lower_perimeter_space.get
            m[0,3] = perimeter_upper_sw_point.x
            m[1,3] = perimeter_upper_sw_point.y
            m[2,3] = perimeter_upper_sw_point.z
            north_lower_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            north_lower_perimeter_space.setBuildingStory(story)
            north_lower_perimeter_space.setName("Story #{floor+1} North Lower Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            east_lower_perimeter_polygon = OpenStudio::Point3dVector.new
            east_lower_perimeter_polygon << lower_ne_point
            east_lower_perimeter_polygon << se_point
            east_lower_perimeter_polygon << perimeter_se_point
            east_lower_perimeter_polygon << perimeter_lower_ne_point
            east_lower_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(east_lower_perimeter_polygon, floor_to_floor_height, model)
            east_lower_perimeter_space = east_lower_perimeter_space.get
            m[0,3] = perimeter_se_point.x
            m[1,3] = perimeter_se_point.y
            m[2,3] = perimeter_se_point.z
            east_lower_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_lower_perimeter_space.setBuildingStory(story)
            east_lower_perimeter_space.setName("Story #{floor+1} East Lower Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            south_perimeter_polygon = OpenStudio::Point3dVector.new
            south_perimeter_polygon << se_point
            south_perimeter_polygon << sw_point
            south_perimeter_polygon << perimeter_lower_sw_point
            south_perimeter_polygon << perimeter_se_point
            south_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(south_perimeter_polygon, floor_to_floor_height, model)
            south_perimeter_space = south_perimeter_space.get
            m[0,3] = sw_point.x
            m[1,3] = sw_point.y
            m[2,3] = sw_point.z
            south_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            south_perimeter_space.setBuildingStory(story)
            south_perimeter_space.setName("Story #{floor+1} South Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            west_core_polygon = OpenStudio::Point3dVector.new
            west_core_polygon << perimeter_lower_sw_point
            west_core_polygon << perimeter_nw_point
            west_core_polygon << perimeter_upper_ne_point
            west_core_polygon << perimeter_upper_sw_point
            west_core_space = OpenStudio::Model::Space::fromFloorPrint(west_core_polygon, floor_to_floor_height, model)
            west_core_space = west_core_space.get
            m[0,3] = perimeter_lower_sw_point.x
            m[1,3] = perimeter_lower_sw_point.y
            m[2,3] = perimeter_lower_sw_point.z
            west_core_space.changeTransformation(OpenStudio::Transformation.new(m))
            west_core_space.setBuildingStory(story)
            west_core_space.setName("Story #{floor+1} West Core Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            east_core_polygon = OpenStudio::Point3dVector.new
            east_core_polygon << perimeter_upper_sw_point
            east_core_polygon << perimeter_lower_ne_point
            east_core_polygon << perimeter_se_point
            east_core_polygon << perimeter_lower_sw_point
            east_core_space = OpenStudio::Model::Space::fromFloorPrint(east_core_polygon, floor_to_floor_height, model)
            east_core_space = east_core_space.get
            m[0,3] = perimeter_lower_sw_point.x
            m[1,3] = perimeter_lower_sw_point.y
            m[2,3] = perimeter_lower_sw_point.z
            east_core_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_core_space.setBuildingStory(story)
            east_core_space.setName("Story #{floor+1} East Core Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            # Minimal zones
          else
            west_polygon = OpenStudio::Point3dVector.new
            west_polygon << sw_point
            west_polygon << nw_point
            west_polygon << upper_ne_point
            west_polygon << upper_sw_point
            west_space = OpenStudio::Model::Space::fromFloorPrint(west_polygon, floor_to_floor_height, model)
            west_space = west_space.get
            m[0,3] = sw_point.x
            m[1,3] = sw_point.y
            m[2,3] = sw_point.z
            west_space.changeTransformation(OpenStudio::Transformation.new(m))
            west_space.setBuildingStory(story)
            west_space.setName("Story #{floor+1} West Space")

            num_complete += 1
            runner.updateProgress(100*num_complete/num_total)

            east_polygon = OpenStudio::Point3dVector.new
            east_polygon << sw_point
            east_polygon << upper_sw_point
            east_polygon << lower_ne_point
            east_polygon << se_point
            east_space = OpenStudio::Model::Space::fromFloorPrint(east_polygon, floor_to_floor_height, model)
            east_space = east_space.get
            m[0,3] = sw_point.x
            m[1,3] = sw_point.y
            m[2,3] = sw_point.z
            east_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_space.setBuildingStory(story)
            east_space.setName("Story #{floor+1} East Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

          end

          #Set vertical story position
          story.setNominalZCoordinate(z)

        end #End of floor loop
        BTAP::Geometry::match_surfaces(model)
        return model
      end

      def self.create_shape_rectangle(model,
          length = 100.0,
          width = 100.0,
          num_floors = 3,
          floor_to_floor_height = 3.8,
          plenum_height = 1,
          perimeter_zone_depth = 4.57
        )

        if length <= 1e-4
          raise("Length must be greater than 0.")
          return false
        end

        if width <= 1e-4
          raise("Width must be greater than 0.")
          return false
        end

        if num_floors <= 1e-4
          raise("Number of floors must be greater than 0.")
          return false
        end

        if floor_to_floor_height <= 1e-4
          raise("Floor to floor height must be greater than 0.")
          return false
        end

        if plenum_height < 0
          raise("Plenum height must be greater than or equal to 0.")
          return false
        end

        shortest_side = [length,width].min
        if perimeter_zone_depth < 0 or 2*perimeter_zone_depth >= (shortest_side - 1e-4)
          raise("Perimeter zone depth must be greater than or equal to 0 and less than #{shortest_side/2}m")
          return false
        end

        #    # Create progress bar
        #    runner.createProgressBar("Creating Spaces")
        #    num_total = perimeter_zone_depth>0 ? num_floors*5 : num_floors
        #    num_complete = 0

        #Loop through the number of floors
        for floor in (0..num_floors-1)

          z = floor_to_floor_height * floor

          #Create a new story within the building
          story = OpenStudio::Model::BuildingStory.new(model)
          story.setNominalFloortoFloorHeight(floor_to_floor_height)
          story.setName("Story #{floor+1}")


          nw_point = OpenStudio::Point3d.new(0,width,z)
          ne_point = OpenStudio::Point3d.new(length,width,z)
          se_point = OpenStudio::Point3d.new(length,0,z)
          sw_point = OpenStudio::Point3d.new(0,0,z)

          # Identity matrix for setting space origins
          m = OpenStudio::Matrix.new(4,4,0)
          m[0,0] = 1
          m[1,1] = 1
          m[2,2] = 1
          m[3,3] = 1

          #Define polygons for a rectangular building
          if perimeter_zone_depth > 0
            perimeter_nw_point = nw_point + OpenStudio::Vector3d.new(perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_ne_point = ne_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_se_point = se_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,perimeter_zone_depth,0)
            perimeter_sw_point = sw_point + OpenStudio::Vector3d.new(perimeter_zone_depth,perimeter_zone_depth,0)

            west_polygon = OpenStudio::Point3dVector.new
            west_polygon << sw_point
            west_polygon << nw_point
            west_polygon << perimeter_nw_point
            west_polygon << perimeter_sw_point
            west_space = OpenStudio::Model::Space::fromFloorPrint(west_polygon, floor_to_floor_height, model)
            west_space = west_space.get
            m[0,3] = sw_point.x
            m[1,3] = sw_point.y
            m[2,3] = sw_point.z
            west_space.changeTransformation(OpenStudio::Transformation.new(m))
            west_space.setBuildingStory(story)
            west_space.setName("Story #{floor+1} West Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            north_polygon = OpenStudio::Point3dVector.new
            north_polygon << nw_point
            north_polygon << ne_point
            north_polygon << perimeter_ne_point
            north_polygon << perimeter_nw_point
            north_space = OpenStudio::Model::Space::fromFloorPrint(north_polygon, floor_to_floor_height, model)
            north_space = north_space.get
            m[0,3] = perimeter_nw_point.x
            m[1,3] = perimeter_nw_point.y
            m[2,3] = perimeter_nw_point.z
            north_space.changeTransformation(OpenStudio::Transformation.new(m))
            north_space.setBuildingStory(story)
            north_space.setName("Story #{floor+1} North Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            east_polygon = OpenStudio::Point3dVector.new
            east_polygon << ne_point
            east_polygon << se_point
            east_polygon << perimeter_se_point
            east_polygon << perimeter_ne_point
            east_space = OpenStudio::Model::Space::fromFloorPrint(east_polygon, floor_to_floor_height, model)
            east_space = east_space.get
            m[0,3] = perimeter_se_point.x
            m[1,3] = perimeter_se_point.y
            m[2,3] = perimeter_se_point.z
            east_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_space.setBuildingStory(story)
            east_space.setName("Story #{floor+1} East Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            south_polygon = OpenStudio::Point3dVector.new
            south_polygon << se_point
            south_polygon << sw_point
            south_polygon << perimeter_sw_point
            south_polygon << perimeter_se_point
            south_space = OpenStudio::Model::Space::fromFloorPrint(south_polygon, floor_to_floor_height, model)
            south_space = south_space.get
            m[0,3] = sw_point.x
            m[1,3] = sw_point.y
            m[2,3] = sw_point.z
            south_space.changeTransformation(OpenStudio::Transformation.new(m))
            south_space.setBuildingStory(story)
            south_space.setName("Story #{floor+1} South Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            core_polygon = OpenStudio::Point3dVector.new
            core_polygon << perimeter_sw_point
            core_polygon << perimeter_nw_point
            core_polygon << perimeter_ne_point
            core_polygon << perimeter_se_point
            core_space = OpenStudio::Model::Space::fromFloorPrint(core_polygon, floor_to_floor_height, model)
            core_space = core_space.get
            m[0,3] = perimeter_sw_point.x
            m[1,3] = perimeter_sw_point.y
            m[2,3] = perimeter_sw_point.z
            core_space.changeTransformation(OpenStudio::Transformation.new(m))
            core_space.setBuildingStory(story)
            core_space.setName("Story #{floor+1} Core Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            # Minimal zones
          else
            core_polygon = OpenStudio::Point3dVector.new
            core_polygon << sw_point
            core_polygon << nw_point
            core_polygon << ne_point
            core_polygon << se_point
            core_space = OpenStudio::Model::Space::fromFloorPrint(core_polygon, floor_to_floor_height, model)
            core_space = core_space.get
            m[0,3] = sw_point.x
            m[1,3] = sw_point.y
            m[2,3] = sw_point.z
            core_space.changeTransformation(OpenStudio::Transformation.new(m))
            core_space.setBuildingStory(story)
            core_space.setName("Story #{floor+1} Core Space")
            #
            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

          end

          #Set vertical story position
          story.setNominalZCoordinate(z)

        end #End of floor loop

        #    runner.destroyProgressBar
        BTAP::Geometry::match_surfaces(model)
        return model
      end

      def self.create_shape_t(model,
          length = 40.0,
          width = 40.0,
          upper_end_width = 20.0,
          lower_end_length = 20.0,
          left_end_offset = 10.0,
          num_floors = 3,
          floor_to_floor_height = 3.8,
          plenum_height = 1.0,
          perimeter_zone_depth = 4.57
        )

        if length <= 1e-4
          raise("Length must be greater than 0.")
          return false
        end

        if width <= 1e-4
          raise("Width must be greater than 0.")
          return false
        end

        if upper_end_width <= 1e-4 or upper_end_width >= (width - 1e-4)
          raise("Upper end width must be greater than 0 and less than #{width}m.")
          return false
        end

        if lower_end_length <= 1e-4 or lower_end_length >= (length - 1e-4)
          raise("Lower end length must be greater than 0 and less than #{length}m.")
          return false
        end

        if left_end_offset <= 1e-4 or left_end_offset >= (length - lower_end_length - 1e-4)
          raise("Left end offset must be greater than 0 and less than #{length - lower_end_length}m.")
          return false
        end

        if num_floors <= 1e-4
          raise("Number of floors must be greater than 0.")
          return false
        end

        if floor_to_floor_height <= 1e-4
          raise("Floor to floor height must be greater than 0.")
          return false
        end

        if plenum_height < 0
          raise("Plenum height must be greater than or equal to 0.")
          return false
        end

        shortest_side = [length,width,upper_end_width,lower_end_length].min
        if perimeter_zone_depth < 0 or 2*perimeter_zone_depth >= (shortest_side - 1e-4)
          raise("Perimeter zone depth must be greater than or equal to 0 and less than #{shortest_side/2}m.")
          return false
        end

        # Create progress bar
        #    runner.createProgressBar("Creating Spaces")
        #    num_total = perimeter_zone_depth>0 ? num_floors*10 : num_floors*2
        #    num_complete = 0

        # Loop through the number of floors
        for floor in (0..num_floors-1)

          z = floor_to_floor_height * floor

          #Create a new story within the building
          story = OpenStudio::Model::BuildingStory.new(model)
          story.setNominalFloortoFloorHeight(floor_to_floor_height)
          story.setName("Story #{floor+1}")


          lower_ne_point = OpenStudio::Point3d.new(left_end_offset,width - upper_end_width,z)
          upper_sw_point = OpenStudio::Point3d.new(0,width - upper_end_width,z)
          upper_nw_point = OpenStudio::Point3d.new(0,width,z)
          upper_ne_point = OpenStudio::Point3d.new(length,width,z)
          upper_se_point = OpenStudio::Point3d.new(length,width - upper_end_width,z)
          lower_nw_point = OpenStudio::Point3d.new(left_end_offset + lower_end_length,width - upper_end_width,z)
          lower_se_point = OpenStudio::Point3d.new(left_end_offset + lower_end_length,0,z)
          lower_sw_point = OpenStudio::Point3d.new(left_end_offset,0,z)

          # Identity matrix for setting space origins
          m = OpenStudio::Matrix.new(4,4,0)
          m[0,0] = 1
          m[1,1] = 1
          m[2,2] = 1
          m[3,3] = 1

          # Define polygons for a L-shape building with perimeter core zoning
          if perimeter_zone_depth > 0
            perimeter_lower_ne_point = lower_ne_point + OpenStudio::Vector3d.new(perimeter_zone_depth,perimeter_zone_depth,0)
            perimeter_upper_sw_point = upper_sw_point + OpenStudio::Vector3d.new(perimeter_zone_depth,perimeter_zone_depth,0)
            perimeter_upper_nw_point = upper_nw_point + OpenStudio::Vector3d.new(perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_upper_ne_point = upper_ne_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_upper_se_point = upper_se_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,perimeter_zone_depth,0)
            perimeter_lower_nw_point = lower_nw_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,perimeter_zone_depth,0)
            perimeter_lower_se_point = lower_se_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,perimeter_zone_depth,0)
            perimeter_lower_sw_point = lower_sw_point + OpenStudio::Vector3d.new(perimeter_zone_depth,perimeter_zone_depth,0)

            west_lower_perimeter_polygon = OpenStudio::Point3dVector.new
            west_lower_perimeter_polygon << lower_sw_point
            west_lower_perimeter_polygon << lower_ne_point
            west_lower_perimeter_polygon << perimeter_lower_ne_point
            west_lower_perimeter_polygon << perimeter_lower_sw_point
            west_lower_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(west_lower_perimeter_polygon, floor_to_floor_height, model)
            west_lower_perimeter_space = west_lower_perimeter_space.get
            m[0,3] = lower_sw_point.x
            m[1,3] = lower_sw_point.y
            m[2,3] = lower_sw_point.z
            west_lower_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            west_lower_perimeter_space.setBuildingStory(story)
            west_lower_perimeter_space.setName("Story #{floor+1} West Lower Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            south_upper_left_perimeter_polygon = OpenStudio::Point3dVector.new
            south_upper_left_perimeter_polygon << lower_ne_point
            south_upper_left_perimeter_polygon << upper_sw_point
            south_upper_left_perimeter_polygon << perimeter_upper_sw_point
            south_upper_left_perimeter_polygon << perimeter_lower_ne_point
            south_upper_left_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(south_upper_left_perimeter_polygon, floor_to_floor_height, model)
            south_upper_left_perimeter_space = south_upper_left_perimeter_space.get
            m[0,3] = upper_sw_point.x
            m[1,3] = upper_sw_point.y
            m[2,3] = upper_sw_point.z
            south_upper_left_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            south_upper_left_perimeter_space.setBuildingStory(story)
            south_upper_left_perimeter_space.setName("Story #{floor+1} South Upper Left Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            west_upper_perimeter_polygon = OpenStudio::Point3dVector.new
            west_upper_perimeter_polygon << upper_sw_point
            west_upper_perimeter_polygon << upper_nw_point
            west_upper_perimeter_polygon << perimeter_upper_nw_point
            west_upper_perimeter_polygon << perimeter_upper_sw_point
            west_upper_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(west_upper_perimeter_polygon, floor_to_floor_height, model)
            west_upper_perimeter_space = west_upper_perimeter_space.get
            m[0,3] = upper_sw_point.x
            m[1,3] = upper_sw_point.y
            m[2,3] = upper_sw_point.z
            west_upper_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            west_upper_perimeter_space.setBuildingStory(story)
            west_upper_perimeter_space.setName("Story #{floor+1} West Upper Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            north_perimeter_polygon = OpenStudio::Point3dVector.new
            north_perimeter_polygon << upper_nw_point
            north_perimeter_polygon << upper_ne_point
            north_perimeter_polygon << perimeter_upper_ne_point
            north_perimeter_polygon << perimeter_upper_nw_point
            north_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(north_perimeter_polygon, floor_to_floor_height, model)
            north_perimeter_space = north_perimeter_space.get
            m[0,3] = perimeter_upper_nw_point.x
            m[1,3] = perimeter_upper_nw_point.y
            m[2,3] = perimeter_upper_nw_point.z
            north_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            north_perimeter_space.setBuildingStory(story)
            north_perimeter_space.setName("Story #{floor+1} North Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            east_upper_perimeter_polygon = OpenStudio::Point3dVector.new
            east_upper_perimeter_polygon << upper_ne_point
            east_upper_perimeter_polygon << upper_se_point
            east_upper_perimeter_polygon << perimeter_upper_se_point
            east_upper_perimeter_polygon << perimeter_upper_ne_point
            east_upper_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(east_upper_perimeter_polygon, floor_to_floor_height, model)
            east_upper_perimeter_space = east_upper_perimeter_space.get
            m[0,3] = perimeter_upper_se_point.x
            m[1,3] = perimeter_upper_se_point.y
            m[2,3] = perimeter_upper_se_point.z
            east_upper_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_upper_perimeter_space.setBuildingStory(story)
            east_upper_perimeter_space.setName("Story #{floor+1} East Upper Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            south_upper_right_perimeter_polygon = OpenStudio::Point3dVector.new
            south_upper_right_perimeter_polygon << upper_se_point
            south_upper_right_perimeter_polygon << lower_nw_point
            south_upper_right_perimeter_polygon << perimeter_lower_nw_point
            south_upper_right_perimeter_polygon << perimeter_upper_se_point
            south_upper_right_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(south_upper_right_perimeter_polygon, floor_to_floor_height, model)
            south_upper_right_perimeter_space = south_upper_right_perimeter_space.get
            m[0,3] = lower_nw_point.x
            m[1,3] = lower_nw_point.y
            m[2,3] = lower_nw_point.z
            south_upper_right_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            south_upper_right_perimeter_space.setBuildingStory(story)
            south_upper_right_perimeter_space.setName("Story #{floor+1} South Upper Left Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            east_lower_perimeter_polygon = OpenStudio::Point3dVector.new
            east_lower_perimeter_polygon << lower_nw_point
            east_lower_perimeter_polygon << lower_se_point
            east_lower_perimeter_polygon << perimeter_lower_se_point
            east_lower_perimeter_polygon << perimeter_lower_nw_point
            east_lower_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(east_lower_perimeter_polygon, floor_to_floor_height, model)
            east_lower_perimeter_space = east_lower_perimeter_space.get
            m[0,3] = perimeter_lower_se_point.x
            m[1,3] = perimeter_lower_se_point.y
            m[2,3] = perimeter_lower_se_point.z
            east_lower_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_lower_perimeter_space.setBuildingStory(story)
            east_lower_perimeter_space.setName("Story #{floor+1} East Lower Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            south_lower_perimeter_polygon = OpenStudio::Point3dVector.new
            south_lower_perimeter_polygon << lower_se_point
            south_lower_perimeter_polygon << lower_sw_point
            south_lower_perimeter_polygon << perimeter_lower_sw_point
            south_lower_perimeter_polygon << perimeter_lower_se_point
            south_lower_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(south_lower_perimeter_polygon, floor_to_floor_height, model)
            south_lower_perimeter_space = south_lower_perimeter_space.get
            m[0,3] = lower_sw_point.x
            m[1,3] = lower_sw_point.y
            m[2,3] = lower_sw_point.z
            south_lower_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            south_lower_perimeter_space.setBuildingStory(story)
            south_lower_perimeter_space.setName("Story #{floor+1} South Lower Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            north_core_polygon = OpenStudio::Point3dVector.new
            north_core_polygon << perimeter_upper_sw_point
            north_core_polygon << perimeter_upper_nw_point
            north_core_polygon << perimeter_upper_ne_point
            north_core_polygon << perimeter_upper_se_point
            north_core_polygon << perimeter_lower_nw_point
            north_core_polygon << perimeter_lower_ne_point
            north_core_space = OpenStudio::Model::Space::fromFloorPrint(north_core_polygon, floor_to_floor_height, model)
            north_core_space = north_core_space.get
            m[0,3] = perimeter_upper_sw_point.x
            m[1,3] = perimeter_upper_sw_point.y
            m[2,3] = perimeter_upper_sw_point.z
            north_core_space.changeTransformation(OpenStudio::Transformation.new(m))
            north_core_space.setBuildingStory(story)
            north_core_space.setName("Story #{floor+1} North Core Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            south_core_polygon = OpenStudio::Point3dVector.new
            south_core_polygon << perimeter_lower_sw_point
            south_core_polygon << perimeter_lower_ne_point
            south_core_polygon << perimeter_lower_nw_point
            south_core_polygon << perimeter_lower_se_point
            south_core_space = OpenStudio::Model::Space::fromFloorPrint(south_core_polygon, floor_to_floor_height, model)
            south_core_space = south_core_space.get
            m[0,3] = perimeter_lower_sw_point.x
            m[1,3] = perimeter_lower_sw_point.y
            m[2,3] = perimeter_lower_sw_point.z
            south_core_space.changeTransformation(OpenStudio::Transformation.new(m))
            south_core_space.setBuildingStory(story)
            south_core_space.setName("Story #{floor+1} South Core Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            # Minimal zones
          else
            north_polygon = OpenStudio::Point3dVector.new
            north_polygon << upper_sw_point
            north_polygon << upper_nw_point
            north_polygon << upper_ne_point
            north_polygon << upper_se_point
            north_polygon << lower_nw_point
            north_polygon << lower_ne_point
            north_space = OpenStudio::Model::Space::fromFloorPrint(north_polygon, floor_to_floor_height, model)
            north_space = north_space.get
            m[0,3] = upper_sw_point.x
            m[1,3] = upper_sw_point.y
            m[2,3] = upper_sw_point.z
            north_space.changeTransformation(OpenStudio::Transformation.new(m))
            north_space.setBuildingStory(story)
            north_space.setName("Story #{floor+1} North Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            south_polygon = OpenStudio::Point3dVector.new
            south_polygon << lower_sw_point
            south_polygon << lower_ne_point
            south_polygon << lower_nw_point
            south_polygon << lower_se_point
            south_space = OpenStudio::Model::Space::fromFloorPrint(south_polygon, floor_to_floor_height, model)
            south_space = south_space.get
            m[0,3] = lower_sw_point.x
            m[1,3] = lower_sw_point.y
            m[2,3] = lower_sw_point.z
            south_space.changeTransformation(OpenStudio::Transformation.new(m))
            south_space.setBuildingStory(story)
            south_space.setName("Story #{floor+1} South Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

          end

          #Set vertical story position
          story.setNominalZCoordinate(z)

        end #End of floor loop

        BTAP::Geometry::match_surfaces(model)
        return model
      end

      def self.create_shape_u(model,
          length = 40.0,
          left_width = 40.0,
          right_width = 40.0,
          left_end_length = 15.0,
          right_end_length = 15.0,
          left_end_offset = 25.0,
          num_floors = 3.0,
          floor_to_floor_height = 3.8,
          plenum_height = 1.0,
          perimeter_zone_depth = 4.57
        )

        if length <= 1e-4
          raise("Length must be greater than 0.")
          return false
        end

        if left_width <= 1e-4
          raise("Left width must be greater than 0.")
          return false
        end

        if left_end_length <= 1e-4 or left_end_length >= (length - 1e-4)
          raise("Left end length must be greater than 0 and less than #{length}m.")
          return false
        end

        if right_end_length <= 1e-4 or right_end_length >= (length - left_end_length - 1e-4)
          raise("Right end length must be greater than 0 and less than #{length - left_end_length}m.")
          return false
        end

        if left_end_offset <= 1e-4 or left_end_offset >= (left_width - 1e-4)
          raise("Left end offset must be greater than 0 and less than #{left_width}m.")
          return false
        end

        if right_width <= (left_width - left_end_offset - 1e-4)
          raise("Right width must be greater than #{left_width - left_end_offset}m.")
          return false
        end

        if num_floors <= 1e-4
          raise("Number of floors must be greater than 0.")
          return false
        end

        if floor_to_floor_height <= 1e-4
          raise("Floor to floor height must be greater than 0.")
          return false
        end

        if plenum_height < 0
          raise("Plenum height must be greater than or equal to 0.")
          return false
        end

        shortest_side = [length/2,left_width,right_width,left_end_length,right_end_length,left_width-left_end_offset].min
        if perimeter_zone_depth < 0 or 2*perimeter_zone_depth >= (shortest_side - 1e-4)
          raise("Perimeter zone depth must be greater than or equal to 0 and less than #{shortest_side/2}m.")
          return false
        end

        # Create progress bar
        #    runner.createProgressBar("Creating Spaces")
        #    num_total = perimeter_zone_depth>0 ? num_floors*11 : num_floors*3
        #    num_complete = 0

        # Loop through the number of floors
        for floor in (0..num_floors-1)

          z = floor_to_floor_height * floor

          #Create a new story within the building
          story = OpenStudio::Model::BuildingStory.new(model)
          story.setNominalFloortoFloorHeight(floor_to_floor_height)
          story.setName("Story #{floor+1}")


          left_nw_point = OpenStudio::Point3d.new(0,left_width,z)
          left_ne_point = OpenStudio::Point3d.new(left_end_length,left_width,z)
          upper_sw_point = OpenStudio::Point3d.new(left_end_length,left_width - left_end_offset,z)
          upper_se_point = OpenStudio::Point3d.new(length - right_end_length,left_width - left_end_offset,z)
          right_nw_point = OpenStudio::Point3d.new(length - right_end_length,right_width,z)
          right_ne_point = OpenStudio::Point3d.new(length,right_width,z)
          lower_se_point = OpenStudio::Point3d.new(length,0,z)
          lower_sw_point = OpenStudio::Point3d.new(0,0,z)

          # Identity matrix for setting space origins
          m = OpenStudio::Matrix.new(4,4,0)
          m[0,0] = 1
          m[1,1] = 1
          m[2,2] = 1
          m[3,3] = 1

          # Define polygons for a L-shape building with perimeter core zoning
          if perimeter_zone_depth > 0
            perimeter_left_nw_point = left_nw_point + OpenStudio::Vector3d.new(perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_left_ne_point = left_ne_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_upper_sw_point = upper_sw_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_upper_se_point = upper_se_point + OpenStudio::Vector3d.new(perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_right_nw_point = right_nw_point + OpenStudio::Vector3d.new(perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_right_ne_point = right_ne_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,-perimeter_zone_depth,0)
            perimeter_lower_se_point = lower_se_point + OpenStudio::Vector3d.new(-perimeter_zone_depth,perimeter_zone_depth,0)
            perimeter_lower_sw_point = lower_sw_point + OpenStudio::Vector3d.new(perimeter_zone_depth,perimeter_zone_depth,0)

            west_left_perimeter_polygon = OpenStudio::Point3dVector.new
            west_left_perimeter_polygon << lower_sw_point
            west_left_perimeter_polygon << left_nw_point
            west_left_perimeter_polygon << perimeter_left_nw_point
            west_left_perimeter_polygon << perimeter_lower_sw_point
            west_left_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(west_left_perimeter_polygon, floor_to_floor_height, model)
            west_left_perimeter_space = west_left_perimeter_space.get
            m[0,3] = lower_sw_point.x
            m[1,3] = lower_sw_point.y
            m[2,3] = lower_sw_point.z
            west_left_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            west_left_perimeter_space.setBuildingStory(story)
            west_left_perimeter_space.setName("Story #{floor+1} West Left Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            north_left_perimeter_polygon = OpenStudio::Point3dVector.new
            north_left_perimeter_polygon << left_nw_point
            north_left_perimeter_polygon << left_ne_point
            north_left_perimeter_polygon << perimeter_left_ne_point
            north_left_perimeter_polygon << perimeter_left_nw_point
            north_left_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(north_left_perimeter_polygon, floor_to_floor_height, model)
            north_left_perimeter_space = north_left_perimeter_space.get
            m[0,3] = perimeter_left_nw_point.x
            m[1,3] = perimeter_left_nw_point.y
            m[2,3] = perimeter_left_nw_point.z
            north_left_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            north_left_perimeter_space.setBuildingStory(story)
            north_left_perimeter_space.setName("Story #{floor+1} North Left Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            east_left_perimeter_polygon = OpenStudio::Point3dVector.new
            east_left_perimeter_polygon << left_ne_point
            east_left_perimeter_polygon << upper_sw_point
            east_left_perimeter_polygon << perimeter_upper_sw_point
            east_left_perimeter_polygon << perimeter_left_ne_point
            east_left_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(east_left_perimeter_polygon, floor_to_floor_height, model)
            east_left_perimeter_space = east_left_perimeter_space.get
            m[0,3] = perimeter_upper_sw_point.x
            m[1,3] = perimeter_upper_sw_point.y
            m[2,3] = perimeter_upper_sw_point.z
            east_left_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_left_perimeter_space.setBuildingStory(story)
            east_left_perimeter_space.setName("Story #{floor+1} East Left Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            north_lower_perimeter_polygon = OpenStudio::Point3dVector.new
            north_lower_perimeter_polygon << upper_sw_point
            north_lower_perimeter_polygon << upper_se_point
            north_lower_perimeter_polygon << perimeter_upper_se_point
            north_lower_perimeter_polygon << perimeter_upper_sw_point
            north_lower_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(north_lower_perimeter_polygon, floor_to_floor_height, model)
            north_lower_perimeter_space = north_lower_perimeter_space.get
            m[0,3] = perimeter_upper_sw_point.x
            m[1,3] = perimeter_upper_sw_point.y
            m[2,3] = perimeter_upper_sw_point.z
            north_lower_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            north_lower_perimeter_space.setBuildingStory(story)
            north_lower_perimeter_space.setName("Story #{floor+1} North Lower Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            west_right_perimeter_polygon = OpenStudio::Point3dVector.new
            west_right_perimeter_polygon << upper_se_point
            west_right_perimeter_polygon << right_nw_point
            west_right_perimeter_polygon << perimeter_right_nw_point
            west_right_perimeter_polygon << perimeter_upper_se_point
            west_right_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(west_right_perimeter_polygon, floor_to_floor_height, model)
            west_right_perimeter_space = west_right_perimeter_space.get
            m[0,3] = upper_se_point.x
            m[1,3] = upper_se_point.y
            m[2,3] = upper_se_point.z
            west_right_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            west_right_perimeter_space.setBuildingStory(story)
            west_right_perimeter_space.setName("Story #{floor+1} West Right Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            north_right_perimeter_polygon = OpenStudio::Point3dVector.new
            north_right_perimeter_polygon << right_nw_point
            north_right_perimeter_polygon << right_ne_point
            north_right_perimeter_polygon << perimeter_right_ne_point
            north_right_perimeter_polygon << perimeter_right_nw_point
            north_right_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(north_right_perimeter_polygon, floor_to_floor_height, model)
            north_right_perimeter_space = north_right_perimeter_space.get
            m[0,3] = perimeter_right_nw_point.x
            m[1,3] = perimeter_right_nw_point.y
            m[2,3] = perimeter_right_nw_point.z
            north_right_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            north_right_perimeter_space.setBuildingStory(story)
            north_right_perimeter_space.setName("Story #{floor+1} North Right Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            east_right_perimeter_polygon = OpenStudio::Point3dVector.new
            east_right_perimeter_polygon << right_ne_point
            east_right_perimeter_polygon << lower_se_point
            east_right_perimeter_polygon << perimeter_lower_se_point
            east_right_perimeter_polygon << perimeter_right_ne_point
            east_right_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(east_right_perimeter_polygon, floor_to_floor_height, model)
            east_right_perimeter_space = east_right_perimeter_space.get
            m[0,3] = perimeter_lower_se_point.x
            m[1,3] = perimeter_lower_se_point.y
            m[2,3] = perimeter_lower_se_point.z
            east_right_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_right_perimeter_space.setBuildingStory(story)
            east_right_perimeter_space.setName("Story #{floor+1} East Right Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            south_lower_perimeter_polygon = OpenStudio::Point3dVector.new
            south_lower_perimeter_polygon << lower_se_point
            south_lower_perimeter_polygon << lower_sw_point
            south_lower_perimeter_polygon << perimeter_lower_sw_point
            south_lower_perimeter_polygon << perimeter_lower_se_point
            south_lower_perimeter_space = OpenStudio::Model::Space::fromFloorPrint(south_lower_perimeter_polygon, floor_to_floor_height, model)
            south_lower_perimeter_space = south_lower_perimeter_space.get
            m[0,3] = lower_sw_point.x
            m[1,3] = lower_sw_point.y
            m[2,3] = lower_sw_point.z
            south_lower_perimeter_space.changeTransformation(OpenStudio::Transformation.new(m))
            south_lower_perimeter_space.setBuildingStory(story)
            south_lower_perimeter_space.setName("Story #{floor+1} South Lower Perimeter Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            west_core_polygon = OpenStudio::Point3dVector.new
            west_core_polygon << perimeter_lower_sw_point
            west_core_polygon << perimeter_left_nw_point
            west_core_polygon << perimeter_left_ne_point
            west_core_polygon << perimeter_upper_sw_point
            west_core_space = OpenStudio::Model::Space::fromFloorPrint(west_core_polygon, floor_to_floor_height, model)
            west_core_space = west_core_space.get
            m[0,3] = perimeter_lower_sw_point.x
            m[1,3] = perimeter_lower_sw_point.y
            m[2,3] = perimeter_lower_sw_point.z
            west_core_space.changeTransformation(OpenStudio::Transformation.new(m))
            west_core_space.setBuildingStory(story)
            west_core_space.setName("Story #{floor+1} West Core Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            south_core_polygon = OpenStudio::Point3dVector.new
            south_core_polygon << perimeter_upper_sw_point
            south_core_polygon << perimeter_upper_se_point
            south_core_polygon << perimeter_lower_se_point
            south_core_polygon << perimeter_lower_sw_point
            south_core_space = OpenStudio::Model::Space::fromFloorPrint(south_core_polygon, floor_to_floor_height, model)
            south_core_space = south_core_space.get
            m[0,3] = perimeter_lower_sw_point.x
            m[1,3] = perimeter_lower_sw_point.y
            m[2,3] = perimeter_lower_sw_point.z
            south_core_space.changeTransformation(OpenStudio::Transformation.new(m))
            south_core_space.setBuildingStory(story)
            south_core_space.setName("Story #{floor+1} South Core Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            east_core_polygon = OpenStudio::Point3dVector.new
            east_core_polygon << perimeter_upper_se_point
            east_core_polygon << perimeter_right_nw_point
            east_core_polygon << perimeter_right_ne_point
            east_core_polygon << perimeter_lower_se_point
            east_core_space = OpenStudio::Model::Space::fromFloorPrint(east_core_polygon, floor_to_floor_height, model)
            east_core_space = east_core_space.get
            m[0,3] = perimeter_upper_se_point.x
            m[1,3] = perimeter_upper_se_point.y
            m[2,3] = perimeter_upper_se_point.z
            east_core_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_core_space.setBuildingStory(story)
            east_core_space.setName("Story #{floor+1} East Core Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            # Minimal zones
          else
            west_polygon = OpenStudio::Point3dVector.new
            west_polygon << lower_sw_point
            west_polygon << left_nw_point
            west_polygon << left_ne_point
            west_polygon << upper_sw_point
            west_space = OpenStudio::Model::Space::fromFloorPrint(west_polygon, floor_to_floor_height, model)
            west_space = west_space.get
            m[0,3] = lower_sw_point.x
            m[1,3] = lower_sw_point.y
            m[2,3] = lower_sw_point.z
            west_space.changeTransformation(OpenStudio::Transformation.new(m))
            west_space.setBuildingStory(story)
            west_space.setName("Story #{floor+1} West Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            south_polygon = OpenStudio::Point3dVector.new
            south_polygon << lower_sw_point
            south_polygon << upper_sw_point
            south_polygon << upper_se_point
            south_polygon << lower_se_point
            south_space = OpenStudio::Model::Space::fromFloorPrint(south_polygon, floor_to_floor_height, model)
            south_space = south_space.get
            m[0,3] = lower_sw_point.x
            m[1,3] = lower_sw_point.y
            m[2,3] = lower_sw_point.z
            south_space.changeTransformation(OpenStudio::Transformation.new(m))
            south_space.setBuildingStory(story)
            south_space.setName("Story #{floor+1} South Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

            east_polygon = OpenStudio::Point3dVector.new
            east_polygon << upper_se_point
            east_polygon << right_nw_point
            east_polygon << right_ne_point
            east_polygon << lower_se_point
            east_space = OpenStudio::Model::Space::fromFloorPrint(east_polygon, floor_to_floor_height, model)
            east_space = east_space.get
            m[0,3] = upper_se_point.x
            m[1,3] = upper_se_point.y
            m[2,3] = upper_se_point.z
            east_space.changeTransformation(OpenStudio::Transformation.new(m))
            east_space.setBuildingStory(story)
            east_space.setName("Story #{floor+1} East Space")

            #        num_complete += 1
            #        runner.updateProgress(100*num_complete/num_total)

          end

          #Set vertical story position
          story.setNominalZCoordinate(z)

        end #End of floor loop

        #    runner.destroyProgressBar
        BTAP::Geometry::match_surfaces(model)
        return model
      end

      def self.test_geometry()
        courtyard = OpenStudio::Model::Model.new()
        Geometry.create_shape_courtyard(courtyard)
        courtyard.save(OpenStudio::Path.new(BTAP::TESTING_FOLDER + "/courtyard.osm"))

        rectangle = OpenStudio::Model::Model.new()
        Geometry.create_shape_rectangle(rectangle)
        Geometry.scale_model(rectangle,2,0.5,1.0)
        Geometry.rotate_model(rectangle,45.0)
        File.delete(BTAP::TESTING_FOLDER + "/rectangle.osm")
        rectangle.save(OpenStudio::Path.new(BTAP::TESTING_FOLDER + "/rectangle.osm"))

        l_shape = OpenStudio::Model::Model.new()
        Geometry.create_shape_l(l_shape)
        l_shape.save(OpenStudio::Path.new(BTAP::TESTING_FOLDER + "/l_shape.osm"))

        h_shape = OpenStudio::Model::Model.new()
        Geometry.create_shape_h(h_shape)
        h_shape.save(OpenStudio::Path.new(BTAP::TESTING_FOLDER + "/h_shape.osm"))

        t_shape = OpenStudio::Model::Model.new()
        Geometry.create_shape_t(t_shape)
        t_shape.save(OpenStudio::Path.new(BTAP::TESTING_FOLDER + "/t_shape.osm"))

        u_shape = OpenStudio::Model::Model.new()
        Geometry.create_shape_u(u_shape)
        u_shape.save(OpenStudio::Path.new(BTAP::TESTING_FOLDER + "/u_shape.osm"))
      end
    end
    def self.match_surfaces(model)
      model.getSpaces.each do |space1|
        model.getSpaces.each do |space2|
          space1.matchSurfaces(space2)
        end
      end
      return model
    end
    # This method will scale the model
    # @params model [OpenStudio::Model::Model] the model object.
    # @params x [Float] x scalar multiplier.
    # @params y [Float] y scalar multiplier.
    # @params z [Float] z scalar multiplier.
    # @return model [OpenStudio::Model::Model] the model object.
    def self.scale_model(model,x,y,z)
      # Identity matrix for setting space origins
      m = OpenStudio::Matrix.new(4,4,0)

      m[0,0] = 1.0/x
      m[1,1] = 1.0/y
      m[2,2] = 1.0/z
      m[3,3] = 1.0
      t = OpenStudio::Transformation.new(m)
      model.getPlanarSurfaceGroups().each do |planar_surface|
        planar_surface.changeTransformation(t)
      end
      return model
    end

    def self.get_fwdr(model)
      outdoor_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(model.getSurfaces(), "Outdoors")
      outdoor_walls = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Wall")
      self.get_surface_to_subsurface_ratio(outdoor_walls)
    end

    def self.get_srr(model)
      outdoor_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(model.getSurfaces(), "Outdoors")
      outdoor_roofs = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "RoofCeiling")
      self.get_surface_to_subsurface_ratio(outdoor_roofs)
    end

    def self.get_surface_to_subsurface_ratio(surfaces)
      total_gross_surface_area = 0.0
      total_net_surface_area = 0.0
      surfaces.each do |surface|
        total_gross_surface_area  = total_gross_surface_area + surface.grossArea
        total_net_surface_area = total_net_surface_area + surface.netArea
      end
      return 1.0  - (total_net_surface_area/total_gross_surface_area )
    end



    # This method will rotate the model
    # @params model [OpenStudio::Model::Model] the model object.
    # @params degrees [Float] rotation value
    # @return model [OpenStudio::Model::Model] the model object.
    def self.rotate_model(model, degrees)
      # Identity matrix for setting space origins
      t = OpenStudio::Transformation::rotation(OpenStudio::Vector3d.new(0,0,1),degrees*Math::PI/180)
      model.getPlanarSurfaceGroups().each { |planar_surface| planar_surface.changeTransformation(t) }
      return model
    end


    module BuildingStoreys

      #This method will delete any exisiting stories and then try to assign stories based on 
      # the z-axis origin of the space.
      def self.auto_assign_spaces_to_stories(model)
        #delete existing stories.
        model.getBuildingStorys.each {|buildingstory| buildingstory.remove }
        #create hash of building storeys, index is the Z-axis origin of the space.
        building_story_hash = Hash.new()
        model.getSpaces.each do |space|
          if building_story_hash[space.zOrigin].nil?
            building_story_hash[space.zOrigin] = OpenStudio::Model::BuildingStory.new(model)
            building_story_hash[space.zOrigin].setName( building_story_hash.length.to_s )
          end


          space.setBuildingStory(building_story_hash[space.zOrigin])
        end
      end
      
      #Get the zones in a storey
      def self.get_zones_from_storey(storey)
        #check to see if the storey has a zone that is part of the zone list. 
        zones = Array.new
        storey.spaces.each do |space|
          if not space.thermalZone.empty?  and not zones.include?(space.thermalZone.get)
            zones.push( space.thermalZone.get )
          end
        end
        return zones
      end
      
      
      # override run to implement the functionality of your script
      # model is an OpenStudio::Model::Model, runner is a OpenStudio::Ruleset::UserScriptRunner
      def self.auto_assign_stories(model)    

        # get all spaces
        spaces = model.getSpaces
    
        puts("Assigning Stories to Spaces")
  
        # make has of spaces and minz values
        sorted_spaces = Hash.new
        spaces.each do |space|
          # loop through space surfaces to find min z value
          z_points = []
          space.surfaces.each do |surface|
            surface.vertices.each do |vertex|
              z_points << vertex.z
            end
          end
          minz = z_points.min + space.zOrigin
          sorted_spaces[space] = minz
        end
  
        # pre-sort spaces
        sorted_spaces = sorted_spaces.sort{|a,b| a[1]<=>b[1]} 
  
  
        # this should take the sorted list and make and assign stories
        sorted_spaces.each do |space|
          space_obj = space[0]
          space_minz = space[1]
          if space_obj.buildingStory.empty?
          
            story = getStoryForNominalZCoordinate(model, space_minz)
            puts("Setting story of Space " + space_obj.name.get + " to " + story.name.get + ".")
            space_obj.setBuildingStory(story)
          end
        end
      end
  
      # find the first story with z coordinate, create one if needed
      def self.getStoryForNominalZCoordinate(model, minz)
  
        model.getBuildingStorys.each do |story|
          z = story.nominalZCoordinate
          if not z.empty?
            if minz == z.get
              return story
            end
          end
        end
    
        story = OpenStudio::Model::BuildingStory.new(model)
        story.setNominalZCoordinate(minz)
        return story
      end
      
    end


    #This module contains helper functions that deal with Space objects.
    module Spaces

      #This method will return the horizontal placement type. (N,S,W,E,C) In the 
      # case of a corner, it will take whatever surface area it faces is the 
      # largest. It will also return the top, bottom or middle conditions.   
      
      def self.get_space_placement(space)
        horizontal_placement = nil
        vertical_placement = nil
        
        #get all exterior surfaces. 
        surfaces =  BTAP::Geometry::Surfaces::filter_by_boundary_condition(space.surfaces, ["Outdoors",
            "Ground",
            "GroundFCfactorMethod",
            "GroundSlabPreprocessorAverage",
            "GroundSlabPreprocessorCore",
            "GroundSlabPreprocessorPerimeter",
            "GroundBasementPreprocessorAverageWall",
            "GroundBasementPreprocessorAverageFloor",
            "GroundBasementPreprocessorUpperWall",
            "GroundBasementPreprocessorLowerWall"])

        #exterior Surfaces
        ext_wall_surfaces = BTAP::Geometry::Surfaces::filter_by_surface_types(surfaces,["Wall"])
        ext_bottom_surface = BTAP::Geometry::Surfaces::filter_by_surface_types(surfaces,["Floor"])
        ext_top_surface = BTAP::Geometry::Surfaces::filter_by_surface_types(surfaces,["RoofCeiling"])
        
        #Interior Surfaces..if needed....
        internal_surfaces =  BTAP::Geometry::Surfaces::filter_by_boundary_condition( space.surfaces, ["Surface"] )
        int_wall_surfaces = BTAP::Geometry::Surfaces::filter_by_surface_types( internal_surfaces,["Wall"] )
        int_bottom_surface = BTAP::Geometry::Surfaces::filter_by_surface_types( internal_surfaces,["Floor"] )
        int_top_surface = BTAP::Geometry::Surfaces::filter_by_surface_types( internal_surfaces,["RoofCeiling"] )
        
        
        vertical_placement = "NA"
        #determine if space is a top or bottom, both or middle space. 
        if ext_bottom_surface.size > 0 and ext_top_surface.size > 0 and int_bottom_surface.size == 0 and int_top_surface.size == 0
          vertical_placement = "single_story_space"
        elsif  int_bottom_surface.size > 0 and ext_top_surface.size > 0 and int_bottom_surface.size > 0 
          vertical_placement = "top"
        elsif ext_bottom_surface.size > 0 and ext_top_surface.size == 0 
          vertical_placement = "bottom"
        elsif ext_bottom_surface.size == 0 and ext_top_surface.size == 0
          vertical_placement = "middle"
        end


        
        #determine if what cardinal direction has the majority of external 
        #surface area of the space. 

        walls_area_array = Array.new
        [0,1,2,3].each { |index| walls_area_array[index] = 0.0 }
        #east is defined as 315-45 degs
        BTAP::Geometry::Surfaces::filter_by_azimuth_and_tilt(ext_wall_surfaces,  0.00,   45.0, 0.00, 180.00).each do |surface|
          #          puts "northern surface found 0-46: #{surface}"
          #          puts surface.azimuth / ( Math::PI / 180.0 )
          walls_area_array[0]  = walls_area_array[0]  + surface.grossArea
        end
        BTAP::Geometry::Surfaces::filter_by_azimuth_and_tilt(ext_wall_surfaces,  315.001,   360.0, 0.00, 180.00).each do |surface|
          #          puts "northern surface found: #{surface}"
          #          puts surface.azimuth / ( Math::PI / 180.0 )
          walls_area_array[0]  = walls_area_array[0]  + surface.grossArea
        end
        
        BTAP::Geometry::Surfaces::filter_by_azimuth_and_tilt(ext_wall_surfaces,  45.001,   135.0, 0.00, 180.00).each do |surface|
          #          puts "eastern surface found: #{surface}"
          #          puts surface.azimuth / ( Math::PI / 180.0 )
          walls_area_array[1]  = walls_area_array[1]  + surface.grossArea
        end
        
        BTAP::Geometry::Surfaces::filter_by_azimuth_and_tilt(ext_wall_surfaces,  135.001,   225.0, 0.00, 180.00).each do |surface|
          #          puts "south surface found: #{surface}"
          #          puts surface.azimuth / ( Math::PI / 180.0 )
          walls_area_array[2]  = walls_area_array[2]  + surface.grossArea
        end
        
        BTAP::Geometry::Surfaces::filter_by_azimuth_and_tilt(ext_wall_surfaces,  225.001,   315.0, 0.00, 180.00).each do |surface|
          #          puts "west surface found: #{surface}"
          #          puts surface.azimuth / ( Math::PI / 180.0 )
          walls_area_array[3]  = walls_area_array[3]  + surface.grossArea
        end
        
        
        
        #find our which cardinal driection has the most exterior surface and declare it that orientation.  
        case walls_area_array.index(walls_area_array.max)
        when 0
          horizontal_placement = "north"
        when 1
          horizontal_placement = "east"
        when 2
          horizontal_placement = "south"
        when 3
          horizontal_placement = "west"
        end
        if walls_area_array.inject{|sum,x| sum + x } == 0.0
          horizontal_placement = "core"
        end
        return horizontal_placement , vertical_placement
      end
      
      

      def self.is_perimeter_space?(model,space)
        return Array.new(BTAP::Common::validate_array(model,space,"Space").first.surfaces).filterByBoundaryConditions(["Outdoors","Ground",
            "GroundFCfactorMethod",
            "GroundSlabPreprocessorAverage",
            "GroundSlabPreprocessorCore",
            "GroundSlabPreprocessorPerimeter",
            "GroundBasementPreprocessorAverageWall",
            "GroundBasementPreprocessorAverageFloor",
            "GroundBasementPreprocessorUpperWall",
            "GroundBasementPreprocessorLowerWall"]).size > 0

      end
      def self.show(model,space)
        if drawing_interface = BTAP::Common::validate_array(model,space,"Space").first.drawing_interface
          if entity = drawing_interface.entity
            entity.visible = true
          end
        end
      end
      def self.hide(model,space)
        if drawing_interface = BTAP::Common::validate_array(model,space,"Space").first.drawing_interface
          if entity = drawing_interface.entity
            entity.visible = false
          end
        end
      end










      # This method will return a Array of surfaces that are contained within the
      # passed spaces. Note: if you wish to avoid to create an array of spaces,
      # simply put the space variable in [] brackets
      # Ex: get_all_surfaces_from_spaces( [space1,space2] )
      # @params spaces_array an array of type [OpenStudio::Model::Space]
      # @return an array of surfaces contained in the passed spaces.
      def self.get_surfaces_from_spaces(model, spaces_array)
        BTAP::Geometry::Surfaces::get_surfaces_from_spaces(spaces_array)
      end

      # This method will return a SpaceArray of surfaces that are contained within the
      # passed floors. Note: if you wish to avoid to create an array of spaces,
      # simply put the space variable in [] brackets
      # Ex: get_all_surfaces_from_spaces( [space1,space2] )
      # @params spaces_array an array of type [OpenStudio::Model::Space]
      # @return an array of surfaces contained in the passed spaces.
      def self.get_spaces_from_storeys(model,floors)
        floors = BTAP::Common::validate_array(model,floors,"BuildingStory")
        spaces = Array.new()
        floors.each { |floor| spaces.concat(floor.spaces) }
        return spaces
      end

      # This method will filter an array of spaces that have an external wall
      # passed floors. Note: if you wish to avoid to create an array of spaces,
      # simply put the space variable in [] brackets
      # Ex: get_all_surfaces_from_spaces( [space1,space2] )
      # @params spaces_array an array of type [OpenStudio::Model::Space]
      # @return an array of spaces.
      def self.filter_perimeter_spaces(model, spaces_array)
        spaces_array = BTAP::Common::validate_array(model,spaces_array,"Space")
        array = Array.new()
        spaces_array.each do |space|
          if space.is_a_perimeter_space?()
            array.push(space)
          end
        end
        return array
      end

      # This method will filter an array of spaces that have no external wall
      # passed floors. Note: if you wish to avoid to create an array of spaces,
      # simply put the space variable in [] brackets
      # Ex: get_all_surfaces_from_spaces( [space1,space2] )
      # @params spaces_array an array of type [OpenStudio::Model::Space]
      # @return an array of spaces.
      def self.filter_core_spaces(model,spaces_array)
        spaces_array = BTAP::Common::validate_array(model,spaces_array,"Space")
        array = Array.new()
        spaces_array.each do |space|
          unless space.is_a_perimeter_space?()
            array.push(space)
          end
        end
        return array
      end


      def self.filter_spaces_by_space_types(model,spaces_array,spacetype_array)
        spaces_array = BTAP::Common::validate_array(model,spaces_array,"Space")
        spacetype_array = BTAP::Common::validate_array(model,spacetype_array,"SpaceType")
        #validate space array
        returnarray = Array.new()
        spaces_array.each do |space|
          returnarray << spacetype_array.include?(space.spaceType())
        end
        return returnarray
      end

      #to do write test.
      def self.assign_spaces_to_thermal_zone(model,spaces_array,thermal_zone)
        spaces_array = BTAP::Common::validate_array(model,spaces_array,"Space")
        thermal_zone = BTAP::Common::validate_array(model,thermal_zone,"ThermalZone")[0]
        spaces_array.each do|space|
          space.setThermalZone(thermal_zone)
        end
      end

    end

    #This Module contains methods that create, modify and query Thermal zone objects.
    module Zones

      def self.enumerate_model(model)

      end




      # This method will filter an array of zones that have an external wall
      # passed floors. Note: if you wish to avoid to create an array of spaces,
      # simply put the space variable in [] brackets
      # Ex: get_all_surfaces_from_spaces( [space1,space2] )
      # @params spaces_array an array of type [OpenStudio::Model::Space]
      # @return an array of thermal zones.
      def self.filter_perimeter_zones(thermal_zones)
        array = Array.new()
        thermal_zones.each do |zone|
          zone.space.each do |space|
            if space.is_a_perimeter_space?()
              array.push(zone)
              next
            end
          end
        end
        return array
      end


      # This method will filter an array of zones that have no external wall
      # passed floors. Note: if you wish to avoid to create an array of spaces,
      # simply put the space variable in [] brackets
      # Ex: ( [space1,space2] )
      # @params zone_array an array of type [OpenStudio::Model::ThermalZone]
      # @return an array of thermal zones.
      def self.filter_core_zones( thermal_zones )
        array = Array.new()
        thermal_zones.getThermalZones.each do |zone|
          zone.space.each do |space|
            if not space.is_a_perimeter_space?()
              array.push(zone)
              next
            end
          end
        end
        return array
      end

      def self.get_surfaces_from_thermal_zones(thermal_zone_array)
        BTAP::Geometry::Surfaces::get_all_surfaces_from_thermal_zones(thermal_zone_array)
      end

      def self.create_thermal_zone(model, spaces_array = "")
        thermal_zone = OpenStudio::Model::ThermalZone.new(model)
        BTAP::Geometry::Spaces::assign_spaces_to_thermal_zone(model, spaces_array, thermal_zone)
        return thermal_zone
      end

    end
    module Surfaces

      def self.create_surface(model,name,os_point3d_array, boundary_condition = "",construction = "")
        os_surface = OpenStudio::Model::Surface.new(os_point3d_array, model)
        os_surface.setName( name )
        if OpenStudio::Model::Surface::validOutsideBoundaryConditionValues.include?(boundary_condition)
          self.set_surfaces_boundary_condition([os_surface], boundary_condition)
        else
          puts "boundary condition not set for #{name}"
        end
        self.set_surfaces_construction([os_surface],construction)
        return os_surface
      end

      # This method will rotate a surface
      # @params surface [OpenStudio::Model::Surface] the model object.
      # @params azimuth_degrees [Float] rotation value
      # @params tilt_degrees [Float] rotation value
      # @return model [OpenStudio::Model::Model] the model object.
      def self.rotate_tilt_translate_surfaces(planar_surfaces, azimuth_degrees, tilt_degrees = 0.0, translation_vector = OpenStudio::Vector3d.new(0.0,0.0,0.0) )
        # Identity matrix for setting space origins
        azimuth_matrix = OpenStudio::Transformation::rotation(OpenStudio::Vector3d.new(0,0,1),azimuth_degrees*Math::PI/180)
        tilt_matrix = OpenStudio::Transformation::rotation(OpenStudio::Vector3d.new(0,0,1),tilt_degrees*Math::PI/180)
        translation_matrix = OpenStudio::createTranslation(translation_vector)
        planar_surfaces.each do |surface|
          surface.changeTransformation(azimuth_matrix)
          surface.changeTransformation(tilt_matrix)
          surface.changeTransformation(translation_matrix)
        end
        return planar_surfaces
      end

      def self.set_fenestration_to_wall_ratio(surfaces,ratio,offset = 0, height_offset_from_floor = true, floor = "all")
        surfaces.each do |surface|
          result = surface.setWindowToWallRatio(ratio,offset,height_offset_from_floor)
          raise( "Unable to set FWR for surface " +
              surface.getAttribute("name").to_s +
              " . Possible reasons are  if the surface is not a wall, if the surface
          is not rectangular in face coordinates, if requested ratio is too large
          (window area ~= surface area) or too small (min dimension of window < 1 foot),
          or if the window clips any remaining sub surfaces. Otherwise, removes all
          existing windows and adds new window to meet requested ratio.") unless result
        end
        return surfaces
      end



      # This Method removes all the subsurfaces in a model (Windows, Doors )
      # @author Phylroy A. Lopez
      # @return [OpenStudio::Model::Model] the OpenStudio model object (self reference).
      def self.remove_all_subsurfaces(surfaces)
        surfaces.each do |subsurface|
          subsurface.remove
        end
        return surfaces
      end

      def self.get_surfaces_from_spaces(spaces_array)
        surfaces = Array.new()
        spaces_array.each do |space|
          surfaces.concat(space.surfaces())
        end
        return surfaces
      end

      def self.get_surfaces_from_building_stories(story_array)
        surfaces = Array.new()
        get_spaces_from_storeys(story_array).each do |space|
          surfaces.concat(space.surfaces())
        end
        return surfaces
      end

      def self.get_surfaces_from_thermal_zones(thermal_zone_array)
        surfaces = Array.new()
        thermal_zone_array.each do |thermal_zone|
          thermal_zone.spaces.each do |space|
            surfaces.concat(space.surfaces())
          end
          return surfaces
        end
      end

      def self.get_subsurfaces_from_surfaces(surface_array)
        subsurfaces = Array.new()
        surface_array.each do |surface|
          subsurfaces.concat(surface.subSurfaces)
        end
        return subsurfaces
      end



      #determine average conductance on set of surfaces or subsurfaces.
      def self.get_weighted_average_surface_conductance(surfaces)
        total_area = 0.0
        temp = 0.0
        surfaces.each do |surface|
          temp = temp + BTAP::Geometry::Surfaces::get_surface_net_area(surface) * BTAP::Geometry::Surfaces::get_surface_construction_conductance(surface)
          total_area = total_area + BTAP::Geometry::Surfaces::get_surface_net_area(surface)
        end
        average_conductance = "NA"
        average_conductance =  temp / total_area unless total_area == 0.0
        return average_conductance
      end

      #get total exterior surface area of building.
      def self.get_total_ext_wall_area(model)
        outdoor_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(model.getSurfaces(), "Outdoors")
        outdoor_walls = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Wall")



      end

      def self.get_total_ext_floor_area(model)

        outdoor_floors = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Floor")
      end

      def self.get_total_ext_fenestration_area(model)

      end

      def self.get_total_ext_roof_area(model)
        outdoor_roofs = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "RoofCeiling")

      end






      #["FixedWindow" , "OperableWindow" , "Door" , "GlassDoor", "OverheadDoor" , "Skylight", "TubularDaylightDiffuser","TubularDaylightDome"]
      def self.filter_subsurfaces_by_types(subsurfaces,subSurfaceTypes)

        #check to see if a string or an array was passed.
        if subSurfaceTypes.kind_of?(String)
          temp = subSurfaceTypes
          subSurfaceTypes = Array.new()
          subSurfaceTypes.push(temp)
        end
        subSurfaceTypes.each do |subSurfaceType|
          unless OpenStudio::Model::SubSurface::validSubSurfaceTypeValues.include?(subSurfaceType)
            raise( "ERROR: Invalid surface type = #{subSurfaceType} Correct Values are: #{OpenStudio::Model::SubSurface::validSubSurfaceTypeValues}")
          end
        end
        return_array = Array.new()
        if subSurfaceTypes.size == 0 or subSurfaceTypes[0].upcase == "All".upcase
          return_array = self
        else
          subsurfaces.each do |subsurface|
            subSurfaceTypes.each do |subSurfaceType|
              if subsurface.subSurfaceType == subSurfaceType
                return_array.push(subsurface)
              end
            end
          end
        end
        return return_array

      end

      #This method creates a new construction based on the current, changes the rsi and assign the construction to the current surface.
      #Most of the meat of this method is in the construction class. Testing is done there.
      def self.set_surfaces_construction_conductance(surfaces , conductance)
        surfaces.each do |surface|
          #a bit of acrobatics to get the construction object from the ConstrustionBase object's name.
          construction = OpenStudio::Model::getConstructionByName(surface.model,surface.construction.get.name.to_s).get
          #create a new construction with the requested conductance value based on the current construction.

          new_construction = BTAP::Resources::Envelope::Constructions::customize_opaque_construction(surface.model,construction,conductance)
          surface.setConstruction(new_construction)
        end
        return surfaces
      end

      #This method creates a new construction based on the current, changes the rsi and assign the construction to the current surface.
      #Most of the meat of this method is in the construction class. Testing is done there.
      def self.get_surface_construction_conductance(surface)
        #a bit of acrobatics to get the construction object from the ConstrustionBase object's name.
        construction = OpenStudio::Model::getConstructionByName(surface.model,surface.construction.get.name.to_s).get
        #create a new construction with the requested RSI value based on the current construction.
        return  BTAP::Resources::Envelope::Constructions::get_conductance(construction)
      end

      def self.get_surface_net_area(surface)
        return surface.netArea()
      end

      def self.get_sub_surface_net_area(subsurface)
        return subsurface.netArea()
      end


      def self.set_surfaces_construction(surfaces,construction)
        surfaces.each do |surface|
          surface.setConstruction(construction)
        end
        return true
      end

      #  This method sets the boundary condition for a surface and it's matching surface.
      #  If set to adiabatic, it will remove all subsurfaces since E+ cannot have adiabatic sub surfaces.
      def self.set_surfaces_boundary_condition(model,surfaces, boundaryCondition)
        surfaces = BTAP::Common::validate_array(model,surfaces,"Surface")
        if OpenStudio::Model::Surface::validOutsideBoundaryConditionValues.include?(boundaryCondition)
          surfaces.each do |surface|
            if boundaryCondition == "Adiabatic"
              #need to remove subsurface as you cannot have a adiabatic surface with a
              #subsurface.
              surface.subSurfaces.each do |subsurface|
                subsurface.remove
              end

              #A bug with adiabatic surfaces. They do not hold the default contruction. 
              surface.setConstruction( surface.construction.get() ) if surface.isConstructionDefaulted
            end

            surface.setOutsideBoundaryCondition(boundaryCondition)
            adj_surface = surface.adjacentSurface
            unless adj_surface.empty?
              adj_surface.get.setOutsideBoundaryCondition( boundaryCondition )
            end
          end
        else
          puts "ERROR: Invalid Boundary Condition = " + boundary_condition
          puts "Correct Values are:"
          puts OpenStudio::Model::Surface::validOutsideBoundaryConditionValues
        end
      end

      def self.filter_by_non_defaulted_surfaces(surfaces)
        non_defaulted_surfaces = Array.new()
        surfaces.each { |surface| non_defaulted_surfaces << surface unless surface.isConstructionDefaulted }
        return non_defaulted_surfaces
      end


      def self.filter_by_boundary_condition(surfaces, boundary_conditions)
        #check to see if a string or an array was passed.
        if boundary_conditions.kind_of?(String)
          temp = boundary_conditions
          boundary_conditions = Array.new()
          boundary_conditions.push(temp)
        end
        #ensure boundary conditions are valid
        boundary_conditions.each do |boundary_condition|
          unless OpenStudio::Model::Surface::validOutsideBoundaryConditionValues.include?(boundary_condition)
            raise "ERROR: Invalid Boundary Condition = " + boundary_condition + "Correct Values are:" + OpenStudio::Model::Surface::validOutsideBoundaryConditionValues.to_s
          end
        end
        #create return array.
        return_array = Array.new()

        if boundary_conditions.size == 0 or boundary_conditions[0].upcase == "All".upcase
          return_array = surfaces
        else
          surfaces.each do |surface|
            boundary_conditions.each do |condition|
              if surface.outsideBoundaryCondition == condition
                return_array.push(surface)
              end
            end
          end
        end
        return return_array
      end

      def self.filter_by_surface_types(surfaces,surfaceTypes)

        #check to see if a string or an array was passed.
        if surfaceTypes.kind_of?(String)
          temp = surfaceTypes
          surfaceTypes = Array.new()
          surfaceTypes.push(temp)
        end
        surfaceTypes.each do |surfaceType|
          unless OpenStudio::Model::Surface::validSurfaceTypeValues.include?(surfaceType)
            raise( "ERROR: Invalid surface type = #{surfaceType} Correct Values are: #{OpenStudio::Model::Surface::validSurfaceTypeValues}")
          end
        end
        return_array = Array.new()
        if surfaceTypes.size == 0 or surfaceTypes[0].upcase == "All".upcase
          return_array = self
        else
          surfaces.each do |surface|
            surfaceTypes.each do |surfaceType|
              if surface.surfaceType == surfaceType
                return_array.push(surface)
              end
            end
          end
        end
        return return_array
      end

      def self.filter_by_interzonal_surface(surfaces)
        return_array = Array.new()
        surfaces.each do |surface|
          unless surface.adjacentSurface().empty?
            return_array.push(surface)
          end
          return return_array
        end
      end

      # Azimuth start from Y axis, Tilts starts from Z-axis
      def self.filter_by_azimuth_and_tilt(surfaces,azimuth_from,azimuth_to,tilt_from,tilt_to,tolerance = 1.0)
        return OpenStudio::Model::PlanarSurface::findPlanarSurfaces(surfaces, OpenStudio::OptionalDouble.new(azimuth_from), OpenStudio::OptionalDouble.new(azimuth_to), OpenStudio::OptionalDouble.new(tilt_from), OpenStudio::OptionalDouble.new(tilt_to),tolerance)
      end


      def self.show(surfaces)
        surfaces.each do |surface|
          if drawing_interface = surface.drawing_interface
            if entity = drawing_interface.entity
              entity.visible = false
            end
          end
        end
      end

      def self.hide(surfaces)
        surfaces.each do |surface|
          if drawing_interface = surface.drawing_interface
            if entity = drawing_interface.entity
              entity.visible = false
            end
          end
        end
      end


    end #Module Surfaces
  end #module Geometry
end