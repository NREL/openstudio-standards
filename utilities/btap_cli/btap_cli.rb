require_relative './libs.rb'
@argument = {}
@options = {}
# Default folders if not using s3
@options[:input_folder] = File.join(__dir__, 'input')
@options[:output_folder] = File.join(__dir__, 'output')
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} -s NAME id ..."
  opts.on('--help', 'Display this screen') do
    puts opts
    exit
  end
  opts.on('--input_path NAME', "Default is #{@options[:input_folder]}") { |s| @options[:input_folder] = s }
  opts.on('--output_path NAME', "Default is #{@options[:output_folder]} ") { |s| @options[:output_folder] = s }
end
optparse.parse!
BTAPDatapoint.new(input_folder: @options[:input_folder],
                  output_folder: @options[:output_folder],
                  input_folder_cache: File.join(__dir__, 'input_cache'))

# Example command using s3 urls for input/output
# bundle exec ruby utilities/btap_cli/btap_cli.rb --input_path 's3://834599497928/test_analysis_new/test_analysis_id/input/02ade4c9-5c11-437b-9664-b28a8d5d9efb' --output_path 's3://834599497928/test_analysis_new/test_analysis_id/output/'
