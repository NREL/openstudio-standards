class NECB2011FullServiceRestaurant < NECB_2011_Model
  attr_accessor :define_space_type_map
  attr_accessor :offCycleLossCoefficienttoAmbientTemperatureWithBooster
  attr_accessor :offCycleLossCoefficienttoAmbientTemperatureWithoutBooster
  def initialize()
    super()
    #Geometry
    @define_space_type_map = {
        '- undefined -' => ['attic'],
        'Dining - family space' => ['Dining'],
        'Food preparation' => ['Kitchen']
    }
    #HVAC
    ##SHW
    @offCycleLossCoefficienttoAmbientTemperatureWithBooster = 1.053159296
    @offCycleLossCoefficienttoAmbientTemperatureWithoutBooster = 9.643286505
  end

  def custom_swh_tweaks(model)
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('Booster')
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(@offCycleLossCoefficienttoAmbientTemperatureWithBooster)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(@offCycleLossCoefficienttoAmbientTemperatureWithBooster)
      else
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(@offCycleLossCoefficienttoAmbientTemperatureWithoutBooster)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(@offCycleLossCoefficienttoAmbientTemperatureWithoutBooster)
      end
    end
    return true
  end




  #not used by NECB

=begin

  def custom_hvac_tweaks(model)
    return true
  end

  def add_door_infiltration()
    raise("should not be used!!!")
  end

  def update_exhaust_fan_efficiency()
    raise("should not be used!!!")
  end

  def add_zone_mixing()
    raise("should not be used!!!")
  end

  def add_extra_equip_kitchen
    raise("should not be used!!!")
  end

  def self.update_sizing_zone(template, model)
    raise("should not be used!!!")
  end

  def reset_kitchen_oa(template, model)
    raise("should not be used!!!")
  end
=end


end