# Taken from: https://github.com/rubyworks/facets/blob/master/lib/core/facets/array/mode.rb#L14
class Array
  # Get most common value from an array
  # If there is a tie for most common, an array is returned of the tied values
  def mode
    max = 0
    c = Hash.new 0
    each {|x| cc = c[x] += 1; max = cc if cc > max}
    c.select {|k,v| v == max}.map {|k,v| k}
  end
end