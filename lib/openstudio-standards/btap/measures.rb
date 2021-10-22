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


# To change this template, choose Tools | Templates
# and open the template in the editor.
require "#{File.dirname(__FILE__)}/btap"

class OSMArg
  ARGUMENT_TYPES = [
    "BOOL",         
    "STRING",       
    "INTEGER",      
    "FLOAT",        
    "STRINGCHOICE",
    "WSCHOICE"     
  ]
        
        
        
  attr_accessor :runner, 
    :variable_name, 
    :type,
    :required,  
    :model_dependant,
    :display_name, 
    :default_value, 
    :min_value,  
    :max_value,  
    :string_choice_array,  	
    :os_object_type
        
  def self.bool( variable_name,display_name,required,default_value )
    raise "#{default_value} defaut value is not a bool." unless default_value.is_a?(Bool)
    default_value.respond_to?(:to_s)
    arg = OSMArg.new( "BOOL", variable_name, display_name, required)
    arg.default_value = default_value
    return arg
  end
        
  def self.string( variable_name,display_name,required,default_value )
    raise "#{default_value} defaut value is not a string." unless default_value.respond_to?(:to_s)
    arg = OSMArg.new( "STRING", variable_name, display_name, required)
    arg.default_value = default_value
    return arg
  end
        
  def self.integer( variable_name,display_name,required,default_value,min_value,max_value )
    raise "#{default_value} defaut value is not a integer." unless default_value.respond_to?(:to_i)
    arg = OSMArg.new( "INTEGER", variable_name, display_name, required)
    arg.default_value = default_value
    arg.min_value = min_value
    arg.max_value = max_value
    return arg          
  end
        
  def self.float( variable_name, display_name, required,default_value,min_value, max_value )
    raise "#{default_value} defaut value is not a float." unless default_value.respond_to?(:to_f)
    arg = OSMArg.new( "INTEGER", variable_name, display_name, required)
    arg.default_value = default_value
    arg.min_value = min_value
    arg.max_value = max_value
    return arg          
  end
        
  def self.choice(variable_name,display_name,required,default_value,string_choice_array)
    raise "#{default_value} defaut value is not an array." unless default_value.is_a?(Array)    
    arg = OSMArg.new( "STRINGCHOICE", variable_name, display_name, required)
    arg.default_value = default_value
    arg.string_choice_array = string_choice_array
    return arg
  end
        
  def self.wschoice( variable_name, display_name, required, default_value, os_object_type)
    arg = OSMArg.new( "WSCHOICE", variable_name, display_name, required )
    arg.default_value = default_value
    arg.os_object_type = os_object_type
    return arg          
  end
        
  def initialize( type, variable_name, display_name, required )
    self.type = type
    self.variable_name = variable_name
    self.display_name = display_name
    self.required = required
    self.model_dependant = false
    if self.type == "WSCHOICE"
      self.model_dependant = true
    else
      self.model_dependant = false
    end
    return self
  end  
end
      




module BTAP
  module Measures
    module OSMeasures
      
      
      
      
      class BTAPModelUserScript < OpenStudio::Ruleset::ModelUserScript
        #if and E+ measure replace OpenStudio::Ruleset::ModelUserScript with OpenStudio::Ruleset::WorkspaceUserScript
        #Array containing information of all inputs required by measure.
        attr_accessor :argument_array_of_arrays
        attr_accessor :argument_array
        attr_accessor :file
        #Name of measure
        #attr_accessor :name

        #if and E+ measure replace OpenStudio::Ruleset::ModelUserScript with OpenStudio::Ruleset::WorkspaceUserScript
        def name
          "BTAPModelUserScript"
          OSMArgument.new
        end
        
        #this method will output the ruby macro to perform the change. 
        def generate_ruby_macro(model,runner)
          if @file == nil or @file == ""
            @file = "Enter_Path_To_#{self.class.name}_measure.rb_File!"
          end
          BTAP::runner_register("MACRO", "\##{self.class.name} Measure Start", runner)
          BTAP::runner_register("MACRO", "require \"#{@file}\"", runner)
          BTAP::runner_register("MACRO", "argument_values = #{@arg_table}", runner)
          BTAP::runner_register("MACRO", "#{self.class.name}.new.set_user_arguments_and_apply(model,argument_values,runner)",runner)
          BTAP::runner_register("MACRO", "\##{self.class.name} Measure End", runner)
        end

        def set_user_arguments_and_apply(model,argument_values,runner)
          message = "Settting Arguments"
          runner.nil? ? puts(message) : runner.registerInfo(message)
          #create argument map
          user_arguments = OpenStudio::Ruleset::OSArgumentMap.new
          #get argument list
          arguments = self.arguments(model)
          #go through each argument
          arguments.each do |argument|
            found = false
            #go through each passed argument_values
            argument_values.each do |pair|
              #when a match is found.
              if argument.name == pair[0]

                clone_argument = argument.clone
                unless clone_argument.setValue(pair[1])
                  message = "Could not set #{argument.name} to #{pair[1]}"
                  runner.nil? ? puts(message) : runner.registerError(message)
                else
                  message = "Set #{argument.name} to #{pair[1]}"
                  runner.nil? ? puts(message) : runner.registerInfo(message)
                end
                user_arguments[pair[0]] = clone_argument
                #log message
                message = " Argument set to #{user_arguments}"
                runner.nil? ? puts(message) : runner.registerInfo(message)
              end
              found = true
            end
            puts  ("Warning: value for argument #{argument.name} not set!.") if found == false
          end
          self.run(model, runner, user_arguments)
        end

        def run(model, runner, user_arguments)
          #IF and E+ measure replace model with workspace as the argument
          #Boilerplate start
          super(model, runner, user_arguments)
          BTAP::runner_register("INFO", "Initial model being modified by #{self.class.name}",runner)
          if not runner.validateUserArguments(self.arguments(model),user_arguments)
            return false
          end
          
          #Set argument to instance variables. 
          self.argument_getter(model, runner,user_arguments)
          #will run the childs method measure_code
          result =  self.measure_code(model,runner)
          generate_ruby_macro(model,runner)
          return result
        end # end method run

        def argument_setter(model,args)
          #***boilerplate code starts. Do not edit...
          

          #iterate through array of hashes and make arguments based on type and set
          # max and min values where applicable.
          @argument_array.each do |row|
            #strip out first char that contains the @ symbol
            row.variable_name[0] = ''
            arg = nil
            case row.type
            when "BOOL"
              arg = OpenStudio::Ruleset::OSArgument::makeBoolArgument(row.variable_name,row.required,row.model_dependant)
            when "STRING"
              arg = OpenStudio::Ruleset::OSArgument::makeStringArgument(row.variable_name,row.required,row.model_dependant)
            when "INTEGER"
              arg = OpenStudio::Ruleset::OSArgument::makeIntegerArgument(row.variable_name,row.required,row.model_dependant)
              arg.setMaxValue( row.max_value.to_i ) unless row.min_value.nil?
              arg.setMaxValue( row.max_value.to_i ) unless  row.max_value.nil?
            when "FLOAT"
              arg = OpenStudio::Ruleset::OSArgument::makeDoubleArgument(row.variable_name,row.required,row.model_dependant)
              arg.setMaxValue( row.max_value.to_f ) unless row.min_value.nil?
              arg.setMaxValue( row.max_value.to_f ) unless  row.max_value.nil?
            when "STRINGCHOICE"
              # #add string choices one by one.
              chs = OpenStudio::StringVector.new
              row.string_choice_array.each {|choice| chs << choice}
              arg = OpenStudio::Ruleset::OSArgument::makeChoiceArgument(row.variable_name, chs,row.required,row.model_dependant)
            when "PATH"
              arg = OpenStudio::Ruleset::OSArgument::makePathArgument("alternativeModelPath",true,"osm")
            when "WSCHOICE"
              arg = OpenStudio::Ruleset::makeChoiceArgumentOfWorkspaceObjects( row.variable_name, row.os_object_type.to_IddObjectType , model, row.required)
            end
            # #common argument aspects.
            unless arg.nil?
              arg.setDisplayName(row.display_name)
              arg.setDefaultValue(row.default_value) unless row.default_value.nil?
              args << arg
            end
          end
          return args
        end

        def argument_getter(model, runner,user_arguments)
          @arg_table = []
          unless @argument_array == nil
            @argument_array.each do |row|
              name = row.variable_name
            
              case row.type
              when "BOOL"
                value = runner.getBoolArgumentValue(name, user_arguments)
                instance_variable_set("@#{name}",value)
                @arg_table << [name,value]
              when "STRING"
                value = runner.getStringArgumentValue(name, user_arguments)
                instance_variable_set("@#{name}",value)
                @arg_table << [name,value]
              when "INTEGER"
                value = runner.getIntegerArgumentValue(name, user_arguments)
                instance_variable_set("@#{name}",value)
                @arg_table << [name,value]
                if ( not row.min_value.nil?  and instance_variable_get("@#{name}") < row.min_value ) or ( not row.max_value.nil? and instance_variable_get("@#{name}") > row.max_value )
                  runner.registerError("#{row.display_name} must be greater than or equal to #{row.min_value} and less than or equal to #{row.max_value}.  You entered #{instance_variable_get("@#{name}")}.")
                  return false
                end
              when "FLOAT"
                value = runner.getDoubleArgumentValue(name, user_arguments)
                instance_variable_set("@#{name}",value)
                @arg_table << [name,value]
                
                if ( not row.min_value.nil?  and instance_variable_get("@#{name}") < row.min_value ) or ( not row.max_value.nil? and instance_variable_get("@#{name}") > row.max_value )
                  runner.registerError("#{row.display_name} must be greater than or equal to #{row.min_value} and less than or equal to #{row.max_value}.  You entered #{instance_variable_get("@#{name}")}.")
                  return false
                end
              when "STRINGCHOICE"
                @arg_table << [name,runner.getBoolArgumentValue(name, user_arguments)]
                instance_variable_set("@#{name}", runner.getStringArgumentValue(name, user_arguments) )
              when "WSCHOICE"
                @arg_table << [name,runner.getBoolArgumentValue(name, user_arguments)]
                instance_variable_set("@#{name}", runner.getOptionalWorkspaceObjectChoiceValue(name, user_arguments,model) )

              when "PATH"
                @arg_table << [name,runner.getBoolArgumentValue(name, user_arguments)]
                instance_variable_set("@#{name}", runner.getPathArgument(name, user_arguments) )
              end #end case
            end #end do
          end
          return @arg_table
        end        
        
      end
      #Measure Template simplified. 
      class TemplateModelMeasure < BTAPModelUserScript

        def name
          "BTAPTempModelMeasure"
        end

        def arguments(model)

          #bool
          @argument_array << OSMArgument.bool(variable_name,display_name,required,default_value)
          #string
          @argument_array << OSMArgument.string(variable_name,display_name,required,default_value)
          #integer
          @argument_array << OSMArgument.integer(variable_name,display_name,required,default_value,min_value,max_value)
          #float
          @argument_array << OSMArgument.float(variable_name,display_name,required,default_value,min_value,max_value)
          #Choice
          @argument_array << OSMArgument.choice(variable_name,display_name,required,default_value,string_choice_array)
          #Workspace choice (using zones as an example)
          @argument_array << OSMArgument.wschoice(variable_name,display_name,required,default_value,string_choice_array)
          args = super(model,@argument_array)
          return args
        end

        def run(model, runner, user_arguments)
          #IF and E+ measure replace model with workspace as the argument
          #Boilerplate start
          parent_method_is_true = super(model, runner, user_arguments)


          #Start measure changes based on model.
          puts @boolean_argument_name
          puts @string_argument_name
          puts @integer_argument_name
          puts @float_argument_name
          puts @choice_argument_name
          puts @ws_choice_argument_name




          #Do your stuff here!
          #Here are some logging methods for reference.
          #      runner.registerInitialCondition("Model initial condition (for example number of floors.")
          #      runner.registerInfo("Use this for information to user.")
          #      runner.registerWarning("Use this for warnings to user.")
          #      runner.registerError("Use this for fatal error message to user. Will not continue. Return a false.") ; return false
          #      runner.registerAsNotApplicable("Measure not applicable because XYZ. Return a true and will continue with other chained measures."); return true
          #      runner.registerFinalCondition("Model ended with # of floors for example")
          #      runner.registerFinalCondition("Indicate what was changed.")


          #If everything went well..
          return  true ? parent_method_is_true  : false
        end # end method run

        #For manually running script via an IDE or a command line.
        #Using the template above as an example.....
        #  argument_values = [
        #
        #       ["boolean_argument_name",    true          ],
        #       ["string_argument_name",     "some string" ],
        #       ["integer_argument_name",    1             ],
        #       ["float_argument_name",      0.001         ],
        #       ["choice_argument_name",     "choice1"     ],
        #       ["ws_choice_argument_name",  "zone1"       ],
        #       ["path_argument_name",       OpenStudio::Path.new(File.dirname(__FILE__))]
        #    ]
        #
        def set_user_arguments_and_apply(model,argument_values,runner)
          self.run(model, runner, super(model,argument_values,runner) )
        end

      end

      class ArchetypeScan < BTAPModelUserScript

        def name
          "BTAPTempModelMeasure"
        end

        def arguments(model)
          #get all osm files in resource folder.
          osmfiles = OpenStudio::StringVector.new
          BTAP::FileIO::get_find_files_from_folder_by_extension(File.dirname(__FILE__), ".osm").each {|filename| osmfiles << File.basename(file_name, ",osm")}


          #list of arguments as they will appear in the interface. They are available in the run command as @variable_name.
          @argument_array_of_arrays = [
            [    "variable_name",          "type",          "required",  "model_dependant", "display_name",         "default_value",  "min_value",  "max_value",  "string_choice_array",  	"os_object_type"	],
            [    "archetype_name",         "STRINGCHOICE",  true,         false,            "archetype_name",       osmfiles[0].to_s ,        nil,          nil,          osmfiles,  	nil					],
          ]
          args = super(model,@argument_array_of_arrays)
          return args
        end

        def run(model, runner, user_arguments)
          #run the super
          parent_method_is_true = super(model, runner, user_arguments)
          
          
          ###############
          
          #Set Archetype name in runner. 
          runner.registerValue('archetype_name',@archetype_name)
          
          #Set path to OSM files. 
          alternative_model_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/#{@archetype_name}.osm")
          #load model and test.
          translator = OpenStudio::OSVersion::VersionTranslator.new
          oModel = translator.loadModel(alternative_model_path)
          if oModel.empty?
            runner.registerError("Could not load alternative model from '" + alternative_model_path.to_s + "'.")
            return false
          end
          new_model = oModel.get

          # pull original weather file object over
          weather_file = new_model.getOptionalWeatherFile
          if not weather_file.empty?
            weather_file.get.remove
            runner.registerInfo("Removed alternate model's weather file object.")
          end
          original_weather_file = model.getOptionalWeatherFile
          if not original_weather_file.empty?
            original_weather_file.get.clone(new_model)
          end

          # pull original design days over
          new_model.getDesignDays.sort.each { |designDay| designDay.remove }
          model.getDesignDays.sort.each { |designDay| designDay.clone(new_model) }

          #swap underlying data in model with underlying data in newModel
          model.swap(new_model)
          runner.registerFinalCondition("Model replaced with alternative #{alternative_model_path}.")
          return  true ? parent_method_is_true  : false
        end # end method run

        #For manually running script via an IDE or a command line script.
        #Using the template above as an example.....
        #  argument_values = [
        #       ["archetype_name",     "FullServiceRestaurant" ]
        #    ]
        #
        def set_user_arguments_and_apply(model,argument_values,runner)
          self.run(model, runner, super(model,argument_values,runner) )
        end
      end
    end

    class CSV_Measures
      def initialize(
          csv_file,
          script_root_folder_path
        )
        @csv_file_path = csv_file
        @csv_data = nil
        @script_root_folder_path = script_root_folder_path
      end


      # A tiny bit of metacode to assign some instance variables named as above. This will set
      # the above variable first to nil, then, if present in the csv row data received, the actual construction data values.
      # So we should after this loop access @ext_wall_rsi for example. If the variable is not present in the row. It will default the value to zero.
      # It should automatically make floats and strings accordingly.
      def set_instance_variables(measure_values)

        measure_values.each do |variable|
          instance_variable_set("@#{variable}", nil )
          instance_variable_set("@#{variable}", @csv_data[ variable ] )  unless ( (@csv_data.nil? == true ) or (@csv_data.has_key?(variable) == false) or (@csv_data[variable].to_s.strip.downcase == "na"))
        end
      end

      def are_all_instance_variables_nil?(measure_values)
        value = true
        measure_values.each do |variable|
          value = false unless instance_variable_get("@#{variable}").nil?
        end
        return value
      end

    end
    class CSV_OS_Measures < CSV_Measures
      #loading methods
      def side_load_base_model_building( model  )
        log_message = ""
        measure_values =["base_model_rel_path"]
        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)
        puts osm_model_full_path = "#{@script_root_folder_path}/#{@base_model_rel_path}"
        newModel = BTAP::FileIO::load_osm(osm_model_full_path,"-")
        model.swap(newModel)
        log_message << "\nModel replaced with alternative model #{osm_model_full_path}.\n"
      end
      def load_base_model_building()
        log_message = ""
        measure_values =[
          "base_model_rel_path"
        ]
        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)
        osm_model_full_path = "#{@script_root_folder_path}/#{@base_model_rel_path}"
        model = BTAP::FileIO::load_osm(osm_model_full_path,"-")
        log_message << "\nModel rloaded #{osm_model_full_path}.\n"
        return model
      end
      def set_weather_file(model)
        measure_values =["weather_file_rel_path"]
        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)
        BTAP::Site::set_weather_file(model,"#{@script_root_folder_path}/#{@weather_file_rel_path}") unless @weather_file_rel_path.nil?
        return "Set weather file to #{@weather_file_rel_path}.\n"
      end
      def set_hourly_output(model)
        #create array of output variables strings from E+
        output_variable_array =
          [
          "Facility Total Electric Demand Power",
          "Water Heater Gas Rate",
          "Plant Supply Side Heating Demand Rate",
          "Heating Coil Gas Rate",
          "Cooling Coil Electric Power",
          "Boiler Gas Rate",
          "Heating Coil Air Heating Rate",
          "Heating Coil Electric Power",
          "Cooling Coil Total Cooling Rate",
          "Water Heater Heating Rate",
          #          "Facility Total HVAC Electric Demand Power",
          #          "Facility Total Electric Demand Power",
          "Zone Air Temperature",
          "Water Heater Electric Power"
          #          "Baseboard Air Inlet Temperature",
          #          "Baseboard Air Outlet Temperature",
          #          "Baseboard Water Inlet Temperature",
          #          "Baseboard Water Outlet Temperature",
          #          "Boiler Inlet Temperature",
          #          "Boiler Outlet Temperature",
          #          "Plant Supply Side Inlet Temperature",
          #          "Plant Supply Side Outlet Temperature",
          #          "People Radiant Heating Rate",
          #          "People Sensible Heating Rate",
          #          "People Latent Gain Rate",
          #          "People Total Heating Rate",
          #          "Lights Total Heating Rate",
          #          "Electric Equipment Total Heating Rate",
          #          "Other Equipment Total Heating Rate",
          #          "District Heating Hot Water Rate",
          #          "District Heating Rate",
          #          "Air System Outdoor Air Flow Fraction",
          #          "Air System Outdoor Air Minimum Flow Fraction",
          #          "Air System Fan Electric Energy"
        ]
        BTAP::Reports::set_output_variables(model,"Hourly", output_variable_array)
        return "added output variables ..." << output_variable_array.to_s << "\n"
      end

      #Helper methods
      def create_cold_lake_vintages(output_folder = nil)
        # check if only a single vintage was requested or a full set.
        baseline_models = Hash.new()
        prototype_models = Hash.new()

        puts "Creating Baseline models"
        CSV.foreach( @csv_file_path, :headers => true, :converters => :all ) do |row|
          @csv_data = row
          unless @csv_data["measure_id"] == "NA"
            model = self.load_base_model_building()
            self.set_weather_file(model)
            self.set_hourly_output(model)
          
            model,log = self.apply_ecms(model,@csv_data)
            BTAP::FileIO::save_osm( model, "#{output_folder}/#{BTAP::FileIO::get_name(model)}.osm") unless output_folder.nil?
            File.open("#{output_folder}/#{BTAP::FileIO::get_name(model)}.log", 'w') { |file| file.write(log) }  unless output_folder.nil?
            baseline_models[BTAP::FileIO::get_name(model)] = model
          end
        end

        #create ECM models.
        puts "Creating ECM models"
        counter = 0
        baseline_models.each do |name,model|
          #Scan folder and get the ecm csv files.
          ecm_csv_files = Dir.glob( "#{@script_root_folder_path}/**/ecm_*.csv" )
          #iterate through each csv file.
          ecm_csv_files.each do |ecm_csv_file|
            puts "evaluating #{ecm_csv_file}"

            # iterate through each row
            CSV.foreach( ecm_csv_file, :headers => true, :converters => :all ) do |row|

              #  If row baseline matches current baseline name then
              if name == "#{row["building_type"]}~#{row["vintage_name"]}~baseline"
                #Skip row if measure_id is NA
                counter = counter + 1
                if row["measure_id"].nil? or row["measure_id"].upcase.strip == "NA" or row["measure_id"].upcase.strip == ""
                else
                  new_model = BTAP::FileIO::deep_copy(model)
                  new_model,log = self.apply_ecms(new_model,row)
                  BTAP::FileIO::save_osm( new_model, "#{output_folder}/#{BTAP::FileIO::get_name(new_model)}.osm") unless output_folder.nil?
                  File.open("#{output_folder}/#{BTAP::FileIO::get_name(new_model)}.log", 'w') { |file| file.write(log) }  unless output_folder.nil?
                end
              end
            end
          end
        end
        puts "ECM generation completed."
      end
      def apply_ecms(model,row_data)
        log = ""
        @csv_data = row_data
        self.methods.select{ |i| i[/^ecm_.*$/] }.each do |ecm_method_name|
          log << "**********#{ecm_method_name}\n"
          raise ("model is nil") if model.nil?
          raise ("name is nil") if ecm_method_name.nil?
          log << self.method(ecm_method_name).call(model)
        end
        return model,log
      end

      #ecms
      def ecm_capital_costs(model)
        log = ""
        measure_values =
          [
          "measure_id",
          "cost_per_floor_m2",
          "cost_per_building"
        ]
        self.set_instance_variables( measure_values )
        
        #cost per building and building area
        building = model.building.get
        raise ("you did not enter a cost for measure #{@measure_id}. All measures must have a cost of at least 0.0 .  Please add a cost_per_building field.") if @cost_per_building.nil?
        unless @cost_per_building.nil?
          BTAP::Resources::Economics::object_cost(building,"#{@measure_id} Capital Cost per building",@cost_per_building.to_f,"CostPerEach")
          log << "added cost of #{@measure_id} per building for #{@measure_id}"
          puts log
        end
        return log
      end
      def ecm_id(model)
        log = ""
        measure_values =
          [
          "building_type",
          "vintage_name",
          "measure_id"
        ]
        self.set_instance_variables( measure_values )
        BTAP::FileIO::set_name(model,"#{@building_type}~#{@vintage_name}~#{@measure_id}")
        puts BTAP::FileIO::get_name(model)
        return "Changed name to #{BTAP::FileIO::get_name(model)}"

      end
      def ecm_envelope( model )
        log = ""
        #List of variables required by this measure that are to be extracted from CSV row.
        measure_values =
          [
          "library_file",
          "default_construction_set_name",
          "ext_wall_rsi",
          "ext_floor_rsi",
          "ext_roof_rsi",
          "ground_wall_rsi",
          "ground_floor_rsi",
          "ground_roof_rsi",
          "fixed_window_rsi",
          "fixed_wind_solar_trans",
          "fixed_wind_vis_trans",
          "operable_window_rsi",
          "operable_wind_solar_trans",
          "operable_wind_vis_trans",
          "door_construction_rsi",
          "glass_door_rsi",
          "glass_door_solar_trans",
          "glass_door_vis_trans",
          "overhead_door_rsi",
          "skylight_rsi",
          "skylight_solar_trans",
          "skylight_vis_trans",
          "tubular_daylight_dome_rsi",
          "tubular_daylight_dome_solar_trans",
          "tubular_daylight_dome_vis_trans",
          "tubular_daylight_diffuser_rsi",
          "tubular_daylight_diffuser_solar_trans",
          "tubular_daylight_diffuser_vis_trans",
          "ext_wall_cost_m3",
          "ext_floor_cost_m3",
          "ext_roof_cost_m3",
          "ground_wall_cost_m3",
          "ground_floor_cost_m3",
          "ground_roof_cost_m3",
          "fixed_window_cost_m3",
          "operable_window_cost_m3",
          "door_construction_cost_m3",
          "glass_door_cost_m3",
          "overhead_door_cost_m3",
          "skylight_cost_m3",
          "tubular_daylight_dome_cost_m3",
          "tubular_daylight_diffuser_cost_m3",
          "total_building_construction_set_cost"
        ]

        self.set_instance_variables(measure_values)
        unless @default_construction_set_name.nil? or @library_file.nil?

          #    #Remove all existing constructions from model.
          BTAP::Resources::Envelope::remove_all_envelope_information( model )

          #    #Load Contruction osm library.
          construction_lib = BTAP::FileIO::load_osm("#{@script_root_folder_path}/#{@library_file}")

          #Get construction set.. I/O expensive so doing it here.
          vintage_construction_set = construction_lib.getDefaultConstructionSetByName(@default_construction_set_name)
          if vintage_construction_set.empty?
            raise("#{@default_construction_set} does not exist in #{@script_root_folder_path}/#{@library_file} library ")
          else
            vintage_construction_set = construction_lib.getDefaultConstructionSetByName(@default_construction_set_name).get
          end


          new_construction_set =vintage_construction_set.clone(model).to_DefaultConstructionSet.get
          #Set conductances to needed values in construction set if possible.
          BTAP::Resources::Envelope::ConstructionSets::customize_default_surface_construction_set_rsi!(
              model: model, name: "#{@default_construction_set}-modified",default_surface_construction_set: new_construction_set,
              ext_wall_rsi: @ext_wall_rsi, ext_floor_rsi: @ext_floor_rsi, ext_roof_rsi: @ext_roof_rsi,
              ground_wall_rsi: @ground_wall_rsi, ground_floor_rsi: @ground_floor_rsi, ground_roof_rsi: @ground_roof_rsi,
              fixed_window_rsi: @fixed_window_rsi, fixed_wind_solar_trans: @fixed_wind_solar_trans, fixed_wind_vis_trans: @fixed_wind_vis_trans,
              operable_window_rsi: @operable_window_rsi, operable_wind_solar_trans: @operable_wind_solar_trans, operable_wind_vis_trans: @operable_wind_vis_trans,
              door_construction_rsi: @door_construction_rsi,
              glass_door_rsi: @glass_door_rsi,  glass_door_solar_trans: @glass_door_solar_trans, glass_door_vis_trans: @glass_door_vis_trans,
              overhead_door_rsi: @overhead_door_rsi,
              skylight_rsi: @skylight_rsi,  skylight_solar_trans: @skylight_solar_trans, skylight_vis_trans: @skylight_vis_trans,
              tubular_daylight_dome_rsi: @tubular_daylight_dome_rsi,  tubular_daylight_dome_solar_trans: @tubular_daylight_dome_solar_trans, tubular_daylight_dome_vis_trans: @tubular_daylight_dome_vis_trans,
              tubular_daylight_diffuser_rsi: @tubular_daylight_diffuser_rsi, tubular_daylight_diffuser_solar_trans: @tubular_daylight_diffuser_solar_trans, tubular_daylight_diffuser_vis_trans: @tubular_daylight_diffuser_vis_trans
          )


          #Set as default to model.
          model.building.get.setDefaultConstructionSet( new_construction_set )

          #Set cost information.
          BTAP::Resources::Envelope::ConstructionSets::customize_default_surface_construction_set_costs(new_construction_set,
            @ext_wall_cost_m2,
            @ext_floor_cost_m2,
            @ext_roof_cost_m2,
            @ground_wall_cost_m2,
            @ground_floor_cost_m2,
            @ground_roof_cost_m2,
            @fixed_window_cost_m2,
            @operable_window_cost_m2,
            @door_construction_cost_m2,
            @glass_door_cost_m2,
            @overhead_door_cost_m2,
            @skylight_cost_m2,
            @tubular_daylight_dome_cost_m2,
            @tubular_daylight_diffuser_cost_m2,
            @total_building_construction_set_cost
          )

          #Give adiabatic surfaces a construction. Does not matter what. This is a bug in Openstudio that leave these surfaces unassigned by the default construction set.
          all_adiabatic_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(model.getSurfaces, "Adiabatic")
          unless all_adiabatic_surfaces.empty?
            BTAP::Geometry::Surfaces::set_surfaces_construction( all_adiabatic_surfaces, model.building.get.defaultConstructionSet.get.defaultInteriorSurfaceConstructions.get.wallConstruction.get)
          end
          #Create sample csv file.
          CSV.open("#{@script_root_folder_path}/sample_envelope_ecm.csv", 'w') { |csv| csv << measure_values.unshift("measure_id") }
          return BTAP::Resources::Envelope::ConstructionSets::get_construction_set_info( new_construction_set )
        end
        return "Constructions were unchanged.\n"
      end
      def ecm_infiltration( model )
        measure_values =
          [
          "infiltration_design_flow_rate",
          "infiltration_flow_per_space",
          "infiltration_flow_per_exterior_area",
          "infiltration_air_changes_per_hour"
        ]
    
        #Set all the above instance variables to the @csv_data values or, if not set or == 'na', to nil.
        self.set_instance_variables(measure_values)

        log = BTAP::Resources::SpaceLoads::ScaleLoads::set_inflitration_magnitude(
          model,
          @infiltration_design_flow_rate,
          @infiltration_flow_per_space,
          @infiltration_flow_per_exterior_area,
          @infiltration_air_changes_per_hour
        )
        return log
      end
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
              pump_variable.setRatedFlowRate(pump_const.ratedFlowRate)
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
              new_pump.setRatedPumpHead(pump.ratedPumpHead())
              new_pump.setRatedPowerConsumption(pump.ratedPowerConsumption.to_f)
              new_pump.setMotorEfficiency(pump.motorEfficiency().to_f)
              new_pump.setFractionofMotorInefficienciestoFluidStream(pump.fractionofMotorInefficienciestoFluidStream().to_f)
              new_pump.setPumpControlType( pump.pumpControlType )
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
  end
end


