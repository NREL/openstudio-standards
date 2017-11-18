class ASHRAE9012007 < ASHRAE901
  # @!group Model

  # Determines which system number is used
  # for the baseline system.
  # @return [String] the system number: 1_or_2, 3_or_4,
  # 5_or_6, 7_or_8, 9_or_10
  def model_prm_baseline_system_number(model, climate_zone, area_type, fuel_type, area_ft2, num_stories, custom)
    sys_num = nil

    # TODO: refactor: figure out this weird template switching case
    # For a custom scenario, use the lookup method from
    # a different standard instead of the specified standard.
    # if custom == "90.1-2007 with addenda dn"
    # OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', 'Custom; per Addenda dn of 90.1-2007, System 10 and 11 (same as system 9 and 10 in 90.1-2010) will be used for heated only space.')
    # template = '90.1-2010'
    # sys_num = model_prm_baseline_system_number(model, climate_zone, area_type, fuel_type, area_ft2, num_stories, custom)
    # return sys_num
    # end

    # Set the area limit
    limit_ft2 = 25_000

    # Warn about heated only
    if area_type == 'heatedonly'
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Per Table G3.1.10.d, '(In the proposed building) Where no cooling system exists or no cooling system has been specified, the cooling system shall be identical to the system modeled in the baseline building design.' This requires that you go back and add a cooling system to the proposed model.  This code cannot do that for you; you must do it manually.")
    end

    case area_type
    when 'residential'
      sys_num = '1_or_2'
    when 'nonresidential', 'heatedonly'
      # nonresidential and 3 floors or less and <25,000 ft2
      if num_stories <= 3 && area_ft2 < limit_ft2
        sys_num = '3_or_4'
      # nonresidential and 4 or 5 floors or 5 floors or less and 25,000 ft2 to 150,000 ft2
      elsif ((num_stories == 4 || num_stories == 5) && area_ft2 < limit_ft2) || (num_stories <= 5 && (area_ft2 >= limit_ft2 && area_ft2 <= 150_000))
        sys_num = '5_or_6'
      # nonresidential and more than 5 floors or >150,000 ft2
      elsif num_stories >= 5 || area_ft2 > 150_000
        sys_num = '7_or_8'
      end
    end

    return sys_num
  end
end
