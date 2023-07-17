# PRM generation custom Error
class PRMError < StandardError
end

# PRM assertion method
# Raise assertion if the test (bool) is failed
#
# Before raise the exception, the method will generate the prm.log for debugging
# @param bool [Boolean, Object] an object for truthy evaluation
# @param log_dir [String] log file directory
# @param log_msg [String] message add to the log
# @param err_msg [String] message raise the exception
def prm_raise(bool, log_dir, err_msg)
  unless bool
    # OpenStudio.logFree(OpenStudio::Debug, 'prm.log', log_msg)
    log_messages_to_file_prm("#{log_dir}/prm.log", true)
    raise PRMError, "#{err_msg} - Check debug log at #{log_dir}/prm.log for more information"
  end
end

# PRM reading function reads user data from a hash map.
# Handles key existence, value is nil and value string is empty
# @param user_data [Hash] a hash contains a user data
# @param key [String] key string
# @param default [Object] values assigned if the data is not available.
def prm_read_user_data(user_data, key, default = nil)
  return user_data.key?(key) && user_data[key] != nil && !user_data[key].to_s.empty? ? user_data[key] : default
end

# This is a PRM handler function handles the .get from an optional object
# The handler will try to access the OpenStudio Object data key
# And do it recursively until all the keys have been checked and final object get or raise exception
# for non_initialized objects.
# @param component [OpenStudio] an OpenStudio object
# @param log_dir [string] directory to save the log
# @param data_key [string] The data key to retrieve the data from the OpenStudio object
# @param remaining_keys [str] Any additional keys in the path
# @return the OpenStudio Object or exception raise
def prm_get_optional_handler(component, log_dir, data_key, *remaining_keys)
  target_data = component.send(data_key)
  OpenStudio.logFree(OpenStudio::Error, 'prm.log', "#{component.name.get} does not contain the required data key #{data_key}. Retrieve the data cause failure.")

  prm_raise(target_data.is_initialized,
            log_dir,
            "Failed to retrieve data from #{component.name.get}"
            )
  target_data_get = target_data.get
  return remaining_keys.length == 0 ? target_data_get : prm_get_optional_handler(target_data_get, log_dir, remaining_keys[0], *remaining_keys[1...])
end

# PRM get an additional property from an OpenStudio object as a boolean,
# if no such additional property, then return default value.
# @param component [OpenStudio object] the component to get the additional property from
# @param key [String] key string
# @param default [Boolean] the default to return when there is no matching key
def get_additional_property_as_boolean(component, key, default = false)
  value = default
  if component.additionalProperties.getFeatureAsBoolean(key).is_initialized
    value = component.additionalProperties.getFeatureAsBoolean(key).get
  else
    OpenStudio.logFree(OpenStudio::Warn, 'prm.log', "Cannot find the #{key} in component: #{component.name.get}, default value #{default} is used.")
  end
  return value
end

# PRM get an additional property from an OpenStudio object as a double,
# if no such additional property, then return default value.
# @param component [OpenStudio object] the component to get the additional property from
# @param key [String] key string
# @param default [Boolean] the default to return when there is no matching key
def get_additional_property_as_double(component, key, default = 0.0)
  value = default
  if component.additionalProperties.getFeatureAsDouble(key).is_initialized
    value = component.additionalProperties.getFeatureAsDouble(key).get
  else
    OpenStudio.logFree(OpenStudio::Warn, 'prm.log', "Cannot find the #{key} in component: #{component.name.get}, default value #{default} is used.")
  end
  return value
end

# PRM get an additional property from an OpenStudio object as a string,
# if no such additional property, then return default value.
# @param component [OpenStudio object] the component to get the additional property from
# @param key [String] key string
# @param default [Boolean] the default to return when there is no matching key
def get_additional_property_as_string(component, key, default = "")
  value = default
  if component.additionalProperties.getFeatureAsString(key).is_initialized
    value = component.additionalProperties.getFeatureAsString(key).get
  else
    OpenStudio.logFree(OpenStudio::Warn, 'prm.log', "Cannot find the #{key} in component: #{component.name.get}, default value #{default} is used.")
  end
  return value
end
