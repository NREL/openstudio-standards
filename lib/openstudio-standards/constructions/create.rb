module OpenstudioStandards
  # The Constructions module provides methods create, modify, and get information about model Constructions
  module Constructions
    # @!group Create
    # Methods to create Constructions

    # This will create a deep copy of the construction, meaning it will clone and create new material objects as well
    #
    # @param construction [OpenStudio::Model::Construction] OpenStudio Construction object object
    # @return [OpenStudio::Model::Construction] New OpenStudio Construction object
    def self.construction_deep_copy(construction)
      new_construction = construction.clone.to_Construction.get
      (0..new_construction.layers.length - 1).each do |layer_number|
        cloned_layer = new_construction.getLayer(layer_number).clone.to_Material.get
        new_construction.setLayer(layer_number, cloned_layer)
      end
      return new_construction
    end

    # @!endgroup Create
  end
end