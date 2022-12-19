# Additional methods for NECB tests
require 'fileutils'

# Check if two files are identical with some added smarts
# (used in place of simple ruby methods)
def file_compare(expected_results_file:, test_results_file:, msg: "Files do not match", type: nil)
  
  if type == "fred"
  else
    # Open files and compare the line by line. Remove line endings before checking strings (this can be an issue when running in docker).
    same = true
    fe = File.open(expected_results_file, 'rb') 
    ft = File.open(test_results_file, 'rb')
    fe.each.zip(ft.each).each do |le, lt|
      le=le.gsub /(\r$|\n$)/,''
      lt=lt.gsub /(\r$|\n$)/,''
      same = le.eql?(lt)
      break if !same
    end
    assert(same, "#{msg} #{self.class.ancestors[0]}. Compare #{expected_results_file} with #{test_results_file}. File contents differ!")
  end
end