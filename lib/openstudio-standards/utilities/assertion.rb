# PRM generation custom Error
class PRMError < StandardError
end

# Finds capacity in W
#
# @param bool [Boolean, Object] an object for truthy evaluation
# @param log_dir [String] log file directory
# @param log_msg [String] message add to the log
# @param err_msg [String] message raise the exception
def prm_raise(bool, log_dir, log_msg, err_msg)
  unless bool
    OpenStudio.logFree(OpenStudio::Debug, 'prm.log', log_msg)
    log_messages_to_file_prm("#{log_dir}/prm.log", true)
    raise PRMError, err_msg
  end
end
