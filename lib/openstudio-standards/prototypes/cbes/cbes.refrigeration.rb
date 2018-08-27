class CBES < Standard
  # @!group refrigeration

  # Determine the latent case credit curve to use
  # for walkins.
  # @todo Should probably use the model_add_refrigeration_walkin
  # and lookups from the spreadsheet instead of hard-coded values.
  def model_walkin_freezer_latent_case_credit_curve(model)
    latent_case_credit_curve_name = 'Single Shelf Horizontal Latent Energy Multiplier_Pre2004'
    return latent_case_credit_curve_name
  end
end
