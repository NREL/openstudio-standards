# **************************************************************************** /
# *  Copyright (c) 2008-2025, Natural Resources Canada
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
# *  Foundation Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
# **************************************************************************** /

require "csv"

module BTAP
  module DefaultData
    ##
    # @author: Denis Bourgeois
    #
    # Centralizes declaration/definition of common BTAP/NECB parameters, e.g.
    # BTAP CLI run options, NECB's model_apply_standard. For now, this is in
    # CSV format: could instead be JSON or YAML (ideally requiring a schema).
    #
    # Information contained in the openstudio-standards/btap/defaults.csv has
    # been gathered by searching through multiple BTAP/NECB files. This is time
    # consuming and cumbersome for any novice (e.g. new employee, graduate
    # student), further justifying the need to centralize core BTAP/NECB
    # parameters. Similarly, many of these parameters are simply set to
    # "NECB_Default", the meaning of which varies from one BTAP/NECB method to
    # another. Most times this is simply a proxy for a nilled variable, e.g. to
    # safely exit a method. Again, cumbersome and time consuming to audit.
    #
    # The proposed solution is to centralize all key parameters in a single
    # file, with at a minimum:
    #   - the name of each parameter
    #   - its assigned default value
    #
    # The file also provides BTAP developers a means to optionally circumscribe
    # parameter attributes, such as defining its class, admissible variants or
    # numeric range, as well as a comment section. This hints at a data
    # dictionary (similar to EnergyPlus' IDD file), but it is not meant to be.
    # It is really up to individual BTAP developers to decide on how to proceed.
    @@data = { param: {}, file: File.join(__dir__, "necb_defaults.csv") }

    if File.exist?(@@data[:file])
      table = CSV.open(@@data[:file], headers: true).read
      #  6 columns: PARAMETER  variable name                required
      #             CLASS      object class                 optional
      #             DEFAULT    default value                required
      #             VARIANTS   admissible variants          optional
      #             RANGE      admissible range if numeric  optional
      #             COMMENT    support text                 optional
      #
      #  examples (spaces added for clarity):
      #
      #   PARAMETER            CLASS        DEFAULT  VARIANTS, RANGE & COMMENT
      #   ____________________ ____________ ________ ___________________________
      #   btap_weather,        boolean,       false, ,,see necb_2011.rb
      #   daylighting_type,    string,          nil, add_daylighting_controls,,
      #   fdwr_set,            float,           nil, ,,
      #   boiler_cap_ratio,    float,           nil, 0/1,,
      #   boiler_eff,          string/hash,     nil, ,,see hvac_systems.rb
      #   nv_opening_fraction, float,           nil, , 0/1,
      #   s3_bucket,           string, 834599497928, ,,
      #
      # All items in the CSV file are parsed and stored as strings, by default.
      # If CLASS is 'boolean', then either DEFAULT 'true' or 'false' is
      # converted as either boolean. If a PARAMETER holds a CLASS specification,
      # e.g. 'string' for 's3_bucket', then the DEFAULT '834599497928' is
      # maintained as a string. If CLASS is instead a numeric (e.g. float or
      # integer), then the DEFAULT is converted accordingly.
      #
      # In model_apply_standard, the vast majority of its arguments are nilled,
      # as reflected in the examples above. If DEFAULT is set to 'nil', then the
      # the variable is actually nilled, and no other validation is applied.
      #
      # If CLASS is left blank, it remains an empty string - deactivating any
      # subsequent validation. CLASS can also hold more than one class. In the
      # case of boiler_eff for instance, CLASS is set as 'string/hash' - this
      # indicates to users what is admissible.
      #
      # VARIANTS may help BTAP developers and users to further circumscribe how
      # a PARAMETER may be set. For instance, only 'add_daylighting_controls' is
      # an admissible VARIANT for 'daylighting_type' (nilled by default). In
      # other cases, the size of admissible VARIANTS may be too great or complex
      # to handle via this mecanism, e.g. all possible EPW files. Other examples
      # include admissible heating fuels or admissible 'boiler_eff' strings:
      #
      # - NECB 85% Efficient Condensing Boiler
      # - NECB 88% Efficient Condensing Boiler
      # - NECB 91% Efficient Condensing Boiler
      # - NECB 94% Efficient Condensing Boiler
      # - Viessmann Vitocrossal 300 CT3-17 96.2% Efficient Condensing Gas Boiler
      #
      # These are currently held as admissible VARIANTS in the CSV file, simply
      # to demonstrate that the solution works as is. If this were to become the
      # main BTAP approach, a more suitable format (like JSON or YAML) may be
      # better suited for complex information like hashes.
      #
      # RANGE is similar to VARIANTS, yet applies only to numeric PARAMETERS,
      # e.g. COP, efficiencies, U-factors. It's up to individual BTAP developers
      # to provide/use this feature.
      #
      # COMMENTS may also point users to inline comments (e.g. see Line ~378
      # in necb_2011.rb) or online README files. Anything that may help a user
      # get a better sense of a PARAMETER's use, scope, model limitations, etc.

      # Default data on file is stored in a hash of hashes, with each PARAMETER
      # as key to an individual hash (once converted as a symbol).
      table.each do |row|
        next unless row[0].respond_to?(:to_sym)

        key = row[0].downcase.to_sym

        @@data[:param][key]            = {}
        @@data[:param][key][:class   ] = row[1].to_s.split("/")
        @@data[:param][key][:default ] = row[2].to_s
        @@data[:param][key][:variants] = row[3].to_s.split("/")
        @@data[:param][key][:range   ] = row[4].to_s.split("/")
        @@data[:param][key][:comment ] = row[5].to_s
      end

      # Overwrite values if required.
      @@data[:param].each do |k, v|
        next unless v[:class].size == 1

        v[:class] = v[:class].first.downcase
        next if v[:class].empty?

        if v[:class] == "boolean"
          v[:default ] = v[:default].downcase
          v[:class   ] = v[:default] == "true" ? TrueClass : FalseClass
          v[:default ] = v[:default] == "true" ? true : false
          v[:variants] = []
          v[:range   ] = []
        elsif v[:default].downcase == "nil"
          v[:default ] = nil
        end

        if v[:class] == "integer"
          unless v[:default].nil?
            val = Integer(v[:default], exception: false)
            # raise "#{k}" if val.nil?
            v[:default] = val unless val.nil?
          end

          var = []

          v[:variants].each do |variant|
            val = Integer(variant, exception: false)
            # raise "#{k}" if val.nil?
            var << val unless val.nil?
          end

          v[:variants] = var
          v[:range   ] = v[:range][0..1] if v[:range].size > 2

          rg = []

          v[:range].each do |rang|
            val = Integer(rang, exception: false)
            # raise "#{k}" if val.nil?
            rg << val unless val.nil?
          end

          v[:range] = rg

          if v[:range].size == 1
            first = v[:range].first
            v[:default] = [v[:default], first].min unless v[:default].nil?
          elsif v[:range].size == 2
            first = v[:range].first
            last  = v[:range].last
            v[:default] = v[:default].clamp(first, last) unless v[:default].nil?
          end
        elsif v[:class] == "float"
          unless v[:default].nil?
            val = Float(v[:default], exception: false)
            # raise "#{k}" if val.nil?
            v[:default] = val unless val.nil?
          end

          var = []

          v[:variants].each do |variant|
            val = Float(variant, exception: false)
            # raise "#{k}" if val.nil?
            var << val unless val.nil?
          end

          v[:variants] = var
          v[:range   ] = v[:range][0..1] if v[:range].size > 2

          rg = []

          v[:range].each do |rang|
            val = Integer(rang, exception: false)
            # raise "#{k}" if val.nil?
            rg << val unless val.nil?
          end

          v[:range] = rg

          if v[:range].size == 1
            first = v[:range].first
            v[:default] = [v[:default], first].min unless v[:default].nil?
          elsif v[:range].size == 2
            first = v[:range].first
            last  = v[:range].last
            v[:default] = v[:default].clamp(first, last) unless v[:default].nil?
          end
        end
      end

      puts "done!"
    end

    ##
    # Returns Defaulted parameters.
    #
    # @return [Hash] Default data
    def data
      @@data
    end

    def self.extended(base)
      base.send(:include, self)
    end
  end

  module Defaults
    extend DefaultData
  end
end

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
# NOTES:
#
# A handful of parameters are unsued, mispelled (i.e. not caught), etc., e.g.:
#
#   analysis_name,string,test_analysis_para,,,deprecated?
#
# ... is specified in both:
#     - utilities/btap_cli/tests/run_options.yml
#     - utilities/btap_cli/tests/run_options.yml
#
# ... yet never used in BTAP/NECB.
#
# Another example (necb_2011.rb):
#
#   def model_enable_demand_controlled_ventilation(model, dcv_type = 'No_DCV')
#     return if dcv_type == 'NECB_Defualt'
#
# The intention is to clearly bail out of the method if set to NECB_Default, yet
# the exit condition is ignored given the typo. Luckily, it looks like the
# subsequent sections of the same method appear sufficiently robust to handle
# the typo, but that's something to fix (@todo).
#
# BTAP/NECB documentation also suggests the following admissible VARIANTS:
#   - No_DCV
#   - No DCV
#   - Occupancy_based_DCV
#   - Occupancy-based DCV
#   - CO2_based_DCV
#   - CO2-based DCV
#
# For instance, in unit test 'test_daylighting_sensor_control.rb':
#
#   @dcv_types = ['No DCV']
#
# ... is likely inactive ?!
