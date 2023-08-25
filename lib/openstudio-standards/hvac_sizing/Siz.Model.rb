
# open the class to add methods to size all HVAC equipment
class OpenStudio::Model::Model

  # Ensure that the version of OpenStudio is 2.4.1 or greater
  # because this is when the .autosizedFoo methods were added to C++.
  min_os_version = "2.4.1"
  if OpenStudio::Model::Model.new.version < OpenStudio::VersionString.new(min_os_version)
    OpenStudio::logFree(OpenStudio::Error, "openstudio.model.Model", "This measure requires a minimum OpenStudio version of #{min_os_version} because this is when the .autosizedFoo methods were added to C++.")
  end

  # Load the helper libraries for getting additional autosized
  # values that aren't included in the C++ API.
  require_relative 'Siz.AirLoopHVAC'
  require_relative 'Siz.CoilCoolingWater'
  require_relative 'Siz.ThermalZone'

  # Heating and cooling fuel methods
  require_relative 'Siz.HeatingCoolingFuels'

  # Component quantity methods
  require_relative 'Siz.HVACComponent'
end
