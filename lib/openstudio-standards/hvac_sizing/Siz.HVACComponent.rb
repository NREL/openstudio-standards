
###### IMPORTANT NOTE ######
# These methods should be done via extension to OS model objects
# directly in the C++ SDK.
###### IMPORTANT NOTE ######

class OpenStudio::Model::HVACComponent
  # Returns the number of individual pieces of equipment
  # represented by a particular HVAC component.  Pulls from
  # the additionalProperties object attached to the component.
  # This can be used during the application of efficiency
  # levels that are based on component capacities, flowrates, etc.
  # @return [Integer] the number of components, 1 if not set
  def component_quantity
    addl_props = self.additionalProperties
    if addl_props.getFeatureAsInteger('component_quantity').is_initialized
      comp_qty = addl_props.getFeatureAsInteger('component_quantity').get
    else
      comp_qty = 1
    end

    return comp_qty
  end

  # Sets the number of individual pieces of equipment
  # represented by a particular HVAC component.  Uses the
  # additionalProperties object attached to the component.
  # This can be used during the application of efficiency
  # levels that are based on component capacities, flowrates, etc.
  # @param comp_qty [Integer] the number of individual pieces of equipment
  # represented by this HVAC component
  # @return [Bool] true if successful, false if not
  def set_component_quantity(comp_qty)
    return self.additionalProperties.setFeature('component_quantity', comp_qty)
  end
end
