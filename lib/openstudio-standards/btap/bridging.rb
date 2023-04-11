# **************************************************************************** /
# *  Copyright (c) 2008-2023, Natural Resources Canada
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

require 'tbd'

module BTAP
  module BridgingData
    ##
    # BTAP module/class for Thermal Bridging & Derating (TBD) functionality
    # for linear thermal bridges, e.g. corners, balconies (rd2.github.io/tbd).
    #
    # @author: Denis Bourgeois

    # BTAP/TBD data extracted from the BTAP costing spreadsheet:
    #
    #   - range of clear-field Uo factors
    #   - range of PSI factors (i.e. MAJOR thermal bridging), e.g. corners
    #   - costing parameters
    #
    # NOTE: This module is be replaced with roo-based spreadsheet parsing,
    #       generating a BTAP costing JSON file. TO DO.
    #
    # Ref: EVOKE BTAP costing spreadsheet modifications (2022), synced with:
    #      - Building Envelope Thermal Bridging Guide (BETBG)
    #      - ASHRAE RP-1365, ISO-12011, etc.

    # BTAP costing data (both original BTAP constructions and EVOKE's
    # additions) hold sub-variants based on cladding/veneer, e.g.:
    #
    #   - "BTAP-ExteriorWall-WoodFramed-5" ... brick veneer
    #   - "BTAP-ExteriorWall-WoodFramed-1" ... wood siding
    #
    # Not all of these sub-variants are currently used within BTAP, e.g.
    # "BTAP-ExteriorWall-WoodFramed-1" is unused. BTAP/TBD data is limited
    # to the following wall constructions (paired LP & HP variants).
    #
    # ---- (Basic) Low Performance (LP) assemblies
    #
    #   ID    : (layers)
    #   -----   ------------------------------------------
    #   STEL1 : cladding | board   | wool | frame | gypsum
    #   WOOD5 : brick    | board   | wool | frame | gypsum
    #   MTAL1 : panel    | xps     | wool | frame | gypsum
    #   MASS2 : brick    | xps     |      | cmu   |
    #   MASS4 : precast  | xps     | wool | frame | gypsum
    #   MASS6 : brick    | xps     |      | cmu   |
    #
    # ---- High Performance (HP) variants
    #
    #   ID    : (layers)
    #   -----   ------------------------------------------
    #   STEL2 : cladding | board   | wool | frame | gypsum
    #   WOOD7 : brick    | mineral | wool | frame | gypsum
    #   MTALD : panel    | polyiso | foam | frame | gypsum
    #   MASSB : brick    | mineral | cmu  | foam  | gypsum
    #   MASS8 : precast  | xps     | wool | frame | gypsum
    #   MASSC : cladding | mineral | cmu  | foam  | gypsum
    #
    # Paired LPs vs HPs vall variants are critical for 'uprating' cases, e.g.
    # NECB2017. See below, and end of this document for additional NOTES.

    MASS2      = "BTAP-ExteriorWall-Mass-2"              # LP wall
    MASS2_BAD  = "BTAP-ExteriorWall-Mass-2 bad"          # LP "bad" PSI factors
    MASS2_GOOD = "BTAP-ExteriorWall-Mass-2 good"         # LP "good" PSI factors
    MASSB      = "BTAP-ExteriorWall-Mass-2b"             # HP, from @Uo < 0.183
    MASSB_BAD  = "BTAP-ExteriorWall-Mass-2b bad"         # HP "bad" PSI factors
    MASSB_GOOD = "BTAP-ExteriorWall-Mass-2b good"        # HP "good" PSI factors

    MASS4      = "BTAP-ExteriorWall-Mass-4"
    MASS4_BAD  = "BTAP-ExteriorWall-Mass-4 bad"
    MASS4_GOOD = "BTAP-ExteriorWall-Mass-4 good"
    MASS8      = "BTAP-ExteriorWall-Mass-8c"             # HP, from @Uo < 0.183
    MASS8_BAD  = "BTAP-ExteriorWall-Mass-8c bad"
    MASS8_GOOD = "BTAP-ExteriorWall-Mass-8c good"

    MASS6      = "BTAP-ExteriorWall-Mass-6"
    MASS6_BAD  = "BTAP-ExteriorWall-Mass-6 bad"
    MASS6_GOOD = "BTAP-ExteriorWall-Mass-6 good"
    MASSC      = "BTAP-ExteriorWall-Mass-10c"            # HP, from @Uo < 0.247
    MASSC_BAD  = "BTAP-ExteriorWall-Mass-10c bad"
    MASSC_GOOD = "BTAP-ExteriorWall-Mass-10c good"

    MTAL1      = "BTAP-ExteriorWall-Metal-1"
    MTAL1_BAD  = "BTAP-ExteriorWall-Metal-1 bad"
    MTAL1_GOOD = "BTAP-ExteriorWall-Metal-1 good"
    MTALD      = "BTAP-ExteriorWall-Metal-1d"            # HP, from @Uo < 0.183
    MTALD_BAD  = "BTAP-ExteriorWall-Metal-1d bad"
    MTALD_GOOD = "BTAP-ExteriorWall-Metal-1d good"

    WOOD5      = "BTAP-ExteriorWall-WoodFramed-5"
    WOOD5_BAD  = "BTAP-ExteriorWall-WoodFramed-5 bad"
    WOOD5_GOOD = "BTAP-ExteriorWall-WoodFramed-5 good"
    WOOD7      = "BTAP-ExteriorWall-WoodFramed-7"        # HP, from @Uo < 0.183
    WOOD7_BAD  = "BTAP-ExteriorWall-WoodFramed-7 bad"
    WOOD7_GOOD = "BTAP-ExteriorWall-WoodFramed-7 good"

    STEL1      = "BTAP-ExteriorWall-SteelFramed-1"
    STEL1_BAD  = "BTAP-ExteriorWall-SteelFramed-1 bad"
    STEL1_GOOD = "BTAP-ExteriorWall-SteelFramed-1 good"
    STEL2      = "BTAP-ExteriorWall-SteelFramed-2"        # HP from @Uo < 0.278
    STEL2_BAD  = "BTAP-ExteriorWall-SteelFramed-2 bad"
    STEL2_GOOD = "BTAP-ExteriorWall-SteelFramed-2 good"

    ROOFS      = "BTAP-ExteriorRoof-IEAD-4"
    FLOOR      = "BTAP-ExteriorFloor-SteelFramed-1"

    UMIN       = 0.010
    UMAX       = 5.678

    # There are 3 distinct BTAP "building_envelope" classes to enrich with
    # TBD functionality (whether BTAP users choose to activate TBD or not):
    #
    #   1. BTAPPRE1980
    #      - superclass for BTAP1980TO2010
    #   2. NECB2011
    #      - superclass for NECB2015
    #      - superclass for NECB2017 (inherits from NECB2015)
    #      - superclass for ECMS
    #   3. NECB2020
    #
    # In all 3 classes, a BTAP/TBD option switch allows BTAP users to activate
    # or deactivate TBD functionality :
    #   - "none" : TBD is deactivated, i.e. no up/de-rating
    #   - "bad" or "good": (BTAP-costed) PSI factor sets, i.e. derating only
    #   - "uprate": iteratively determine initial Uo ... prior to derating
    #
    # For vintages < NECB2017, the default BTAP policy is to switch off TBD,
    # i.e. 'none' (see the NOTE on this topic at the end of this document). To
    # instead assess prescriptive Ut compliance for vintages NECB2017 and
    # NECB2020, the BTAP/TBD must be set to "uprate" so it can iteratively reset
    # combined Uo & PSI factors towards finding the least expensive, yet
    # compliant combination. Why? Improved Uo construction variants are
    # necessarily required, given:
    #
    #   Ut = Uo + ( ∑psi  L )/A + ( ∑khi  n )/A   (ref: rd2.github.io/tbd)
    #
    # If one ignores linear ("( ∑psi  L )/A") and point ("( ∑khi  n )/A")
    # conductances, Ut simply equates to Uo. Yet for ANY added linear or
    # point conductance, Uo factors must necessarily be lower than required
    # NECB2017 or NECB2020 Ut factors. EVOKE's 2022 contribution extends
    # initial (pre-2022) BTAP wall construction variants, offering much
    # lower Uo factors (in some cases slightly below 0.1 W/m2.K or ~R70).
    # These BTAP upgrades provide more options for attaining required Ut
    # factors. For some variants, this simply implies a thicker insulation
    # layer. For others, it involves more radical construction changes, such
    # as switching over to the latest commercially-available HP
    # thermally-broken cladding clips. While some solutions are simple
    # (free) detailing changes, most improvements increase construction
    # costs. Despite adding new HP constructions, it is unlikely that TBD
    # will find NECB2017 or NECB2020 compliant combinations (prescriptive
    # path) for EVERY OpenStudio model. Read here as to "why?":
    #
    #   github.com/rd2/tbd/blob/f34ec6a017fcc0f6022f2a46e056b46b9d036b3b/
    #   spec/tbd_tests_spec.rb#L9219
    #
    # For these reasons, BTAP's use of TBD rests on an ITERATIVE uprating
    # solution for e.g. NECB2017 and NECB2020:
    #
    #   1. TBD attempts to achieve NECB-required area-weighted Ut factors
    #      for above-grade walls (then for roofs and exposed floors),
    #      starting with the least expensive combination:
    #        - highest admissible Uo factors for the climate zone
    #        - "bad" (LP) thermal bridging details
    #
    #   2. If, for a given OpenStudio model, required area-weighted Ut
    #      factors cannot be achieved, TBD then switches over to "good"
    #      (HP) thermal bridging detailing for that same construction, and
    #      repeats the exercise.
    #
    #   3. A subsequent failed attempt triggers a switch over to EVOKE's
    #      HP (improved Uo) assemblies. For instance:
    #        - "BTAP-ExteriorWall-WoodFramed-5" ... switches over to:
    #        - "BTAP-ExteriorWall-WoodFramed-7b"
    #
    #      ... switching over to another construction this way also means
    #      reverting back to "bad" (LP) thermal bridging PSI factors.
    #
    #   4. A final switch to "good" (HP) details is available (last resort).
    #
    # If none of the available combinations are sufficient:
    #   - TBD red-flags a failed attempt at NECB2017 or NECB2020 compliance
    #   - TBD keeps iteration #4 Uo + PSI combo, then derates
    #   - BTAP runs the simulation (giving some performance gap indication)

    # Hash of admissible Uo factors. If initial BTAP constructions fail to
    # comply when uprating, jump to subsequent high-performance variant,
    # e.g. "STEL1" switches to "STEL2". In most cases, the solution
    # prioritizes basic solutions (less $), only opting for HP variants as a
    # last recourse. There are 3x exceptions:
    #
    #   - Steel-framed construction: the selected HP variant has metal
    #     cladding. The only LP steel-framed BTAP option is wood-clad -
    #     something of an anomaly in commercial construction. By making the
    #     switch earlier to metal cladding, everywhere in Canada except
    #     (milder) SW BC and SW NS, it is hoped that a more consistent,
    #     apples-to-apples comparison is ensured.
    #
    #   - CMU-construction with lightweight cladding: The HP variant 10c
    #     (CMU, gypsum-finished, metal-clad) doesn't have any obvious LP
    #     construction counterpart. The proposed solution is to rely on
    #     Mass-6 constructions (literal copies of Mass-2 constructions,
    #     which are unfinished and brick-clad), as a starting point for
    #     milder climate zones only, and switch as early as possible to
    #     10c constructions.
    #
    #   - ROOF and (exposed) FLOOR surfaces refer to a single LP/HP selection
    #     respectively. This is expected to change in the future ...

    # Preset BTAP/TBD wall construction parameters.
    #   :sptypes   : BTAP/TBD Hash of linked NECB SpaceTypes (symbols)
    #   :uos       : BTAP/TBD Hash of associated of Uo sub-variants
    #   :lp or :hp : low- or high-performance attribute
    @@data = {}

    @@data[MASS2] = { sptypes: {}, uos: {}, lp: true }
    @@data[MASSB] = { sptypes: {}, uos: {}, hp: true }
    @@data[MASS4] = { sptypes: {}, uos: {}, lp: true }
    @@data[MASS8] = { sptypes: {}, uos: {}, hp: true }
    @@data[MASS6] = { sptypes: {}, uos: {}, lp: true }
    @@data[MASSC] = { sptypes: {}, uos: {}, hp: true }
    @@data[MTAL1] = { sptypes: {}, uos: {}, lp: true }
    @@data[MTALD] = { sptypes: {}, uos: {}, hp: true }
    @@data[WOOD5] = { sptypes: {}, uos: {}, lp: true }
    @@data[WOOD7] = { sptypes: {}, uos: {}, hp: true }
    @@data[STEL1] = { sptypes: {}, uos: {}, lp: true }
    @@data[STEL2] = { sptypes: {}, uos: {}, hp: true }
    @@data[FLOOR] = { sptypes: {}, uos: {}           }
    @@data[ROOFS] = { sptypes: {}, uos: {}           }

    # A construction sub-variant is identified strictly by its Uo factor:
    #
    #   e.g. :314 describes a Uo factor of 0.314 W/m2.K
    #
    # Listed items for each sub-variant are layer identifiers (for BTAP
    # costing only). For the moment, they are listed integers (but should
    # be expanded (e.g. as Hash keys) to hold additional costing metadata,
    # e.g. $/m2). This should be (soon) removed from BTAP/TBD data.
    #
    # NOTE: Missing gypsum finish for WOOD7 Uo 0.130?

    @@data[MASS2][:uos]["314"] = [ 24, 25, 26, 27, 28,134, 20, 21,139,141   ]
    @@data[MASS2][:uos]["278"] = [ 24, 25, 26, 27, 28, 42, 20, 21,139,141   ]
    @@data[MASS2][:uos]["247"] = [ 24, 25, 26, 27, 28, 58, 20, 21,139,141   ]
    @@data[MASS2][:uos]["210"] = [ 24, 25, 26, 27, 28, 55, 20, 21,139,141   ]
    @@data[MASS2][:uos]["183"] = [ 24, 25, 26, 27, 28, 68, 20, 21,139,141   ]
    @@data[MASSB][:uos]["130"] = [  1, 11, 24,160,164,179,141               ]
    @@data[MASSB][:uos]["100"] = [  1, 11, 24,160,165,179,141               ]

    @@data[MASS4][:uos]["314"] = [  1, 11, 43,  6, 92, 41                   ]
    @@data[MASS4][:uos]["278"] = [  1, 11, 69,  6, 41,150                   ]
    @@data[MASS4][:uos]["247"] = [  1, 11, 43,  6, 58, 41                   ]
    @@data[MASS4][:uos]["210"] = [  1, 11, 43,  6,134, 41                   ]
    @@data[MASS4][:uos]["183"] = [  1, 11, 49, 80, 41                       ]
    @@data[MASS8][:uos]["130"] = [  1, 11,168,195                           ]
    @@data[MASS8][:uos]["100"] = [  1, 11,168,195                           ]

    @@data[MASS6][:uos]["314"] = [ 24, 25, 26, 27, 28,134, 20, 21,139,141                    ]
    @@data[MASS6][:uos]["278"] = [ 24, 25, 26, 27, 28, 42, 20, 21,139,141                    ]
    @@data[MASS6][:uos]["247"] = [ 24, 25, 26, 27, 28, 58, 20, 21,139,141                    ]
    @@data[MASSC][:uos]["210"] = [  1, 11,160, 24, 25, 26, 27, 28,172,181,162,196,180,141    ]
    @@data[MASSC][:uos]["183"] = [  1, 11,160, 24, 25, 26, 27, 28,172,182,163,196,180,141    ]
    @@data[MASSC][:uos]["130"] = [  1, 11,160, 24, 25, 26, 27, 28,172,185,165,196,180,141    ]
    @@data[MASSC][:uos]["100"] = [  1, 11,160, 24, 25, 26, 27, 28,172,186,163,165,196,180,141]
    @@data[MASSC][:uos]["080"] = [  1, 11,160, 24, 25, 26, 27, 28,172,188,165,165,196,180,141]

    @@data[MTAL1][:uos]["314"] = [  1, 11, 43,  6, 56,150, 48                ]
    @@data[MTAL1][:uos]["278"] = [  1, 11, 43,  6, 48, 55                    ]
    @@data[MTAL1][:uos]["247"] = [  1, 11, 43, 56,  6, 48, 59                ]
    @@data[MTAL1][:uos]["210"] = [  1, 11, 43, 63,  6, 48, 59                ]
    @@data[MTAL1][:uos]["183"] = [  1, 11, 43, 58,  6, 48, 59                ]
    @@data[MTALD][:uos]["130"] = [ 11,160,204,203,205,204,174,173,180,  1    ]
    @@data[MTALD][:uos]["100"] = [ 11,160,204,203,205,204,174,174,180,  1    ]

    @@data[WOOD5][:uos]["314"] = [138,  3, 43,  5,  6,153, 20, 21,139,141,  1]
    @@data[WOOD5][:uos]["278"] = [138,  3, 53, 56,  5,  6, 20, 21,139,141,  1]
    @@data[WOOD5][:uos]["247"] = [138,  3,  4,  5, 56,  6, 20, 21,139,141,  1]
    @@data[WOOD5][:uos]["210"] = [138,  3, 53,  5, 56,  6, 20, 21,139,141,  1]
    @@data[WOOD5][:uos]["183"] = [138,  3, 53,  5, 67,  6, 20, 21,139,141,  1]
    @@data[WOOD7][:uos]["130"] = [138,160, 56,163,197, 20, 21,139,141,  1    ] # < added '1' for gypsum finish

    @@data[STEL1][:uos]["314"] = [ 11,  3, 43,153,  6,  7,141,  9, 10,  1        ]
    @@data[STEL1][:uos]["278"] = [ 11,  3, 53,  5, 56,  6,  7,141,  9, 10,  1    ]
    @@data[STEL2][:uos]["247"] = [ 11,  3, 53,  5, 63,  6,  7,141,  9, 10,  1    ]
    @@data[STEL2][:uos]["210"] = [ 11,  3, 53,  5, 67,  6,  7,141,  9, 10,  1    ]
    @@data[STEL2][:uos]["183"] = [ 11,  3, 53,  5, 56, 67,  6,  7,141,  9, 10,  1]
    @@data[STEL2][:uos]["130"] = [ 11,  3, 43,171,172,164,163,186,196,180,141,  1]
    @@data[STEL2][:uos]["100"] = [ 11,  3, 43,171,172,165,163,187,197,180,141,  1]
    @@data[STEL2][:uos]["080"] = [ 11,  3, 43,171,172,165,165,188,197,180,141,  1]

    @@data[FLOOR][:uos]["227"] = [117,145,118,  3, 99,  6,119    ]
    @@data[FLOOR][:uos]["183"] = [117,145,118,  3, 99, 56,  6,119]
    @@data[FLOOR][:uos]["162"] = [117,145,118,  3, 99, 67,  6,119]
    @@data[FLOOR][:uos]["142"] = [117,145,118,  3, 68, 56,  6,119]
    @@data[FLOOR][:uos]["116"] = [117,145,118,  3,157,  6,157,  6]
    @@data[FLOOR][:uos]["101"] = [117,145,118,  3,157,158,  6,119]

    @@data[ROOFS][:uos]["227"] = [ 94, 97, 71, 92, 93]
    @@data[ROOFS][:uos]["193"] = [ 94, 97, 80, 80, 93]
    @@data[ROOFS][:uos]["183"] = [ 94, 97,134,134, 93]
    @@data[ROOFS][:uos]["162"] = [ 94, 97,102,153, 93]
    @@data[ROOFS][:uos]["156"] = [ 94, 97,134, 91, 93]
    @@data[ROOFS][:uos]["142"] = [ 94, 97,106, 93    ]
    @@data[ROOFS][:uos]["138"] = [ 94, 97,106, 93    ] # same as :142 ?
    @@data[ROOFS][:uos]["121"] = [ 94, 97,106,150, 93]
    @@data[ROOFS][:uos]["100"] = [ 94, 97,106,106, 93]

    # In BTAP costing, each NECB building/space type is linked to a default
    # construction set, which holds one of the preceding wall options. This
    # linkage is now extended to OpenStudio models (not just costing),
    # given the construction-specific nature of MAJOR thermal bridging.
    #
    # Each of these wall options holds NECB building (or space) type keywords
    # (see below). The default (fall back) keyword is :office. String pattern
    # recognition, e.g.:
    #
    #   :gym from "Gymnasium/Fitness centre exercise area"
    #
    # ... is implemented elsewhere in the BTAP/TBD class. The default BTAP
    # wall construction for :office (fall back) is STEL1. Subsequent PSI
    # factor selection is based strictly on selected wall construction, e.g.
    # regardless of selected roof, fenestration. The linkage remains valid
    # for both building and space types (regardless of NECB vintage).
    #
    # The implementation is likely to be revised in the future, yet would
    # remain conceptually similar.

    # "BTAP-ExteriorWall-Mass-2" & "BTAP-ExteriorWall-Mass-2b"
    @@data[MASS2][:sptypes][:exercise       ] = {}
    @@data[MASS2][:sptypes][:firestation    ] = {}
    @@data[MASS2][:sptypes][:gym            ] = {}
    @@data[MASSB][:sptypes][:exercise       ] = {}
    @@data[MASSB][:sptypes][:firestation    ] = {}
    @@data[MASSB][:sptypes][:gym            ] = {}

    # "BTAP-ExteriorWall-Mass-4" & "BTAP-ExteriorWall-Mass-8c"
    @@data[MASS4][:sptypes][:courthouse     ] = {}
    @@data[MASS4][:sptypes][:museum         ] = {}
    @@data[MASS4][:sptypes][:parking        ] = {}
    @@data[MASS4][:sptypes][:post           ] = {}
    @@data[MASS4][:sptypes][:transportation ] = {}
    @@data[MASS8][:sptypes][:courthouse     ] = {}
    @@data[MASS8][:sptypes][:museum         ] = {}
    @@data[MASS8][:sptypes][:parking        ] = {}
    @@data[MASS8][:sptypes][:post           ] = {}
    @@data[MASS8][:sptypes][:transportation ] = {}

    # "BTAP-ExteriorWall-Mass-6" & "BTAP-ExteriorWall-Mass-10c"
    @@data[MASS6][:sptypes][:automotive     ] = {}
    @@data[MASS6][:sptypes][:penitentiary   ] = {}
    @@data[MASS6][:sptypes][:arena          ] = {}
    @@data[MASS6][:sptypes][:warehouse      ] = {}
    @@data[MASS6][:sptypes][:storage        ] = {}
    @@data[MASSC][:sptypes][:automotive     ] = {}
    @@data[MASSC][:sptypes][:penitentiary   ] = {}
    @@data[MASSC][:sptypes][:arena          ] = {}
    @@data[MASSC][:sptypes][:warehouse      ] = {}
    @@data[MASSC][:sptypes][:storage        ] = {}

    # "BTAP-ExteriorWall-Metal-1" & "BTAP-ExteriorWall-Metal-1d"
    @@data[MTAL1][:sptypes][:mfg            ] = {}
    @@data[MTAL1][:sptypes][:workshop       ] = {}
    @@data[MTALD][:sptypes][:mfg            ] = {}
    @@data[MTALD][:sptypes][:workshop       ] = {}

    # "BTAP-ExteriorWall-WoodFramed-5" & "BTAP-ExteriorWall-WoodFramed-7"
    @@data[WOOD5][:sptypes][:religious      ] = {}
    @@data[WOOD5][:sptypes][:dwelling       ] = {} # if < 5 stories
    @@data[WOOD5][:sptypes][:library        ] = {} # if < 3 stories
    @@data[WOOD5][:sptypes][:school         ] = {} # if < 3 stories
    @@data[WOOD7][:sptypes][:religious      ] = {}
    @@data[WOOD7][:sptypes][:dwelling       ] = {} # if < 5 stories
    @@data[WOOD7][:sptypes][:library        ] = {} # if < 3 stories
    @@data[WOOD7][:sptypes][:school         ] = {} # if < 3 stories

    # "BTAP-ExteriorWall-SteelFramed-1" & "BTAP-ExteriorWall-SteelFramed-2"
    @@data[STEL1][:sptypes][:dwelling5      ] = {} # if > 4 stories
    @@data[STEL1][:sptypes][:library3       ] = {} # if > 2 stories
    @@data[STEL1][:sptypes][:school3        ] = {} # if > 2 stories
    @@data[STEL1][:sptypes][:convention     ] = {}
    @@data[STEL1][:sptypes][:dining         ] = {}
    @@data[STEL1][:sptypes][:health         ] = {}
    @@data[STEL1][:sptypes][:hospital       ] = {}
    @@data[STEL1][:sptypes][:motion         ] = {}
    @@data[STEL1][:sptypes][:performance    ] = {}
    @@data[STEL1][:sptypes][:police         ] = {}
    @@data[STEL1][:sptypes][:retail         ] = {}
    @@data[STEL1][:sptypes][:town           ] = {}
    @@data[STEL1][:sptypes][:office         ] = {}
    @@data[STEL2][:sptypes][:dwelling5      ] = {} # if > 4 stories
    @@data[STEL2][:sptypes][:library3       ] = {} # if > 2 stories
    @@data[STEL2][:sptypes][:school3        ] = {} # if > 2 stories
    @@data[STEL2][:sptypes][:convention     ] = {}
    @@data[STEL2][:sptypes][:dining         ] = {}
    @@data[STEL2][:sptypes][:health         ] = {}
    @@data[STEL2][:sptypes][:hospital       ] = {}
    @@data[STEL2][:sptypes][:motion         ] = {}
    @@data[STEL2][:sptypes][:performance    ] = {}
    @@data[STEL2][:sptypes][:police         ] = {}
    @@data[STEL2][:sptypes][:retail         ] = {}
    @@data[STEL2][:sptypes][:town           ] = {}
    @@data[STEL2][:sptypes][:office         ] = {}

    # Initialize PSI factor qualities per wall construction.
    @@data.values.each do |construction|
      construction[:bad ] = {}
      construction[:good] = {}
    end

    # Thermal bridge types :balcony, :party and :joint are NOT expected to
    # be processed within BTAP. They are not costed out either. At some
    # point, it may become wise to do so (notably for cantilevered balconies
    # in MURBs). Default, generic BETBG PSI factors are nonetheless provided
    # here (just in case):
    #
    #   - for the "bad" BTAP cases, retained values are those of the
    #     generic "bad" BETBG set
    #   - while "good" BTAP values are those of the generic BETBG
    #     "efficient" set

    @@data[MASS2][ :bad][:rimjoist    ] = { psi: 0.470 }
    @@data[MASS2][ :bad][:parapet     ] = { psi: 0.500 }
    @@data[MASS2][ :bad][:head        ] = { psi: 0.350 }
    @@data[MASS2][ :bad][:jamb        ] = { psi: 0.350 }
    @@data[MASS2][ :bad][:sill        ] = { psi: 0.350 }
    @@data[MASS2][ :bad][:corner      ] = { psi: 0.150 }
    @@data[MASS2][ :bad][:balcony     ] = { psi: 1.000 }
    @@data[MASS2][ :bad][:party       ] = { psi: 0.850 }
    @@data[MASS2][ :bad][:grade       ] = { psi: 0.520 }
    @@data[MASS2][ :bad][:joint       ] = { psi: 0.300 }
    @@data[MASS2][ :bad][:transition  ] = { psi: 0.000 }

    @@data[MASS2][:good][:rimjoist    ] = { psi: 0.100 }
    @@data[MASS2][:good][:parapet     ] = { psi: 0.230 }
    @@data[MASS2][:good][:head        ] = { psi: 0.078 }
    @@data[MASS2][:good][:jamb        ] = { psi: 0.078 }
    @@data[MASS2][:good][:sill        ] = { psi: 0.078 }
    @@data[MASS2][:good][:corner      ] = { psi: 0.090 }
    @@data[MASS2][:good][:balcony     ] = { psi: 0.200 }
    @@data[MASS2][:good][:party       ] = { psi: 0.200 }
    @@data[MASS2][:good][:grade       ] = { psi: 0.090 }
    @@data[MASS2][:good][:joint       ] = { psi: 0.100 }
    @@data[MASS2][:good][:transition  ] = { psi: 0.000 }

    @@data[MASSB][ :bad][:rimjoist    ] = { psi: 0.470 }
    @@data[MASSB][ :bad][:parapet     ] = { psi: 0.500 }
    @@data[MASSB][ :bad][:head        ] = { psi: 0.350 }
    @@data[MASSB][ :bad][:jamb        ] = { psi: 0.350 }
    @@data[MASSB][ :bad][:sill        ] = { psi: 0.350 }
    @@data[MASSB][ :bad][:corner      ] = { psi: 0.150 }
    @@data[MASSB][ :bad][:balcony     ] = { psi: 1.000 }
    @@data[MASSB][ :bad][:party       ] = { psi: 0.850 }
    @@data[MASSB][ :bad][:grade       ] = { psi: 0.520 }
    @@data[MASSB][ :bad][:joint       ] = { psi: 0.300 }
    @@data[MASSB][ :bad][:transition  ] = { psi: 0.000 }

    @@data[MASSB][:good][:rimjoist    ] = { psi: 0.100 }
    @@data[MASSB][:good][:parapet     ] = { psi: 0.230 }
    @@data[MASSB][:good][:head        ] = { psi: 0.078 }
    @@data[MASSB][:good][:jamb        ] = { psi: 0.078 }
    @@data[MASSB][:good][:sill        ] = { psi: 0.078 }
    @@data[MASSB][:good][:corner      ] = { psi: 0.090 }
    @@data[MASSB][:good][:balcony     ] = { psi: 0.200 }
    @@data[MASSB][:good][:party       ] = { psi: 0.200 }
    @@data[MASSB][:good][:grade       ] = { psi: 0.090 }
    @@data[MASSB][:good][:joint       ] = { psi: 0.100 }
    @@data[MASSB][:good][:transition  ] = { psi: 0.000 }

    @@data[MASS4][ :bad][:rimjoist    ] = { psi: 0.200 }
    @@data[MASS4][ :bad][:parapet     ] = { psi: 0.650 }
    @@data[MASS4][ :bad][:head        ] = { psi: 0.078 }
    @@data[MASS4][ :bad][:jamb        ] = { psi: 0.078 }
    @@data[MASS4][ :bad][:sill        ] = { psi: 0.078 }
    @@data[MASS4][ :bad][:corner      ] = { psi: 0.370 }
    @@data[MASS4][ :bad][:balcony     ] = { psi: 1.000 }
    @@data[MASS4][ :bad][:party       ] = { psi: 0.850 }
    @@data[MASS4][ :bad][:grade       ] = { psi: 0.800 }
    @@data[MASS4][ :bad][:joint       ] = { psi: 0.300 }
    @@data[MASS4][ :bad][:transition  ] = { psi: 0.000 }

    @@data[MASS4][:good][:rimjoist    ] = { psi: 0.020 }
    @@data[MASS4][:good][:parapet     ] = { psi: 0.240 }
    @@data[MASS4][:good][:head        ] = { psi: 0.078 }
    @@data[MASS4][:good][:jamb        ] = { psi: 0.078 }
    @@data[MASS4][:good][:sill        ] = { psi: 0.078 }
    @@data[MASS4][:good][:corner      ] = { psi: 0.160 }
    @@data[MASS4][:good][:balcony     ] = { psi: 0.200 }
    @@data[MASS4][:good][:party       ] = { psi: 0.200 }
    @@data[MASS4][:good][:grade       ] = { psi: 0.320 }
    @@data[MASS4][:good][:joint       ] = { psi: 0.100 }
    @@data[MASS4][:good][:transition  ] = { psi: 0.000 }

    @@data[MASS8][ :bad][:rimjoist    ] = { psi: 0.200 }
    @@data[MASS8][ :bad][:parapet     ] = { psi: 0.650 }
    @@data[MASS8][ :bad][:head        ] = { psi: 0.078 }
    @@data[MASS8][ :bad][:jamb        ] = { psi: 0.078 }
    @@data[MASS8][ :bad][:sill        ] = { psi: 0.078 }
    @@data[MASS8][ :bad][:corner      ] = { psi: 0.370 }
    @@data[MASS8][ :bad][:balcony     ] = { psi: 1.000 }
    @@data[MASS8][ :bad][:party       ] = { psi: 0.850 }
    @@data[MASS8][ :bad][:grade       ] = { psi: 0.800 }
    @@data[MASS8][ :bad][:joint       ] = { psi: 0.300 }
    @@data[MASS8][ :bad][:transition  ] = { psi: 0.000 }

    @@data[MASS8][:good][:rimjoist    ] = { psi: 0.020 }
    @@data[MASS8][:good][:parapet     ] = { psi: 0.240 }
    @@data[MASS8][:good][:head        ] = { psi: 0.078 }
    @@data[MASS8][:good][:jamb        ] = { psi: 0.078 }
    @@data[MASS8][:good][:sill        ] = { psi: 0.078 }
    @@data[MASS8][:good][:corner      ] = { psi: 0.160 }
    @@data[MASS8][:good][:balcony     ] = { psi: 0.200 }
    @@data[MASS8][:good][:party       ] = { psi: 0.200 }
    @@data[MASS8][:good][:grade       ] = { psi: 0.320 }
    @@data[MASS8][:good][:joint       ] = { psi: 0.100 }
    @@data[MASS8][:good][:transition  ] = { psi: 0.000 }

    @@data[MASS6][ :bad][:rimjoist    ] = { psi: 0.470 }
    @@data[MASS6][ :bad][:parapet     ] = { psi: 0.500 }
    @@data[MASS6][ :bad][:head        ] = { psi: 0.350 }
    @@data[MASS6][ :bad][:jamb        ] = { psi: 0.350 }
    @@data[MASS6][ :bad][:sill        ] = { psi: 0.350 }
    @@data[MASS6][ :bad][:corner      ] = { psi: 0.150 }
    @@data[MASS6][ :bad][:balcony     ] = { psi: 1.000 }
    @@data[MASS6][ :bad][:party       ] = { psi: 0.850 }
    @@data[MASS6][ :bad][:grade       ] = { psi: 0.520 }
    @@data[MASS6][ :bad][:joint       ] = { psi: 0.300 }
    @@data[MASS6][ :bad][:transition  ] = { psi: 0.000 }

    @@data[MASS6][:good][:rimjoist    ] = { psi: 0.100 }
    @@data[MASS6][:good][:parapet     ] = { psi: 0.230 }
    @@data[MASS6][:good][:head        ] = { psi: 0.078 }
    @@data[MASS6][:good][:jamb        ] = { psi: 0.078 }
    @@data[MASS6][:good][:sill        ] = { psi: 0.078 }
    @@data[MASS6][:good][:corner      ] = { psi: 0.090 }
    @@data[MASS6][:good][:balcony     ] = { psi: 0.200 }
    @@data[MASS6][:good][:party       ] = { psi: 0.200 }
    @@data[MASS6][:good][:grade       ] = { psi: 0.090 }
    @@data[MASS6][:good][:joint       ] = { psi: 0.100 }
    @@data[MASS6][:good][:transition  ] = { psi: 0.000 }

    @@data[MASSC][ :bad][:rimjoist    ] = { psi: 0.170 }
    @@data[MASSC][ :bad][:parapet     ] = { psi: 0.500 }
    @@data[MASSC][ :bad][:head        ] = { psi: 0.350 }
    @@data[MASSC][ :bad][:jamb        ] = { psi: 0.350 }
    @@data[MASSC][ :bad][:sill        ] = { psi: 0.350 }
    @@data[MASSC][ :bad][:corner      ] = { psi: 0.150 }
    @@data[MASSC][ :bad][:balcony     ] = { psi: 1.000 }
    @@data[MASSC][ :bad][:party       ] = { psi: 0.850 }
    @@data[MASSC][ :bad][:grade       ] = { psi: 0.720 }
    @@data[MASSC][ :bad][:joint       ] = { psi: 0.300 }
    @@data[MASSC][ :bad][:transition  ] = { psi: 0.000 }

    @@data[MASSC][:good][:rimjoist    ] = { psi: 0.017 }
    @@data[MASSC][:good][:parapet     ] = { psi: 0.230 }
    @@data[MASSC][:good][:head        ] = { psi: 0.078 }
    @@data[MASSC][:good][:jamb        ] = { psi: 0.078 }
    @@data[MASSC][:good][:sill        ] = { psi: 0.078 }
    @@data[MASSC][:good][:corner      ] = { psi: 0.090 }
    @@data[MASSC][:good][:balcony     ] = { psi: 0.200 }
    @@data[MASSC][:good][:party       ] = { psi: 0.200 }
    @@data[MASSC][:good][:grade       ] = { psi: 0.470 }
    @@data[MASSC][:good][:joint       ] = { psi: 0.100 }
    @@data[MASSC][:good][:transition  ] = { psi: 0.000 }

    @@data[MTAL1][ :bad][:rimjoist    ] = { psi: 0.320 }
    @@data[MTAL1][ :bad][:parapet     ] = { psi: 0.420 }
    @@data[MTAL1][ :bad][:head        ] = { psi: 0.520 }
    @@data[MTAL1][ :bad][:jamb        ] = { psi: 0.520 }
    @@data[MTAL1][ :bad][:sill        ] = { psi: 0.520 }
    @@data[MTAL1][ :bad][:corner      ] = { psi: 0.150 }
    @@data[MTAL1][ :bad][:balcony     ] = { psi: 1.000 }
    @@data[MTAL1][ :bad][:party       ] = { psi: 0.850 }
    @@data[MTAL1][ :bad][:grade       ] = { psi: 0.700 }
    @@data[MTAL1][ :bad][:joint       ] = { psi: 0.300 }
    @@data[MTAL1][ :bad][:transition  ] = { psi: 0.000 }

    @@data[MTAL1][:good][:rimjoist    ] = { psi: 0.030 }
    @@data[MTAL1][:good][:parapet     ] = { psi: 0.350 }
    @@data[MTAL1][:good][:head        ] = { psi: 0.078 }
    @@data[MTAL1][:good][:jamb        ] = { psi: 0.078 }
    @@data[MTAL1][:good][:sill        ] = { psi: 0.078 }
    @@data[MTAL1][:good][:corner      ] = { psi: 0.070 }
    @@data[MTAL1][:good][:balcony     ] = { psi: 0.200 }
    @@data[MTAL1][:good][:party       ] = { psi: 0.200 }
    @@data[MTAL1][:good][:grade       ] = { psi: 0.500 }
    @@data[MTAL1][:good][:joint       ] = { psi: 0.100 }
    @@data[MTAL1][:good][:transition  ] = { psi: 0.000 }

    @@data[MTALD][ :bad][:rimjoist    ] = { psi: 0.320 }
    @@data[MTALD][ :bad][:parapet     ] = { psi: 0.420 }
    @@data[MTALD][ :bad][:head        ] = { psi: 0.520 }
    @@data[MTALD][ :bad][:jamb        ] = { psi: 0.520 }
    @@data[MTALD][ :bad][:sill        ] = { psi: 0.520 }
    @@data[MTALD][ :bad][:corner      ] = { psi: 0.150 }
    @@data[MTALD][ :bad][:balcony     ] = { psi: 1.000 }
    @@data[MTALD][ :bad][:party       ] = { psi: 0.850 }
    @@data[MTALD][ :bad][:grade       ] = { psi: 0.700 }
    @@data[MTALD][ :bad][:joint       ] = { psi: 0.300 }
    @@data[MTALD][ :bad][:transition  ] = { psi: 0.000 }

    @@data[MTALD][:good][:rimjoist    ] = { psi: 0.030 }
    @@data[MTALD][:good][:parapet     ] = { psi: 0.350 }
    @@data[MTALD][:good][:head        ] = { psi: 0.078 }
    @@data[MTALD][:good][:jamb        ] = { psi: 0.078 }
    @@data[MTALD][:good][:sill        ] = { psi: 0.078 }
    @@data[MTALD][:good][:corner      ] = { psi: 0.070 }
    @@data[MTALD][:good][:balcony     ] = { psi: 0.200 }
    @@data[MTALD][:good][:party       ] = { psi: 0.200 }
    @@data[MTALD][:good][:grade       ] = { psi: 0.500 }
    @@data[MTALD][:good][:joint       ] = { psi: 0.100 }
    @@data[MTALD][:good][:transition  ] = { psi: 0.000 }

    @@data[WOOD5][ :bad][:rimjoist    ] = { psi: 0.050 }
    @@data[WOOD5][ :bad][:parapet     ] = { psi: 0.050 }
    @@data[WOOD5][ :bad][:head        ] = { psi: 0.270 }
    @@data[WOOD5][ :bad][:jamb        ] = { psi: 0.270 }
    @@data[WOOD5][ :bad][:sill        ] = { psi: 0.270 }
    @@data[WOOD5][ :bad][:corner      ] = { psi: 0.040 }
    @@data[WOOD5][ :bad][:balcony     ] = { psi: 1.000 }
    @@data[WOOD5][ :bad][:party       ] = { psi: 0.850 }
    @@data[WOOD5][ :bad][:grade       ] = { psi: 0.550 }
    @@data[WOOD5][ :bad][:joint       ] = { psi: 0.300 }
    @@data[WOOD5][ :bad][:transition  ] = { psi: 0.000 }

    @@data[WOOD5][:good][:rimjoist    ] = { psi: 0.030 }
    @@data[WOOD5][:good][:parapet     ] = { psi: 0.050 }
    @@data[WOOD5][:good][:head        ] = { psi: 0.078 }
    @@data[WOOD5][:good][:jamb        ] = { psi: 0.078 }
    @@data[WOOD5][:good][:sill        ] = { psi: 0.078 }
    @@data[WOOD5][:good][:corner      ] = { psi: 0.040 }
    @@data[WOOD5][:good][:balcony     ] = { psi: 0.200 }
    @@data[WOOD5][:good][:party       ] = { psi: 0.200 }
    @@data[WOOD5][:good][:grade       ] = { psi: 0.090 }
    @@data[WOOD5][:good][:joint       ] = { psi: 0.100 }
    @@data[WOOD5][:good][:transition  ] = { psi: 0.000 }

    @@data[WOOD7][ :bad][:rimjoist    ] = { psi: 0.050 }
    @@data[WOOD7][ :bad][:parapet     ] = { psi: 0.050 }
    @@data[WOOD7][ :bad][:head        ] = { psi: 0.270 }
    @@data[WOOD7][ :bad][:jamb        ] = { psi: 0.270 }
    @@data[WOOD7][ :bad][:sill        ] = { psi: 0.270 }
    @@data[WOOD7][ :bad][:corner      ] = { psi: 0.040 }
    @@data[WOOD7][ :bad][:balcony     ] = { psi: 1.000 }
    @@data[WOOD7][ :bad][:party       ] = { psi: 0.850 }
    @@data[WOOD7][ :bad][:grade       ] = { psi: 0.550 }
    @@data[WOOD7][ :bad][:joint       ] = { psi: 0.300 }
    @@data[WOOD7][ :bad][:transition  ] = { psi: 0.000 }

    @@data[WOOD7][:good][:rimjoist    ] = { psi: 0.030 }
    @@data[WOOD7][:good][:parapet     ] = { psi: 0.050 }
    @@data[WOOD7][:good][:head        ] = { psi: 0.078 }
    @@data[WOOD7][:good][:jamb        ] = { psi: 0.078 }
    @@data[WOOD7][:good][:sill        ] = { psi: 0.078 }
    @@data[WOOD7][:good][:corner      ] = { psi: 0.040 }
    @@data[WOOD7][:good][:balcony     ] = { psi: 0.200 }
    @@data[WOOD7][:good][:party       ] = { psi: 0.200 }
    @@data[WOOD7][:good][:grade       ] = { psi: 0.090 }
    @@data[WOOD7][:good][:joint       ] = { psi: 0.100 }
    @@data[WOOD7][:good][:transition  ] = { psi: 0.000 }

    @@data[STEL1][ :bad][:rimjoist    ] = { psi: 0.280 }
    @@data[STEL1][ :bad][:parapet     ] = { psi: 0.650 }
    @@data[STEL1][ :bad][:head        ] = { psi: 0.270 }
    @@data[STEL1][ :bad][:jamb        ] = { psi: 0.270 }
    @@data[STEL1][ :bad][:sill        ] = { psi: 0.270 }
    @@data[STEL1][ :bad][:corner      ] = { psi: 0.150 }
    @@data[STEL1][ :bad][:balcony     ] = { psi: 1.000 }
    @@data[STEL1][ :bad][:party       ] = { psi: 0.850 }
    @@data[STEL1][ :bad][:grade       ] = { psi: 0.720 }
    @@data[STEL1][ :bad][:joint       ] = { psi: 0.300 }
    @@data[STEL1][ :bad][:transition  ] = { psi: 0.000 }

    @@data[STEL1][:good][:rimjoist    ] = { psi: 0.090 }
    @@data[STEL1][:good][:parapet     ] = { psi: 0.350 }
    @@data[STEL1][:good][:head        ] = { psi: 0.078 }
    @@data[STEL1][:good][:jamb        ] = { psi: 0.078 }
    @@data[STEL1][:good][:sill        ] = { psi: 0.078 }
    @@data[STEL1][:good][:corner      ] = { psi: 0.090 }
    @@data[STEL1][:good][:balcony     ] = { psi: 0.200 }
    @@data[STEL1][:good][:party       ] = { psi: 0.200 }
    @@data[STEL1][:good][:grade       ] = { psi: 0.470 }
    @@data[STEL1][:good][:joint       ] = { psi: 0.100 }
    @@data[STEL1][:good][:transition  ] = { psi: 0.000 }

    @@data[STEL2][ :bad][:rimjoist    ] = { psi: 0.280 }
    @@data[STEL2][ :bad][:parapet     ] = { psi: 0.650 }
    @@data[STEL2][ :bad][:head        ] = { psi: 0.270 }
    @@data[STEL2][ :bad][:jamb        ] = { psi: 0.270 }
    @@data[STEL2][ :bad][:sill        ] = { psi: 0.270 }
    @@data[STEL2][ :bad][:corner      ] = { psi: 0.150 }
    @@data[STEL2][ :bad][:balcony     ] = { psi: 1.000 }
    @@data[STEL2][ :bad][:party       ] = { psi: 0.850 }
    @@data[STEL2][ :bad][:grade       ] = { psi: 0.720 }
    @@data[STEL2][ :bad][:joint       ] = { psi: 0.300 }
    @@data[STEL2][ :bad][:transition  ] = { psi: 0.000 }

    @@data[STEL2][:good][:rimjoist    ] = { psi: 0.090 }
    @@data[STEL2][:good][:parapet     ] = { psi: 0.100 }
    @@data[STEL2][:good][:head        ] = { psi: 0.078 }
    @@data[STEL2][:good][:jamb        ] = { psi: 0.078 }
    @@data[STEL2][:good][:sill        ] = { psi: 0.078 }
    @@data[STEL2][:good][:corner      ] = { psi: 0.090 }
    @@data[STEL2][:good][:balcony     ] = { psi: 0.200 }
    @@data[STEL2][:good][:party       ] = { psi: 0.200 }
    @@data[STEL2][:good][:grade       ] = { psi: 0.470 }
    @@data[STEL2][:good][:joint       ] = { psi: 0.100 }
    @@data[STEL2][:good][:transition  ] = { psi: 0.000 }

    # Extend for BTAP costing.
    @@data.values.each do |construction|
      construction[:good].values.each { |bridge| bridge[:mat] = {} }
      construction[ :bad].values.each { |bridge| bridge[:mat] = {} }
    end

    # BTAP costed "materials" (Hash keywords in double quotations) for MAJOR
    # thermal bridges. Corresponding Hash values are multipliers.
    #
    # NOTE: "0" as a NIL placeholder (no cost associated to thermal bridge).
    @@data[MASS2][ :bad][:id          ] = MASS2_BAD
    # @@data[MASS2][ :bad][:rimjoist    ][:mat][ "21"] =  1.000
    # @@data[MASS2][ :bad][:rimjoist    ][:mat]["172"] =  0.250
    # @@data[MASS2][ :bad][:parapet     ][:mat][  "0"] =  1.000
    # @@data[MASS2][ :bad][:head        ][:mat]["139"] =  0.750
    # @@data[MASS2][ :bad][:jamb        ][:mat]["139"] =  0.750
    # @@data[MASS2][ :bad][:sill        ][:mat]["139"] =  0.750
    # @@data[MASS2][ :bad][:corner      ][:mat][  "0"] =  1.000
    # @@data[MASS2][ :bad][:balcony     ][:mat][   ""] =  1.000
    # @@data[MASS2][ :bad][:party       ][:mat][   ""] =  1.000
    # @@data[MASS2][ :bad][:grade       ][:mat][ "21"] =  1.000
    # @@data[MASS2][ :bad][:grade       ][:mat]["139"] =  0.500
    # @@data[MASS2][ :bad][:joint       ][:mat][   ""] =  1.000
    # @@data[MASS2][ :bad][:transition  ][:mat][   ""] =  1.000

    @@data[MASS2][:good][:id          ] = MASS2_GOOD
    # @@data[MASS2][:good][:rimjoist    ][:mat]["189"] =  1.000
    # @@data[MASS2][:good][:rimjoist    ][:mat]["172"] =  0.500
    # @@data[MASS2][:good][:parapet     ][:mat][ "57"] =  3.300
    # @@data[MASS2][:good][:parapet     ][:mat]["139"] =  1.000
    # @@data[MASS2][:good][:head        ][:mat]["139"] =  0.500
    # @@data[MASS2][:good][:jamb        ][:mat]["139"] =  0.500
    # @@data[MASS2][:good][:sill        ][:mat]["139"] =  0.500
    # @@data[MASS2][:good][:corner      ][:mat][  "0"] =  1.000
    # @@data[MASS2][:good][:balcony     ][:mat][   ""] =  1.000
    # @@data[MASS2][:good][:party       ][:mat][   ""] =  1.000
    # @@data[MASS2][:good][:grade       ][:mat]["189"] =  1.000
    # @@data[MASS2][:good][:grade       ][:mat]["139"] =  0.500
    # @@data[MASS2][:good][:grade       ][:mat]["192"] =  0.500
    # @@data[MASS2][:good][:joint       ][:mat][   ""] =  1.000
    # @@data[MASS2][:good][:transition  ][:mat][   ""] =  1.000

    @@data[MASSB][ :bad][:id          ] = MASSB_BAD
    # @@data[MASSB][ :bad][:rimjoist    ][:mat][ "21"] =  1.000
    # @@data[MASSB][ :bad][:rimjoist    ][:mat]["172"] =  0.250
    # @@data[MASSB][ :bad][:parapet     ][:mat][  "0"] =  1.000
    # @@data[MASSB][ :bad][:head        ][:mat]["139"] =  0.750
    # @@data[MASSB][ :bad][:jamb        ][:mat]["139"] =  0.750
    # @@data[MASSB][ :bad][:sill        ][:mat]["139"] =  0.750
    # @@data[MASSB][ :bad][:corner      ][:mat][  "0"] =  1.000
    # @@data[MASSB][ :bad][:balcony     ][:mat][   ""] =  1.000
    # @@data[MASSB][ :bad][:party       ][:mat][   ""] =  1.000
    # @@data[MASSB][ :bad][:grade       ][:mat][ "21"] =  1.000
    # @@data[MASSB][ :bad][:grade       ][:mat]["139"] =  0.500
    # @@data[MASSB][ :bad][:joint       ][:mat][   ""] =  1.000
    # @@data[MASSB][ :bad][:transition  ][:mat][   ""] =  1.000

    @@data[MASSB][:good][:id          ] = MASSB_GOOD
    # @@data[MASSB][:good][:rimjoist    ][:mat]["189"] =  1.000
    # @@data[MASSB][:good][:rimjoist    ][:mat]["172"] =  0.500
    # @@data[MASSB][:good][:parapet     ][:mat][ "57"] =  3.300
    # @@data[MASSB][:good][:parapet     ][:mat]["139"] =  1.000
    # @@data[MASSB][:good][:head        ][:mat]["139"] =  0.500
    # @@data[MASSB][:good][:jamb        ][:mat]["139"] =  0.500
    # @@data[MASSB][:good][:sill        ][:mat]["139"] =  0.500
    # @@data[MASSB][:good][:corner      ][:mat][  "0"] =  1.000
    # @@data[MASSB][:good][:balcony     ][:mat][   ""] =  1.000
    # @@data[MASSB][:good][:party       ][:mat][   ""] =  1.000
    # @@data[MASSB][:good][:grade       ][:mat]["189"] =  1.000
    # @@data[MASSB][:good][:grade       ][:mat]["139"] =  0.500
    # @@data[MASSB][:good][:grade       ][:mat]["192"] =  0.500
    # @@data[MASSB][:good][:joint       ][:mat][   ""] =  1.000
    # @@data[MASSB][:good][:transition  ][:mat][   ""] =  1.000

    @@data[MASS4][ :bad][:id          ] = MASS4_BAD
    # @@data[MASS4][ :bad][:rimjoist    ][:mat][  "0"] =  1.000
    # @@data[MASS4][ :bad][:parapet     ][:mat][  "0"] =  1.000
    # @@data[MASS4][ :bad][:head        ][:mat]["139"] =  0.250
    # @@data[MASS4][ :bad][:jamb        ][:mat]["139"] =  0.250
    # @@data[MASS4][ :bad][:sill        ][:mat]["139"] =  0.250
    # @@data[MASS4][ :bad][:corner      ][:mat]["141"] =  1.000
    # @@data[MASS4][ :bad][:balcony     ][:mat][   ""] =  1.000
    # @@data[MASS4][ :bad][:party       ][:mat][   ""] =  1.000
    # @@data[MASS4][ :bad][:grade       ][:mat]["139"] =  0.500
    # @@data[MASS4][ :bad][:joint       ][:mat][   ""] =  1.000
    # @@data[MASS4][ :bad][:transition  ][:mat][   ""] =  1.000

    @@data[MASS4][:good][:id          ] = MASS4_GOOD
    # @@data[MASS4][:good][:rimjoist    ][:mat][  "0"] =  1.000
    # @@data[MASS4][:good][:parapet     ][:mat][ "57"] =  3.300
    # @@data[MASS4][:good][:parapet     ][:mat]["139"] =  1.000
    # @@data[MASS4][:good][:head        ][:mat]["139"] =  0.250
    # @@data[MASS4][:good][:head        ][:mat]["150"] =  0.083
    # @@data[MASS4][:good][:jamb        ][:mat]["139"] =  0.250
    # @@data[MASS4][:good][:jamb        ][:mat]["150"] =  0.083
    # @@data[MASS4][:good][:sill        ][:mat]["139"] =  0.250
    # @@data[MASS4][:good][:sill        ][:mat]["150"] =  0.083
    # @@data[MASS4][:good][:corner      ][:mat]["141"] =  1.250
    # @@data[MASS4][:good][:balcony     ][:mat][  "0"] =  1.000
    # @@data[MASS4][:good][:party       ][:mat][   ""] =  1.000
    # @@data[MASS4][:good][:grade       ][:mat]["192"] =  0.500
    # @@data[MASS4][:good][:grade       ][:mat]["139"] =  0.500
    # @@data[MASS4][:good][:joint       ][:mat][   ""] =  1.000
    # @@data[MASS4][:good][:transition  ][:mat][   ""] =  1.000

    @@data[MASS8][ :bad][:id          ] = MASS8_BAD
    # @@data[MASS8][ :bad][:rimjoist    ][:mat][  "0"] =  1.000
    # @@data[MASS8][ :bad][:parapet     ][:mat][  "0"] =  1.000
    # @@data[MASS8][ :bad][:head        ][:mat]["139"] =  0.250
    # @@data[MASS8][ :bad][:jamb        ][:mat]["139"] =  0.250
    # @@data[MASS8][ :bad][:sill        ][:mat]["139"] =  0.250
    # @@data[MASS8][ :bad][:corner      ][:mat]["141"] =  1.000
    # @@data[MASS8][ :bad][:balcony     ][:mat][   ""] =  1.000
    # @@data[MASS8][ :bad][:party       ][:mat][   ""] =  1.000
    # @@data[MASS8][ :bad][:grade       ][:mat]["139"] =  0.500
    # @@data[MASS8][ :bad][:joint       ][:mat][   ""] =  1.000
    # @@data[MASS8][ :bad][:transition  ][:mat][   ""] =  1.000

    @@data[MASS8][:good][:id          ] = MASS8_GOOD
    # @@data[MASS8][:good][:rimjoist    ][:mat][  "0"] =  1.000
    # @@data[MASS8][:good][:parapet     ][:mat][ "57"] =  3.300
    # @@data[MASS8][:good][:parapet     ][:mat]["139"] =  1.000
    # @@data[MASS8][:good][:head        ][:mat]["139"] =  0.250
    # @@data[MASS8][:good][:head        ][:mat]["150"] =  0.083
    # @@data[MASS8][:good][:jamb        ][:mat]["139"] =  0.250
    # @@data[MASS8][:good][:jamb        ][:mat]["150"] =  0.083
    # @@data[MASS8][:good][:sill        ][:mat]["139"] =  0.250
    # @@data[MASS8][:good][:sill        ][:mat]["150"] =  0.083
    # @@data[MASS8][:good][:corner      ][:mat]["141"] =  1.250
    # @@data[MASS8][:good][:balcony     ][:mat][  "0"] =  1.000
    # @@data[MASS8][:good][:party       ][:mat][   ""] =  1.000
    # @@data[MASS8][:good][:grade       ][:mat]["192"] =  0.500
    # @@data[MASS8][:good][:grade       ][:mat]["139"] =  0.500
    # @@data[MASS8][:good][:joint       ][:mat][   ""] =  1.000
    # @@data[MASS8][:good][:transition  ][:mat][   ""] =  1.000

    @@data[MASS6][ :bad][:id          ] = MASS6_BAD
    # @@data[MASS6][ :bad][:rimjoist    ][:mat][ "21"] =  1.000
    # @@data[MASS6][ :bad][:rimjoist    ][:mat]["172"] =  0.250
    # @@data[MASS6][ :bad][:parapet     ][:mat][  "0"] =  1.000
    # @@data[MASS6][ :bad][:head        ][:mat]["139"] =  0.750
    # @@data[MASS6][ :bad][:jamb        ][:mat]["139"] =  0.750
    # @@data[MASS6][ :bad][:sill        ][:mat]["139"] =  0.750
    # @@data[MASS6][ :bad][:corner      ][:mat][  "0"] =  1.000
    # @@data[MASS6][ :bad][:balcony     ][:mat][   ""] =  1.000
    # @@data[MASS6][ :bad][:party       ][:mat][   ""] =  1.000
    # @@data[MASS6][ :bad][:grade       ][:mat][ "21"] =  1.000
    # @@data[MASS6][ :bad][:grade       ][:mat]["139"] =  0.500
    # @@data[MASS6][ :bad][:joint       ][:mat][   ""] =  1.000
    # @@data[MASS6][ :bad][:transition  ][:mat][   ""] =  1.000

    @@data[MASS6][:good][:id          ] = MASS6_GOOD
    # @@data[MASS6][:good][:rimjoist    ][:mat]["189"] =  1.000
    # @@data[MASS6][:good][:rimjoist    ][:mat]["172"] =  0.500
    # @@data[MASS6][:good][:parapet     ][:mat][ "57"] =  3.300
    # @@data[MASS6][:good][:parapet     ][:mat]["139"] =  1.000
    # @@data[MASS6][:good][:head        ][:mat]["139"] =  0.500
    # @@data[MASS6][:good][:jamb        ][:mat]["139"] =  0.500
    # @@data[MASS6][:good][:sill        ][:mat]["139"] =  0.500
    # @@data[MASS6][:good][:corner      ][:mat][  "0"] =  1.000
    # @@data[MASS6][:good][:balcony     ][:mat][   ""] =  1.000
    # @@data[MASS6][:good][:party       ][:mat][   ""] =  1.000
    # @@data[MASS6][:good][:grade       ][:mat]["189"] =  1.000
    # @@data[MASS6][:good][:grade       ][:mat]["139"] =  0.500
    # @@data[MASS6][:good][:grade       ][:mat]["192"] =  0.500
    # @@data[MASS6][:good][:joint       ][:mat][   ""] =  1.000
    # @@data[MASS6][:good][:transition  ][:mat][   ""] =  1.000

    @@data[MASSC][ :bad][:id          ] = MASSC_BAD
    # @@data[MASSC][ :bad][:rimjoist    ][:mat]["139"] = 10.000
    # @@data[MASSC][ :bad][:parapet     ][:mat][  "0"] =  1.000
    # @@data[MASSC][ :bad][:head        ][:mat]["139"] =  0.750
    # @@data[MASSC][ :bad][:jamb        ][:mat]["139"] =  0.750
    # @@data[MASSC][ :bad][:sill        ][:mat]["139"] =  0.750
    # @@data[MASSC][ :bad][:corner      ][:mat][  "0"] =  1.000
    # @@data[MASSC][ :bad][:balcony     ][:mat][   ""] =  1.000
    # @@data[MASSC][ :bad][:party       ][:mat][   ""] =  1.000
    # @@data[MASSC][ :bad][:grade       ][:mat]["139"] =  0.000
    # @@data[MASSC][ :bad][:joint       ][:mat][   ""] =  1.000
    # @@data[MASSC][ :bad][:transition  ][:mat][   ""] =  1.000

    @@data[MASSC][:good][:id          ] = MASSC_GOOD
    # @@data[MASSC][:good][:rimjoist    ][:mat]["172"] =  0.500
    # @@data[MASSC][:good][:parapet     ][:mat][ "57"] =  3.300
    # @@data[MASSC][:good][:parapet     ][:mat]["139"] =  1.000
    # @@data[MASSC][:good][:head        ][:mat]["139"] =  0.500
    # @@data[MASSC][:good][:jamb        ][:mat]["139"] =  0.500
    # @@data[MASSC][:good][:sill        ][:mat]["139"] =  0.500
    # @@data[MASSC][:good][:corner      ][:mat][  "0"] =  1.000
    # @@data[MASSC][:good][:balcony     ][:mat][   ""] =  1.000
    # @@data[MASSC][:good][:party       ][:mat][   ""] =  1.000
    # @@data[MASSC][:good][:grade       ][:mat]["192"] =  1.000
    # @@data[MASSC][:good][:grade       ][:mat]["139"] =  1.000
    # @@data[MASSC][:good][:joint       ][:mat][   ""] =  1.000
    # @@data[MASSC][:good][:transition  ][:mat][   ""] =  1.000

    @@data[MTAL1][ :bad][:id          ] = MTAL1_BAD
    # @@data[MTAL1][ :bad][:rimjoist    ][:mat][  "0"] =  1.000
    # @@data[MTAL1][ :bad][:parapet     ][:mat][  "0"] =  1.000
    # @@data[MTAL1][ :bad][:head        ][:mat]["139"] =  1.000
    # @@data[MTAL1][ :bad][:jamb        ][:mat]["139"] =  1.000
    # @@data[MTAL1][ :bad][:sill        ][:mat]["139"] =  1.000
    # @@data[MTAL1][ :bad][:corner      ][:mat]["191"] =  1.000
    # @@data[MTAL1][ :bad][:balcony     ][:mat][   ""] =  1.000
    # @@data[MTAL1][ :bad][:party       ][:mat][   ""] =  1.000
    # @@data[MTAL1][ :bad][:grade       ][:mat]["139"] =  0.500
    # @@data[MTAL1][ :bad][:joint       ][:mat][   ""] =  1.000
    # @@data[MTAL1][ :bad][:transition  ][:mat][   ""] =  1.000

    @@data[MTAL1][:good][:id          ] = MTAL1_GOOD
    # @@data[MTAL1][:good][:rimjoist    ][:mat][  "0"] =  1.000
    # @@data[MTAL1][:good][:parapet     ][:mat][ "57"] =  3.300
    # @@data[MTAL1][:good][:parapet     ][:mat]["139"] =  1.000
    # @@data[MTAL1][:good][:head        ][:mat]["139"] =  0.500
    # @@data[MTAL1][:good][:jamb        ][:mat]["139"] =  0.500
    # @@data[MTAL1][:good][:sill        ][:mat]["139"] =  0.500
    # @@data[MTAL1][:good][:corner      ][:mat]["191"] =  1.000
    # @@data[MTAL1][:good][:balcony     ][:mat][   ""] =  1.000
    # @@data[MTAL1][:good][:party       ][:mat][   ""] =  1.000
    # @@data[MTAL1][:good][:grade       ][:mat]["192"] =  0.500
    # @@data[MTAL1][:good][:grade       ][:mat]["139"] =  0.500
    # @@data[MTAL1][:good][:joint       ][:mat][   ""] =  1.000
    # @@data[MTAL1][:good][:transition  ][:mat][   ""] =  1.000

    @@data[MTALD][ :bad][:id          ] = MTALD_BAD
    # @@data[MTALD][ :bad][:rimjoist    ][:mat][  "0"] =  1.000
    # @@data[MTALD][ :bad][:parapet     ][:mat][  "0"] =  1.000
    # @@data[MTALD][ :bad][:head        ][:mat]["139"] =  1.000
    # @@data[MTALD][ :bad][:jamb        ][:mat]["139"] =  1.000
    # @@data[MTALD][ :bad][:sill        ][:mat]["139"] =  1.000
    # @@data[MTALD][ :bad][:corner      ][:mat]["191"] =  1.000
    # @@data[MTALD][ :bad][:balcony     ][:mat][   ""] =  1.000
    # @@data[MTALD][ :bad][:party       ][:mat][   ""] =  1.000
    # @@data[MTALD][ :bad][:grade       ][:mat]["139"] =  0.500
    # @@data[MTALD][ :bad][:joint       ][:mat][   ""] =  1.000
    # @@data[MTALD][ :bad][:transition  ][:mat][   ""] =  1.000

    @@data[MTALD][:good][:id          ] = MTALD_GOOD
    # @@data[MTALD][:good][:rimjoist    ][:mat][  "0"] =  1.000
    # @@data[MTALD][:good][:parapet     ][:mat][ "57"] =  3.300
    # @@data[MTALD][:good][:parapet     ][:mat]["139"] =  1.000
    # @@data[MTALD][:good][:head        ][:mat]["139"] =  0.500
    # @@data[MTALD][:good][:jamb        ][:mat]["139"] =  0.500
    # @@data[MTALD][:good][:sill        ][:mat]["139"] =  0.500
    # @@data[MTALD][:good][:corner      ][:mat]["191"] =  1.000
    # @@data[MTALD][:good][:balcony     ][:mat][   ""] =  1.000
    # @@data[MTALD][:good][:party       ][:mat][   ""] =  1.000
    # @@data[MTALD][:good][:grade       ][:mat]["192"] =  0.500
    # @@data[MTALD][:good][:grade       ][:mat]["139"] =  0.500
    # @@data[MTALD][:good][:joint       ][:mat][   ""] =  1.000
    # @@data[MTALD][:good][:transition  ][:mat][   ""] =  1.000

    @@data[WOOD5][ :bad][:id          ] = WOOD5_BAD
    # @@data[WOOD5][ :bad][:rimjoist    ][:mat][ "21"] =  1.000
    # @@data[WOOD5][ :bad][:rimjoist    ][:mat]["172"] =  0.250
    # @@data[WOOD5][ :bad][:parapet     ][:mat][  "0"] =  1.000
    # @@data[WOOD5][ :bad][:head        ][:mat][  "0"] =  1.000
    # @@data[WOOD5][ :bad][:jamb        ][:mat][  "0"] =  1.000
    # @@data[WOOD5][ :bad][:sill        ][:mat][  "0"] =  1.000
    # @@data[WOOD5][ :bad][:corner      ][:mat][  "0"] =  1.000
    # @@data[WOOD5][ :bad][:balcony     ][:mat][   ""] =  1.000
    # @@data[WOOD5][ :bad][:party       ][:mat][   ""] =  1.000
    # @@data[WOOD5][ :bad][:grade       ][:mat][ "21"] =  1.000
    # @@data[WOOD5][ :bad][:grade       ][:mat]["139"] =  0.500
    # @@data[WOOD5][ :bad][:joint       ][:mat][   ""] =  1.000
    # @@data[WOOD5][ :bad][:transition  ][:mat][   ""] =  1.000

    @@data[WOOD5][:good][:id          ] = WOOD5_GOOD
    # @@data[WOOD5][:good][:rimjoist    ][:mat]["189"] =  1.000
    # @@data[WOOD5][:good][:rimjoist    ][:mat]["172"] =  0.500
    # @@data[WOOD5][:good][:parapet     ][:mat]["190"] =  0.500
    # @@data[WOOD5][:good][:head        ][:mat][  "0"] =  1.000
    # @@data[WOOD5][:good][:jamb        ][:mat][  "0"] =  1.000
    # @@data[WOOD5][:good][:sill        ][:mat][  "0"] =  1.000
    # @@data[WOOD5][:good][:corner      ][:mat][  "0"] =  1.000
    # @@data[WOOD5][:good][:balcony     ][:mat][   ""] =  1.000
    # @@data[WOOD5][:good][:party       ][:mat][   ""] =  1.000
    # @@data[WOOD5][:good][:grade       ][:mat]["189"] =  1.000
    # @@data[WOOD5][:good][:grade       ][:mat]["139"] =  0.500
    # @@data[WOOD5][:good][:grade       ][:mat]["192"] =  0.500
    # @@data[WOOD5][:good][:joint       ][:mat][   ""] =  1.000
    # @@data[WOOD5][:good][:transition  ][:mat][   ""] =  1.000

    @@data[WOOD7][ :bad][:id          ] = WOOD7_BAD
    # @@data[WOOD7][ :bad][:rimjoist    ][:mat][ "21"] =  1.000
    # @@data[WOOD7][ :bad][:rimjoist    ][:mat]["172"] =  0.250
    # @@data[WOOD7][ :bad][:parapet     ][:mat][  "0"] =  1.000
    # @@data[WOOD7][ :bad][:head        ][:mat][  "0"] =  1.000
    # @@data[WOOD7][ :bad][:jamb        ][:mat][  "0"] =  1.000
    # @@data[WOOD7][ :bad][:sill        ][:mat][  "0"] =  1.000
    # @@data[WOOD7][ :bad][:corner      ][:mat][  "0"] =  1.000
    # @@data[WOOD7][ :bad][:balcony     ][:mat][   ""] =  1.000
    # @@data[WOOD7][ :bad][:party       ][:mat][   ""] =  1.000
    # @@data[WOOD7][ :bad][:grade       ][:mat][ "21"] =  1.000
    # @@data[WOOD7][ :bad][:grade       ][:mat]["139"] =  0.500
    # @@data[WOOD7][ :bad][:joint       ][:mat][   ""] =  1.000
    # @@data[WOOD7][ :bad][:transition  ][:mat][   ""] =  1.000

    @@data[WOOD7][:good][:id          ] = WOOD7_GOOD
    # @@data[WOOD7][:good][:rimjoist    ][:mat]["189"] =  1.000
    # @@data[WOOD7][:good][:rimjoist    ][:mat]["172"] =  0.500
    # @@data[WOOD7][:good][:parapet     ][:mat]["190"] =  0.500
    # @@data[WOOD7][:good][:head        ][:mat][  "0"] =  1.000
    # @@data[WOOD7][:good][:jamb        ][:mat][  "0"] =  1.000
    # @@data[WOOD7][:good][:sill        ][:mat][  "0"] =  1.000
    # @@data[WOOD7][:good][:corner      ][:mat][  "0"] =  1.000
    # @@data[WOOD7][:good][:balcony     ][:mat][   ""] =  1.000
    # @@data[WOOD7][:good][:party       ][:mat][   ""] =  1.000
    # @@data[WOOD7][:good][:grade       ][:mat]["189"] =  1.000
    # @@data[WOOD7][:good][:grade       ][:mat]["139"] =  0.500
    # @@data[WOOD7][:good][:grade       ][:mat]["192"] =  0.500
    # @@data[WOOD7][:good][:joint       ][:mat][   ""] =  1.000
    # @@data[WOOD7][:good][:transition  ][:mat][   ""] =  1.000

    @@data[STEL1][ :bad][:id          ] = STEL1_BAD
    # @@data[STEL1][ :bad][:rimjoist    ][:mat]["139"] = 10.000
    # @@data[STEL1][ :bad][:parapet     ][:mat][  "0"] =  1.000
    # @@data[STEL1][ :bad][:head        ][:mat]["139"] =  0.750
    # @@data[STEL1][ :bad][:jamb        ][:mat]["139"] =  0.750
    # @@data[STEL1][ :bad][:sill        ][:mat]["139"] =  0.750
    # @@data[STEL1][ :bad][:corner      ][:mat][  "0"] =  1.000
    # @@data[STEL1][ :bad][:balcony     ][:mat][   ""] =  1.000
    # @@data[STEL1][ :bad][:party       ][:mat][   ""] =  1.000
    # @@data[STEL1][ :bad][:grade       ][:mat]["139"] =  1.000
    # @@data[STEL1][ :bad][:joint       ][:mat][   ""] =  1.000
    # @@data[STEL1][ :bad][:transition  ][:mat][   ""] =  1.000

    @@data[STEL1][:good][:id          ] = STEL1_GOOD
    # @@data[STEL1][:good][:rimjoist    ][:mat]["172"] =  0.500
    # @@data[STEL1][:good][:parapet     ][:mat][ "57"] =  3.300
    # @@data[STEL1][:good][:parapet     ][:mat]["139"] =  1.000
    # @@data[STEL1][:good][:head        ][:mat]["139"] =  0.500
    # @@data[STEL1][:good][:jamb        ][:mat]["139"] =  0.500
    # @@data[STEL1][:good][:sill        ][:mat]["139"] =  0.500
    # @@data[STEL1][:good][:corner      ][:mat][  "0"] =  1.000
    # @@data[STEL1][:good][:balcony     ][:mat][   ""] =  1.000
    # @@data[STEL1][:good][:party       ][:mat][   ""] =  1.000
    # @@data[STEL1][:good][:grade       ][:mat]["192"] =  1.000
    # @@data[STEL1][:good][:grade       ][:mat]["139"] =  1.000
    # @@data[STEL1][:good][:joint       ][:mat][   ""] =  1.000
    # @@data[STEL1][:good][:transition  ][:mat][   ""] =  1.000

    @@data[STEL2][ :bad][:id          ] = STEL2_BAD
    # @@data[STEL2][ :bad][:rimjoist    ][:mat]["139"] = 10.000
    # @@data[STEL2][ :bad][:parapet     ][:mat][  "0"] =  1.000
    # @@data[STEL2][ :bad][:head        ][:mat]["139"] =  0.750
    # @@data[STEL2][ :bad][:jamb        ][:mat]["139"] =  0.750
    # @@data[STEL2][ :bad][:sill        ][:mat]["139"] =  0.750
    # @@data[STEL2][ :bad][:corner      ][:mat][  "0"] =  1.000
    # @@data[STEL2][ :bad][:balcony     ][:mat][   ""] =  1.000
    # @@data[STEL2][ :bad][:party       ][:mat][   ""] =  1.000
    # @@data[STEL2][ :bad][:grade       ][:mat]["139"] =  1.000
    # @@data[STEL2][ :bad][:joint       ][:mat][   ""] =  1.000
    # @@data[STEL2][ :bad][:transition  ][:mat][   ""] =  1.000

    @@data[STEL2][:good][:id          ] = STEL2_GOOD
    # @@data[STEL2][:good][:rimjoist    ][:mat]["172"] =  0.500
    # @@data[STEL2][:good][:parapet     ][:mat]["206"] =  1.000
    # @@data[STEL2][:good][:head        ][:mat]["139"] =  0.500
    # @@data[STEL2][:good][:jamb        ][:mat]["139"] =  0.500
    # @@data[STEL2][:good][:sill        ][:mat]["139"] =  0.500
    # @@data[STEL2][:good][:corner      ][:mat][  "0"] =  1.000
    # @@data[STEL2][:good][:balcony     ][:mat][   ""] =  1.000
    # @@data[STEL2][:good][:party       ][:mat][   ""] =  1.000
    # @@data[STEL2][:good][:grade       ][:mat]["192"] =  1.000
    # @@data[STEL2][:good][:grade       ][:mat]["139"] =  1.000
    # @@data[STEL2][:good][:joint       ][:mat][   ""] =  1.000
    # @@data[STEL2][:good][:transition  ][:mat][   ""] =  1.000

    ##
    # Retrieve TBD building/space type keyword.
    #
    # @param spacetype [String] NECB (or other) building/space type
    # @param stories [Integer] number of building stories
    #
    # @return [Symbol] matching TBD keyword (:office if failure)
    def sptype(spacetype = "", stories = 999)
      tp  = spacetype.downcase
      typ = :office

      return typ unless stories.is_a?(Integer) && stories.between?(1,999)

      typ = :exercise       if tp.include?("exercise"     )
      typ = :firestation    if tp.include?("fire"         )
      typ = :gym            if tp.include?("gym"          )
      typ = :gym            if tp.include?("locker"       )
      typ = :courthouse     if tp.include?("courthouse"   )
      typ = :courtrhouse    if tp.include?("courtroom"    )
      typ = :museum         if tp.include?("museum"       )
      typ = :parking        if tp.include?("parking"      )
      typ = :post           if tp.include?("post"         )
      typ = :transportation if tp.include?("transp"       )
      typ = :transportation if tp.include?("maintenance"  )
      typ = :automotive     if tp.include?("automotive"   )
      typ = :penitentiary   if tp.include?("penitentiary" )
      typ = :penitentiary   if tp.include?("confinement"  )
      typ = :arena          if tp.include?("arena"        )
      typ = :warehouse      if tp.include?("warehouse"    )
      typ = :storage        if tp.include?("storage"      )
      typ = :mfg            if tp.include?("mfg"          )
      typ = :mfg            if tp.include?("manufacturing")
      typ = :mfg            if tp.include?("loading"      )
      typ = :workshop       if tp.include?("workshop"     )
      typ = :religious      if tp.include?("religious"    )
      typ = :dwelling5      if tp.include?("dorm"         )
      typ = :dwelling5      if tp.include?("otel"         )
      typ = :dwelling5      if tp.include?("residential"  )
      typ = :dwelling5      if tp.include?("long-term"    )
      typ = :dwelling5      if tp.include?("dwelling"     )
      typ = :dwelling5      if tp.include?("lodging"      )
      typ = :dwelling5      if tp.include?("RP-28"        )
      typ = :dwelling5      if tp.include?("guest"        )
      typ = :dwelling       if tp.include?("dorm"         ) && stories < 5
      typ = :dwelling       if tp.include?("otel"         ) && stories < 5
      typ = :dwelling       if tp.include?("residential"  ) && stories < 5
      typ = :dwelling       if tp.include?("long-term"    ) && stories < 5
      typ = :dwelling       if tp.include?("dwelling"     ) && stories < 5
      typ = :dwelling       if tp.include?("lodging"      ) && stories < 5
      typ = :dwelling       if tp.include?("RP-28"        ) && stories < 5
      typ = :dwelling       if tp.include?("guest"        ) && stories < 5
      typ = :library3       if tp.include?("library"      )
      typ = :library        if tp.include?("library"      ) && stories < 3
      typ = :school3        if tp.include?("school"       )
      typ = :school3        if tp.include?("classroom"    )
      typ = :school3        if tp.include?("lab"          )
      typ = :school3        if tp.include?("auditorium"   )
      typ = :school         if tp.include?("school"       ) && stories < 3
      typ = :school         if tp.include?("classroom"    ) && stories < 3
      typ = :school         if tp.include?("lab"          ) && stories < 3
      typ = :school         if tp.include?("auditorium"   ) && stories < 3
      typ = :convention     if tp.include?("convention"   )
      typ = :dining         if tp.include?("dining"       )
      typ = :dining         if tp.include?("food"         )
      typ = :health         if tp.include?("health"       )
      typ = :hospital       if tp.include?("hospital"     )
      typ = :hospital       if tp.include?("emergency"    )
      typ = :hospital       if tp.include?("laundry"      )
      typ = :hospital       if tp.include?("pharmacy"     )
      typ = :motion         if tp.include?("motion"       )
      typ = :performance    if tp.include?("perform"      )
      typ = :police         if tp.include?("police"       )
      typ = :retail         if tp.include?("retail"       )
      typ = :retail         if tp.include?("sales"        )
      typ = :town           if tp.include?("town"         )

      typ
    end

    ##
    # Retrieve building/space type-specific assembly/construction.
    #
    # @param spacetype [Symbol] BTAP/TBD spacetype
    # @param stype [Symbol] :walls, :floors or :roofs
    # @param performance [Symbol] :lp (low-) or :hp (high-performance)
    #
    # @return [String] corresponding BTAP construction (STEL2 if fail)
    def assembly(spacetype = :office, stype = :walls, performance = :hp)
      return FLOOR if stype == :floors
      return ROOFS if stype == :roofs

      @@data.each do |id, construction|
        next  unless construction.key?(performance)
        return id if construction[:sptypes].key?(spacetype)
      end

      STEL2
    end

    ##
    # Retrieve assembly-specific PSI factor set.
    #
    # @param assembly [String] BTAP/TBD wall construction
    # @param quality [Symbol] BTAP/TBD PSI quality (:bad or :good)
    #
    # @return [Hash] BTAP/TBD PSI factor set (defaults to STEL2, :good)
    def set(assembly = STEL2, quality = :good)
      psi = {}
      chx = @@data[STEL2][:good  ]
      chx = @@data[STEL2][quality]          if @@data[STEL2   ].key?(quality)

      if @@data.key?(assembly)
        chx = @@data[assembly][quality]     if @@data[assembly].key?(quality)
        chx = @@data[assembly][:good  ] unless @@data[assembly].key?(quality)
      end

      psi[:id        ] = chx[:id        ]
      psi[:rimjoist  ] = chx[:rimjoist  ][:psi]
      psi[:parapet   ] = chx[:parapet   ][:psi]
      psi[:head      ] = chx[:head      ][:psi]
      psi[:jamb      ] = chx[:jamb      ][:psi]
      psi[:sill      ] = chx[:sill      ][:psi]
      psi[:corner    ] = chx[:corner    ][:psi]
      psi[:balcony   ] = chx[:balcony   ][:psi]
      psi[:party     ] = chx[:party     ][:psi]
      psi[:grade     ] = chx[:grade     ][:psi]
      psi[:joint     ] = chx[:joint     ][:psi]
      psi[:transition] = chx[:transition][:psi]

      psi
    end

    ##
    # Return BTAP/TBD data.
    #
    # @return [Hash] preset BTAP/TBD data
    def data
      @@data
    end

    def self.extended(base)
      base.send(:include, self)
    end
  end

  class BTAP::Bridging
    extend BridgingData

    TOL  = TBD::TOL
    TOL2 = TBD::TOL2
    DBG  = TBD::DBG
    INF  = TBD::INF
    WRN  = TBD::WRN
    ERR  = TBD::ERR
    FTL  = TBD::FTL

    # @return [Hash] BTAP/TBD Hash, specific to an OpenStudio model
    attr_reader :model

    # @return [Hash] logged messages TBD reports back to BTAP
    attr_reader :feedback

    # @return [Hash] TBD tallies e.g. total lengths of linear thermal bridges
    attr_reader :tally

    ##
    # Initialize OpenStudio model-specific BTAP/TBD data - uprates/derates.
    #
    # @param model [OpenStudio::Model::Model] a model
    # @param argh [Hash] BTAP/TBD argument hash
    def initialize(model = nil, argh = {})
      @model    = {}
      @tally    = {}
      @feedback = { logs: [] }
      lgs       = @feedback[:logs]

      # BTAP generates free-floating, unoccupied spaces (e.g. attics) as
      # 'indirectly conditioned', rather than 'unconditioned' (e.g. vented
      # attics). For instance, all outdoor-facing sloped roof surfaces of an
      # attic in BTAP are insulated, while attic floors remain uninsulated. BTAP
      # adds to the thermal zone of each unoccupied space a thermostat without
      # referecing heating and/or cooling setpoint schedule objects. These
      # conditions do not meet TBD's internal 'plenum' logic/check (which is
      # based on OpenStudio-Standards), and so TBD ends up tagging such spaces
      # as unconditioned. Consequently, TBD attempts to up/de-rate attic floors
      # - not sloped roof surfaces. The original BTAP solution will undoubtedly
      # need revision. In the meantime, and in an effort to harmonize TBD with
      # BTAP's current approach, an OpenStudio model may be temporarily
      # modified prior to TBD processes, ensuring that each attic space is
      # temporarily mistaken as a conditioned plenum. The return variable of the
      # following method is a Hash holding temporarily-modified spaces,
      # i.e. buffer zones.
      buffers = self.alter_buffers(model)

      # Populate BTAP/TBD inputs with BTAP & OpenStudio model parameters,
      # which returns 'true' if successful. Check @feedback logs if failure to
      # populate (e.g. invalid argument hash, invalid OpenStudio model).
      return unless self.populate(model, argh)

      # Initialize loop counters, controls and flags.
      initial = true
      comply  = false
      redflag = false
      perform = :lp    # Low-performance wall constructions
      quality = :bad   # default PSI factors - BTAP users can reset to :good
      quality = :good if argh.key?(:quality) && argh[:quality] == :good
      combo   = "#{perform.to_s}_#{quality.to_s}".to_sym # e.g. :lp_bad
      args    = {}     # initialize native TBD arguments

      # If uprating, initialize native TBD args.
      [:walls, :floors, :roofs].each do |stypes|
        next if @model[stypes].empty?
        next unless argh.key?(stypes)
        next unless argh[stypes].key?(:ut)

        ut = argh[stypes][:ut]
        ok = ut.is_a?(Numeric) && ut.between?(UMIN, UMAX)
        lgs << "Invalid BTAP/TBD #{stypes} Ut" unless ok
        next                                   unless ok

        stype  = stypes.to_s.chop
        uprate = "uprate_#{stypes.to_s}".to_sym
        option = "#{stype}_option".to_sym
        ut     = "#{stype}_ut".to_sym

        args[uprate] = true
        args[option] = "ALL #{stype} constructions"
        args[ut    ] = ut
      end

      args[:io_path] = @model[combo] # contents of a "tbd.json" file
      args[:option ] = ""            # safeguard

      loop do
        if initial
          initial = false
        else
          # Subsequent runs. Upgrade technologies. Reset TBD args.
          if quality == :bad
            quality = :good
            combo   = "#{perform.to_s}_#{quality.to_s}".to_sym
            args[:io_path] = @model[combo]
          elsif perform == :lp
            # Switch 'perform' from :lp to :hp - reset quality to :bad.
            perform = :hp
            quality = :bad
            combo   = "#{perform.to_s}_#{quality.to_s}".to_sym
            args[:io_path] = @model[combo]
          end
        end

        # Run TBD on cloned OpenStudio models until compliant.
        mdl = OpenStudio::Model::Model.new
        mdl.addObjects(model.toIdfFile.objects)
        TBD.clean!
        res = TBD.process(mdl, args)

        if TBD.status.zero?
          comply = true
        else
          # TBD logs warnings and non/fatal errors when 'processing'
          # OpenStudio models, often when faced with invalid OpenStudio
          # objects that may not be necessarily flagged by OpenStudio
          # Standards and/or by BTAP. Examples could include subsurfaces not
          # fitting neatly within a host surface, (slight) overlaps between
          # subsurfaces, 5-sided windows, and so on. TBD typically logs such
          # non-fatal errors, ignores the faulty object, and otherwise pursues
          # its calculations. It would usually be up to BTAP users to decide
          # how to proceed when faced with most non-fatal errors. However,
          # when it comes ultimately to failed attempts by TBD to 'uprate'
          # constructions of an OpenStudio model for NECB compliance, BTAP
          # should definitely skip to the next loop iteration.
          unable = false

          TBD.logs.each do |log|
            break if unable

            unable = log[:message].include?("Unable to uprate ")
            break if unable

            unable = log[:message].include?("Can't uprate "    )
          end

          if unable
            # puts # TEMPORARY for debugging
            # puts "¨¨¨ combo : #{combo}"
            # puts args[:io_path][:psis]
            # TBD.logs.each { |lg| puts lg }
            # puts
          else
            comply = true
          end
        end

        if comply
          # Not completely out of the woods yet for uprated cases. Despite
          # having TBD identify a winning combination, determine if BTAP holds
          # admissible Uo values (see lines ~245, :uos key). If TBD-estimated
          # Uo is lower than any of these admissible BTAP Uo factors, then no
          # commercially available solution has been identified. Reset "comply"
          # to "false", and loop again (until TBD-reported Uo is above or equal
          # to any of the BTAP Uo factors). This needs revisiting once BTAP
          # enables building-type construction selection.
          [:walls, :floors, :roofs].each do |stypes|
            break unless comply
            next if @model[stypes].empty?
            next unless argh.key?(stypes)
            next unless argh[stypes].key?(:ut)

            ut = argh[stypes][:ut]
            stype_uo = "#{stypes.to_s.chop}_uo".to_sym

            # If successul, TBD adds a building-wide uprated Uo factor to its
            # native input arguments, e.g. "walls_uo". Reject if missing.
            comply = false unless args.key?(stype_uo)
            break          unless args.key?(stype_uo)

            # Safeguard. TBD should never generate uprated Uo > required Ut.
            ok     = args[stype_uo] < ut || (args[stype_uo] - ut).abs < 0.001
            comply = false unless ok
            break          unless ok

            # Check if within range of BTAP commercially-available options, for:
            #   - walls, floors & roofs
            #   - specific to each space type
            @model[:sptypes].each do |id, spacetype|
              uo_sptype = nil
              break unless comply
              next unless spacetype.key?(stypes)
              next unless spacetype[stypes].key?(perform) # :lp or :hp

              construction = spacetype[stypes][perform]
              next unless @@data.key?(construction)
              next unless @@data[construction].key?(:uos)

              # puts
              # puts "required Uo for #{id} #{stypes}: #{args[stype_uo]}"
              # puts

              @@data[construction][:uos].keys.each do |u|
                uo = u.to_f / 1000
                ok = uo < args[stype_uo] || (uo - args[stype_uo]).abs < 0.001
                next unless ok

                uo_sptype = uo # winning combo?
                @model[:constructions] = {} unless @model.key?(:constructions)
                @model[:constructions][construction] = { uo: uo }
                break
              end

              next unless uo_sptype.nil?

              comply = false
              val    = format("%.3f", args[stype_uo])
              lgs << "... required Uo for #{stypes}: #{val}"
            end
          end
        end

        # Conditional break from the 'loop'.
        if comply
          break
        elsif combo == :hp_good
          # i.e. TBD's uprating features are requested, yet unable to locate
          # either a physically- or economically-plausible Uo + PSI combo.
          redflag = true
          comply  = true # (temporarily) signal compliance
          lgs << "REDFLAG: no Ut-compliant TBD combo"

          [:walls, :floors, :roofs].each do |stypes|
            next unless argh.key?(stypes)
            next unless argh[stypes].key?(:ut)

            groups = {}
            stype  = stypes.to_s.chop
            uprate = "uprate_#{stypes.to_s}".to_sym
            option = "#{stype}_option".to_sym
            ut     = "#{stype}_ut".to_sym

            # Cancel uprating request before derating.
            args.delete(uprate)
            args.delete(option)
            args.delete(ut    )

            # Group BTAP constructions based on lowest Uo factors e.g.:
            #  - 0.130 for WOOD7
            #  - 0.080 for STEL2
            #  - 0.100 for all ROOFS
            @model[stypes].each do |id, type|
              next unless type.key?(:sptype)

              spacetype = type[:sptype] # e.g. :office
              next unless @model[:sptypes].key?(spacetype)
              next unless @model[:sptypes][spacetype].key?(stypes)
              next unless @model[:sptypes][spacetype][stypes].key?(perform)

              construction = @model[:sptypes][spacetype][stypes][perform]
              next unless @@data.key?(construction)
              next unless @@data[construction].key?(:uos)

              uos = []
              @@data[construction][:uos].keys.each { |u| uos << u.to_f / 1000 }
              uo  = uos.min
              @model[:constructions] = {} unless @model.key?(:constructions)
              @model[:constructions][construction] = { uo: uo }

              exists = groups.key?(construction)
              groups[construction] = { uo: uo, faces: [] } unless exists
              surface = model.getSurfaceByName(id)
              next if surface.empty?

              groups[construction][:faces] << surface.get
            end

            groups.each do |id, group|
              # puts
              # puts "#{id} : #{stypes} : #{group[:uo]}: #{group[:faces].size}x"
              # group[:faces].each { |s| puts s.nameString }
              sss = BTAP::Geometry::Surfaces.set_surfaces_construction_conductance(group[:faces], group[:uo])
              # puts
              #
              # sss.each do |ssss|
              #   lc = ssss.construction.get.to_LayeredConstruction.get
              #   usi = 1 / TBD.rsi(lc, ssss.filmResistance)
              #   puts "#{ssss.construction.get.nameString} : #{usi}"
              # end
              #
              # puts "~~~~~~~~~~"
              # puts
            end
          end

          comply = true # temporary
          break
        end
      end

      @model[:comply ] = comply
      @model[:perform] = perform
      @model[:quality] = quality
      @model[:combo  ] = combo

      if comply
        # Run "process" TBD (with last generated args Hash) one last time on
        # "model" (not cloned "mdl"). This may uprate (if applicable ... unless
        # redflagged), then derate BTAP above-grade surface constructions before
        # simulation.
        TBD.clean!
        res = TBD.process(model, args)

        # puts # TEMPORARY
        # puts args[:io_path][:psis]
        # puts

        @model[:comply  ] = false            if redflag
        @model[:io      ] = res[:io      ] # TBD outputs (i.e. "tbd.out.json")
        @model[:surfaces] = res[:surfaces] # TBD derated surface data
        @model[:args    ] = args           # last TBD inputs (i.e. "tbd.json")

        self.gen_tallies                   # tallies for BTAP costing
        self.gen_feedback                  # log success messages for BTAP
      end

      self.purge_buffer_schedules(model, buffers)
    end

    ##
    # Modify BTAP-generated 'buffer zones' (e.g. attics) to ensure TBD tags
    # these as indirectly conditioned spaces (e.g. plenums).
    #
    # @param model [OpenStudio::Model::Model] a model
    #
    # @return [Array] identifiers of modified buffer spaces in model
    def alter_buffers(model = nil)
      buffers = []
      sched   = nil
      lgs     = @feedback[:logs]
      cl      = OpenStudio::Model::Model
      lgs << "Invalid OpenStudio model (buffers)" unless model.is_a?(cl)
      return buffers                              unless model.is_a?(cl)

      model.getSpaces.each do |space|
        next if space.partofTotalFloorArea
        next if space.thermalZone.empty?

        id    = space.nameString
        zone  = space.thermalZone.get
        next if zone.isPlenum
        next if zone.thermostat.empty?

        tstat  = zone.thermostat.get
        staged = tstat.respond_to?(:heatingTemperatureSetpointSchedule)
        tstat  = tstat.to_ZoneControlThermostatStagedDualSetpoint.get if staged
        tstat  = tstat.to_ThermostatSetpointDualSetpoint.get      unless staged

        if sched.nil?
          name  = "TBD attic setpoint sched"
          sched = OpenStudio::Model::ScheduleCompact.new(model)
          sched.setName(name)
        end

        tstat.setHeatingTemperatureSetpointSchedule(sched)     if staged
        tstat.setHeatingSetpointTemperatureSchedule(sched) unless staged

        buffers << id
      end

      buffers
    end

    ##
    # Remove previously BTAP/TBD-added heating setpoint schedules for 'buffer
    # zones' (e.g. attics).
    #
    # @param model [OpenStudio::Model::Model] a model
    # @param buffers [Array] identifiers of modified buffer spaces in model
    #
    # @return [Bool] true if successful
    def purge_buffer_schedules(model = nil, buffers = [])
      scheds = []
      lgs    = @feedback[:logs]
      cl     = OpenStudio::Model::Model
      lgs << "Invalid OpenStudio model (purge)" unless model.is_a?(cl)
      lgs << "Invalid BTAP/TBD buffers"         unless buffers.is_a?(Array)
      return false                              unless model.is_a?(cl)
      return false                              unless buffers.is_a?(Array)

      buffers.each do |id|
        space = model.getSpaceByName(id)
        next if space.empty?

        space = space.get
        next if space.thermalZone.empty?

        zone = space.thermalZone.get
        next if zone.thermostat.empty?

        tstat  = zone.thermostat.get
        staged = tstat.respond_to?(:heatingTemperatureSetpointSchedule)
        tstat  = tstat.to_ZoneControlThermostatStagedDualSetpoint.get if staged
        tstat  = tstat.to_ThermostatSetpointDualSetpoint.get      unless staged
        sched  = tstat.heatingTemperatureSetpointSchedule             if staged
        sched  = tstat.heatingSetpointTemperatureSchedule         unless staged
        next if sched.empty?

        sched = sched.get
        scheds << sched.nameString
        tstat.resetHeatingSetpointTemperatureSchedule             unless staged
        tstat.resetHeatingTemperatureSetpointSchedule                 if staged
      end

      scheds.each do |sched|
        schd = model.getScheduleByName(sched)
        next if schd.empty?
        schd = schd.get
        schd.remove
      end

      true
    end

    ##
    # Fetch min U-factor of outdoor-facing OpenStudio model surface types.
    #
    # @param model [OpenStudio::Model::Model] a model
    # @param stype [Symbol] model surface type (e.g. :walls)
    #
    # @return [Float] min U factor (default 5.678 W/m2.K)
    def minU(model = nil, stypes = :walls)
      u     = UMAX
      lgs   = @feedback[:logs]
      cl    = OpenStudio::Model::Model
      stype = stypes.to_s.chop.downcase
      ok    = stype == "wall" || stype == "floor" || stype == "roof"
      stype = "wall"                                     unless ok
      lgs << "Invalid OpenStudio model (#{stypes} minU)" unless model.is_a?(cl)
      return u                                           unless model.is_a?(cl)

      model.getSurfaces.each do |s|
        next unless s.surfaceType.downcase.include?(stype)
        next unless s.outsideBoundaryCondition.downcase == "outdoors"
        next if s.construction.empty?
        next if s.construction.get.to_LayeredConstruction.empty?

        lc = s.construction.get.to_LayeredConstruction.get
        uo = 1 / TBD.rsi(lc, s.filmResistance)

        u = [uo, u].min
      end

      # u0 = format("%.3f", u) # TEMPORARY
      # puts "~~ Extracted #{stypes} minU (#{u0}) W/m2.K from OpenStudio model"

      u
    end

    ##
    # Populate BTAP/TBD model with BTAP & OpenStudio model parameters.
    #
    # @param model [OpenStudio::Model::Model] a model
    # @param argh [Hash] BTAP/TBD argument hash
    #
    # @return [Bool] true if valid (check @feedback logs if false)
    def populate(model = nil, argh = {})
      lgs    = @feedback[:logs]
      cl     = OpenStudio::Model::Model
      args   = { option: "(non thermal bridging)" }    # for initial TBD dry run

      # Pre-TBD BTAP validatation.
      lgs << "Invalid BTAP/TBD feedback" unless @feedback.is_a?(Hash)
      lgs << "Missing BTAP/TBD logs"     unless @feedback.key?(:logs)
      lgs << "Invalid BTAP/TBD logs"     unless @feedback[:logs].is_a?(Array)
      return false unless @feedback.is_a?(Hash)
      return false unless @feedback.key?(:logs)
      return false unless @feedback[:logs].is_a?(Array)

      lgs << "Invalid OpenStudio model to de/up-rate" unless model.is_a?(cl)
      lgs << "Invalid BTAP/TBD argument Hash"         unless argh.is_a?(Hash)
      lgs << "Empty BTAP/TBD argument hash"               if argh.empty?
      return false                                    unless model.is_a?(cl)
      return false                                    unless argh.is_a?(Hash)
      return false                                        if argh.empty?

      # Fetch number of stories in OpenStudio model.
      stories = model.getBuilding.standardsNumberOfAboveGroundStories
      stories = stories.get                  unless stories.empty?
      stories = model.getBuildingStorys.size unless stories.is_a?(Integer)

      @model[:stories] = stories
      @model[:stories] = 1              if stories < 1
      @model[:stories] = 999            if stories > 999
      @model[:spaces ] = {}
      @model[:sptypes] = {}

      # Run TBD on cloned OpenStudio models (dry run).
      mdl      = OpenStudio::Model::Model.new
      mdl.addObjects(model.toIdfFile.objects)
      TBD.clean!
      res      = TBD.process(mdl, args)
      surfaces = res[:surfaces]

      # TBD validation of OpenStudio model.
      lgs << "TBD-identified FATAL error(s):"      if TBD.fatal?
      lgs << "TBD-identified non-FATAL error(s):"  if TBD.error?
      TBD.logs.each { |log| lgs << log[:message] } if TBD.fatal? || TBD.error?
      return false                                 if TBD.fatal?

      lgs << "TBD: no deratable surfaces in model" if surfaces.nil?
      return false                                 if surfaces.nil?

      # Initialize deratable walls, exposed floors & roofs.
      [:walls, :floors, :roofs].each { |stypes| @model[stypes] = {} }

      surfaces.each do |id, surface|
        next unless surface.key?(:type     ) # :wall, :floor, :ceiling
        next unless surface.key?(:space    ) # OpenStudio space object
        next unless surface.key?(:deratable) # true/false
        next unless surface[:deratable]

        stypes = :walls  if surface[:type] == :wall
        stypes = :floors if surface[:type] == :floor
        stypes = :roofs  if surface[:type] == :ceiling
        next unless stypes == :walls || stypes == :floors || stypes == :roofs

        space     = surface[:space].nameString
        spacetype = surface[:stype].nameString if surface.key?(:stype)
        spacetype = ""                     unless surface.key?(:stype)
        typ       = self.sptype(spacetype, @model[:stories]) # e.g. :office

        # Keep track of individual surface's space and spacetype keyword.
        @model[stypes][id]          = {}
        @model[stypes][id][:space ] = space
        @model[stypes][id][:sptype] = typ

        # Keep track of individual spaces and spacetypes.
        exists = @model[:spaces].key?(space)
        @model[:spaces][space]          = {}        unless exists
        @model[:spaces][space][:sptype] = typ       unless exists

        exists = @model[:sptypes].key?(typ)
        @model[:sptypes][typ ]          = {}        unless exists
        @model[:sptypes][typ ][:sptype] = spacetype unless exists
        next if @model[:sptypes][typ].key?(stypes)

        # Low- vs Hi-Performance BTAP assemblies.
        lo = self.assembly(typ, stypes, :lp)
        hi = self.assembly(typ, stypes, :hp)
        @model[:sptypes][typ][stypes]      = {}
        @model[:sptypes][typ][stypes][:lp] = lo
        @model[:sptypes][typ][stypes][:hp] = hi
        next unless stypes == :walls

        # Fetch bad vs good PSI factor sets - strictly a function of walls.
        @model[:sptypes][typ][:lp_bad ] = self.set(lo, :bad )
        @model[:sptypes][typ][:lp_good] = self.set(lo, :good)
        @model[:sptypes][typ][:hp_bad ] = self.set(hi, :bad )
        @model[:sptypes][typ][:hp_good] = self.set(hi, :good)
      end

      # Post-TBD validation: BTAP-fed Uo factors, then Ut factors (optional).
      [:walls, :floors, :roofs].each do |stypes|
        lgs << "Missing BTAP/TBD #{stypes}"    unless argh.key?(stypes)
        lgs << "Missing BTAP/TBD #{stypes} Uo" unless argh[stypes].key?(:uo)
        return false                           unless argh.key?(stypes)
        return false                           unless argh[stypes].key?(:uo)
        next                                       if @model[stypes].empty?

        uo = self.minU(model, stypes)
        ok = uo.is_a?(Numeric) && uo.between?(UMIN, UMAX)
        argh[stypes][:uo] = uo                     if ok
        next                                       if ok

        lgs << "Invalid BTAP/TBD #{stypes} Uo"
        return false
      end

      [:walls, :floors, :roofs].each do |stypes| # Ut optional
        next                                   unless argh[stypes].key?(:ut)
        next                                       if @model[stypes].empty?

        ut = self.minU(model, stypes)
        ok = ut.is_a?(Numeric) && ut.between?(UMIN, UMAX)
        argh[stypes][:ut] = ut                     if ok
        next                                       if ok

        lgs << "Invalid BTAP #{stypes} Ut"
        return false
      end

      # Generate native TBD input Hashes for the model, for both :good & :bad
      # PSI factor sets. The typical TBD use case involves writing out the
      # contents of either Hash (e.g. JSON::pretty_generate) as a "tbd.json"
      # input file, to save under a standard OpenStudio "files" folder. At
      # runtime, TBD then reopens the JSON file and populates its own data
      # model in memory. Yet BTAP is not a typical use case. To avoid writing
      # out (then re-reading) TBD JSON files/hashes (i.e. resource intensive),
      # BTAP/TBD instead populates the TBD data model directly.
      @model[:lp_bad ] = self.inputs(:lp, :bad )
      @model[:lp_good] = self.inputs(:lp, :good)
      @model[:hp_bad ] = self.inputs(:hp, :bad )
      @model[:hp_good] = self.inputs(:hp, :good)

      @model[:osm] = model

      true
    end

    ##
    # Generate (native) TBD input hash.
    #
    # @param perform [Symbol] :lp or :hp wall variant
    # @param quality [Symbol] :bad or :good PSI-factor
    #
    # @return [Hash] native TBD inputs
    def inputs(perform = :hp, quality = :good)
      input   = {}
      psis    = {} # construction-specific PSI sets
      types   = {} # space type-specific references to previous PSI sets
      perform = :hp   unless perform == :lp  || perform == :hp
      quality = :good unless quality == :bad || quality == :good

      # Once building-type construction selection is introduced within BTAP,
      # define default TBD "building" PSI set. In the meantime, this is added
      # strictly as a backup solution (just in case).
      building = self.set(STEL1, quality) if perform == :lp
      building = self.set(STEL2, quality) if perform == :hp

      psis[ building[:id] ] = building

      # Collect unique BTAP/TBD instances.
      combo = "#{perform.to_s}_#{quality.to_s}".to_sym

      @model[:sptypes].values.each do |type|
        next unless type.key?(combo)

        psi = type[combo]
        next if psis.key?(psi[:id])

        psis[ psi[:id] ] = psi
      end

      # TBD JSON schema added as a reminder. No schema validation in BTAP.
      schema = "https://github.com/rd2/tbd/blob/master/tbd.schema.json"

      input[:schema     ] = schema
      input[:description] = "TBD input for BTAP"              # append run # ?
      input[:psis       ] = psis.values

      @model[:sptypes].values.each do |type|
        next unless type.key?(:sptype)
        next unless type.key?(combo)
        next if types.key?(type[:sptype])

        types[ type[:sptype] ] = { psi: type[combo][:id] }
      end

      types.each do |id, type|
        input[:spacetypes] = [] unless input.key?(:spacetypes)
        input[:spacetypes] << { id: id, psi: type[:psi] }
      end

      input[:building] = { psi: building[:id] }

      input
    end

    ##
    # Generate BTAP/TBD tallies
    #
    # @return [Bool] true if BTAP/TBD tally is successful
    def gen_tallies
      edges  = {}
      return false unless @model.key?(:io)
      return false unless @model[:io].key?(:edges)

      @model[:io][:edges].each do |e|
        # Content of TBD-generated 'edges' (hashes):
        #      psi: BTAP PSI set ID, e.g. "BTAP-ExteriorWall-Mass-6 good"
        #     type: thermal bridge type, e.g. :corner
        #   length: (in m)
        # surfaces: linked OpenStudio surface IDs
        edges[e[:type]]           = {} unless edges.key?(e[:type])
        edges[e[:type]][e[:psi]]  = 0  unless edges[e[:type]].key?(e[:psi])
        edges[e[:type]][e[:psi]] += e[:length]
      end

      return false if edges.empty?

      @tally[:edges] = edges

      # Add final selection of (uprated) Uo factors per BTAP construction.
      return true unless @model.key?(:constructions)

      @tally[:constructions] = @model[:constructions]

      true
    end

    ##
    # Generate BTAP/TBD post-processing feedback.
    #
    # @return [Bool] true if valid BTAP/TBD model
    def gen_feedback
      lgs = @feedback[:logs]
      return false unless @model.key?(:comply)
      return false unless @model.key?(:args  )

      args = @model[:args]

      # Successfully uprated Uo (if requested).
      [:walls, :floors, :roofs].each do |stypes|
        break unless @model[:comply]

        stype_ut = "#{stypes.to_s.chop}_ut".to_sym
        stype_uo = "#{stypes.to_s.chop}_uo".to_sym
        next unless args.key?(stype_ut)
        next unless args.key?(stype_uo)
        next unless @model.key?(stypes)
        next     if @model[stypes].empty?

        ut = args[stype_ut]
        uo = args[stype_uo]
        next unless ut.is_a?(Numeric)
        next unless uo.is_a?(Numeric)

        ut = format("%.3f", ut)
        uo = format("%.3f", uo)
        lgs << "Compliant #{stypes}: Uo #{uo} vs Ut #{ut} W/m2.K"
      end

      # Uprating unsuccessful: report min Uo factor per construction.
      if @model.key?(:constructions)
        @model[:constructions].each do |id, construction|
          break if @model[:comply]

          lgs << "Non-compliant #{id} Uo factor #{construction[:uo]} (W/K.m^2)"
        end
      end

      # Summary of TBD-derated constructions.
      @model[:osm].getSurfaces.each do |s|
        next if s.construction.empty?
        next if s.construction.get.to_LayeredConstruction.empty?

        lc = s.construction.get.to_LayeredConstruction.get
        next unless lc.nameString.include?(" c tbd")

        rsi = TBD.rsi(lc, s.filmResistance)
        rsi = format("%.1f", rsi)
        lgs << "~~ '#{lc.nameString}' derated Rsi: #{rsi} (m^2.K/W)"
      end

      # Log PSI factor tallies (per thermal bridge type).
      if @tally.key?(:edges)
        @tally[:edges].each do |type, e|
          next if type == :transition

          lgs << "# '#{type}' (#{e.size}x):"

          e.each do |psi, length|
            l = format("%.2f", length)
            lgs << "... PSI set '#{psi}' : #{l} m"
          end
        end
      end

      true
    end
  end
end

# NOTE: BTAP supports Uo variants for each of the aforementioned wall
#       constructions, e.g. meeting NECB2011 and NECB2015 prescriptive "Uo"
#       requirements for each NECB climate zone. By definition, these Uo
#       variants ignore the effects of MAJOR thermal bridging, such as
#       intermediate slab edges. This does not imply that NECB2011 and NECB2015
#       do not hold prescriptive requirements for MAJOR thermal bridging. There
#       are indeed a handful of general, qualitative requirements (those of the
#       MNECB1997) that would make NECB2011- and NECB2015-compliant buildings
#       slightly better than BTAPPRE1980 "bottom-of-the-barrel" construction,
#       but lilely not any better than circa 1990s "run-of-the-mill" commercial
#       construction. Currently, BTAP does not assess the impact of MAJOR
#       thermal bridging for vintages < NECB2017. But ideally it SHOULD, if the
#       goal remains a fair assessment of the (relative) contribution of more
#       recent NECB requirements (e.g. 2020).

# NOTE: The BTAP costing spreadsheet holds entries for curtain wall (CW)
#       spandrel inserts above/below fenestration for certain spacetypes, see:
#
#         test/necb/unit_tests/resources/btap_spandrels.png
#
#       This is yet to be implemented. This note is an "aide-mémoire" for future
#       consideration. The BETBG does not hold any CW glazed spandrels achieving
#       U factors ANYWHERE near NECB requirements, regardless of NECB vintage or
#       NECB climate zone. Same for the Guide to Low Thermal Energy Demand for
#       Large Buildings. The original intention was to rely on BTAP variants
#       "Metal-2" and "Metal-3" as HP CW spandrels ACTUALLY achieving NECB
#       prescriptive targets, which could only be possible in practice at
#       tremendous cost and effort.
#
#       If TBD's uprating calculations (e.g. NECB 2017) were in theory no longer
#       required, BTAP's treatment of HP CW spandrels could be implemented
#       strictly as a costing adjustment: energy simulation models wouldn't have
#       to be altered. Otherwise, adaptations would be required. PSI factors are
#       noticeably different for spandrels (obviously no lintels/shelf-angles).
#       More importantly, the default assumption with CW technology is that
#       there wouldn't be any additional linear conductances to consider along
#       vision vs spandrel sections (as perimeter heat loss would already have
#       been considered as per NFRC or CSA rating methodologies). On the other
#       hand, vision jambs along non-CW assemblies (i.e. original BTAP
#       intention) most certainly constitute (new) MAJOR thermal bridges to
#       consider (just as with shared edges between spandrels and other wall
#       assemblies). Again, none of these features are currently implemented
#       within BTAP. Recommended (future) solution, if desired:
#
#         - Automated OSM façade-splitting feature
#           - insert spandrels above/below windows
#             > ~200 lines of Ruby code
#           - simple cases only e.g., vertical, no overlaps, h > 200mm
#             > split above/below plenum walls as well
#             > potentially another 200 lines to catch invalid input
#
#        - Further develop PSI sets to cover CWs (see below)
#          - e.g. PSI factors for CW vision "jamb" transitions
#          - e.g. PSI factors for CW spandrel "jamb" transitions
#
#       These added features would simplify the process tremendously. Yet
#       without admissible CW spandrel U factors down to 0.130 or 0.100 W/m2.K,
#       TBD's uprating features would necessarily push other wall constructions
#       to compensate - noticeably for climate zone 7 (or colder). This would
#       make it MUCH MORE difficult to identify NECB2017 or NECB2020 compliant
#       combinations of Uo+PSI factors if ever HP CW spandrels were integrated
#       within BTAP.

# NOTE: Some of the aforementioned constructions have exterior brick veneer.
#       For 2-story OpenStudio models with punch windows (i.e. not strip
#       windows), one would NOT expect a continuous shelf angle along the
#       intermediate floor slab edge (typically a MAJOR thermal bridge). One
#       would instead expect loose lintels above punch windows, just as with
#       doors. Loose lintels usually do not constitute MAJOR thermal bridges.
#       For taller builings, shelf angles are indeed expected. And if windows
#       are instead strip windows (not punch windows), then loose lintels would
#       typically be cast aside in favour of an offset shelf angle (even for
#       1-story buildings).
#
#       Many of the US DOE Commercial Benchmark Building and BTAP models are
#       1-story or 2-stories in height, yet they all have strip windows as their
#       default fenestration layout. As a result, BTAP/TBD presumes continuous
#       shelf angles, offset by the height difference between slab edge and
#       window head. Loose lintels (included in the clear field costing, $/m2)
#       should be limited to those above doors (TO-DO).
#
# NOTE: BTAP costing: In addition to the listed items for parapets as MAJOR
#       thermal bridges (eventually generating an overall $ per linear meter),
#       BTAP costing requires extending the areas (m2) of OpenStudio wall
#       surfaces (along parapet edges) by 3'-6" (1.1 m) x parapet lengths, to
#       account for the extra cost of completely wrapping the parapet in
#       insulation for "good" (HP) details. See final TBD tally. TO-DO.
#
# NOTE: Overview of current BTAP building/space type construction link, e.g.:
#
#         - ALL dwelling units/buildings < 5 stories are wood-framed
#         - ALL dwelling units/buildings > 4 stories are steel-framed
#
#       ... yet all (public) washrooms, corridors, stairwells, etc. are
#       steel-framed (regardless of building type). Overview of possible fixes.
#       TO-DO.