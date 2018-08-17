require 'json'
# Largest Processing Time algorithm
# https://en.wikipedia.org/wiki/Multiprocessor_scheduling#Algorithms

# similar solution https://github.com/sanathkumarbs/longest-processing-time-algorithm-lpt/blob/master/lpt.py
class LPT
  # Jobs hash format. The key is the line from the circleCi text file
  # total is the number of seconds to run the job specified by the key
  # any other keys are not used
  # {
  #   "ci_test_files/doe_test_bldg_large_hotel-90.1_2010-ashrae_169_2006_2_a.rb": {
  #       "total": 44
  #   },
  #       "ci_test_files/doe_test_add_hvac_systems_vav_reheat-natural_gas-natural_gas-electricity.rb": {
  #       "total": 99
  #   },
  #   .........
  # }
  # procs: Integer i.e. Number of cpus
  def initialize(jobs,procs)
    @jobs = jobs
    @processors = procs
  end

  def run()
    scheduled_jobs, loads = lpt_algorithm() # runs the algorithn
    return [scheduled_jobs, loads] # returns the results
  end

  def lpt_algorithm
    # sort jobs from large to small
    sorted_jobs = @jobs.sort_by {|_key, value| value['total']}.reverse
    # puts JSON.pretty_generate(sorted_jobs)

    loads = [] # stores an array of total times per each cpu
    scheduled_jobs = [] # # stores an array of jobs per each cpu

    for i in 1..@processors do
      loads << 0 # set default loads to 0
      scheduled_jobs << [] # set default jobs for each processor as an empty array
    end

    sorted_jobs.each {|file_name, timing|
      load =  timing['total'] # stores the total time it takes for each job to complete
      minloadproc_indx = loads.each_with_index.min[1] # gets the processor with the minimum load
      scheduled_jobs[minloadproc_indx] << file_name # adds the current job to the processor with minimum load
      loads[minloadproc_indx] += load # adds the load of the job to the cpu with the lowest load
    }

    return [scheduled_jobs, loads]
  end
end
