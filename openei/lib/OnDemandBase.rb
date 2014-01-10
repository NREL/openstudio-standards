# <basepath>/api/ondemand/endpoint?arguments=a|b,c|d&passthru=1&debug=1

class OnDemandBase
  attr_accessor :args
  attr_accessor :opts

  #arguments
  #passthru
  #debug


  def initialize(argv)
    @exit_code = 0
    @passthru = false
    @debug = false

    tmp = argv[0]
    if !tmp.nil?
      @args = JSON.parse(tmp)
    end

    tmp = argv[1]
    if !tmp.nil?
      @opts = JSON.parse(tmp)

      # Parse the "option" arguments to specific member
      # variables.
      if @opts["passthru"] == "1"
        @passthru = true
      end
      if @opts["debug"] == "1"
        @debug = true
      end

    end
  end

  def debug?
    @debug
  end

  def passthru?
    @passthru
  end

  def invalidate()
    @exit_code = 1
  end

  def finalize()
    "STATUS:#{@exit_code}"
  end
end