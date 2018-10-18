# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent
  # Sets the minimum effectiveness of the heat exchanger per
  # the standard.
  def apply_efficiency(template)
    # Assumed to be sensible and latent at all flow
    min_effct = case template
                when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
                  0.5
                when 'NREL ZNE Ready 2017'
                  0.7
                else
                  0.5
                end

   setSensibleEffectivenessat100HeatingAirFlow(min_effct)
   setLatentEffectivenessat100HeatingAirFlow(min_effct)
   setSensibleEffectivenessat75HeatingAirFlow(min_effct)
   setLatentEffectivenessat75HeatingAirFlow(min_effct)
   setSensibleEffectivenessat100CoolingAirFlow(min_effct)
   setLatentEffectivenessat100CoolingAirFlow(min_effct)
   setSensibleEffectivenessat75CoolingAirFlow(min_effct)
   setLatentEffectivenessat75CoolingAirFlow(min_effct)

   OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.HeatExchangerAirToAirSensibleAndLatent', "For #{name}: Set sensible and latent effectiveness to #{(min_effct * 100).round}%.")

    return true
  end
end
