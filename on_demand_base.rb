

# <basepath>/api/ondemand/endpoint?arguments=a|b,c|d&passthru=1&debug=1

class OnDemandBase
  attr_accessor :passthrough
  #arguments
  #passthru
  #debug


  def initialize(args)
    ondemand_arguments = ARGV[0]
    ondemand_options = ARGV[1]
    passthrough = ondemand_options[passthru]
    passthru = ARGV[1]



    args_hash = JSON.parse(vals)

  end
  def debug?

  end



end