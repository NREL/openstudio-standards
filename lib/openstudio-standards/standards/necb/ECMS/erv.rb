class ECMS
  # This method will add a skeleton erv to all air loops if requested.
  def apply_erv_ecm(model:, erv_package: nil)
    # If erv is nil.. do nothing.
    return if erv_package.nil? || erv_package == 'none' || erv_package == 'NECB_Default'
    erv_info = @standards_data['tables']['erv']['table'].detect { |item| item['erv_name'] == erv_package }
    # Check if we were able to get data.
    if erv_info.nil?
      # Get name of ERVs in erv.json.
      valid = @standards_data['tables']['erv']['table'].map{|x| x['erv_name']}
      #tell user.
      raise("ERV package name #{erv_package} does not exist. must be #{valid} /n Stopping.")
    end
    if erv_info['application'] ==  "Add_ERVs_To_All_Airloops"
      #remove all existing ERVs
      model.getHeatExchangerAirToAirSensibleAndLatents.each { |erv| erv.remove}
      #add ervs
      model.getAirLoopHVACs.each do |air_loop|
        # Adds default erv to all air_loops. This will be changed in the set efficiency methods.
        air_loop_hvac_apply_energy_recovery_ventilator(air_loop, nil)
      end
    end
  end

  # This method will set the properties of the ERV that was added above. Must be run after the standard efficiency is complete as this will overwrite
  # those values. See data/erv.json to view/add different erv packages.
  def apply_erv_ecm_efficiency(model:, erv_package: nil)
    # If erv is nil.. do nothing.
    return if erv_package.nil? || erv_package == 'none' || erv_package == 'NECB_Default'
    # This calls the NECB2011 implementation of the method.
    model.getHeatExchangerAirToAirSensibleAndLatents.each { |erv| heat_exchanger_air_to_air_sensible_and_latent_apply_efficiency(erv, erv_package) }
  end
end