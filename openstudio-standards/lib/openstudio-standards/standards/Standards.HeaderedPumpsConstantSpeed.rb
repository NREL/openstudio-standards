
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::HeaderedPumpsConstantSpeed
  include Pump

  # Takes the total rated flow rate and returns per-pump values
  # as an optional double
  # @return [OptionalDouble] the total rated flow rate per pump
  def autosizedRatedFlowRate
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
  def ratedFlowRate
    result = OpenStudio::OptionalDouble.new
    total_rated_flow_rate = totalRatedFlowRate
    if total_rated_flow_rate.is_initialized
      per_pump_rated_flow_rate = total_rated_flow_rate.get / numberofPumpsinBank
      result = OpenStudio::OptionalDouble.new(per_pump_rated_flow_rate)
    end

    return result
  end
end
