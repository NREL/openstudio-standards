
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::ThermalZone

  # Calculates the zone outdoor airflow requirement (Voz)
  # based on the inputs in the DesignSpecification:OutdoorAir obects
  # in all spaces in the zone.
  #
  # @return [Double] the zone outdoor air flow rate
  #   @units cubic meters per second (m^3/s)
  def outdoor_airflow_rate

    tot_oa_flow_rate = 0.0
  
    spaces = self.spaces.sort

    sum_floor_area = 0.0
    sum_number_of_people = 0.0
    sum_volume = 0.0

    # Variables for merging outdoor air
    any_max_oa_method = false
    sum_oa_for_people = 0.0
    sum_oa_for_floor_area = 0.0
    sum_oa_rate = 0.0
    sum_oa_for_volume = 0.0

    # Find common variables for the new space
    spaces.each do |space|

      floor_area = space.floorArea
      sum_floor_area += floor_area

      number_of_people = space.numberOfPeople
      sum_number_of_people += number_of_people

      volume = space.volume
      sum_volume += volume

      dsn_oa = space.designSpecificationOutdoorAir
      next if dsn_oa.empty?
      dsn_oa = dsn_oa.get
      
      # compute outdoor air rates in case we need them
      oa_for_people = number_of_people * dsn_oa.outdoorAirFlowperPerson
      oa_for_floor_area = floorArea * dsn_oa.outdoorAirFlowperFloorArea
      oa_rate = dsn_oa.outdoorAirFlowRate
      oa_for_volume = volume * dsn_oa.outdoorAirFlowAirChangesperHour

      # First check if this space uses the Maximum method and other spaces do not
      if dsn_oa.outdoorAirMethod == 'Maximum'
        sum_oa_rate += [oa_for_people, oa_for_floor_area, oa_rate, oa_for_volume].max
      elsif dsn_oa.outdoorAirMethod == 'Sum'
        sum_oa_for_people += oa_for_people
        sum_oa_for_floor_area += oa_for_floor_area
        sum_oa_rate += oa_rate
        sum_oa_for_volume += oa_for_volume
      end

    end

    tot_oa_flow_rate += sum_oa_for_people
    tot_oa_flow_rate += sum_oa_for_floor_area
    tot_oa_flow_rate += sum_oa_rate
    tot_oa_flow_rate += sum_oa_for_volume
    
    # Convert to cfm
    tot_oa_flow_rate_cfm = OpenStudio.convert(tot_oa_flow_rate,'m^3/s','cfm').get
    
    OpenStudio::logFree(OpenStudio::Debug, "openstudio.Standards.Model", "For #{self.name}, design min OA = #{tot_oa_flow_rate_cfm.round} cfm.")
    
    return tot_oa_flow_rate

  end

  # Calculates the zone outdoor airflow requirement and
  # divides by the zone area.
  #
  # @return [Double] the zone outdoor air flow rate per area
  #   @units cubic meters per second (m^3/s)
  def outdoor_airflow_rate_per_area()

    tot_oa_flow_rate_per_area = 0.0

    # Find total area of the zone
    sum_floor_area = 0.0
    self.spaces.sort.each do |space|
      sum_floor_area += space.floorArea
    end

    # Get the OA flow rate
    tot_oa_flow_rate = outdoor_airflow_rate
    
    # Calculate the per-area value
    tot_oa_flow_rate_per_area = tot_oa_flow_rate / sum_floor_area

    OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.Model", "For #{self.name}, OA per area = #{tot_oa_flow_rate_per_area.round(8)} m^3/s*m^2.")

    return tot_oa_flow_rate_per_area

  end
  
end
