
# open the class to add methods to return sizing values
class OpenStudio::Model::CoilCoolingWater

  # returns the autosized design coil load
  def autosizedDesignCoilLoad

    return self.getAutosizedValue('Design Size Design Coil Load', 'W')

  end


end
