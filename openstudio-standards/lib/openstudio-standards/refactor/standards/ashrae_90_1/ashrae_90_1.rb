class A90_1_Model < StandardsModel

  # Load the helper libraries for
  require "#{@@prototype_folder}/Prototype.Fan"
  require "#{@@prototype_folder}/Prototype.FanConstantVolume"
  require "#{@@prototype_folder}/Prototype.FanVariableVolume"
  require "#{@@prototype_folder}/Prototype.FanOnOff"
  require "#{@@prototype_folder}/Prototype.FanZoneExhaust"
  require "#{@@prototype_folder}/Prototype.HeatExchangerAirToAirSensibleAndLatent"
  require "#{@@prototype_folder}/Prototype.ControllerWaterCoil"
  require "#{@@prototype_folder}/Prototype.Model.hvac"
  require "#{@@prototype_folder}/Prototype.Model.swh"
  require "#{@@standards_folder}/Standards.Model"
  require "#{@@prototype_folder}/Prototype.building_specific_methods"
  require "#{@@prototype_folder}/Prototype.Model.elevators"
  require "#{@@prototype_folder}/Prototype.Model.exterior_lights"

  def initialize
    super()
  end
  
end