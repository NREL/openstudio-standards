class ASHRAE9012007 < ASHRAE901
  # Determine what part load efficiency degredation curve should be used for a boiler
  #
  # @param boiler_hot_water [OpenStudio::Model::BoilerHotWater] hot water boiler object
  # @return [String] returns name of the boiler curve to be used, or nil if not applicable
  def boiler_get_eff_fplr(boiler_hot_water)
    return 'Boiler with No Minimum Turndown'
  end
end
