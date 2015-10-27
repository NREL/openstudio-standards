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



require "singleton"


module BTAP
  module EQuest
    # Author::    Phylroy Lopez  (mailto:plopez@nrcan.gc.ca)
    # Copyright:: Copyright (c) NRCan
    # License::   GNU Public Licence
    #This class contains encapsulates the generic interface for the DOE2.x command
    #set. It stores the u type, commands, and keyword pairs for each command. It also
    #stores the parent and child command relationships w.r.t. the building envelope
    #and the hvac systems. I have attempted to make the underlying storage of data
    #private so, if required, we could move to a database solution in the future
    #if required for web development..

    class DOECommand

      # Contains the user specified name
      attr_accessor :utype
      #Contains the u-value
      attr_accessor :uvalue
      # Contains the DOE-2 command name.
      attr_accessor :commandName
      # Contains the Keyword Pairs.
      attr_accessor :keywordPairs
      # Lists all ancestors in increasing order.
      attr_accessor :parents
      # An Array of all the children of this command.
      attr_accessor :children
      # The command type.
      attr_accessor :commandType
      # Flag to see if this component is exempt.
      attr_accessor :exempt
      # Comments. To be added to the command.
      attr_accessor :comments
      # A list of all the non_utype_commands.
      attr_accessor :non_utype_commands
      # A list of all the one line commands (no keyword pairs)
      attr_accessor :one_line_commands
      # Pointer to the building obj.
      attr_accessor :building




      def remove()
        #unlink children
        self.children.each {|item| item.remove}
        #unlink from parent.
        self.get_parents[0].children.delete(self)
        #remove from command array.
        @building.commands.delete(self)
        return self
      end

      def set_parent(parent)
        @parents.clear
        parent.get_parents().each {|parent| @parents << parent}
        @parents << parent
      end

      #This method will return the value of the keyword pair if available.
      #Example:
      #If you object has this data in it...
      #
      #"EL1 West Perim Spc (G.W4)" = SPACE
      #SHAPE            = POLYGON
      #ZONE-TYPE        = CONDITIONED
      #PEOPLE-SCHEDULE  = "EL1 Bldg Occup Sch"
      #LIGHTING-SCHEDUL = ( "EL1 Bldg InsLt Sch" )
      #EQUIP-SCHEDULE   = ( "EL1 Bldg Misc Sch" )
      #
      #
      #then calling
      #
      #get_keyword_value("ZONE-TYPE")
      #
      #will return the string
      #
      #"CONDITIONED".
      #
      #if the keyword does not exist, it will return a nil object.
      # Returns the value associated with the keyword.
      def get_keyword_value(string)
        return_string = String.new()
        found = false
        @keywordPairs.each do |pair|
          if pair[0] == string
            found = true
            return_string = pair[1]
          end
        end
        if found == false
          raise "Error: In the command #{@utype}:#{@command_name} Attempted to get a Keyword pair #{string} present in the command\n Is this keyword missing? \n#{output}"
        end
        return return_string
      end

      # Sets the keyword value.
      def set_keyword_value(keyword, value)
        found = false
        unless @keywordPairs.empty?
          @keywordPairs.each do |pair|
            if pair[0] == keyword
              pair[1] = value
              found = true
            end
          end
          if (found == false)
            @keywordPairs.push([keyword,value])
          end
        else
          #First in the array...
          add_keyword_pair(keyword,value)
        end
      end

      # Removes the keyword pair.
      def remove_keyword_pair(string)
        return_string = String.new()
        @keywordPairs.each do |pair|
          if pair[0] == string
            @keywordPairs.delete(pair)
          end
        end
        return return_string
      end

      def initialize()
        @utype = String.new()
        @commandName= String.new()
        @keywordPairs=Array.new()
        @parents = Array.new()
        @children = Array.new()
        @commandType = String.new()
        @exempt = false
        #HVAC Hierarchry
        @comments =Array.new()
        @hvacLevel = Array.new()
        @hvacLevel[0] =["SYSTEM"]
        @hvacLevel[1] =["ZONE"]
        #Envelope Hierachy
        @envelopeLevel = Array.new()
        @envelopeLevel[0] = ["FLOOR"]
        @envelopeLevel[1] = ["SPACE"]

        @envelopeLevel[2] = [
          "EXTERIOR-WALL",
          "INTERIOR-WALL",
          "UNDERGROUND-WALL",
          "ROOF"
        ]

        @envelopeLevel[3] = [
          "WINDOW",
          "DOOR"]

        @non_utype_commands = Array.new()
        @non_utype_commands = [
          "TITLE",
          "SITE-PARAMETERS",
          "BUILD-PARAMETER",
          "LOADS_REPORT",
          "SYSTEMS-REPORT",
          "MASTERS-METERS",
          "ECONOMICS-REPORT",
          "PLANT-REPORT",
          "LOADS-REPORT",
          "COMPLIANCE"
        ]
        @one_line_commands = Array.new()
        @one_line_commands = ["INPUT","RUN-PERIOD","DIAGNOSTIC","ABORT", "END", "COMPUTE", "STOP", "PROJECT-DATA"]
      end

      # Determines the DOE scope, either envelope or hvac (Window, Wall, Space Floor) or (System->Plant) 
      # Hierarchy) this is required to determine parent/child relationships in the building. 
      def doe_scope
        scope = "none"
        @envelopeLevel.each_index do |index|
          @envelopeLevel[index].each do |name|
            if (@commandName == name )
              scope = "envelope"
            end
          end
        end

        @hvacLevel.each_index do |index|
          @hvacLevel[index].each do |name|
            if (@commandName == name )
              scope = "hvac"
            end
          end
        end
        return scope
      end
      # Determines the DOE scope depth (Window, Wall, Space Floor) or (System->Plant) Hierarchy)
      def depth
        level = 0
        scopelist=[]
        if (doe_scope == "hvac")
          scopelist = @hvacLevel
        else
          scopelist = @envelopeLevel
        end
        scopelist.each_index do |index|
          scopelist[index].each do |name|
            if (@commandName == name )
              level = index
            end
          end
        end
        return level
      end

      #Outputs the command in DOE 2.2 format.
      def output
        return basic_output()
      end

      #Outputs the command in DOE 2.2 format.
      def basic_output()
        temp_string = String.new()

        if (@utype != "")
          temp_string = temp_string + "#{@utype} = "
        end
        temp_string = temp_string + @commandName
        temp_string = temp_string + "\n"
        @keywordPairs.each {|array| temp_string = temp_string +  "\t#{array[0]} = #{array[1]}\n" }
        temp_string = temp_string + "..\n"

        temp_string = temp_string + "$Parents\n"
        @parents.each do |array|
          temp_string = temp_string +  "$\t#{array.utype} = #{array.commandName}\n"
        end
        temp_string = temp_string + "..\n"

        temp_string = temp_string + "$Children\n"
        @children.each {|array| temp_string = temp_string +  "$\t#{array.utype} = #{array.commandName}\n" }
        temp_string = temp_string + "..\n"

      end

      # Creates the command informantion based on DOE 2.2 syntax.
      def get_command_from_string(command_string)
        #Split the command based on the equal '=' sign.
        remove = ""
        keyword=""
        value=""

        if (command_string != "")
          #Get command and u-value
          if ( command_string.match(/(^\s*(\".*?\")\s*\=\s*(\S+)\s*)/) )
            @commandName=$3.strip
            @utype = $2.strip
            remove = Regexp.escape($1)

          else
            # if no u-value, get just the command.
            command_string.match(/(^\s*(\S*)\s)/ )
            remove = Regexp.escape($1)
            @commandName=$2.strip
          end
          #Remove command from string.

          command_string.sub!(/#{remove}/,"")
          command_string.strip!


          #Loop throught the keyword values.
          while ( command_string.length > 0 )
            #DOEMaterial, or SCHEDULES
            if ( command_string.match(/(^\s*(MATERIAL|DAY-SCHEDULES|WEEK-SCHEDULES)\s*(\=?)\s*(.*)\s*)/))
              #puts "Bracket"
              keyword = $2.strip
              value = $4.strip
              remove = Regexp.escape($1)
              #Stars
            elsif ( command_string.match(/(^\s*(\S*)\s*(\=?)\s*(\*.*?\*)\s*)/))
              #puts "Bracket"
              keyword = $2.strip
              value = $4.strip
              remove = Regexp.escape($1)

              #Brackets
            elsif ( command_string.match(/(^\s*(\S*)\s*(\=?)\s*(\(.*?\))\s*)/))
              #puts "Bracket"
              keyword = $2.strip
              value = $4.strip
              remove = Regexp.escape($1)
              #Quotes
            elsif ( command_string.match(/(^\s*(\S*)\s*(\=?)\s*(".*?")\s*)/) )
              #puts "Quotes"
              keyword = $2
              value = $4.strip
              remove = Regexp.escape($1)
              #single command
            elsif command_string.match(/(^\s*(\S*)\s*(\=?)\s*(\S+)\s*)/)
              #puts "Other"
              keyword = $2
              value = $4.strip
              remove = Regexp.escape($1)
            end
            #puts "DOE22::DOECommand: #{command_string}"
            #puts "K = #{keyword} V = #{value}\n"
            if (keyword != "")
              set_keyword_value(keyword,value)
            end
            command_string.sub!(/#{remove}/,"")
          end
          #puts "Keyword"
          #puts keywordPairs
        end
      end

      #Returns an array of the commands parents.
      def get_parents
        return @parents
      end

      #Returns an array of the commands children.
      def get_children
        return children
      end

      # Gets name.
      def get_name()
        return @utype
      end

      # Check if keyword exists.
      def check_keyword?(keyword)
        @keywordPairs.each do |pair|
          if pair[0] == keyword
            return true
          end
        end
        return false
      end

      # Gets the parent of command...if any.
      def get_parent(keyword)

        get_parents().each do |findcommand|

          if ( findcommand.commandName == keyword)
            return findcommand
          end
        end
        return nil

      end

      #Gets children of command, if any.
      def get_children_of_command(keyword)
        array = Array.new()
        children.each do |findcommand|
          if ( findcommand.commandName == keyword)
            array.push(findcommand)
          end
        end
        return array
      end

      def name()
        return utype
      end

      private
      def add_keyword_pair(keyword,pair)
        array = [keyword,pair]
        keywordPairs.push(array)
      end
    end
    class DOEZone < BTAP::EQuest::DOECommand
      attr_accessor :space
      # a vector of spaces used when the declaration of space is "combined"
      attr_accessor :space_uses
      # a lighting object which stores the lighting characteristics of each zone
      attr_accessor :lighting
      #defines the thermal mass characteristics of the zone.
      #could be a string object or a user defined object
      attr_accessor :thermal_mass
      # stores a constant floating value of the amount of air leakage,
      #accoriding to rule #4.3.5.9.
      attr_accessor :air_leakage
      # this will be a vector consisting of heat transfer objects,
      # which contains a pointer to the adjacent thermal block and a pointer
      # to the wall in between them
      attr_accessor :heat_transfers
      def initialize
        super()
      end

      def output

        temp_string = basic_output()
        if (@space == nil)
          temp_string = temp_string + "$ No space found to match zone!\n"
        else
          temp_string = temp_string + "$Space\n"
          temp_string = temp_string +  "$\t#{@space.utype} = #{@space.commandName}\n"
        end
        return temp_string
      end

      # This method finds all the exterior surfaces, ie. Exterior Wall and Roof
      # Output => surfaces as an Array of commands
      def get_exterior_surfaces()
        surfaces = Array.new()
        @space.get_children().each do |child|

          if child.commandName == "EXTERIOR-WALL" ||
              child.commandName == "ROOF"
            surfaces.push(child)
          end
        end
        return surfaces
      end

      # This method returns all the children of the space
      def get_children()
        return @space.get_children()
      end



      # This method returns the area of the space
      def get_area()
        @space.get_area()
      end


     

      def convert_to_openstudio(model,runner = nil)
        if self.space.get_shape() == "NO-SHAPE"
          BTAP::runner_register("Info", "Thermal Zone contains a NO-SHAPE space named. OS does not support no shape spaces.  Thermal Zone will not be created.",runner)
        else
          os_zone = OpenStudio::Model::ThermalZone.new(model)
          os_zone.setAttribute("name", self.name)
          #set space to thermal zone
          OpenStudio::Model::getSpaceByName(model,self.space.name).get.setThermalZone(os_zone)
          BTAP::runner_register("Info", "\tThermalZone: " + self.name + " created",runner)
        end
      end
    end
    

    class DOESurface < DOECommand
      attr_accessor :construction
      attr_accessor :polygon

      def initialize
        super()
        @polygon = nil
      end

      def get_azimuth()
        #puts OpenStudio::radToDeg( OpenStudio::getAngle(OpenStudio::Vector3d.new(0.0, 0.0, 0.0), OpenStudio::Vector3d.new(1.0, 0.0, 0.0) ) )
        if check_keyword?("LOCATION")
          case get_keyword_value("LOCATION")
          when /SPACE-\s*V\s*(.*)/
            index = $1.strip.to_i - 1
            point0 = self.get_parent("SPACE").polygon.point_list[index]
            point1 = self.get_parent("SPACE").polygon.point_list[index + 1] ? get_parent("SPACE").polygon.point_list[index + 1] : get_parent("SPACE").polygon.point_list[0]
            edge = point1-point0

            sign = OpenStudio::Vector3d.new(1.0, 0.0, 0.0).dot(( edge )) > 0 ? 1 :-1
            angle = OpenStudio::radToDeg( sign * OpenStudio::getAngle(OpenStudio::Vector3d.new(1.0, 0.0, 0.0), ( point1 - point0 ) ) )

            #since get angle only get acute angles we need to get sign and completment for reflex angle
            angle = angle + 180 if edge.y < 0
            return angle
          when "FRONT"
            return  OpenStudio::radToDeg( OpenStudio::getAngle(OpenStudio::Vector3d.new(0.0, 1.0, 0.0), ( get_parent("SPACE").polygon.point_list[1] - get_parent("SPACE").polygon.point_list[0] ) ) )
          when "RIGHT"
            return OpenStudio::radToDeg( OpenStudio::getAngle(OpenStudio::Vector3d.new(0.0, 1.0, 0.0), ( get_parent("SPACE").polygon.point_list[2] - get_parent("SPACE").polygon.point_list[1] ) ) )
          when "BACK"
            return OpenStudio::radToDeg( OpenStudio::getAngle(OpenStudio::Vector3d.new(0.0, 1.0, 0.0), ( get_parent("SPACE").polygon.point_list[3] - get_parent("SPACE").polygon.point_list[2] ) ) )
          when "LEFT"
            return OpenStudio::radToDeg( OpenStudio::getAngle(OpenStudio::Vector3d.new(0.0, 1.0, 0.0), ( get_parent("SPACE").polygon.point_list[0] - get_parent("SPACE").polygon.point_list[3] ) ) )
          end
        end
        return self.check_keyword?("AZIMUTH")? self.get_keyword_value("AZIMUTH").to_f : 0.0
      end

      def get_tilt()
        #puts OpenStudio::radToDeg( OpenStudio::getAngle(OpenStudio::Vector3d.new(0.0, 0.0, 0.0), OpenStudio::Vector3d.new(1.0, 0.0, 0.0) ) )
        if check_keyword?("LOCATION")
          case get_keyword_value("LOCATION")
          when "FRONT","BACK","LEFT","RIGHT",/SPACE-\s*V\s*(.*)/
            return  90.0
          when "TOP"
            return 0.0
          when "BOTTOM"
            return 180.0
          end
        end
        return self.check_keyword?("TILT")? self.get_keyword_value("TILT").to_f : 0.0
      end




      def get_origin()
        space_xref = self.check_keyword?("X")? self.get_keyword_value("X").to_f : 0.0
        space_yref = self.check_keyword?("Y")? self.get_keyword_value("Y").to_f : 0.0
        space_zref = self.check_keyword?("Z")? self.get_keyword_value("Z").to_f : 0.0
        return OpenStudio::Vector3d.new(space_xref,space_yref,space_zref)
      end
      
      def get_sub_surface_origin()
        height = ""
        BTAP::runner_register("Info", "geting origin",runner)
        origin = ""
        if self.check_keyword?("X") and self.check_keyword?("Y") and self.check_keyword?("Z")
          BTAP::runner_register("Info", "XYZ definition",runner)
          space_xref = self.get_keyword_value("X").to_f
          space_yref = self.get_keyword_value("Y").to_f
          space_zref = self.get_keyword_value("Z").to_f
          return OpenStudio::Vector3d.new(space_xref,space_yref,space_zref)
        end
        BTAP::runner_register("Info", get_name(),runner)
        array = Array.new()
        origin = ""
        floor = get_parent("FLOOR")
        space = get_parent("SPACE")
        case space.get_keyword_value("ZONE-TYPE")
        when "PLENUM"
          height = floor.get_keyword_value("FLOOR-HEIGHT").to_f  - floor.get_keyword_value("SPACE-HEIGHT").to_f
        when "CONDITIONED","UNCONDITIONED"
          height =  space.check_keyword?("HEIGHT") ? space.get_keyword_value("HEIGHT").to_f : floor.get_keyword_value("SPACE-HEIGHT").to_f

        end
        BTAP::runner_register("Info", "Space is #{space.get_shape}",runner)
        case space.get_shape
        when "BOX"
          BTAP::runner_register("Info", "Box Space Detected....",runner)
          #get height, width and depth of box.
          height = space.check_keyword?("HEIGHT").to_f ? space.check_keyword?("HEIGHT") : height
          width = space.get_keyword_value("WIDTH").to_f
          depth = space.get_keyword_value("DEPTH").to_f

          case get_keyword_value("LOCATION")
          when "TOP"
            BTAP::runner_register("Info", "Top of Box....",runner)
            #counter clockwise
            origin = OpenStudio::Point3d.new(0.0,0.0,height)

          when "BOTTOM"
            BTAP::runner_register("Info", "Bottom of Box....",runner)
            #counter clockwise
            origin = OpenStudio::Point3d.new( 0.0, 0.0, 0.0 )
          when "FRONT"
            BTAP::runner_register("Info", "Front of Box....",runner)
            #counter clockwise
            origin = OpenStudio::Point3d.new( 0.0, 0.0, 0.0 )
          when "RIGHT"
            BTAP::runner_register("Info", "Right of Box....",runner)
            #counter clockwise
            origin = OpenStudio::Point3d.new(width, 0.0, 0.0)
          when "BACK"
            BTAP::runner_register("Info", "Back of Box....",runner)
            #counter clockwise
            origin = OpenStudio::Point3d.new(width,depth,0.0)
          when "LEFT"
            BTAP::runner_register("Info", "Left of Box....",runner)
            #counter clockwise
            origin = OpenStudio::Point3d.new(0.0,depth,0.0)

          end

        when "POLYGON"
          #puts "Polygon Space definition detected..."
          if check_keyword?("LOCATION")
            #puts "LOCATION surface definition detected..."
            case get_keyword_value("LOCATION")
            when "BOTTOM"
              origin = OpenStudio::Vector3d.new(0.0,0.0, 0.0 )
            when "TOP"
              #puts "TOP surface definition detected..."
              #need to move floor polygon up to space height for top. Using Transformation.translation matrix for this.
                
              origin = OpenStudio::Vector3d.new(0.0,0.0, height ) #to-do!!!!!!!!!!!
            when /SPACE-\s*V\s*(.*)/
              #puts "SPACE-V#{$1} surface definition detected..."
              index = $1.strip.to_i - 1
              point0 = space.polygon.point_list[index]
              #counter clockwise
              origin = OpenStudio::Point3d.new( point0.x, point0.y, 0.0)

            end
          else
            #puts "CATCH-ALL for surface definition.."
            #nasty. The height is NOT defined if the height is the same as the space height...so gotta get it from it's parent space. 
            space_height =  space.check_keyword?("HEIGHT") ? space.get_keyword_value("HEIGHT").to_f : floor.get_keyword_value("SPACE-HEIGHT").to_f
            height = self.check_keyword?("HEIGHT") ? self.get_keyword_value("HEIGHT").to_f : space_height
            width =  self.get_keyword_value("WIDTH").to_f
            #origin
            origin = OpenStudio::Point3d.new(width,0.0,0.0)
          end
        when "NO-SHAPE"
          raise("Using SHAPE = NO-SHAPE deifnition for space is not supported by open Studio")
        end
        
        origin =  OpenStudio::Vector3d.new(origin.x,origin.y,origin.z)
        #puts "Surface origin vector is #{origin}"
        return origin
      end
      


      def get_transformation_matrix
        #Rotate points around z (azimuth) and x (Tilt)
        translation = OpenStudio::createTranslation(self.get_origin) 
        e_a = OpenStudio::EulerAngles.new(	OpenStudio::degToRad( self.get_tilt ), 0.0, OpenStudio::degToRad( 180.0 - self.get_azimuth  ) )
        rotations = OpenStudio::Transformation::rotation(e_a)
        return  translation * rotations
      end

      def get_3d_polygon()
        array = Array.new()
        origin = ""
        floor = get_parent("FLOOR")
        space = get_parent("SPACE")
        case space.get_keyword_value("ZONE-TYPE")
        when "PLENUM"
          height = floor.get_keyword_value("FLOOR-HEIGHT").to_f  - floor.get_keyword_value("SPACE-HEIGHT").to_f
        when "CONDITIONED","UNCONDITIONED"
          height =  space.check_keyword?("HEIGHT") ? space.get_keyword_value("HEIGHT").to_f : floor.get_keyword_value("SPACE-HEIGHT").to_f
        end

        #if the surface has been given a polygon. Then use it.
        if check_keyword?("POLYGON")
          #          puts "Polygon Surface Detected...Doing a local transform.."
          #          
          #          puts "Point List"
          #          puts self.polygon.point_list
          #          puts "Origin"
          #          puts self.get_origin
          #          puts "azimuth"
          #          puts self.get_azimuth
          #          puts "tilt"
          #          puts self.get_tilt
          

          
          #all other methods below create points relative to the space. This method however, need to be transformed.
          array = self.polygon.point_list


          #if surfaces are defined by shape of space.
        else
          case space.get_shape
          when "BOX"
            BTAP::runner_register("Info", "Box Space Detected....",runner)
            #get height, width and depth of box.
            height = space.check_keyword?("HEIGHT").to_f ? space.check_keyword?("HEIGHT") : height
            width = space.get_keyword_value("WIDTH").to_f
            depth = space.get_keyword_value("DEPTH").to_f

            case get_keyword_value("LOCATION")
            when "TOP"
              #puts "Top of Box...."
              #counter clockwise
              origin = OpenStudio::Point3d.new(0.0,0.0,height)
              p2 = OpenStudio::Point3d.new(width,0.0,height)
              p3 = OpenStudio::Point3d.new(width,depth,height)
              p4 = OpenStudio::Point3d.new(0.0,depth,height)
              array =  [origin,p2,p3,p4]
            when "BOTTOM"
              #puts "Bottom of Box...."
              #counter clockwise
              origin = OpenStudio::Point3d.new( 0.0, 0.0, 0.0 )
              p2 = OpenStudio::Point3d.new( 0.0, depth, 0.0)
              p3 = OpenStudio::Point3d.new( width, depth, 0.0)
              p4 = OpenStudio::Point3d.new( width,0.0 ,0.0 )
              array =  [origin,p2,p3,p4]
            when "FRONT"
              #puts "Front of Box...."
              #counter clockwise
              origin = OpenStudio::Point3d.new( 0.0, 0.0, 0.0 )
              p2 = OpenStudio::Point3d.new( width,0.0 ,0.0 )
              p3 = OpenStudio::Point3d.new( width, 0.0, height)
              p4 = OpenStudio::Point3d.new( 0.0, 0.0, height)
              array =  [origin,p2,p3,p4]
            when "RIGHT"
              #puts "Right of Box...."
              #counter clockwise
              origin = OpenStudio::Point3d.new(width, 0.0, 0.0)
              p2 = OpenStudio::Point3d.new(width,depth, 0.0)
              p3 = OpenStudio::Point3d.new(width,depth,height)
              p4 = OpenStudio::Point3d.new(width,0.0,height)
              array =  [origin,p2,p3,p4]
            when "BACK"
              #puts "Back of Box...."
              #counter clockwise
              origin = OpenStudio::Point3d.new(width,depth,0.0)
              p2 = OpenStudio::Point3d.new(0.0,depth,0.0)
              p3 = OpenStudio::Point3d.new(0.0,depth,height)
              p4 = OpenStudio::Point3d.new(width,depth,height)
              array =  [origin,p2,p3,p4]
            when "LEFT"
              #puts "Left of Box...."
              #counter clockwise
              origin = OpenStudio::Point3d.new(0.0,depth,0.0)
              p2 = OpenStudio::Point3d.new( 0.0, 0.0, 0.0 )
              p3 = OpenStudio::Point3d.new(0.0, 0.0,height)
              p4 = OpenStudio::Point3d.new(0.0,depth,height)
              array =  [origin,p2,p3,p4]
            end

          when "POLYGON"
            #puts "Polygon Space definition detected..."
            if check_keyword?("LOCATION")
              #puts "LOCATION surface definition detected..."
              case get_keyword_value("LOCATION")
              when "BOTTOM"
                #puts "BOTTOM surface definition detected..."
                #reverse array
                array = space.polygon.point_list.dup
                first = array.pop
                array.insert(0,first).reverse!
              when "TOP"
                #puts "TOP surface definition detected..."
                #need to move floor polygon up to space height for top. Using Transformation.translation matrix for this.
                array = OpenStudio::createTranslation(OpenStudio::Vector3d.new(0.0,0.0, height )) * space.polygon.point_list
              when /SPACE-\s*V\s*(.*)/
                #puts "SPACE-V#{$1} surface definition detected..."
                index = $1.strip.to_i - 1
                point0 = space.polygon.point_list[index]
                point1 = space.polygon.point_list[index + 1] ? space.polygon.point_list[index + 1] : space.polygon.point_list[0]
                #counter clockwise
                origin = OpenStudio::Point3d.new( point0.x, point0.y, 0.0)
                p2 = OpenStudio::Point3d.new(     point1.x, point1.y, 0.0)
                p3 = OpenStudio::Point3d.new(     point1.x, point1.y, height )
                p4 = OpenStudio::Point3d.new(     point0.x, point0.y, height )
                array =  [origin,p2,p3,p4]
              end
            else
              #puts "CATCH-ALL for surface definition.."
              #nasty. The height is NOT defined if the height is the same as the space height...so gotta get it from it's parent space. 
              space_height =  space.check_keyword?("HEIGHT") ? space.get_keyword_value("HEIGHT").to_f : floor.get_keyword_value("SPACE-HEIGHT").to_f
              height = self.check_keyword?("HEIGHT") ? self.get_keyword_value("HEIGHT").to_f : space_height
              width =  self.get_keyword_value("WIDTH").to_f
              #counter clockwise
              origin = OpenStudio::Point3d.new(width,0.0,0.0)
              p2 = OpenStudio::Point3d.new( 0.0,0.0,0.0 )
              p3 = OpenStudio::Point3d.new(0.0,0.0,height)
              p4 = OpenStudio::Point3d.new(width,0.0,height)
              array = [p4, p3, p2, origin]
  

              
            end
          when "NO-SHAPE"
            raise("Using SHAPE = NO-SHAPE deifnition for space is not supported...yet")
          end
        end
        #        if self.check_keyword?("AZIMUTH") or self.check_keyword?("TILT")
        #          puts "Did a transform"
        #          return get_transformation_matrix * array
        #        else
        #          return array
        #        end
        return array
      end


      def get_windows()
        return self.get_children_of_command("WINDOW")
      end

      def get_doors()
        return self.get_children_of_command("DOOR")
      end



      # This method finds all the commands within the building that are "Construction"
      # and if the utype matches, it gets the construction
      def determine_user_defined_construction()
        constructions = @building.find_all_commands("CONSTRUCTION")
        constructions.each do |construction|
          if ( construction.utype == get_keyword_value("CONSTRUCTION") )
            @construction = construction
          end
        end
        return @construction
      end

      #This method will try to convert a DOE inp file to an openstudio file.. 
      def convert_to_openstudio(model,runner = nil)
        #Get 3d polygon of surface and tranform the points based on space origin and the floor origin since they each may use their own co-ordinate base system.
        total_transform = ""
        if self.check_keyword?("AZIMUTH") or self.check_keyword?("TILT")
          total_transform =  get_parent("FLOOR").get_transformation_matrix() * get_parent("SPACE").get_transformation_matrix() * get_transformation_matrix()
        else
          total_transform =  get_parent("FLOOR").get_transformation_matrix() * get_parent("SPACE").get_transformation_matrix()
        end
        surface_points = total_transform * self.get_3d_polygon()
        #Add the surface to the new openstudio model.
        
        os_surface = OpenStudio::Model::Surface.new(surface_points, model)
        #set the name of the surface. 
        os_surface.setAttribute("name", self.name)
        case self.commandName
          #Set the surface boundary condition if it is a ground surface.
        
        when "UNDERGROUND-WALL"
          BTAP::Geometry::Surfaces::set_surfaces_boundary_condition(model,os_surface, "Ground") 
        when "EXTERIOR-WALL","ROOF"
          #this is needed since the surface constructor defaults to a Ground boundary and Floor Surface type 
          #when a horizontal surface is initialized. 
          if os_surface.outsideBoundaryCondition == "Ground" and os_surface.surfaceType == "Floor" 
            os_surface.setSurfaceType("RoofCeiling") 
          end
          BTAP::Geometry::Surfaces::set_surfaces_boundary_condition(model,os_surface, "Outdoors")
        when "INTERIOR-WALL"
          BTAP::Geometry::Surfaces::set_surfaces_boundary_condition(model,os_surface, "Surface")
        end
        
        #Add to parent space that was already created. 
        os_surface.setSpace(OpenStudio::Model::getSpaceByName( model,get_parent("SPACE").name).get )
        #output to console for debugging. 
        BTAP::runner_register("Info", "\tSurface: " + self.name + " created",runner)
        #check if we need to create a mirror surface in another space.
        if self.check_keyword?("NEXT-TO")
          #reverse the points.
          new_array = surface_points.dup
          first = new_array.pop
          new_array.insert(0,first).reverse!
          #...then add the reverse surface to the model and assign the name with a mirror suffix. 
          os_surface_mirror = OpenStudio::Model::Surface.new(new_array, model)
          os_surface_mirror.setAttribute("name", self.name + "-mirror" )
          #Assign the mirror surface to the parent space that is NEXT-TO
          os_surface_mirror.setSpace(OpenStudio::Model::getSpaceByName(model,get_keyword_value("NEXT-TO")).get)
          #output to console for debugging. 
          BTAP::runner_register("Info", "\tSurface: " + self.name + "-mirror"  + " created",runner)
        end #if statement
        
        #Some switches for debugging. 
        convert_sub_surfaces = true
        convert_sub_surfaces_as_surfaces = false
        
        #
        if convert_sub_surfaces
          #convert subsurfaces
          self.get_children().each do |child|
            #Get height and width of subsurface
            height = child.get_keyword_value("HEIGHT").to_f
            width = child.get_keyword_value("WIDTH").to_f
            
          
            #Sum the origin of the surface and the translation of the window
            x = os_surface.vertices.first().x + ( child.check_keyword?("X")?  child.get_keyword_value("X").to_f : 0.0 )
            y = os_surface.vertices.first().y + ( child.check_keyword?("Y")?  child.get_keyword_value("Y").to_f : 0.0 )
            z = os_surface.vertices.first().z
          
            #counter clockwise
            origin = OpenStudio::Point3d.new( x, y , z )
            p2 = OpenStudio::Point3d.new(x + width , y, z )
            p3 = OpenStudio::Point3d.new(x + width , y + height , z )
            p4 = OpenStudio::Point3d.new(x, y + height, z )
            polygon =  [origin,p2,p3,p4]

            #get floot and space rotations
            space_azi = 360.0 - get_parent("SPACE").get_azimuth()
            floor_azi = 360.0 - get_parent("FLOOR").get_azimuth()

          
            tilt_trans = OpenStudio::Transformation::rotation(os_surface.vertices.first(), OpenStudio::Vector3d.new(1.0,0.0,0.0), OpenStudio::degToRad( self.get_tilt ))
            azi_trans = OpenStudio::Transformation::rotation(os_surface.vertices.first(), OpenStudio::Vector3d.new(0.0,0.0,1.0), OpenStudio::degToRad( 360.0 - self.get_azimuth + space_azi + floor_azi  ))
            surface_points =  azi_trans  * tilt_trans * polygon
            if convert_sub_surfaces_as_surfaces
              #Debug subsurface
              os_sub_surface = OpenStudio::Model::Surface.new(surface_points, model)
              #set the name of the surface. 
              os_sub_surface.setAttribute("name", child.name)
              #Add to parent space that was already created. 
              os_sub_surface.setSpace(OpenStudio::Model::getSpaceByName( model,self.get_parent("SPACE").name).get )
            else
              #Add the subsurface to the new openstudio model. 
              os_sub_surface = OpenStudio::Model::SubSurface.new(surface_points, model)
              #set the name of the surface. 
              os_sub_surface.setAttribute("name", child.name )
              #Add to parent space that was already created. 
              os_sub_surface.setSurface(os_surface)
              #output to console for debugging. 
              BTAP::runner_register("Info", "\tSubSurface: " + child.name + " created",runner)
              case child.commandName
              when "WINDOW"
                #By default it is a window. 
              when "DOOR"
                os_sub_surface.setSubSurfaceType( "Door" )
              end #end case.
              
              # Add overhang for subsurface if required. Note this only supports overhangs of width the same as the window.  
              if child.check_keyword?("OVERHANG-D") == true
                offset = 0.0
                offset = child.get_keyword_value("OVERHANG-O").to_f if child.check_keyword?("OVERHANG-O")
                depth = 0.0
                depth = child.get_keyword_value("OVERHANG-D").to_f 
                os_sub_surface.addOverhang(	depth , offset )
              end
              	
            end
          end
        end
      end

    end
    
    #This class allows to manipulate a subsurface (window/door) in inherits from surface. 
    class DOESubSurface < DOESurface

      def initialize
        #run the parent class initialization. 
        super()
      end

      # This method returns the area of the window
      def get_area()
        unless check_keyword?("HEIGHT")  and check_keyword?("WIDTH")
          raise "Error: In the command #{@utype}:#{@command_name} the area could not be evaluated. Either the HEIGHT or WIDTH is invalid.\n #{output}"
        end
        return get_keyword_value("WIDTH").to_f * get_keyword_value("HEIGHT").to_f
      end

      #Return the widow polygon with an origin of zero
      def get_3d_polygon()
        height = get_keyword_value("HEIGHT").to_f
        width = get_keyword_value("WIDTH").to_f
        x = self.check_keyword?("X")?  self.get_keyword_value("X").to_f : 0.0
        y = self.check_keyword?("Y")?  self.get_keyword_value("Y").to_f : 0.0
        #counter clockwise
        origin = OpenStudio::Point3d.new( x, y , 0.0 )
        p2 = OpenStudio::Point3d.new(x + width , y,0.0 )
        p3 = OpenStudio::Point3d.new(x + width , y + height , 0.0 )
        p4 = OpenStudio::Point3d.new(x, y + height,0.0 )
        return [origin,p2,p3,p4]
      end

      #Returns the origin relative to the parent surface. 
      def get_origin()
        origin = get_parent_surface().get_sub_surface_origin()
        return origin
      end

      #Gets azimuth, based on parent surface. 
      def get_azimuth()
        get_parent_surface().get_azimuth()
      end

      #gets tilt based on parent surface. 
      def get_tilt()
        get_parent_surface().get_tilt()
      end

      #return the parent surface of the subsurface. 
      def get_parent_surface()
        get_parents().each do |findcommand|
          [
            "EXTERIOR-WALL",
            "INTERIOR-WALL",
            "UNDERGROUND-WALL",
            "ROOF"
          ].each do |type|

            if ( findcommand.commandName == type)
              return findcommand
            end
          end
        end
        raise("#no parent surface defined!")
      end

      #returns the translation matrix reletive to its parent ( the surface ) 
      def get_transformation_matrix
        return  self.get_rotation_matrix() * self.get_translation_matrix()
      end
      
      def get_rotation_matrix
        #Rotate points around z (azimuth) and x (Tilt)
        e_a = OpenStudio::EulerAngles.new(	OpenStudio::degToRad( self.get_tilt ), 0.0, OpenStudio::degToRad( 0.0  ) )
        rotations = OpenStudio::Transformation::rotation(e_a)
        return  rotations 
      end
      
      def get_translation_matrix
        #Rotate points around z (azimuth) and x (Tilt)
        translation = OpenStudio::createTranslation(self.get_origin) 
        return  translation 
      end
      
      
      
      

      # this will translate the subsurface to the openstudio model. 
      def convert_to_openstudio(model)        
      end
    end
    
    #an attempt to organize the BDLlibs...don't think it works well at all. 
    class DOEBDLlib

      attr_accessor :db, :materials

      include Singleton




      # stores the name of the individual materials

      attr_accessor :commandList
      # stores the name of the individual layers


      def initialize
        @commandList = Array.new()
        @db = Sequel.sqlite
        @db.create_table :materials do # Create a new table
          primary_key :id, :integer, :auto_increment => true
          column :command_name, :text
          column :name, :text
          column :type, :text
          column :thickness, :float
          column :conductivity, :float
          column :resistance, :float
          column :density, :float
          column :spec_heat, :float
        end
        @materials = @db[:materials] # Create a dataset

        @db.create_table :layers do # Create a new table
          primary_key :id, :integer, :auto_increment => true
          column :command_name, :text
          column :name, :text
          column :material, :text
          column :inside_film_res, :float
        end
        @layers = @db[:layers] # Create a dataset


        store_material()
      end



      def find_material(utype)
        posts =  @materials.filter(:name => utype)
        record = posts.first()
        #Create the new command object.
        command = DOE2::DOECommand.new()
        #Insert the collected information into the object.
        command.commandName = "MATERIAL"
        command.utype = record[:name]
        command.set_keyword_value("TYPE", record[:type])
        command.set_keyword_value("THICKNESS", record[:thickness])
        command.set_keyword_value("CONDUCTIVITY", record[:conductivity])
        command.set_keyword_value("DENSITY", record[:density])
        command.set_keyword_value("SPECIFIC HEAT", record[:spec_heat])

        return command
      end


      def find_layer(utype)
        posts =  @layers.filter(:name => utype)
        record = posts.first()
        #Create the new command object.
        command = DOE2::DOECommand.new()
        #Insert the collected information into the object.
        command.commandName = "LAYERS"
        command.utype = record[:name]
        command.set_keyword_value("MATERIAL", record[:material])
        command.set_keyword_value("THICKNESS", record[:thickness])
        command.set_keyword_value("CONDUCTIVITY", record[:conductivity])
        command.set_keyword_value("DENSITY", record[:density])
        command.set_keyword_value("SPECIFIC HEAT", record[:spec_heat])

        return command
      end





      # stores the material information using keywordPairs into the command structure
      # accessed using the find_command method
      private
      def store_material

        begin
          f = File.open("../Resources/DOE2_2/bdllib.dat")
        rescue
          f = File.open("Resources/DOE2_2/bdllib.dat")
        end

        lines = f.readlines
        # Iterating through the file.
        lines.each_index do |i|
          command_string = ""
          # If we find a material.
          if lines[i].match(/\$LIBRARY-ENTRY\s(.{32})MAT .*/)
            #Get the name strips the white space.
            name = ("\""+$1.strip + "\"")

            #Is this the last line?
            command_string = get_data(command_string, i, lines)
            #Extract data for material type PROPERTIES.
            if (match = command_string.match(/^\s*TYPE\s*=\s*(\S*)\s*TH\s*=\s*(\S*)\s*COND\s*=\s*(\S*)\s*DENS\s*=\s*(\S*)\s*S-H\s*=\s*(\S*)\s*$/) )
              #Create the new command object.
              command = DOE2::DOECommand.new()
              #Insert the collected information into the object.
              command.commandName = "MATERIAL"
              command.utype = name
              command.set_keyword_value("TYPE", $1.strip)
              command.set_keyword_value("THICKNESS", $2.strip.to_f.to_s)
              command.set_keyword_value("CONDUCTIVITY", $3.strip.to_f.to_s)
              command.set_keyword_value("DENSITY", $4.strip.to_f.to_s)
              command.set_keyword_value("SPECIFIC HEAT", $5.strip.to_f.to_s)
              #Push the object into the array for storage.
              @commandList.push(command)
              @materials << {:name => name,
                :command_name => 'MATERIAL',
                :type =>  $1.strip,
                :thickness =>  $2.strip.to_f.to_s,
                :conductivity =>  $3.strip.to_f.to_s,
                :density =>  $4.strip.to_f.to_s,
                :spec_heat =>  $5.strip.to_f.to_s}



              #Extract data for material type RESISTANCE.
            elsif (match = command_string.match(/^\s*TYPE\s*=\s*(\S*)\s*RES\s*=\s*(\S*)\s*$/) )
              command = DOE2::DOECommand.new()
              command.commandName = "MATERIAL"
              command.utype = name
              command.set_keyword_value("TYPE", $1.strip)
              command.set_keyword_value("RESISTANCE", $2.strip.to_f.to_s)
              #Push the object into the array for storage.
              @materials << {:name => name,
                :command_name => 'MATERIAL',
                :type =>  $1.strip,
                :resistance =>  $2.strip.to_f.to_s}

              @commandList.push(command)
            else
              raise("data not extracted")
            end
          end

          if lines[i].match(/\$LIBRARY-ENTRY\s(.{32})LA .*/)
            #Get the name
            name = ("\""+$1.strip + "\"")
            #Is this the last line?
            command_string = get_data(command_string, i, lines)
            #Extract data into the command.
            if (match = command_string.match(/^\s*MAT\s*=\s*(.*?)\s*I-F-R\s*=\s*(\S*)\s*$/) )
              command = DOE2::DOECommand.new()
              command.commandName = "LAYERS"
              command.utype = name
              command.set_keyword_value("MATERIAL",$1)
              #Push the object into the array for storage.
              @layers << {:name => name,
                :command_name => 'LAYER',
                :material =>  $1.strip,
                :inside_film_res =>  $2.strip.to_f.to_s}
              @commandList.push(command)
            else
              raise("data not extracted")
            end
          end
        end
        #@materials.print
        #@layers.print
      end

      private
      # This method will get all the
      def get_data(command_string, i, lines)
        #Do this while this is NOT the last line of data.
        while (! lines[i].match(/^(.*?)\.\.\s*(.{6})?\s*?(\d*)?/) )
          #Grab all the data in between.
          if ( lines[i].match(/^\$.*$/) )
          elsif ( myarray = lines[i].match(/^(.*?)\s*(.{6})?\s*?(\d*)?\s*$/) )
            command_string = command_string + $1.strip
          end
          #Increment counter.
          i = i + 1
        end
        #Get the last line
        lines[i].match(/^(.*?)\.\.\s*(.{6})?\s*?(\d*)?/)
        command_string = command_string + $1.strip
        if command_string == ""
          raise("error")
        end
        i  = i + 1
        command_string
      end
    end
    
    #class that 
    class DOEExteriorWall < DOESurface

      def initialize
        #call the parent class. 
        super()
      end

      # This method finds the area of the exterior wall
      def get_area()
        OpenStudio::getArea(self.get_3d_polygon())
      end

      #This method finds the floor parent
      def get_floor()
        get_parent("FLOOR")
      end

      #This method finds the space parent command
      def get_space()
        get_parent("SPACE")
      end

      #This method gets the construction command
      def get_construction_name()
        get_keyword_value("CONSTRUCTION")
      end

      #This method returns the window area
      def get_window_area()
        get_children_area("WINDOW")
      end

      #This method returns the door area
      def get_door_area()
        get_children_area("DOOR")
      end

      # This method returns the difference between the wall area and the window
      # and door
      def get_opaque_area()
        get_area.to_f - get_window_area().to_f - get_door_area().to_f
      end

      # This method returns the fraction of the wall dominated by the window
      def get_fwr()
        get_window_area().to_f / get_area.to_f
      end

      # This method returns the area of the children classes based on the given
      # commandname.
      # Input => A command_name as a String
      # Output => Total area as a float
      def get_children_area(scommand_name)
        area = 0.0
        @children.each do |child|

          if child.commandName == scommand_name
            area = child.get_area() + area
          end
        end
        return area
      end

      # This method checks if the construction only has a defined U-value
      def just_u_value?()
        @construction.check_keyword?("U-VALUE")
      end


    end
    
    

    

    
    #The interface for the roof command.. same as parent. 
    class DOERoof < DOECommand
      def initialize
        super()
      end

      # This method finds the area of the roof
      def get_area

        # Finds the floor and space parents and assigns them to @floor and @space
        # variables to be used later
        parent = get_parents
        parent.each do |findcommand|
          if ( findcommand.commandName == "FLOOR" )
            @floor = findcommand
          end
          if ( findcommand.commandName == "SPACE")
            @space = findcommand
          end
        end

        # Get the keyword value for location
        begin
          location = get_keyword_value("LOCATION")
        rescue
        end

        # Get the keyword value for polygon
        begin
          polygon_id = get_keyword_value("POLYGON")
        rescue
        end

        # if the polygon_id keyword value was nil and the location value was nil, then
        # the height and width are directly defined within the "roof" command


        if  ( location == "BOTTOM" || location == "TOP") && (@space.get_shape != "BOX")
          return @space.polygon.get_area

        elsif ( location == nil  && polygon_id == nil )
          height = get_keyword_value("HEIGHT")
          width = get_keyword_value("WIDTH")
          height = height.to_f
          width = width.to_f
          return height * width
        elsif ( location == nil && polygon_id != nil)
          return @space.polygon.get_area


          # if the location was defined as "SPACE...", it is immediately followed by a
          # vertex, upon which lies the width of the roof
        elsif location.match(/SPACE.*/)
          location = location.sub( /^(.{6})/, "")
          width = @space.polygon.get_length(location)
          height = @floor.get_space_height
          return width * height
          # if the shape was a box, the width and height would be taken from the
          # "SPACE" object
        elsif ( @space.get_shape == "BOX" )
          width = @space.get_width
          height = @space.get_height
          return width * height
        else
          raise "The area could not be evaluated"
        end
      end

      #returns tilt of roof surface. 
      def get_tilt()
        if check_keyword?("TILT") then return get_keyword_value("TILT").to_f
        else
          if check_keyword?("LOCATION")
            location = get_keyword_value("LOCATION")
            case location
            when "TOP"
              return 0.0
            when "BOTTOM"
              return 180.0
            when "LEFT", "RIGHT", "BACK", "FRONT"
              return 90.0
            end
          end
          # If it is a polygon or not defined, set to DOE default = 0.0
          return 0
        end
      end

      # This method returns the Azimuth value as a FLOAT if it exists
      # It first checks if the azimuth keyword value is present within the roof
      # command itself. If it does not find this, then it checks for the location
      # keyword and assigns the correct azimuth depending on the azimuth of the parent
      # space. However, if the shape of the parent space is defined as a polygon, then it
      # searches for the location of the roof and uses the polygon's get-azimuth for the vertex
      # to return the azimuth of the roof

      #NOTE: The FRONT is defined as 0, going clockwise, ie. RIGHT = 90 degrees

      #OUTPUT: Azimuth between the parent SPACE and the ROOF
      def get_azimuth()
        space = get_parent("SPACE")
        if check_keyword?("AZIMUTH") then return get_keyword_value("AZIMUTH").to_f
        else
          if check_keyword?("LOCATION")
            location = get_keyword_value("LOCATION")

            case location
            when "TOP"
              raise "Exception: Azimuth does not exist"
            when "BOTTOM"
              raise "Exception: Azimuth does not exist"
            when "FRONT"
              return 0.0 + space.get_azimuth
            when "RIGHT"
              return 90.0 + space.get_azimuth
            when "BACK"
              return 180.0 + space.get_azimuth
            when "LEFT"
              return 270.0 + space.get_azimuth
            end
          end
          if space.get_keyword_value("SHAPE") == "POLYGON"
            space_vertex = get_keyword_value("LOCATION")
            space_vertex.match(/SPACE-(.*)/)
            vertex = $1.strip
            return space.polygon.get_azimuth(vertex)
          end

        end
      end

      # This method returns the Azimuth value as a FLOAT if it exists
      # It first checks if the azimuth keyword value is present within the roof
      # command itself. If it does not find this, then it checks for the location
      # keyword and assigns the correct azimuth depending on the azimuth of the parent
      # space. However, if the shape of the parent space is defined as a polygon, then it
      # searches for the location of the roof and uses the polygon's get-azimuth for the vertex
      # and adding it on to the overall azimuth to get the Absolute Azimuth from True North

      #NOTE: The FRONT is defined as 0, going clockwise, ie. RIGHT = 90 degrees

      #OUTPUT: Azimuth between ROOF and TRUE NORTH
      def get_absolute_azimuth
        space = get_parent("SPACE")
        if check_keyword?("AZIMUTH")
          azimuth = get_keyword_value("AZIMUTH").to_f
          space_azimuth = space.get_absolute_azimuth
          return azimuth + space_azimuth
        else
          if check_keyword?("LOCATION")
            location = get_keyword_value("LOCATION")
            case location
            when "TOP"
              raise "Exception: Azimuth does not exist"
            when "BOTTOM"
              raise "Exception: Azimuth does not exist"
            when "FRONT"
              return 0.0 + space.get_absolute_azimuth
            when "RIGHT"
              return 90.0 + space.get_absolute_azimuth
            when "BACK"
              return 180.0 + space.get_absolute_azimuth
            when "LEFT"
              return 270.0 + space.get_absolute_azimuth
            end
          end
          if space.get_keyword_value("SHAPE") == "POLYGON"
            space_vertex = get_keyword_value("LOCATION")
            space_vertex.match(/SPACE-(.*)/)
            vertex = $1.strip
            return space.polygon.get_azimuth(vertex) + space.get_absolute_azimuth
          end
        end
      end
    end
    #Interface for the DOESpace Command. 
    class DOESpace < DOECommand
      attr_accessor :polygon
      attr_accessor :zone
      def initialize

        super()
      end

      #this outputs the command to a string. 
      def output
        temp_string = basic_output()
        if @polygon != nil
          temp_string = temp_string + "$Polygon\n"
          temp_string = temp_string +  "$\t#{@polygon.utype} = #{@polygon.commandName}\n"
        end
        if @zone != nil
          temp_string = temp_string + "$Zone\n"
          temp_string = temp_string +  "$\t#{@zone.utype} = #{@zone.commandName}\n"
        end
        return temp_string
      end

      # This method finds the area of the space
      def get_area

        # get the keyword value of shape
        shape = get_keyword_value("SHAPE")

        # if the shape value is nil, or it is defined as "NO-SHAPE", the get_area value
        # would be defined, and would represent the get_area of the space
        if ( shape == nil || shape == "NO-SHAPE")
          area = get_keyword_value("AREA")
          area = area.to_f
          return area

          # if the shape value is "BOX", the height and width key values are given,
          # and the get_area would be defined as their product
        elsif ( shape == "BOX" )
          height = get_keyword_value("HEIGHT")
          width = get_keyword_value("WIDTH")
          height = height.to_f
          width = width.to_f
          return height * width

          # if the shape value is defined as a polygon , the get_area of the polygon would
          # represent the get_area of the space
        elsif ( shape == "POLYGON")
          return @polygon.get_area
        else
          raise "Error: The area could not be evaluated. Please check inputs\n "

        end
      end

      # This method finds the volume of the space
      def get_volume

        # get the keyword value of "SHAPE"
        shape = get_keyword_value("SHAPE")

        # if the shape value returns nil, or is defined as "NO-SHAPE", the volume is
        # given directly
        if ( shape == nil || shape == "NO-SHAPE")
          volume = get_keyword_value("VOLUME")
          volume = volume.to_f
          return volume

          # if the shape is defined as a "BOX", the values for height, width, and
          # depth are given, from which you can get the volume
        elsif ( shape == "BOX" )
          height = get_keyword_value("HEIGHT")
          width = get_keyword_value("WIDTH")
          depth = get_keyword_value("DEPTH")
          height = height.to_f
          width = width.to_f
          depth = depth.to_f
          return height * width * depth

          # if the shape is defined as a "POLYGON", the get_area is defined as the area
          # of the polygon, and the height is given by the value of "HEIGHT"
        elsif ( shape == "POLYGON")
          height = getKeywordvalue("HEIGHT")
          temp = get_keyword_value("POLYGON")
          height = height.to_f
          @polygon.utype = temp
          return @polygon.get_area * height
        else
          raise "Error: The volume could not be evaluated. Please check inputs\n "

        end

      end

      def get_height()
        if check_keyword?("HEIGHT") then return get_keyword_value("HEIGHT").to_f end
        return get_floor.get_keyword_value("SPACE-HEIGHT").to_f
      end

      def get_width
        width = get_keyword_value("WIDTH")
        width = width.to_f
        return width
      end

      def get_depth
        depth = get_keyword_value("DEPTH")
        depth = depth.to_f
        return depth
      end

      def get_shape
        return "NO-SHAPE" unless check_keyword?("SHAPE")
        return get_keyword_value("SHAPE")
      end

      def get_floor
        get_parent("FLOOR")
      end


      def get_origin()
        space_origin = nil
        if check_keyword?("LOCATION") and ( not self.check_keyword?("X") or not self.check_keyword?("Y") or not self.check_keyword?("Z") )
          zero = OpenStudio::Point3d.new( 0.0, 0.0, 0.0 )
          case get_keyword_value("LOCATION")
          when /FLOOR-\s*V\s*(.*)/
            index = $1.strip.to_i - 1
            surf_vector =  get_parent("FLOOR").polygon.point_list[index] - zero
          when "FRONT"
            surf_vector =  get_parent("FLOOR").polygon.point_list[0] - zero
          when "RIGHT"
            surf_vector =  get_parent("FLOOR").polygon.point_list[1] - zero
          when "BACK"
            surf_vector =  get_parent("FLOOR").polygon.point_list[2] - zero
          when "LEFT"
            surf_vector =  get_parent("FLOOR").polygon.point_list[3] - zero
          end
          space_xref = self.check_keyword?("X")? self.get_keyword_value("X").to_f : 0.0
          space_yref = self.check_keyword?("Y")? self.get_keyword_value("Y").to_f : 0.0
          space_zref = self.check_keyword?("Z")? self.get_keyword_value("Z").to_f : 0.0
          space_origin = OpenStudio::Vector3d.new(space_xref,space_yref,space_zref)
          space_origin = surf_vector + space_origin
        else
          space_xref = self.check_keyword?("X")? self.get_keyword_value("X").to_f : 0.0
          space_yref = self.check_keyword?("Y")? self.get_keyword_value("Y").to_f : 0.0
          space_zref = self.check_keyword?("Z")? self.get_keyword_value("Z").to_f : 0.0
          space_origin = OpenStudio::Vector3d.new(space_xref,space_yref,space_zref)
        end
        return space_origin
      end

      def get_azimuth()
        angle = 0.0
        #puts OpenStudio::radToDeg( OpenStudio::getAngle(OpenStudio::Vector3d.new(0.0, 0.0, 0.0), OpenStudio::Vector3d.new(1.0, 0.0, 0.0) ) )
        if check_keyword?("LOCATION") and not check_keyword?("AZIMUTH")
          case get_keyword_value("LOCATION")
          when /FLOOR-\s*V\s*(.*)/
            index = $1.strip.to_i - 1
            point0 = self.get_parent("FLOOR").polygon.point_list[index]
            point1 = self.get_parent("FLOOR").polygon.point_list[index + 1] ? get_parent("FLOOR").polygon.point_list[index + 1] : get_parent("FLOOR").polygon.point_list[0]
            edge = point1-point0


            sign = 1.0# OpenStudio::Vector3d.new(1.0, 0.0, 0.0).dot(( edge )) > 0 ? 1 :-1
            angle = OpenStudio::radToDeg( sign * OpenStudio::getAngle(OpenStudio::Vector3d.new(1.0, 0.0, 0.0), ( point1 - point0 ) ) )

            #since get angle only get acute angles we need to get sign and completment for reflex angle
            if edge.y > 0.0
              angle = -1.0 * angle 
            end

          when "FRONT"
            angle = OpenStudio::radToDeg( OpenStudio::getAngle(OpenStudio::Vector3d.new(0.0, 1.0, 0.0), ( get_parent("FLOOR").polygon.point_list[1] - get_parent("FLOOR").polygon.point_list[0] ) ) )
          when "RIGHT"
            angle = OpenStudio::radToDeg( OpenStudio::getAngle(OpenStudio::Vector3d.new(0.0, 1.0, 0.0), ( get_parent("FLOOR").polygon.point_list[2] - get_parent("FLOOR").polygon.point_list[1] ) ) )
          when "BACK"
            angle = OpenStudio::radToDeg( OpenStudio::getAngle(OpenStudio::Vector3d.new(0.0, 1.0, 0.0), ( get_parent("FLOOR").polygon.point_list[3] - get_parent("FLOOR").polygon.point_list[2] ) ) )
          when "LEFT"
            angle = OpenStudio::radToDeg( OpenStudio::getAngle(OpenStudio::Vector3d.new(0.0, 1.0, 0.0), ( get_parent("FLOOR").polygon.point_list[0] - get_parent("FLOOR").polygon.point_list[3] ) ) )
          end
        else
          angle =  self.check_keyword?("AZIMUTH")? self.get_keyword_value("AZIMUTH").to_f : 0.0
        end
        return angle
      end


      def get_transformation_matrix()
        #This will transform the space vertices to normal space co-ordinates using Sketchup/OS convention
        return OpenStudio::createTranslation(self.get_origin) * OpenStudio::Transformation::rotation(OpenStudio::Vector3d.new(0.0, 0.0, 1.0), OpenStudio::degToRad(360.0 - self.get_azimuth()))
      end
      
      def get_rotation_matrix()
        return OpenStudio::Transformation::rotation(OpenStudio::Vector3d.new(0.0, 0.0, 1.0), OpenStudio::degToRad(360.0 - self.get_azimuth()))
      end

      def convert_to_openstudio(model,runner = nil)
        if self.get_keyword_value("SHAPE") == "NO-SHAPE"
          BTAP::runner_register("Info", "OpenStudio does not support NO-SHAPE SPACE definitions currently. Not importing the space #{self.name}.",runner)
        else
          os_space = OpenStudio::Model::Space.new(model)
          os_space.setAttribute("name", self.name)
          #set floor
          os_space.setBuildingStory(OpenStudio::Model::getBuildingStoryByName(model,self.get_parent("FLOOR").name).get)
          BTAP::runner_register("Info", "\tSpace: " + self.name + " created",runner)
          #puts "\t\t Azimuth:#{self.get_azimuth}"
          #puts "\t\t Azimuth:#{self.get_origin}"
        end
      end

    end
    class DOEFloor < DOESurface
      attr_accessor :polygon
      # a string object which defines the type of roof (e.g. attic)
      attr_accessor :type
      # The absorptance of the exterior surface of the floor
      # (see rule #4.3.5.3.(6)
      attr_accessor :absorptance
      # thermal insulation of floors
      attr_accessor :thermal_insulation

      def initialize
        super()
      end

      #This method returns the floor area
      def get_area

        # get the keyword for the shape of the floor
        case get_keyword_value("SHAPE")

          # if the keyword value is "BOX", the width and depth values are defined
        when "BOX"
          return get_keyword_value("WIDTH").to_f * get_keyword_value("DEPTH").to_f

          # if the keyword value is "POLYGON", the get_area is defined as the area of the
          # given polygon
        when "POLYGON"
          return @polygon.get_area

          # if the keyword value of the floor is "No-SHAPE", the get_area is given as the
          # get_area keyword value
        when "NO-SHAPE"
          return get_keyword_value("AREA").to_f
        else
          raise "Error: The area could not be evaluated. Please check inputs\n "
        end
      end

      # This method returns the volume of the floor space
      def get_volume
        return get_floor_height.to_f * get_area.to_f
      end

      # gets the height of the floor
      def get_height
        return get_keyword_value("FLOOR-HEIGHT").to_f
      end

      # gets the space height
      def get_space_height
        return get_keyword_value("SPACE-HEIGHT").to_f
      end

      def get_origin()
        space_xref = self.check_keyword?("X")? self.get_keyword_value("X").to_f : 0.0
        space_yref = self.check_keyword?("Y")? self.get_keyword_value("Y").to_f : 0.0
        space_zref = self.check_keyword?("Z")? self.get_keyword_value("Z").to_f : 0.0
        return OpenStudio::Vector3d.new(space_xref,space_yref,space_zref)
      end

      def get_azimuth()
        return self.check_keyword?("AZIMUTH")? self.get_keyword_value("AZIMUTH").to_f : 0.0
      end

      def get_transformation_matrix()
        return OpenStudio::createTranslation(self.get_origin) * OpenStudio::Transformation::rotation(OpenStudio::Vector3d.new(0.0, 0.0, 1.0), OpenStudio::degToRad(360.0 - self.get_azimuth()))
      end
      
      def get_rotation_matrix()
        return OpenStudio::Transformation::rotation(OpenStudio::Vector3d.new(0.0, 0.0, 1.0), OpenStudio::degToRad(360.0 - self.get_azimuth()))
      end

      def convert_to_openstudio(model,runner = nil)
        floor = OpenStudio::Model::BuildingStory.new(model)
        floor.setAttribute("name", self.name)
        BTAP::runner_register("Info", "\tBuildingStory: " + self.name + " created",runner)
      end

    end
    #This class makes it easier to deal with DOE Polygons.
    class DOEPolygon < DOECommand

      attr_accessor :point_list

      #The constructor.
      def initialize
        super()
        @point_list = Array.new()
        #Convert Keywork Pairs to points.

      end

      def create_point_list()

        #Convert Keywork Pairs to points.
        @point_list.clear
        @keywordPairs.each do |array|

          array[1].match(/\(\s*(\-?\d*\.?\d*)\s*\,\s*(\-?\d*\.?\d*)\s*\)/)
          #puts array[1]

          point = OpenStudio::Point3d.new($1.to_f,$2.to_f,0.0)
          @point_list.push(point)
        end
        #      @point_list.each do |p|
        #        puts p.x.to_s + " " + p.y.to_s + " " + p.z.to_s + " "
        #      end
      end

      # This method returns the area of the polygon.
      def get_area
        openstudio::getArea(@points_list)
      end


      # This method must determine the length of the given point to the next point
      # in the polygon list. If the point is the last point, then it will be the
      # distance from the last point to the first.
      # point_name is the string named keyword in the keyword pair list.
      # Example:
      # "DOEPolygon 2" = POLYGON
      #   V1               = ( 0, 0 )
      #   V2               = ( 0, 1 )
      #   V3               = ( 2, 1 )
      #   V4               = ( 2 ,0 )
      # get_length(3) should return "2"
      # get_length(2) should return "1"

      def get_length(point_index)
        if @points_list.size < pointindex + 2
          return OpenStudio::getDistance(@point_list[0],@point_list.last)
        else
          return OpenStudio::getDistance(@point_list[point_index],@point_list[point_index + 1] )
        end
      end


      def get_azimuth(point_index)
        if @points_list.size < pointindex + 2
          return OpenStudio::radToDeg(OpenStudio::getAngle(@point_list.last - @point_list[0] , openstudio::Vector3d( 1.0, 0.0, 0.0)))
        else
          return OpenStudio::radToDeg(OpenStudio::getAngle(@point_list[point_index + 1] - @point_list[point_index] , openstudio::Vector3d( 1.0, 0.0, 0.0)))
        end
      end

    end
    class DOELayer < DOECommand
      # type of material (see rule #4.3.5.2.(3))
      attr_accessor :material
      # the thickness of the material (see rule #4.3.5.2.(3))
      attr_accessor :thickness
      def initialize
        super()
      end
    end
    class DOEMaterial < DOECommand
      # characteristics of the materials
      attr_accessor :density
      attr_accessor :specific_heat
      attr_accessor :thermal_conductivity
      def initialize
        super()
      end
    end
    class DOEConstruction < DOECommand

      def initialize
        super()
      end

      def get_materials()
        bdllib = DOE2::DOEBDLlib.instance
        materials = Array.new

        case self.get_keyword_value("TYPE")
        when "LAYERS"
          # finds the command associated with the layers keyword
          layers_command = building.find_command_with_utype( self.get_keyword_value("LAYERS") )

          #if Layres command cannot be found in the inp file... find it in the bdl database.
          layers_command = bdllib.find_layer(self.get_keyword_value("LAYERS")) unless layers_command.length == 1

          # if there ends up to be more than one command with the layers keyword
          # raise an exception
          raise "Layers was defined more than once " + self.get_keyword_value("LAYERS").to_s if layers_command.length > 1

          # get all the materials, separate it by the quotation marks and push it
          # onto the materials array
          layers_command[0].get_keyword_value("MATERIAL").scan(/(\".*?\")/).each do |material|
            material_command = ""

            #Try to find material in doe model.
            material_command_array = building.find_command_with_utype(material.to_s.strip)

            # if there ends up to be more than one, raise an exception
            raise "Material was defined more than once #{material}" if material_command_array.length > 1

            # if the material cannot be found within the model, find it within the doe2 database
            material_command = bdllib.find_material(material) if material_command_array.length < 1

            #If material was found then set it.
            material_command = material_command_array[0] if material_command_array.length == 1

            materials.push(material_command)
          end
          return materials
        when "U-VALUE"
          return nil
        end
      end

      # This method finds the u-value of the given construction
      # Output => total conductivity as a float
      def get_u_value()
        total_conductivity = 0.0
        case self.get_keyword_value("TYPE")
        when "LAYERS"
          self.get_materials().each do |material_command|
            case material_command.get_keyword_value("TYPE")
            when  "RESISTANCE"
              conductivity = 1 / material_command.get_keyword_value("RESISTANCE").to_f
            when "PROPERTIES"
              conductivity = material_command.get_keyword_value("CONDUCTIVITY").to_f
            else
              raise "Error in material properties"
            end
            total_conductivity = total_conductivity + conductivity
          end
          return total_conductivity
        when "U-VALUE"
          return self.get_keyword_value("U-VALUE").to_f
        end
      end


    end
    class DOECommandFactory
      def initialize

      end

      def DOECommandFactory.command_factory(command_string, building)
        
        command = ""
        command_name = ""
        if (command_string != "")
          #Get command and u-value
          if ( command_string.match(/(^\s*(\".*?\")\s*\=\s*(\S+)\s*)/) )
            command_name=$3.strip
          else
            # if no u-value, get just the command.
            command_string.match(/(^\s*(\S*)\s)/ )
            @command_name=$2.strip
            
          end
        end
        case command_name
        when  "ZONE" then
          command = DOEZone.new()
        when  "FLOOR" then
          command = DOEFloor.new()
        when  "SPACE" then
          command = DOESpace.new()
        when  "EXTERIOR-WALL" then
          command = DOEExteriorWall.new()
        when  "INTERIOR-WALL" then
          command = DOESurface.new()
        when  "UNDERGROUND-WALL" then
          command = DOESurface.new()
        when  "ROOF" then
          command = DOERoof.new()
        when "WINDOW" then
          command = DOESubSurface.new()
        when "DOOR" then
          command = DOESubSurface.new()
        when "POLYGON" then
          command = DOEPolygon.new()
        when "LAYER" then
          command = DOELayer.new()
        when "MATERIAL" then
          command = DOEMaterial.new()
        when "CONSTRUCTION" then
          command = DOEConstruction.new()
        else
          command = DOECommand.new()
        end

        command.get_command_from_string(command_string)
        command.building = building
        return command
      end
    end
    
    # This is the main interface dealing with DOE inp files. You can load, save
    # manipulate doe files with this interface at a command level. 
    class DOEBuilding

      #An array to contain all the DOE
      attr_accessor  :commands
      #An array to contain the current parent when reading in the input files.
      attr_accessor  :parents


      # This method makes a deep copy of the building object.
      def clone
        return Marshal::load(Marshal.dump(self))
      end

      # The Constructor.
      def initialize

        @commands=[]
        @parents=[]
        @commandList = Array.new()

      end

      # This method will find all Commands given the command name string.
      # Example
      # def find_all_Command("ZONE")  will return an array of all the ZONE commands
      # used in the building.
      def find_all_commands (sCOMMAND)
        array = Array.new()
        @commands.each do |command|
          if (command.commandName == sCOMMAND)
            array.push(command)
          end
        end
        return array
      end

      # This method will find all Commands given the command name string.
      # Example
      # def find_all_Command("Default Construction")  will return an array of all
      # the commands with "Default Construction" as the u-type used in the building.
      def find_command_with_utype (utype)
        array = Array.new()
        @commands.each do |command|
          if (command.utype == utype)
            array.push(command)
          end
        end
        return array
      end


      # Same as find_all_commands except you can use regular expressions.
      def find_all_regex(sCOMMAND)
        array = Array.new()
        search =/#{sCOMMAND}/
        @commands.each do |command|
          if (command.commandName.match(search) )
            array.push(command)
          end

        end
        return array
      end

      # Find a matching keyword value pair in from an array of commands.
      # Example:
      # find_keyword_value(building.commands, "TYPE", "CONDITIONED")  will return
      # all the commands that have the
      # TYPE = CONDITIONED"
      # Keyword pair.
      def search_by_keyword_value( keyword, value)
        returnarray = Array.new()
        @commands.each do |command|
          if ( command.keywordPairs[keyword] == value )
            returnarray.push(command)
          end
        end
        return returnarray
      end


      # Will read an input file into memory and store all the commands into the
      # @commands array.
      def load_inp(filename,runner = nil)
        BTAP::runner_register("Info", "loading file:" + filename, runner)
        #Open the file.
        #puts filename
        iter = 0


        File.exist?(filename)
        f = File.open(filename, "r")




        #Read the file into an array, line by line.
        lines = f.readlines
        #Set up the temp string.
        command_string =""

        lines.each do|line|
          iter = iter.next
          #line.forced_encoding("US-ASCII")
          #Ignore comments (To do!...strip from file as well as in-line comments.
          if (!line.match(/\$.*/) )

            if (myarray = line.match(/(.*?)\.\./) )
              #Add the last part of the command to the newline...may be blank."
              command_string = command_string + myarray[1]
              #Determine correct command class to create, then populates it."
              command = DOECommandFactory.command_factory(command_string, self)
              #Push the command into the command array."
              @commands.push(command)
              command_string = ""
            else
              myarray = line.match(/(.*)/)
              command_string = command_string + myarray[1]
            end
          end
        end
        
        organize_data()
        BTAP::runner_register("Info","INP model contains:", runner)
        #report number of things read in. 
        ["SPACE","ZONE","EXTERIOR-WALL","ROOF","INTERIOR-WALL","UNDERGROUND-WALL","WINDOW","DOOR","MATERIAL","CONSTRUCTION"].each do |item|
          items = self.find_all_commands(item)
          message = "\t#{item} = #{items.size}"
          BTAP::runner_register("Info",message, runner)
        end
        BTAP::runner_register("Info", "\tFinished Loading File:" + filename,runner)
      end



      # This will right a clean output file, meaning no comments. Good for doing
      # diffs
      def save_inp(string)
        array = @commands
        w = File.open(string, 'w')
        array.each { |command| w.print command.output }
        w.close
      end



      

      #This routine organizes the hierarchy of the space <-> zones and the polygon
      # associations that are not formally identified by the sequential relationship
      # like the floor, walls, windows. It would seem that zones and spaces are 1 to
      # one relationships.  So each zone will have a reference to its space and vice versa.
      # If there is a polygon command in the space or floor definition, a reference to the
      # polygon class will be set.
      def organize_data()
        # set_envelope_hierarchy
        # This method determines the current parents of the current command.
        def determine_current_parents(new_command)
          if @last_command.nil?
            @last_command = new_command
          end
          #Check to see if scope (HVAC versus Envelope) has changed or the parent depth is undefined "0"
          if (!@parents.empty? and (new_command.doe_scope != @parents.last.doe_scope or new_command.depth == 0 ))
            @parents.clear
          end
          #no change in parent.
          if ( (new_command.depth  == @last_command.depth))
            #no change
            @last_command = new_command
            #puts "#{new_command.commandName}"
          end
          #Parent depth added
          if ( new_command.depth  > @last_command.depth)
            @parents.push(@last_command)
            #puts "Added parent#{@last_command.commandName}"
            @last_command = new_command
          end
          #parent depth removed.
          if ( new_command.depth  < @last_command.depth)
            parent = @parents.pop
            #puts "Removed parent #{parent}"
            @last_command = new_command
          end
          array = Array.new(@parents)
          return array
        end


        @commands.each do |command|
          if command.doe_scope() == "envelope"
            #Sets parents of command.
            parents = determine_current_parents(command)
            if (!parents.empty?)
              command.parents = parents
            end
            #inserts current command into the parent's children.
            if (!command.parents.empty?)
              command.parents.last.children.push(command)
            end
          end
        end
        # Associating the polygons with the FLoor and spaces.
        polygons =  find_all_commands("POLYGON")
        spaces = find_all_commands("SPACE")
        floors = find_all_commands("FLOOR")
        zones = find_all_commands("ZONE")
        ext_walls = find_all_commands("EXTERIOR-WALL")
        roof = find_all_commands("ROOF")
        door = find_all_commands("DOOR")
        int_walls = find_all_commands("INTERIOR-WALL")
        underground_walls = find_all_commands("UNDERGROUND-WALL")
        underground_floors = find_all_commands("UNDERGROUND-FLOOR")
        constructions =find_all_commands("CONSTRUCTION")
        surface_lists = [ ext_walls, roof, door, int_walls, underground_walls, underground_floors]


        #Organize surface data.
        surface_lists.each do |surfaces|
          surfaces.each do |surface|
            #Assign constructions to surface objects
            constructions.each do |construction|
              if ( construction.utype == surface.get_keyword_value("CONSTRUCTION") )
                surface.construction = construction
              end
            end
            #Find Polygons associated with surface.
            polygons.each do |polygon|
              if ( surface.check_keyword?("POLYGON") and polygon.utype == surface.get_keyword_value("POLYGON")  )
                surface.polygon = polygon
              end
            end
          end
        end



        #Organize polygon data for space and floors.
        polygons.each do |polygon|
          #set up point list in polygon objects
          polygon.create_point_list()
          #Find Polygons associated with  floor and and reference to floor.
          floors.each do |floor|
            if ( polygon.utype == floor.get_keyword_value("POLYGON") )
              floor.polygon = polygon
            end
          end
          #Find Polygons for space and add reference to the space.
          spaces.each do |space|
            if space.check_keyword?("POLYGON")
              if ( polygon.utype == space.get_keyword_value("POLYGON") )
                space.polygon = polygon
              end
            end
          end
        end



        #    Find spaces that belong to the zone.
        zones.each do |zone|
          spaces.each do |space|
            if ( space.utype ==  zone.get_keyword_value("SPACE") )
              space.zone = zone
              zone.space = space
            end
          end
        end
      end



      def get_building_transformation_matrix()
        build_params = self.find_all_commands("BUILD-PARAMETERS")[0]
        building_xref = build_params.check_keyword?("X-REF")? build_params.get_keyword?("X-REF") : 0.0
        building_yref = build_params.check_keyword?("Y-REF")? build_params.get_keyword?("Y-REF") : 0.0
        building_origin = OpenStudio::Vector3d.new(building_xref,building_yref,0.0)
        building_azimuth = build_params.check_keyword?("AZIMUTH")? build_params.get_keyword?("AZIMUTH") : 0.0
        return  OpenStudio::Transformation::rotation(OpenStudio::Vector3d(0.0, 0.0, 1.0), openstudio::degToRad(building_azimuth)) * OpenStudio::Transformation::translation(building_origin)
      end




      #this method will convert a DOE inp file to the OSM file.. This will return
      # and openstudio model object. 
      def create_openstudio_model_new(runner = nil)
        beginning_time = Time.now

        end_time = Time.now
        BTAP::runner_register("Info", "Time elapsed #{(end_time - beginning_time)*1000} milliseconds",runner)
        model = OpenStudio::Model::Model.new()
        #add All Materials
        #    find_all_commands( "Materials" ).each do |doe_material|
        #    end
        #
        #    find_all_commands( "Constructions" ).each do |doe_cons|
        #    end

        #this block will create OS story objects in the OS model. 
        BTAP::runner_register("Info", "Exporting DOE FLOORS to OS",runner)
        find_all_commands("FLOOR").each do |doe_floor|
          doe_floor.convert_to_openstudio(model)
        end
        BTAP::runner_register("Info", OpenStudio::Model::getBuildingStorys(model).size.to_s + " floors created",runner)

        #this block will create OS space objects in the OS model. 
        BTAP::runner_register("Info", "Exporting DOE SPACES to OS",runner)
        find_all_commands("SPACE").each do |doe_space|
          doe_space.convert_to_openstudio(model)
        end
        BTAP::runner_register("Info", OpenStudio::Model::getSpaces(model).size.to_s + " spaces created",runner)
        
        #this block will create OS space objects in the OS model. 
        BTAP::runner_register("Info", "Exporting DOE ZONES to OS",runner)
        find_all_commands("ZONE").each do |doe_zone|
          doe_zone.convert_to_openstudio(model)
        end
        BTAP::runner_register("Info", OpenStudio::Model::getThermalZones(model).size.to_s + " zones created",runner)
        
        #this block will create OS surface objects in the OS model.
        BTAP::runner_register("Info", "Exporting DOE Surfaces to OS",runner)
        all_surfaces = Array.new()
        @commands.each do |command|
          case command.commandName
          when "EXTERIOR-WALL","INTERIOR-WALL","UNDERGROUND-WALL","ROOF"
            all_surfaces.push(command)
          end
        end
        all_surfaces.each do |doe_surface|
          doe_surface.convert_to_openstudio(model)
        end
        BTAP::runner_register("Info", OpenStudio::Model::getSurfaces(model).size.to_s + " surfaces created",runner)
        BTAP::runner_register("Info", OpenStudio::Model::getSubSurfaces(model).size.to_s + " sub_surfaces created",runner)
        BTAP::runner_register("Info", "Setting Boundary Conditions for surfaces",runner)
        BTAP::Geometry::match_surfaces(model)
        
        x_scale = y_scale = z_scale = 0.3048
        BTAP::runner_register("Info", "scaling model from feet to meters",runner)
        model.getPlanarSurfaces.each do |surface|
          new_vertices = OpenStudio::Point3dVector.new
          surface.vertices.each do |vertex|
            new_vertices << OpenStudio::Point3d.new(vertex.x * x_scale, vertex.y * y_scale, vertex.z * z_scale)
          end    
          surface.setVertices(new_vertices)
        end
 
        model.getPlanarSurfaceGroups.each do |surface_group|
          transformation = surface_group.transformation
          translation = transformation.translation
          euler_angles = transformation.eulerAngles
          new_translation = OpenStudio::Vector3d.new(translation.x * x_scale, translation.y * y_scale, translation.z * z_scale)
          #TODO these might be in the wrong order
          new_transformation = OpenStudio::createRotation(euler_angles) * OpenStudio::createTranslation(new_translation) 
          surface_group.setTransformation(new_transformation)
        end
        BTAP::runner_register("Info", "DOE2.2 -> OS Geometry Conversion Complete",runner)
        BTAP::runner_register("Info", "Summary of Conversion",runner)
        BTAP::runner_register("Info", OpenStudio::Model::getBuildingStorys(model).size.to_s + " floors created",runner)
        BTAP::runner_register("Info", OpenStudio::Model::getSpaces(model).size.to_s + " spaces created",runner)
        BTAP::runner_register("Info", OpenStudio::Model::getThermalZones(model).size.to_s + " thermal zones created",runner)
        BTAP::runner_register("Info", OpenStudio::Model::getSurfaces(model).size.to_s + " surfaces created",runner)
        BTAP::runner_register("Info", OpenStudio::Model::getSubSurfaces(model).size.to_s + " sub_surfaces created",runner)
        BTAP::runner_register("Info", "No Contruction were converted.",runner)
        BTAP::runner_register("Info", "No Materials were converted",runner)
        BTAP::runner_register("Info", "No HVAC components were converted",runner)
        BTAP::runner_register("Info", "No Environment or Simulation setting were converted.",runner)

        end_time = Time.now
        BTAP::runner_register("Info", "Time elapsed #{(end_time - beginning_time)} seconds",runner)
        return model
      end





      def get_materials()
        BTAP::runner_register("Info", "Spaces",runner)
        find_all_commands("SPACE").each do |space|
          BTAP::runner_register("Info", space.get_azimuth(),runner)
        end
        BTAP::runner_register("Info", "Materials",runner)
        find_all_commands("MATERIAL").each do |materials|
          BTAP::runner_register("Info", materials.get_name(),runner)
        end
        BTAP::runner_register("Info", "Layers",runner)
        find_all_commands("LAYERS").each do |materials|
          BTAP::runner_register("Info", materials.get_name(),runner)
        end
        BTAP::runner_register("Info", "Constructions",runner)
        find_all_commands("CONSTRUCTION").each do |materials|
          BTAP::runner_register("Info", materials.get_name(),runner)
        end

      end


    end
    # This class will manage all the layer information of the Reference components.
    class LayerManager
      include Singleton
      class Layer

        attr_accessor :name
        attr_accessor :thickness
        attr_accessor :conductivity
        attr_accessor :density
        attr_accessor :specific_heat
        attr_accessor :air_space
        attr_accessor :resistance
        def initialize
          @air_space = false
        end

        def set( thickness, conductivity, density, specific_heat)
          @thickness, @conductivity, @density, @specific_heat =  thickness, conductivity, density, specific_heat
          @airspace = false
        end

        def set_air_space(thickness, resistance)
          @thickness, @resistance = thickness, resistance
          @air_space = true
        end

        def output
          string = "Airspace = #{@air_space}\nThickness = #{@thickness}\nConductivity = #{@conductivity}\nResistance = #{@resistance}\nDensity = #{@density}\nSpecificHeat = #{@specific_heat}\n"
        end
      end
      # Array of all the layers
      attr_accessor :layers
      def initialize
        @layers = Array.new()
      end

      #Add a layer. If the layer already exists. It will return the exi
      def add_layer(new_layer)
        #first determine if the layer already exists.
        @layers.each do  |current_layer|
          if new_layer == current_layer
            return current_layer
          end
        end
        @layers.push(new_layer)
        return @layers.last()
      end

      private

      def clear()
        @layers.clear()
      end
    end
    #This class manages all of the constructions that are used in the simulation. It
    #should remove any constructions that are doubly defined in the project.
    class ConstructionManager
      # An array containing all the constructions.
      attr_accessor :constructions

      # The layer manager all the constructions.
      attr_accessor :layer_manager
      class Construction

        #The unique name for the construction.
        attr_accessor :name
        #The array which contains the material layers of the construction.
        attr_accessor :layers

        def initialize
          #Set up the array for the layers.
          @layers = Array.new()
        end

        #Adds a layer object to the construction.
        # Must pass a Layer object as an arg.
        def add_layer_object( object )
          layers.push( object )
        end

        #Adds a layer based on the physical properties list.
        #All units are based on the simulators input.
        def add_layer(thickness, conductivity, density, specific_heat)
          layer = Layer.new()
          # Make sure all the values are > 0.
          layer.set(thickness, conductivity, density, specific_heat)
          @layers.push(layer)
        end

        # Adds an airspace to the construction based on the thickness and Resistances.
        #All units are based on the simulators input.
        def add_air_space(thickness, resistance )
          layer = Layer.new()
          layer.set_air_space(thickness, resistance)
          @layers.push(layer)
        end

        def output()
          soutput = ""
          @layers.each do|layer|
            soutput = soutput + layer.output() + "\n"
          end
          soutput
        end
      end


      def initialize
        @constructions = Array.new()
        @layer_manager = LayerManager.instance()
      end


      #Adds a new construction to the construction array.
      #Arg must be a construction object.
      def add_construction(new_construction)
        #first determine if the layer already exists.
        @constructions.each do  |current_construction|
          if new_construction == current_construction
            return current_construction
          end
        end
        new_construction.layers.each do |new_layer|
          #If the new layer already exists...use the old one instead.
          # it is the layerManager's job to decide this.
          new_layer = @layer_manager.add_layer(new_layer)
        end
        @constructions.push(new_construction)
        return @constructions.last()
      end

      def clear()
        @constructions.clear()
        @layer_manager.clear()
      end

    end
  end
end

