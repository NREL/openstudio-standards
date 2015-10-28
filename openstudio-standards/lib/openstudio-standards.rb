require "openstudio-standards/version"

module OpenstudioStandards

  require 'json' # Used to load standards JSON files

  # HVAC sizing
  require 'openstudio-standards/hvac_sizing/HVACSizing.Model'

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
 
end
