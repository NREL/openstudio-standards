
# open the class to add methods to return sizing values
class OpenStudio::Model::ThermalZone

  # Determine the zone heating fuels, including
  # any fuels used by zone equipment, reheat terminals,
  # the air loops serving the zone, and any plant loops
  # serving those air loops.
  #
  # return [Array<String>] An array. Possible values are
  # Electricity, NaturalGas, Propane, PropaneGas, FuelOilNo1, FuelOilNo2,
  # Coal, Diesel, Gasoline, DistrictCooling, DistrictHeating,
  # and SolarEnergy.
  def heating_fuels

    fuels = []

    # Special logic for models imported from Sefaira.
    # In this case, the fuels are listed as a comment
    # above the Zone object.
    if !self.comment == ''
      m = self.comment.match /! *(.*)/
      if m
        all_fuels = m[1].split(',')
        all_fuels.each do |fuel|
          fuels += fuel.strip
        end
      end
      if fuels.size > 0
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "For #{self.name}, fuel type #{fuels.join(', ')} pulled from Zone comment.")
        fuels.uniq.sort
      end
    end

    # Check the zone hvac heating fuels
    fuels += self.model.zone_equipment_heating_fuels(self)

    # Check the zone airloop heating fuels
    fuels += self.model.zone_airloop_heating_fuels(self)

    OpenStudio::logFree(OpenStudio::Debug, 'openstudio.model.Model', "For #{name}, heating fuels = #{fuels.uniq.sort.join(', ')}.")

    return fuels.uniq.sort

  end

  # Determine the zone cooling fuels, including
  # any fuels used by zone equipment, reheat terminals,
  # the air loops serving the zone, and any plant loops
  # serving those air loops.
  #
  # return [Array<String>] An array. Possible values are
  # Electricity, NaturalGas, Propane, PropaneGas, FuelOilNo1, FuelOilNo2,
  # Coal, Diesel, Gasoline, DistrictCooling, DistrictHeating,
  # and SolarEnergy.
  def cooling_fuels

    fuels = []

    # Check the zone hvac cooling fuels
    fuels += self.model.zone_equipment_cooling_fuels(self)

    # Check the zone airloop cooling fuels
    fuels += self.model.zone_airloop_cooling_fuels(self)

    OpenStudio::logFree(OpenStudio::Debug, 'openstudio.model.Model', "For #{name}, cooling fuels = #{fuels.uniq.sort.join(', ')}.")

    return fuels.uniq.sort

  end

end
