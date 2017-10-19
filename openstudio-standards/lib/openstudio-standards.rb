require_relative 'openstudio-standards/version'

module OpenstudioStandards
 
  require 'json' # Used to load standards JSON files


  # HVAC sizing
  require_relative 'openstudio-standards/hvac_sizing/Siz.Model'

  # Prototype Inputs
  require_relative 'openstudio-standards/prototypes/Prototype.Model'
  require_relative 'openstudio-standards/prototypes/Prototype.utilities'
  require_relative 'openstudio-standards/prototypes/Prototype.add_objects'
  require_relative 'openstudio-standards/prototypes/Prototype.hvac_systems'

  # Weather data
  require_relative 'openstudio-standards/weather/Weather.Model'

  # HVAC standards
  require_relative 'openstudio-standards/standards/Standards.Model'

  # BTAP (Natural Resources Canada)
  require_relative 'openstudio-standards/btap/btap'

  # Utilities
  require_relative 'openstudio-standards/utilities/logging'
  require_relative 'openstudio-standards/utilities/simulation'
  require_relative 'openstudio-standards/utilities/hash'
  require_relative 'openstudio-standards/utilities/sqlfile'

  # Load the Openstudio Standards JSON
  # and assign to a constant.  This
  # should never be altered by the gem.
  # @Todo: A constant in ruby is $CONSTANT not $constant
  $os_standards = load_openstudio_standards_json

  #refactored includes
  require_relative 'openstudio-standards/refactor/standards/standards_model'
  require_relative 'openstudio-standards/refactor/standards/necb/necb_2011/necb_2011'
  require_relative 'openstudio-standards/refactor/standards/ashrae_90_1/ashrae_90_1_2007/ashrae90_1_2007'
  require_relative 'openstudio-standards/refactor/standards/ashrae_90_1/ashrae_90_1_2004/ashrae90_1_2004'
  require_relative 'openstudio-standards/refactor/standards/ashrae_90_1/ashrae_90_1_2010/ashrae90_1_2010'
  require_relative 'openstudio-standards/refactor/standards/ashrae_90_1/ashrae_90_1_2013/ashrae90_1_2013'
  require_relative 'openstudio-standards/refactor/standards/ashrae_90_1/doe_ref_pre_1980/doe_ref_pre_1980'
  require_relative 'openstudio-standards/refactor/standards/ashrae_90_1/doe_ref_1980_2004/doe_ref_pre_1980_2004'
end
