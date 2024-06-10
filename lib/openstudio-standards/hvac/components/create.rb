module OpenstudioStandards
  # The HVAC module provides methods create, modify, and get information about HVAC systems in the model
  module HVAC
    # @!group Component:Create
    # Methods to create HVAC component objects

    # creates HeatExchangerAirToAirSensibleAndLatent object with user-input effectiveness values
    #
    # @param model [<OpenStudio::Model::Model>] OpenStudio model
    # @param name [String]
    # @param type [String] Heat Exchanger Type. One of 'Plate', 'Rotary'
    # @param economizer_lockout [Boolean] whether hx is locked out during economizing
    # @param supply_air_outlet_temperature_control [Boolean]
    # @param frost_control_type [String] HX frost control type. One of 'None', 'ExhaustAirRecirculation', 'ExhaustOnly', 'MinimumExhaustTemperature'
    # @param nominal_electric_power [Float] Nominal electric power
    # @param sensible_heating_100_eff [Float]
    # @param sensible_heating_75_eff [Float]
    # @param latent_heating_100_eff [Float]
    # @param latent_heating_75_eff [Float]
    # @param sensible_cooling_100_eff [Float]
    # @param sensible_cooling_75_eff [Float]
    # @param latent_cooling_100_eff [Float]
    # @param latent_cooling_75_eff [Float]
    # @return [<OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent>]
    def self.create_hx_air_to_air_sensible_and_latent(model,
                                                      name: nil,
                                                      type: nil,
                                                      economizer_lockout: nil,
                                                      supply_air_outlet_temperature_control: nil,
                                                      frost_control_type: nil,
                                                      nominal_electric_power: nil,
                                                      sensible_heating_100_eff: nil,
                                                      sensible_heating_75_eff: nil,
                                                      latent_heating_100_eff: nil,
                                                      latent_heating_75_eff: nil,
                                                      sensible_cooling_100_eff: nil,
                                                      sensible_cooling_75_eff: nil,
                                                      latent_cooling_100_eff: nil,
                                                      latent_cooling_75_eff: nil)

      hx = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(model)
      hx.setName(name) unless name.nil?

      unless type.nil?
        if OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.heatExchangerTypeValues.include?(type)
          hx.setHeatExchangerType(type)
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Hvac', "Entered heat exchanger type #{type} not a valid type value. Enter one of #{OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.heatExchangerTypeValues}")
        end
      end

      unless frost_control_type.nil?
        if OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.frostControlTypeValues.include?(frost_control_type)
          hx.setFrostControlType(frost_control_type)
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Hvac', "Entered heat exchanger frost control type #{frost_control_type} not a valid type value. Enter one of #{OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.frostControlTypeValues}")
        end
      end

      hx.setEconomizerLockout(economizer_lockout) unless economizer_lockout.nil?
      hx.setSupplyAirOutletTemperatureControl(supply_air_outlet_temperature_control) unless supply_air_outlet_temperature_control.nil?
      hx.setNominalElectricPower(nominal_electric_power) unless nominal_electric_power.nil?

      if model.version < OpenStudio::VersionString.new('3.8.0')
        hx.setSensibleEffectivenessat100HeatingAirFlow(sensible_heating_100_eff) unless sensible_heating_100_eff.nil?
        hx.setSensibleEffectivenessat75HeatingAirFlow(sensible_heating_75_eff) unless sensible_heating_75_eff.nil?
        hx.setLatentEffectivenessat100HeatingAirFlow(latent_heating_100_eff) unless latent_heating_100_eff.nil?
        hx.setLatentEffectivenessat75HeatingAirFlow(latent_heating_75_eff) unless latent_heating_75_eff.nil?
        hx.setSensibleEffectivenessat100CoolingAirFlow(sensible_cooling_100_eff) unless sensible_cooling_100_eff.nil?
        hx.setSensibleEffectivenessat75CoolingAirFlow(sensible_cooling_75_eff) unless sensible_cooling_75_eff.nil?
        hx.setLatentEffectivenessat100CoolingAirFlow(latent_cooling_100_eff) unless latent_cooling_100_eff.nil?
        hx.setLatentEffectivenessat75CoolingAirFlow(latent_cooling_75_eff) unless latent_cooling_75_eff.nil?
      else
        effectiveness_inputs = Hash.new { |hash, key| hash[key] = {} }
        effectiveness_inputs['Sensible Heating'][0.75] = sensible_heating_75_eff.to_f unless sensible_heating_75_eff.nil?
        effectiveness_inputs['Sensible Heating'][1.0] = sensible_heating_100_eff.to_f unless sensible_heating_100_eff.nil?
        effectiveness_inputs['Latent Heating'][0.75] = latent_heating_75_eff.to_f unless latent_heating_75_eff.nil?
        effectiveness_inputs['Latent Heating'][1.0] = latent_heating_100_eff.to_f unless latent_heating_100_eff.nil?
        effectiveness_inputs['Sensible Cooling'][0.75] = sensible_cooling_75_eff.to_f unless sensible_cooling_75_eff.nil?
        effectiveness_inputs['Sensible Cooling'][1.0] = sensible_cooling_100_eff.to_f unless sensible_cooling_100_eff.nil?
        effectiveness_inputs['Latent Cooling'][0.75] = latent_cooling_75_eff.to_f unless latent_cooling_75_eff.nil?
        effectiveness_inputs['Latent Cooling'][1.0] = latent_cooling_100_eff.to_f unless latent_cooling_100_eff.nil?

        if effectiveness_inputs.values.all?(&:empty?)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Hvac', 'Creating HX with historical effectiveness curves')
          defaults = true
        else
          defaults = false
        end

        OpenstudioStandards::HVAC.heat_exchanger_air_to_air_set_effectiveness_values(hx, defaults: defaults, values: effectiveness_inputs)
      end

      return hx
    end

    # creates LookupTable objects to define effectiveness of HeatExchangerAirToAirSensibleAndLatent objects
    #
    # @param hx [<OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent>] OpenStudio HX object to update
    # @param type [String] type of curve to create. one of 'Sensible Heating', 'Latent Heating, 'Sensible Cooling', 'Latent Cooling'
    # @param values_hash [Hash{Float=>Float}] user_input flow decimal fraction => effectiveness decimal fraction pairs, e.g. {0.75 => 0.81, 1.0 => 0.76}
    # @return [<OpenStudio::Model::TableLookup>] lookup table object
    def self.create_hx_effectiveness_table(hx, type, values_hash)
      # validate inputs
      types = ['Sensible Heating', 'Latent Heating', 'Sensible Cooling', 'Latent Cooling']
      unless types.include? type
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Hvac', "#{__method__} requires effectiveness type as one of #{types}")
        return false
      end

      def self.validate_effectiveness_hash(values_hash)
        values_hash.all? do |key, value|
          key.is_a?(Float) && value.is_a?(Float) && key.between?(0.0, 1.0) && value.between?(0.0, 1.0)
        end
      end

      if !validate_effectiveness_hash(values_hash)
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Hvac', "#{__method__} require values_hash to have keys and values between 0.0 and 1.0: #{values_hash}")
        return false
      end

      # look for existing curve
      type_a = type.split
      method_name = "#{type_a[0].downcase}Effectivenessof#{type_a[1]}AirFlowCurve"

      # use existing independent variable object if found and matches inputs
      iv = nil
      curve = OpenStudio::Model::OptionalTableLookup.new
      if hx.send(method_name).is_initialized
        curve = hx.send(method_name).get.to_TableLookup.get
        iv_existing = curve.independentVariables.first
        if values_hash.keys.sort == iv_existing.values.sort
          iv = iv_existing
        end
      end

      # otherwise create new independent variable
      if iv.nil?
        iv = OpenStudio::Model::TableIndependentVariable.new(hx.model)
        iv.setName("#{hx.name.get}_#{type.gsub(' ', '')}_IndependentVariable")
        iv.setInterpolationMethod('Linear')
        iv.setExtrapolationMethod('Linear')
        iv.setMinimumValue(0.0)
        iv.setMaximumValue(10.0)
        iv.setUnitType('Dimensionless')
        values_hash.keys.sort.each { |k| iv.addValue(k) }
      end

      # create new lookup table
      t = OpenStudio::Model::TableLookup.new(hx.model)
      t.setName("#{hx.name.get}_#{type.gsub(/ible|ent|ing|\s/, '')}Eff")
      t.addIndependentVariable(iv)
      t.setNormalizationMethod('DivisorOnly')
      t.setMinimumOutput(0.0)
      t.setMaximumOutput(10.0)
      t.setOutputUnitType('Dimensionless')
      values = values_hash.sort.map { |a| a[1] }
      # protect against setting normalization divisor to zero for zero effectiveness
      values[-1].zero? ? t.setNormalizationDivisor(1) : t.setNormalizationDivisor(values[-1])
      values.each { |v| t.addOutputValue(v) }

      # remove curve if found
      curve.remove if curve.is_initialized

      return t
    end
  end
end
