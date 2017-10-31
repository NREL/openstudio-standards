require_relative '../../../test/helpers/minitest_helper'

require 'json'


array = []


# this reads in the json file.
JSON.parse(File.read("#{File.dirname(__FILE__)}/../refactor/prototypes/common/data/prototype_database.json")).each do |info|
  # Use this to load the osm file into a model objects.
  info["geometry"]

  #skips if there are no multipliers.
  if not info["space_multiplier_map"].nil?
  info["space_multiplier_map"].each do |space_name, multiplier|
    space_name = space_name.to_s
    multiplier = multiplier.to_i
    # after that is done you should have a model object.
    thermal_zone = OpenStudio::Model::ThermalZone.new(model)
    # Create a more informative space name.
    thermal_zone.setName("TZ-#{space_name}")
    # Add zone mulitplier if required.
    thermal_zone.setMultiplier(multiplier)
    # get the space in the model.
    space = model.getSpaceByName(space_name)
    #associates the thermal to the space.
    space.setThermalZone(thermal_zone)
  end
  end
end


