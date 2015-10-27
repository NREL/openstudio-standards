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



#Add this to Openstudio.rb
# require File.expand_path(File.dirname(__FILE__)) + /btap


require 'openstudio'
require 'openstudio/energyplus/find_energyplus'
require 'fileutils'
require 'singleton'
require 'find'
require 'date'
require "#{File.dirname(__FILE__)}/fileio" 
require "#{File.dirname(__FILE__)}/geometry" 
require "#{File.dirname(__FILE__)}/compliance" 
require "#{File.dirname(__FILE__)}/analysis" 
require "#{File.dirname(__FILE__)}/simmanager" 
require "#{File.dirname(__FILE__)}/environment" 
require "#{File.dirname(__FILE__)}/mpc" 
require "#{File.dirname(__FILE__)}/envelope"
require "#{File.dirname(__FILE__)}/spaceloads"
require "#{File.dirname(__FILE__)}/spacetypes"
require "#{File.dirname(__FILE__)}/schedules"
require "#{File.dirname(__FILE__)}/hvac"
require "#{File.dirname(__FILE__)}/economics"
require "#{File.dirname(__FILE__)}/measures"
require "#{File.dirname(__FILE__)}/utilities"
require "#{File.dirname(__FILE__)}/os_lib_schedules"
require "#{File.dirname(__FILE__)}/reporting"
require "#{File.dirname(__FILE__)}/equest"
 
class String
  #This method converts to Boolean.
  #@author phylroy.lopez@nrcan.gc.ca
  def to_bool
    return true if self == true || self =~ (/^(true|t|yes|y|1)$/i)
    return false if self == false  || self =~ (/^(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end
end


class Fixnum
  #This method converts to Boolean.
  #@author phylroy.lopez@nrcan.gc.ca
  def to_bool
    return true if self == 1
    return false if self == 0
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end
end

class TrueClass
  #This method converts to i.
  #@author phylroy.lopez@nrcan.gc.ca
  def to_i; 1; end
  #This method converts to Boolean.
  #@author phylroy.lopez@nrcan.gc.ca
  def to_bool; self; end
end

class FalseClass
  #This method converts to i.
  #@author phylroy.lopez@nrcan.gc.ca
  def to_i; 0; end
  #This method converts to Boolean.
  #@author phylroy.lopez@nrcan.gc.ca
  def to_bool; self; end
end

class NilClass
  #This method converts to Boolean.
  #@author phylroy.lopez@nrcan.gc.ca
  def to_bool; false; end
end


# A set of methods developed by NRCan to simplify building model creation and
# analysis. These methods are meant to compliment the OpenStudio classes and methods
# For full access to the OpenStudio API please refer to the OpenStudio Website.
# http://openstudio.nrel.gov/latest-c-sdk-documentation/model
module BTAP

  #Path constants
  OS_RUBY_PATH = File.expand_path("..\\..\\..", __FILE__)
  TESTING_FOLDER = "C:\\test"
  
#  A wrapper for outputing feedback to users and developers. 
#  BTAP::runner_register("InitialCondition",   "Your Information Message Here", runner)
#  BTAP::runner_register("Info",    "Your Information Message Here", runner)
#  BTAP::runner_register("Warning", "Your Information Message Here", runner)
#  BTAP::runner_register("Error",   "Your Information Message Here", runner)
#  BTAP::runner_register("Debug",   "Your Information Message Here", runner)
#  BTAP::runner_register("FinalCondition",   "Your Information Message Here", runner)
#  @params type [String]
#  @params runner [OpenStudio::Ruleset::OSRunner] # or a nil. 
  def self.runner_register(type,text,runner = nil)
    #dump to console. 
    puts "#{type.upcase}: #{text}"
    #dump to runner. 
    if runner.is_a?(OpenStudio::Ruleset::OSRunner)
      case type.downcase
      when "info"
        runner.registerInfo(text)
      when "warning"
        runner.registerWarning(text)
      when "error"
        runner.registerError(text)
      when "notapplicable"
        runner.registerAsNotApplicable(text)
      when "finalcondition"
        runner.registerFinalCondition(text)
      when "initialcondition"
        runner.registerInitialCondition(text)
      when "debug"
      else
        raise("Runner Register type #{type.downcase} not info,warning,error,notapplicable,finalcondition,initialcondition.")
      end
    end
  end
  
  def self.runner_register_value(name,value,runner = nil)
    if runner.is_a?(OpenStudio::Ruleset::OSRunner)
      runner.registerValue( name,value.to_s)
      BTAP::runner_register("Info", "#{name} = #{value} has been registered in the runner", runner)
    end
  end
  
  
  
  

  
  
  
  def self.gut_building(model)
    #clean up any remaining items that we don't need for NECB.
    puts "Removing casual loads."
    BTAP::Resources::SpaceLoads::remove_all_casual_loads(model)
    puts "Removing space loads."
    BTAP::Resources::SpaceLoads::remove_all_SpaceLoads(model)
    puts "Removing OA loads."
    BTAP::Resources::SpaceLoads::remove_all_DesignSpecificationOutdoorAir(model)
    puts "Removing Envelope"
    BTAP::Resources::Envelope::remove_all_envelope_information(model)
    puts "Removing Infiltration"
    BTAP::Resources::SpaceLoads::remove_all_SpaceInfiltrationDesignFlowRate(model)
    puts "Removing all Schedules"
    BTAP::Resources::Schedules::remove_all_schedules( model )
    puts "Removing HVAC"
    BTAP::Resources::HVAC.clear_all_hvac_from_model( model )
  end
  

  class OpenStudioLibrary
    include Singleton
    attr_accessor :library
    #This method initializes the library.
    #@author phylroy.lopez@nrcan.gc.ca
    def initialize()
      #path to openstudio library
      @lib_path = "C:\\Program Files (x86)\\OpenStudio 1.2.0\\share\\openstudio\\OSApp\\hvaclibrary\\hvac_library.osm"
      @library = BTAP::FileIO::load_osm(@lib_path, "OpenStudio_Library")
    end
  end
  module SimulationSettings
    #This sets the simulation period for the model. All arguments are integers.
    #@author Phylroy A. Lopez
    #@params model [OpenStudio::model::Model] A model object {http://openstudio.nrel.gov/latest-c-sdk-documentation/model}
    #@params start_month [Integer] a list of output variables that you wish to report from the simulation.
    #@params start_day [Integer] a list of output variables that you wish to report from the simulation.
    #@params end_month [Integer] a list of output variables that you wish to report from the simulation.
    #@params end_day [Integer] a list of output variables that you wish to report from the simulation.
    #@params repeat [Integer = 1] Number of times the simulation period is run. 1 is default.
    #@return model [OpenStudio::Model::Model] the OpenStudio model object (self reference).
    def self.set_run_period(model,start_month,start_day,end_month,end_day, repeat = 1)
      raise("Run Period is invalid") unless Date.valid_civil?(2001, start_month , start_day) and Date.valid_civil?(2001, end_month , end_day) and repeat > 0
      run_period = model.getRunPeriod
      run_period.setBeginMonth(start_month)
      run_period.setBeginDayOfMonth(start_day)
      run_period.setEndMonth(end_month)
      run_period.setEndDayOfMonth(end_day)
      run_period.setNumTimePeriodRepeats(repeat)
      return model
    end
  end
  module Reports
    #This method clears all the output variables to make simulations run faster or to
    #start fresh.
    #@author Phylroy A. Lopez
    #@params model [OpenStudio::model::Model] A model object {http://openstudio.nrel.gov/latest-c-sdk-documentation/model}
    #@return [OpenStudio::Model::Model] the OpenStudio model object (self reference).
    def self.clear_output_variables(model)
      #remove existing outputs
      model.getOutputVariables.each do |object|
        object.remove
      end
      return model
    end

    #This turns all output on. Warning: Long runtimes will result.
    #@author Phylroy A. Lopez
    #@params model [OpenStudio::model::Model] A model object
    #@params frequency [Fixnum]
    #@return model [OpenStudio::Model::Model] a copy of the OpenStudio model object (self reference).
    def self.all_output_variables(model,frequency)
      BTAP::Reports::set_output_variables(model, frequency, BTAP::Reports::get_possible_output_variables(model))
      return model
    end

    #This method returns a vector of the results that are available in the current
    #model.
    #@author Phylroy A. Lopez
    #@params model [OpenStudio::model::Model] A model object
    #@return output_variables [Array<String>] a list of all the possible output variables.
    def self.get_possible_output_variables( model )
      #Run simulation
      copy = BTAP::FileIO::deep_copy(model)
      copy.building.get.setName("rdd_run")
      BTAP::SimulationSettings::set_run_period(copy, 1, 1, 1, 1)
      BTAP::SimManager::run_simulation(copy,"C:\\temp\\rdd_maker")
      rdd_file_path = ""
      Find.find("C:\\temp\\rdd_maker") do |path|
        rdd_file_path = path if path =~ /.*\.rdd$/
      end
      contents = File.read(rdd_file_path)
      output_variables = Array.new()
      contents.each do |line|
        match = line.match /^\s*Output:Variable,\*,(.*),(.*);(.*)/
        if match
          output_variables.push(match[1])
        end
      end
      return output_variables
    end

    #This method sets up some predetermined output variables. May take a while to run with these settings.
    #@author Phylroy A. Lopez
    #@params model [OpenStudio::model::Model] A model object
    #@params frequency [Fixnum]
    #@params output_variable_array [Array<String>] a list of output variables that you wish to report from the simulation.
    #@return model [OpenStudio::Model::Model] the OpenStudio model object (self reference).
    def self.set_output_variables(model,frequency, output_variable_array)
      raise("Frequency is not valid. Must by \"Hourly\" or \"Timestep\" but got #{frequency}.") unless ["Hourly","Timestep"].include?(frequency)
      output_variable_array.each do |variable|
        output = OpenStudio::Model::OutputVariable.new(variable,model)
        output.setKeyValue("*")
        output.setReportingFrequency(frequency)
      end
      return model
    end


  end
  module Site
    #This method sets the weather file for the model.
    #It takes a simple string, remember to escape the slashes..(i.e. // not / )
    #@author Phylroy A. Lopez
    #@params model [OpenStudio::model::Model] A model object
    #@params  epw_path [String] a simple string of the epw file path, remember to escape the slashes..(i.e. // not / )
    def self.set_weather_file(model, epw_path)
      BTAP::Environment::WeatherFile.new(epw_path).set_weather_file(model)
    end

  end
  # This contains methods for creation and querying object that deal with Envelope, SpaceLoads,Schedules, and HVAC.
  
  module Common
    #This model checks to see if the obj_array passed is
    #the object we require, or if a string is given to search for a object of that strings name.
    #@author Phylroy A. Lopez
    #@params model [OpenStudio::model::Model] A model object
    #@params obj_array <Object>
    #@params object_type [Object]
    def self.validate_array(model,obj_array,object_type)

      command =
        %Q^#make copy of argument to avoid side effect.
        object_array = obj_array
        new_object_array = Array.new()
        #check if it is not an array
        unless  obj_array.is_a?(Array)
          if object_array.is_a?(String)
            #if the arguement is a simple string, convert to an array.
            object_array = [object_array]
            #check if it is a single object_type
          elsif not object_array.to_#{object_type}.empty?()
            object_array = [object_array]
          else
            raise("Object passed is neither a #{object_type} or a name of a #{object_type}. Please choose a #{object_type} name that exists such as :\n\#{object_names.join("\n")}")
          end
        end

        object_array.each do |object|
          #if it is a string name of an object, try to find it and insert it into the
          # return array.
          if object.is_a?(String)
            if model.get#{object_type}ByName(object).empty?
               #if we could not find an exact match. raise an exception.
               object_names = Array.new
               model.get#{object_type}s.each { |object| object_names << object.name }
              raise("Object passed is neither  a #{object_type} or a name of a #{object_type}. Please choose a #{object_type} name that exists such as :\n\#{object_names.join("\n")}")
            else
            new_object_array << model.get#{object_type}ByName(object).get
            end
          elsif not object.to_#{object_type}.empty?
          #if it is already a #{object_type}. insert it into the array.
          new_object_array << object
          else
            raise("invalid object")
          end
        end
        return new_object_array
      ^
      eval(command)
    end

    #This method gets a date from a string.
    #@author phylroy.lopez@nrcan.gc.ca
    #@params datestring [String] a date string
    def self.get_date_from_string(datestring)
      month = datestring.split("-")[0].to_s
      day   = datestring.split("-")[1].to_i
      month_list = ["Jan","Feb","Mar","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
      raise ("Month given #{month} is not in format required please enter month with following 3 letter format#{month_list}.") unless month_list.include?(month)
      OpenStudio::Date.new(OpenStudio::MonthOfYear.new(month),day)
    end

    #This method gets a time from a string.
    #@author phylroy.lopez@nrcan.gc.ca
    #@params timestring [String] a time string
    def self.get_time_from_string(timestring)
      #ensure that it is in 0-24 hour format.
      hour = timestring.split(":")[0].to_i
      min = timestring.split(":")[1].to_i
      raise ("invalid time format #{timestring} please use 0-24 as a range for the hour and 0-59 for range for the minutes: Clock starts at 0:00 and stops at 24:00") if (hour < 0 or hour > 24) or ( min < 0 or min > 59 ) or (hour == 24 and min > 0)
      OpenStudio::Time.new(timestring)
    end
  end
end
#module BTAP

#This method creates a proposed model.
#@author phylroy.lopez@nrcan.gc.ca
#@params non_compliance_model [OpenStudio::model::Model]
def self.create_proposed_model(non_compliance_model)
  # copy non-compliance model.
  proposed_model = BTAP::FileIO::deep_copy(non_compliance_model)
  # Remove all non used resources.
  proposed_model.purgeUnusedResourceObjects()

  BTAP::Compliance::NECB2011::Rules::rule_8_4_3_2(non_compliance_model)

  BTAP::Compliance::NECB2011::Rules::rule_8_4_3_2(non_compliance_model)

  BTAP::Compliance::NECB2011::Rules::rule_8_4_3_3(non_compliance_model)

  BTAP::Compliance::NECB2011::Rules::rule_8_4_3_4(non_compliance_model)

  BTAP::Compliance::NECB2011::Rules::rule_8_4_3_5(non_compliance_model)

  BTAP::Compliance::NECB2011::Rules::rule_8_4_3_6(non_compliance_model)

  BTAP::Compliance::NECB2011::Rules::rule_8_4_3_7(non_compliance_model)

  BTAP::Compliance::NECB2011::Rules::rule_8_4_3_8(non_compliance_model)

  BTAP::Compliance::NECB2011::Rules::rule_8_4_3_9(non_compliance_model)

  BTAP::Compliance::NECB2011::Rules::rule_8_4_3_10(non_compliance_model)

end

#This method creates a reference model.
#@author phylroy.lopez@nrcan.gc.ca
#@params model [OpenStudio::model::Model] A model object
#@params hdd [String] 
#@params auto_blinds [Boolean] 
#@params auto_windows [Boolean] 
def self.create_reference_model(model, hdd, auto_blinds = false , auto_windows = false)
  # Section 8.4.4.1
  #     Sentence 1
  #         No action required.
  #     Sentence 2
  #         Set Precriptive requirements from Section 3.2
  #         Set Precriptive requirements from Section 4.2
  #         Set Precriptive requirements from Section 5.2
  #         Set Precriptive requirements from Section 6.2
  #         Set Precriptive requirements from Section 7.2
  #
  #     Sentence 3
  #         No action required.
  #     Sentence 4
  #         No action required.
  #     Sentence 5
  #         No action required.
  #     Sentence 6
  #         No action required.
  #     Sentence 7
  #         No action required.
  # Section 8.4.4.2
  #         No action required. Same as proposed.
  # Section 8.4.4.3
  #     Sentence 1
  #         No action required. Same as proposed.
  #     Sentence 2
  #         **This does not make sense, why is this in the reference building?**
  # Section 8.4.4.4 Building Envelope Components
  #     Sentence 1
  #         No action required. Same as proposed.
  #     Sentence 2
  #         Set solar absortptance to 0.7 since user will have entered this for the non-compliance building.
  #     Sentence 3
  #         Set Fenestration to wall ratio as per 3.2.1.4
  #     Sentence 4
  #         Remove all permanent shading devices.
  #     Sentence 5
  #         Allow external shading from buildings or external structures.
  #     Sentence 6
  #         No action required. Infiltration is the same as proposed.
  #     Sentence 7
  #         No action required. Heat transfer through interior partitions are the same as proposed.
  # Section 8.4.4.5
  #     Sentence 1
  #         Set Thermal mass to density = 40.8 kg/m2 and specific heat = 45.5 kJ/(m2*C) for all contructions, as per Appendix A example 1
  #     Sentence 2
  #         No action required. Same as proposed.
  #
  # Section 8.4.4.6
  #     Sentence 1
  #         Ensure that lighting power density adhear to Section 4.2.1.5 and 4.2.1.6
  #     Sentence 2
  #         Set dwelling units to a LPD or 5 W/m2. This was done in proposed.
  #     Sentence 3
  #         If occupancy sensors are used. Set adjust LPD to 90%
  #     Sentence 4
  #         No action required. Radiant, Convective and portion of heat directed to return is the same as proposed.
  #
  # Section 8.4.4.7 Purchased Energy
  #     Sentence 1
  #         a) Purchased heating should be an electric boiler.
  #         b) 100% eff constant.
  #         c) boiler capacity = prop purchased energy capacity / proposed total heating capacity * reference total heating capacity.
  #     Sentence 2
  #         a) Purchased heating should be an electric boiler.
  #         b) 1.0 COP constant.
  #         c) chiller capacity = prop purchased cooling energy capacity / proposed total cooling capacity * reference total cooling capacity.
  #     Sentence 3
  #         a) Purchased hot water should be an electric boiler. (might need a gui)
  #         b) 100% eff constant.
  #         c) boiler capacity = prop purchased energy capacity / proposed total heating capacity * reference total heating capacity.
  #     Sentence 4
  #         Operating schedules, priority and other operations charecteristics of purchased energy should be included.
  # Section 8.4.4.8
  #     Sentence 1 & 2
  #         Loop though all space types can group systems based on Table 8.4.4.8.A and 8.4.4.8.B Throw an error if space types are not NECB types.
  #     Sentence 3
  #         No action required.
  #     Sentence 4
  #         For each zone that that has a heat pump in the proposed building, follow Section 8.4.4.14
  #
  # Section 8.4.4.9 Equipment Oversizing
  #     Sentence 1
  #         heating sizing factor = [proposed heating over sizing, 30%].min
  #     Sentence 2
  #         cooling sizing factor = [proposed heating over sizing, 10%].min
  #
  #
  #
  # Section 8.4.4.10 Heating System
  # Section 8.4.4.11 Cooling System
  # Section 8.4.4.12 Cooling Towers
  # Section 8.4.4.13 Cooling with OA
  # Section 8.4.4.14 Heat Pumps
  # Section 8.4.4.15 Hydronic Pumps
  # Section 8.4.4.16 OA
  # Section 8.4.4.17 Space Temperature Control
  # Section 8.4.4.18 Fans
  # Section 8.4.4.19 Supply Air Systems
  # Section 8.4.4.20 Heat Recovery Systems
  # Section 8.4.4.21 Service Water Heating Systems
  # Section 8.4.4.22 Performance Curves.
end