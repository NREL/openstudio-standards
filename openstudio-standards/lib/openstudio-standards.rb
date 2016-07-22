require "openstudio-standards/version"

module OpenstudioStandards

  require 'json' # Used to load standards JSON files
  
  # HVAC sizing
  require 'openstudio-standards/hvac_sizing/Siz.Model'

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

  # Load the Openstudio Standards JSON
  # and assign to a constant.  This
  # should never be altered by the gem.
  $os_standards = load_openstudio_standards_json 
  
  
end
