
# open the class to add methods to return sizing values
# @todo currently OpenStudio is missing the WaterHeater:Sizing object, so unlikely to need it right now...
class OpenStudio::Model::WaterHeaterMixed


  # returns the autosized Heater Maximum Capacity as an optional double
  def autosizedHeaterMaximumCapacity

    # @todo check the correct syntax here
    return self.model.getAutosizedValue(self, 'Design Size Nominal Capacity', 'W')

  end


end # close the class