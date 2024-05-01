# **************************************************************************** /
# *  Copyright (c) 2008-2024, Natural Resources Canada
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
  module ActivityData
    @@data = {bldg: {}, space: {}}

    @@data[:templates] = ["NECB2011", "NECB2015", "NECB2017", "NECB2020"]

    # Hard setting path for both files (temporary @todo)
    @@data[:bldg ][:file      ] = File.join(__dir__, "NECB_building_types.csv")
    @@data[:space][:file      ] = File.join(__dir__, "NECB_space_types.csv")
    @@data[:bldg ][:table     ] = nil
    @@data[:space][:table     ] = nil
    @@data[:bldg ][:activity  ] = {}
    @@data[:space][:activity  ] = {}
    @@data[:bldg ][:activities] = []
    @@data[:bldg ][:categories] = []

    # Parse building data on file.
    if File.exists?(@@data[:bldg][:file])
      table = CSV.open(@@data[:bldg][:file], headers: true).read

      # 35 unique entries, 6 columns per row:
      #   column 0: BTAP building ACTIVITY  e.g. "restaurant"
      #   column 1: BTAP building CATEGORY  e.g. "commerce"
      #   column 2: NECB 2011 building type e.g. "Dining - family restaurant"
      #   column 3: NECB 2015 building type
      #   column 4: NECB 2017 building type
      #   column 5: NECB 2020 building type
      table.each do |row|
        key = row[0]

        @@data[:bldg][:activity][key]             = {}
        @@data[:bldg][:activity][key][:category ] = row[1]
        @@data[:bldg][:activity][key]["NECB2011"] = row[2]
        @@data[:bldg][:activity][key]["NECB2015"] = row[3]
        @@data[:bldg][:activity][key]["NECB2017"] = row[4]
        @@data[:bldg][:activity][key]["NECB2020"] = row[5]
      end

      # Keep CSV table. Isolate admissible building activities & categories.
      @@data[:bldg][:table     ] = table
      @@data[:bldg][:activities] = table.by_col[0].uniq
      @@data[:bldg][:categories] = table.by_col[1].uniq
      # @@data[:bldg][:activities] = table.by_col[0].uniq.map!(&:to_sym)
      # @@data[:bldg][:categories] = table.by_col[1].uniq.map!(&:to_sym)

      # Add "common" & "rp28" as building activities.
      # @@data[:bldg][:activities] << :common
      # @@data[:bldg][:activities] << :rp28
      @@data[:bldg][:activities] << "common"
      @@data[:bldg][:activities] << "rp28"
      @@data[:bldg][:activities].freeze
      @@data[:bldg][:categories].freeze
    else
      # raise?
    end

    # Parse space data on file.
    if File.exists?(@@data[:space][:file])
      table = CSV.open(@@data[:space][:file], headers: true).read

      # 119 unique rows, 5 columns per row:
      #   column 0: BTAP space ACTIVITY  e.g. "exhibit::convention"
      #   column 1: NECB 2011 space type e.g. "Convention centre - exhibit"
      #   column 2: NECB 2015 space type e.g. "Convention centre exhibit space"
      #   column 3: NECB 2017 space type
      #   column 4: NECB 2020 space type
      table.each do |row|
        key = row[0]
        str = key.split("::")
        cat = str[0]
        act = str[1]

        @@data[:space][:activity][key]             = {}
        @@data[:space][:activity][key][:act      ] = act
        @@data[:space][:activity][key][:cat      ] = cat
        @@data[:space][:activity][key]["NECB2011"] = row[1]
        @@data[:space][:activity][key]["NECB2015"] = row[2]
        @@data[:space][:activity][key]["NECB2017"] = row[3]
        @@data[:space][:activity][key]["NECB2020"] = row[4]
      end

      @@data[:space][:table] = table
    else
      # raise?
    end

    ##
    # Returns BTAP Activity data.
    #
    # @return [Hash] BTAP Activity data
    def data
      @@data
    end

    def self.extended(base)
      base.send(:include, self)
    end
  end

  class BTAP::Activity
    extend ActivityData

    # @return [Integer] NECB template (e.g. "NECB2011")
    attr_reader :template

    # @return [String] assigned building ACTIVITY (e.g. "warehouse")
    attr_reader :activity

    # @return [String] building type CATEGORY (e.g. "industry")
    attr_reader :category

    # @return [String] associated BTAP/NECB building type (e.g. "Warehouse")
    attr_reader :stdtype

    # @return [Hash] logged messages
    attr_reader :feedback


    ##
    # Initialize BTAP Activity parameters.
    #
    # @param model [OpenStudio::Model::Model] a model
    # @param template [String] an NECB template
    def initialize(model = nil, template = "NECB2011")
      @template = template.respond_to?(:to_s) ? template.to_s.upcase : ""
      @activity = ""
      @category = ""
      @type     = ""
      @feedback = {logs: []}

      lgs = @feedback[:logs]
      mth = "BTAP::Activity::#{__callee__}"

      unless model.is_a?(OpenStudio::Model::Model)
        lgs << "Invalid or empty OpenStudio model (#{mth})"
        return
      end

      if @template.empty?
        lgs << "Invalid NECB template: #{template.class} (#{mth})"
        return
      else
        unless data[:templates].include?(@template)
          lgs << "#{@template}? Unknown NECB template (#{mth})"
          return
        end
      end

      # Both module CSV files, in addition to a valid OSM file holding either:
      #   - a valid NECB building TYPE string, or
      #   - a combination of valid NECB space TYPE strings
      #
      # ... allow BTAP to set a single building CATEGORY per model, from which
      # other key BTAP attributes are set, e.g. structure, envelope. BTAP users
      # may hard-set an OSM's building TYPE, or let the solution auto-assign an
      # NECB building TYPE, ACTIVITY and CATEGORY, based on the prevalence of
      # NECB space types in a model.
      bldg = model.getBuilding
      type = bldg.standardsBuildingType

      unless type.empty?
        type = type.get.downcase

        # Matching building ACTIVITY?
        data[:bldg][:activity].each do |key, value|
          break unless activity.empty?
          next  unless type.include?(key)

          @activity = key
          @category = value[:category]
          @stdtype  = value[template]
        end
      end

      # @todo: Pursue if @activity empty (e.g. loop through std space types).

      # @todo: Many NECB space types are listed as "common". Examples include
      #        spaces that are educational in nature (e.g. "clssroom",
      #        "teachinglabs", "auditorium"), typical office spaces (e.g.
      #        "openplan", "office", "meeting"). This prevents easily auto-
      #        assigning an overall building type/activity, based on the
      #        prevalence of space types in a model (e.g. "school"). A fallback
      #        solution is needed when the predominant space type ends up
      #        "common" or "rp28" for a given model, such as looking up the 2nd
      #        (or 3rd) most predominant space type, e.g. "classroom" or
      #        "office". In such cases, the easiest remains simply assigning an
      #        NECB building type in the model.
    end
  end

  # ---- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---- #
  # Temporary testing.
  # activity = BTAP::Activity.new
  # puts activity.data[:space][:table].headers
  # puts activity.data[:bldg][:activity].size
  # puts activity.data[:bldg][:activities].size # 37 = 35 + "common" + "rp28"

  # activity.data[:space][:activity].values.each_with_index do |v, i|
  #   raise "BLDG?" unless activity.data[:bldg][:activities].include?(v[:act])
  # end
end
