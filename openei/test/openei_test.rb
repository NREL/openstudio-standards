require "test/unit"
require "pathname"
require "#{Pathname.new(__FILE__) + '../../lib/OpenEI'}"
require "#{Pathname.new(__FILE__) + '../../lib/OpenEIRate'}"


class OpenEIZipCode < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  #def test_zipcode_check
  #  path = Pathname.new(__FILE__)
  #  puts path
  #
  #  file = File.open(path + "../lib/zipcodes.csv", 'r')
  #  cnt = 0
  #  file.readlines.each do |line|
  #    if cnt % 1000 == 0
  #      open_ei = OpenEI.new(line)
  #      puts open_ei.to_csv
  #      assert(open_ei.rates.empty?, "no rates found, check search criteria")
  #    end
  #    cnt += 1
  #  end
  #end

  def test_list_rates
    path = Pathname.new(__FILE__)
    puts path

    file = File.open(path + "../lib/zipcodes.csv", 'r')
    cnt = 0
    tries = 0 # number of rows tried
    name_fails = 0 # number of name failures
    num_rates = Hash.new # map of number of rates to count (e.g. histogram)
    file.readlines.each do |line|
      if cnt % 1000 == 0
        tries += 1
        open_ei = OpenEI.new(line)
        puts open_ei.to_csv
        if open_ei.utility_name.nil? or open_ei.utility_name.empty?
          name_fails += 1
        end
        n = open_ei.rates.size
        num_rates[n] = 0 if num_rates[n].nil?
        num_rates[n] = num_rates[n] + 1
      end
      cnt += 1
    end
    
    puts "tries = #{tries}"
    puts "name_fails = #{name_fails}"
    for n in 0..num_rates.keys.max
      count = num_rates[n]
      count = 0 if count.nil?
      puts "#{count} samples have #{n} rates"
    end
  end

end