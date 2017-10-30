



class NECB2011HighRiseApartment < NECB_2011_Model
  attr_accessor :define_space_type_map
  attr_accessor :offCycleLossCoefficienttoAmbientTemperatureWithBooster
  attr_accessor :offCycleLossCoefficienttoAmbientTemperatureWithoutBooster
  attr_accessor :fanOnOffEfficiency
  attr_accessor :fanOnOffMotorEfficiency
  def initialize()
    super()
    #Geometry
    @define_space_type_map = space_type_map = {
        'Office - enclosed' => ['Office'],
        "Corr. < 2.4m wide-sch-G" => ['T Corridor', 'G Corridor', 'F2 Corridor', 'F3 Corridor', 'F4 Corridor', 'M Corridor', 'F6 Corridor', 'F7 Corridor', 'F8 Corridor', 'F9 Corridor'],
        'Dwelling Unit(s)' => [
            'G SW Apartment',
            'G NW Apartment',
            'G NE Apartment',
            'G N1 Apartment',
            'G N2 Apartment',
            'G S1 Apartment',
            'G S2 Apartment',
            'F2 SW Apartment',
            'F2 NW Apartment',
            'F2 SE Apartment',
            'F2 NE Apartment',
            'F2 N1 Apartment',
            'F2 N2 Apartment',
            'F2 S1 Apartment',
            'F2 S2 Apartment',
            'F3 SW Apartment',
            'F3 NW Apartment',
            'F3 SE Apartment',
            'F3 NE Apartment',
            'F3 N1 Apartment',
            'F3 N2 Apartment',
            'F3 S1 Apartment',
            'F3 S2 Apartment',
            'F4 SW Apartment',
            'F4 NW Apartment',
            'F4 SE Apartment',
            'F4 NE Apartment',
            'F4 N1 Apartment',
            'F4 N2 Apartment',
            'F4 S1 Apartment',
            'F4 S2 Apartment',
            'M SW Apartment',
            'M NW Apartment',
            'M SE Apartment',
            'M NE Apartment',
            'M N1 Apartment',
            'M N2 Apartment',
            'M S1 Apartment',
            'M S2 Apartment',
            'F6 SW Apartment',
            'F6 NW Apartment',
            'F6 SE Apartment',
            'F6 NE Apartment',
            'F6 N1 Apartment',
            'F6 N2 Apartment',
            'F6 S1 Apartment',
            'F6 S2 Apartment',
            'F7 SW Apartment',
            'F7 NW Apartment',
            'F7 SE Apartment',
            'F7 NE Apartment',
            'F7 N1 Apartment',
            'F7 N2 Apartment',
            'F7 S1 Apartment',
            'F7 S2 Apartment',
            'F8 SW Apartment',
            'F8 NW Apartment',
            'F8 SE Apartment',
            'F8 NE Apartment',
            'F8 N1 Apartment',
            'F8 N2 Apartment',
            'F8 S1 Apartment',
            'F8 S2 Apartment',
            'F9 SW Apartment',
            'F9 NW Apartment',
            'F9 SE Apartment',
            'F9 NE Apartment',
            'F9 N1 Apartment',
            'F9 N2 Apartment',
            'F9 S1 Apartment',
            'F9 S2 Apartment',
            'T SW Apartment',
            'T NW Apartment',
            'T SE Apartment',
            'T NE Apartment',
            'T N1 Apartment',
            'T N2 Apartment',
            'T S1 Apartment',
            'T S2 Apartment'
        ]
    }
    #HVAC
    ##SHW
    @offCycleLossCoefficienttoAmbientTemperatureWithBooster = 1.053159296
    @offCycleLossCoefficienttoAmbientTemperatureWithoutBooster = 9.643286505
    @fanOnOffEfficiency = 0.53625
    @fanOnOffMotorEfficiency = 0.825
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)


    return true
  end # add hvac

  def self.update_fan_efficiency(model)
    model.getFanOnOffs.sort.each do |fan_onoff|
      fan_onoff.setFanEfficiency(@fanOnOffEfficiency)
      fan_onoff.setMotorEfficiency(@fanOnOffMotorEfficiency)
    end
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

  def custom_hvac_tweaks(model)
    return true
  end


  #not used by NECB

=begin
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