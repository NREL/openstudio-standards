module OpenstudioStandards
  # The HVAC module provides methods create, modify, and get information about HVAC systems in the model
  module HVAC
    #@!group Component:Modify
    # Methods to modify HVAC Component objects

    # Applies historical default or user-input effectiveness values to a HeatExchanger:AirToAir:SensibleAndLatent object
    #
    # @param hx [<OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent>] OpenStudio HX object to update
    # @param defaults [Boolean] flag to apply historical default curves
    # @param values [Hash{String=>Hash{Float=>Float}}] user-input effectiveness values, where keys are one of
    #   'Sensible Heating', 'Latent Heating, 'Sensible Cooling', 'Latent Cooling'
    #   and value is a hash of {flow decimal fraction => effectivess decimal fraction}, e.g. {0.75 => 0.81, 1.0 => 0.76}
    # @return [<OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent>] modified OpenStudio HX object
    def self.heat_exchanger_air_to_air_set_effectiveness_values(hx, defaults: false, values: nil)
      if defaults
        hx.assignHistoricalEffectivenessCurves
        if values.nil?
          return hx
        end
      elsif values.nil?
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Hvac', "#{__method__} called with defaults=false and no values provided. #{hx.name.get} will not be modified")
        return hx
      end

      values.each do |type, values_hash|
        # ensure values_hash has one value at 100% flow
        unless values_hash.key?(1.0)
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Hvac', "Effectiveness Values for #{type} do not include 100% flow effectivenss. Cannot set effectiveness curves")
          return false
        end

        lookup_table = OpenstudioStandards::HVAC.create_hx_effectiveness_table(hx, type, values_hash)
        type_a = type.split(' ')
        hx.send("set#{type_a[0]}Effectivenessat100#{type_a[1]}AirFlow",values_hash[1.0])
        hx.send("set#{type_a[0]}Effectivenessof#{type_a[1]}AirFlowCurve", lookup_table)
      end

      return hx
    end


  end

end
