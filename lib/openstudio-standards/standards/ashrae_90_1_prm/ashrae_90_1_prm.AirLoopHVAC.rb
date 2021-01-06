class ASHRAE901PRM < Standard
  # @!group AirLoopHVAC

  # Determine if the system is a multizone VAV system
  #
  # @return [Bool] Returns true if required, false if not.
  def air_loop_hvac_multizone_vav_system?(air_loop_hvac)
    return true if air_loop_hvac.name.to_s.include?("Sys5") || air_loop_hvac.name.to_s.include?("Sys6") || air_loop_hvac.name.to_s.include?("Sys7") || air_loop_hvac.name.to_s.include?("Sys8")

    return false
  end

end
