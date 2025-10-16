# Lightweight wrapper around the loaded standards data to avoid huge inspect dumps
# when test failures or exceptions include the standards_data object.
class StandardsDataWrapper
  # Initialize with the underlying data (usually a Hash)
  def initialize(data)
    @data = data
  end

  # Provide a concise inspect that shows the top-level keys and size only
  def inspect
    if @data.respond_to?(:keys)
      keys = @data.keys
      "#<StandardsDataWrapper keys=#{keys.size} sample_keys=#{keys.first(10)}>"
    elsif @data.respond_to?(:size)
      "#<StandardsDataWrapper size=#{@data.size}>"
    else
      "#<StandardsDataWrapper>"
    end
  end

  def to_s
    inspect
  end

  # Delegate missing methods to the underlying data object so behaviour remains the same
  def method_missing(m, *args, &block)
    if @data.respond_to?(m)
      @data.public_send(m, *args, &block)
    else
      super
    end
  end

  def respond_to_missing?(m, include_private = false)
    @data.respond_to?(m) || super
  end
end
