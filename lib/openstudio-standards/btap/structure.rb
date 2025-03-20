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

module BTAP
  module StructureData
    ##
    # @author: Denis Bourgeois
    #
    # Building STRUCTURE parameters, ultimately driving BTAP definitions of e.g.
    #   - internal mass
    #   - envelope CLADDING/FRAMING/FINISH selection
    #   - related thermal bridging calculations (and uprated insulation levels)
    #   - costing
    #   - embodied carbon tallies
    #
    # As detailed a bit further on, this determination is either via user input:
    #   - e.g. "clt" (mass timber) post/beam STRUCTURE, for a school.
    #
    # Or auto-assigned based on the prevalence of model space type assignments:
    #   - e.g. 75% of spaces are commercial in nature (see activity.rb),
    #     therefore the building STRUCTURE defaults to "steel" post/beam.
    #
    # The overarching idea is that (in most cases) OpenStudio surface
    # construction & material choices (in addition to internal mass definitions),
    # mostly stem from underlying structural design choices (which aren't
    # natively defined in OpenStudio). Structural choices have more to do with
    # fire safety, budget, durability & practicality (low-rise vs high-rise),
    # local workforce, on-site vs prefab, etc.
    #
    # Ensuring consistency between building STRUCTURE, envelope selection,
    # internal mass definitions, etc. is key in harmonizing predicted energy
    # use, peak demand assessments, GHG emissions, vs thermal resilience and
    # embodied energy/GHG tallies.
    #
    # --- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- --- #
    # Although "wood" framed walls constitute the load-bearing components of a
    # "wood" framed building STRUCTURE (ex. low-rise housing), they can equally
    # be found as non-load-bearing components in a "clt" post-beam STRUCTURE.
    # Light gauge "steel" framed walls are much more common in a non-residential
    # STRUCTURE (e.g. "steel" post/frame, "concrete" post & beam, and even
    # "clt"), though rarely found in low-rise housing. Although one may observe
    # some real-world mixing of STRUCTURE vs FRAMING in a building, it remains
    # largely deterministic: designers select constructions (FRAMING,
    # insulation) while taking building classification and STRUCTURE selection
    # into consideration - the inverse is rarely true.
    #
    #   STRUCTURE   description
    #   __________  ___________________________________________________________
    #   "steel"     steel, post/frame (default)
    #   "metal"     prefab panelized steel STRUCTURE (**, ++), typically 1 story
    #   "concrete"  reinforced concrete, post/beam/slab
    #   "cmu"       load-bearing concrete masonry unit walls, typically 1-story
    #   "wood"      conventional load-bearing wood-framed and/or -engineered
    #   "clt"       prefab, post/beam mass/cross-laminated/timber (**)
    #
    #   NOTES:
    #
    #    **  Neither "metal" nor "clt" options can be considered as fully
    #        supported by BTAP, e.g.:
    #          - no range of admissible envelope Uo factors
    #          - no associated PSI-factors (thermal bridging)
    #          - no costing data
    #          - no embodied energy/carbon data
    #        They are nonetheless (minimally) maintained here as an
    #        "aide-mémoire" for future BTAP upgrades - @todo.
    #
    #    ++  ASHRAE 90.1 2022 definitions of:
    #
    #        "METAL BUILDING": a complete integrated set of mutually dependent
    #        components and assemblies that form a building, which consists of
    #        a steel-framed superSTRUCTURE and metal skin.
    #
    #        "METAL BUILDING ROOF": a roof that:
    #        a. is constructed with a metal, structural, weathering surface;
    #        b. has no ventilated cavity; and
    #        c. has the insulation entirely below deck (i.e., does not include
    #           composite concrete and metal deck construction nor a roof
    #           FRAMING system that is separated from the superSTRUCTURE by a
    #           wood substrate) and whose STRUCTURE consists of one or more of
    #           the following configurations:
    #           1. Metal roofing in direct contact with steel FRAMING members
    #           2. Metal roofing separated from steel FRAMING by insulation
    #           3. Insulated metal roofing panels installed per (a) or (b)
    #
    #        "METAL BUILDING WALL": a wall whose STRUCTURE consists of metal
    #        spanning members supported by steel structural members (i.e. does
    #        not include spandrel glass or metal panels in curtain wall systems).
    #
    # Note that there's a (growing?) need to contrast "metal" buildings against
    # the default "steel" post/beam option. Like a "wood" framed STRUCTURE or a
    # load-bearing "cmu" wall, a "metal" building's envelope structure and skin
    # are indistinguishable, i.e. no mixing/matching of STRUCTURE vs envelope.
    #
    # There are of course several other (smaller scale) structural options,
    # often load-bearing envelopes like adobe/hemp/straw bale construction. Most
    # would agree that these are fairly rare occurrences - rare enough to avoid
    # shortlisting them for commercial building stock assessments. One could
    # state the same when it comes to the current (marginal) use of "clt". Yet
    # as the latter is rapidly becoming a robust low-carbon alternative to
    # "steel" and "concrete" options, its inclusion is justified. Additional
    # options may nonetheless be added in the future.
    @@data = {structure: {}, cladding: {}, finish: {}, category: {}}

    # Each STRUCTURE inherits a default FRAMING option. Together with the
    # STRUCTURE selection, FRAMING determines inter alia:
    #   - above-grade floor assemblies
    #   - insulated roof assemblies
    #   - cantilevered balconies
    #   - interzone walls
    @@data[:structure]            = {}
    @@data[:structure][:steel   ] = {framing: :steel}
    @@data[:structure][:metal   ] = {framing: :metal}
    @@data[:structure][:concrete] = {framing: :steel}
    @@data[:structure][:cmu     ] = {framing: :cmu  }
    @@data[:structure][:wood    ] = {framing: :wood }
    @@data[:structure][:clt     ] = {framing: :wood }

    # An example. STRUCTURE == "wood" + default FRAMING == "wood", e.g. housing:
    #   - typical engineered wood joists + FINISH
    #   - similar engineered wood rafters + FINISH (if flat or cathedral roof)
    #   - anchored engineered wood joist balconies
    #   - standard 2"x4" wood-framed interzone walls
    #
    # FRAMING may also determine above-grade exterior wall composition (e.g.
    # wool-insulated wood-framed exterior walls, if FRAMING == "wood"). This
    # may instead be determined by CLADDING selection in several cases.
    #
    # Exterior CLADDING and interior FINISH options are both limited to 4
    # generic labels. Defaults for all STRUCTUREs are "light", for both CLADDING
    # (e.g. metal siding on vented hat-channels) and FINISH (e.g. painted
    # drywall). Brick veneer is an example of "medium" CLADDING, while a 4"
    # precast concrete panel is considered "heavy" CLADDING. A "medium" FINISH
    # is akin to a 4" precast panel concrete, while a "heavy" FINISH is a
    # heftier 8" of (poured) reinforced concrete. Option "none" for CLADDING is
    # rare, even in pre-code buildings. An example would be a load-bearing,
    # "cmu" wall with 2 coats of paint in a semi-heated industrial facility. The
    # "none" FINSIH option is slightly more common, e.g. exposed ceilings, bare
    # "clt" walls, and again bare "cmu" walls (or with 2 coats of paint).
    @@data[:cladding] = [:none, :light, :medium, :heavy]
    @@data[:finish  ] = [:none, :light, :medium, :heavy]

    # An above-grade building STRUCTURE would normally be auto-assigned based on
    # the prevalence of space type selections in the model (see activity.rb).
    # Note that all below-grade STRUCTUREs remain "concrete", e.g.:
    #   - basement slabs and slabs-on-grade
    #   - load-bearing basement walls
    #   - basement columns, shear walls, etc. (internal mass)
    #
    # Users can optionally assign STRUCTURE, FRAMING, CLADDING & FINISH options,
    # as per OpenStudio's building-to-space hierarchy, e.g.:
    #
    #   Example A: Composite STRUCTURE:
    #     - "concrete" post/beam STRUCTURE for first 4 building stories
    #     - "steel" post/frame STRUCTURE for building stories > 4
    #
    #   Example B: School gym:
    #     - "cmu" gymnasium walls in an otherwise "steel" post/frame school
    #
    # An invalid user-selected STRUCTURE is however caught/logged/corrected:
    #   - no other STRUCTURE above "steel", "metal", "cmu" or "wood" STRUCTUREs
    #   - a "wood" STRUCTURE may rest upon a "clt" STRUCTURE
    #   - any other STRUCTURE may rest upon a "concrete" STRUCTURE
    #
    # With the exception of "metal" buildings, users may optionally interchange
    # some paired STRUCTURE vs FRAMING options (among available :frames above).
    # Unusual in some cases, yet not completely unheard of.
    @@data[:structure][:steel   ][:frames] = [:wood        ]
    @@data[:structure][:metal   ][:frames] = [             ]
    @@data[:structure][:concrete][:frames] = [:wood, :cmu  ]
    @@data[:structure][:cmu     ][:frames] = [:wood, :steel]
    @@data[:structure][:wood    ][:frames] = [:steel       ]
    @@data[:structure][:clt     ][:frames] = [:clt, :steel ]

    # --- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- --- #
    # STRUCTURE options hold "co2" carbon intensities (in CO2-e kg/m2), which
    # are placeholders for now (to be replaced at some point by 3rd-party
    # estimates). They're meant to specifically track the carbon footprint of
    # the STRUCTURE (not the envelope, nor interior partitions, nor integrated
    # furniture). These estimates should include the embodied carbon of
    # above-grade, structural floors per se, in addition to the embodied carbon
    # of structural elements that can't (or are unlikely to) be represented in
    # an OpenStudio model, e.g.:
    #   - columns
    #   - bracing
    #   - stairwells and elevator shafts
    @@data[:structure][:steel   ][:co2] = 203
    @@data[:structure][:metal   ][:co2] = 202
    @@data[:structure][:concrete][:co2] = 205
    @@data[:structure][:cmu     ][:co2] = 204
    @@data[:structure][:wood    ][:co2] = 200
    @@data[:structure][:clt     ][:co2] = 201

    # Once refined, these CO2-e kg/m2 estimates are expected to differ
    # considerably between STRUCTURE options, possibly affected by regional
    # considerations (i.e. national vs local estimates), number of building
    # stories, structural requirements, etc. - to be set parametrically.

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # To simplify data management, building TYPES (e.g. those listed in Table
    # A-8.4.3.2.(2)-A of the NECB 2020) are proposed to fall into more general
    # building CATEGORIES (see activity.rb & NECB_building_types.csv):
    #
    #      CATEGORY   examples
    # _____________  __________________________________________________________
    #     "housing"  MURB, long-term stay, dormitory
    #     "lodging"  hotel, motel, highway lodging
    #      "public"  museum, hospital, school, theatre, terminal
    #    "commerce"  office, dining, retail, fitness, dealership, theatre
    #    "industry"  automotive, manufacturing, workshop, storage
    #  "recreation"  gymnastics, ice arena, indoor soccer/pool
    #      "robust"  penitentiary, parking garage (i.e. heavyduty, resistant)
    #
    # Each CATEGORY holds "small"-scale and "large"-scale STRUCTURE options by
    # defaults, depending on the characteristics of the building.
    @@data[:category]              = {}
    @@data[:category]["housing"   ] = {small: :wood    , large: :concrete}
    @@data[:category]["lodging"   ] = {small: :wood    , large: :concrete}
    @@data[:category]["robust"    ] = {small: :concrete, large: :concrete}
    @@data[:category]["public"    ] = {small: :steel   , large: :concrete}
    @@data[:category]["commerce"  ] = {small: :steel   , large: :steel}
    @@data[:category]["industry"  ] = {small: :cmu     , large: :metal}
    @@data[:category]["recreation"] = {small: :metal   , large: :steel}

    # What constitutes small- vs large-scale varies between CATEGORY, depending
    # either on the maximum number of stories, or the max floor-to-roof height
    # of the tallest first story space.
    @@data[:category]["housing"   ][:stories] =  4
    @@data[:category]["lodging"   ][:stories] =  2
    @@data[:category]["public"    ][:stories] =  2
    @@data[:category]["industry"  ][:height ] =  4
    @@data[:category]["recreation"][:height ] = 10

    # For instance, a multi-unit residential buildings (MURB) would have a
    # typical "wood" framed, load-bearing envelope/STRUCTURE up to (and
    # including) 4 stories above-grade. This default STRUCTURE assignment
    # switches to reinforced "concrete" post + flat slab beyond 5 stories.
    # Building CATEGORIES that hold neither :stories nor :height key:value pairs
    # simply retain the same STRUCTURE option by default, regardless of scale
    # (e.g. "robust", "commerce").
    #
    # Default STRUCTURE assignment per building CATEGORY does not preclude the
    # investigation of e.g. "clt" construction in MURBs, offices or sporting
    # facilities. It simply generates a reasonable reference set of structural/
    # framing options, applicable for large parts of the US and Canada. Users
    # have the option of overriding default assignments (@todo).

    ##
    # Returns BTAP Structure data.
    #
    # @return [Hash] BTAP Structure data
    def data
      @@data
    end

    def self.extended(base)
      base.send(:include, self)
    end
  end

  class BTAP::Structure
    extend StructureData

    # @return [String] building type CATEGORY (e.g. :institutional)
    attr_reader :category

    # @return [Symbol] building STRUCTURE selection (e.g. :steel)
    attr_reader :structure

    # @return [Float] calculated embodied carbon of STRUCTURE (CO2-e kg/m2)
    attr_reader :co2

    # @return [Hash] logged messages
    attr_reader :feedback


    ##
    # Initialize BTAP STRUCTURE parameters.
    #
    # @param model [OpenStudio::Model::Model] a model
    # @param cat [String] building category
    def initialize(model = nil, cat = "commerce")
      mth        = "BTAP::Structure::#{__callee__}"
      @feedback  = {logs: []}
      lgs        = @feedback[:logs]

      unless model.is_a?(OpenStudio::Model::Model)
        lgs << "Invalid or empty OpenStudio model (#{mth})"
        return
      end

      if cat.respond_to?(:to_s)
        cat = cat.to_s.downcase

        if cat.empty?
          lgs << "Empty building category (#{mth})"
          return
        else
          unless data[:category].keys.include?(cat)
            lgs << "Unknown building category: #{cat} (#{mth})"
            return
          end
        end
      else
        lgs << "Invalid building category: #{cat.class} (#{mth})"
        return
      end

      @category  = cat
      @structure = data[:category][cat][:small] # @todo, based on height vs stories
      @co2       = 0

      true
    end

    ##
    # Returns embodied carbon, strictly related to building STRUCTURE.
    #
    # @param model [OpenStudio::Model::Model] a model
    #
    # @return [Float] STRUCTURE related embodied carbon (CO2-e kg/m2)
    def tallyCO2(model)
      mth = "BTAP::Structure::#{__callee__}"
      cl  = OpenStudio::Model::Model
      lgs = @feedback[:logs]

      unless model.is_a?(cl)
        lgs << "Invalid OpenStudio model (#{mth})"
        return 0
      end

      # - tally above-grade vs below-grade floor areas
      # - apply associated CO2-e kg/m2
      # - return
      #   @todo
    end
  end

  # Temporary testing.
  # require "openstudio"
  # require_relative "activity"
  #
  # m = OpenStudio::Model::Model.new
  # a = BTAP::Activity.new(m)
  # s = BTAP::Structure.new(m, a.category)
  # puts "#{a.template} : #{a.activity} : #{a.category} : #{s.structure}"
end
