
# Reopen the OpenStudio class to add methods to apply standards to this object
class StandardsModel < OpenStudio::Model::Model
  include Pump

  # Takes the total rated flow rate and returns per-pump values
  # as an optional double
  # @return [OptionalDouble] the total rated flow rate per pump
  def headered_pumps_constant_speed_autosizedRatedFlowRate(headered_pumps_constant_speed)
    result = OpenStudio::OptionalDouble.new
    total_rated_flow_rate = autosizedTotalRatedFlowRate
    if total_rated_flow_rate.is_initialized
      per_pump_rated_flow_rate = total_rated_flow_rate.get / numberofPumpsinBank
      result = OpenStudio::OptionalDouble.new(per_pump_rated_flow_rate)
    end

    return result
  end

  # Takes the total rated flow rate and returns per-pump values
  # as an optional double
  # @return [OptionalDouble] the total rated flow rate per pump
  def headered_pumps_constant_speed_ratedFlowRate(headered_pumps_constant_speed)
    result = OpenStudio::OptionalDouble.new
    total_rated_flow_rate = totalRatedFlowRate
    if total_rated_flow_rate.is_initialized
      per_pump_rated_flow_rate = total_rated_flow_rate.get / numberofPumpsinBank
      result = OpenStudio::OptionalDouble.new(per_pump_rated_flow_rate)
    end

    return result
  end
end
