require 'json'
class LPT
  def initialize(jobs,procs)
    @jobs = jobs
    @processors = procs
  end

  def run()
    scheduled_jobs, loads = lpt_algorithm()
    return [scheduled_jobs, loads]
  end

  def lpt_algorithm
    sorted_jobs = @jobs.sort_by {|_key, value| value['total']}.reverse

    # puts JSON.pretty_generate(sorted_jobs)

    loads = []
    scheduled_jobs = []

    for i in 1..@processors do
      loads << 0
      scheduled_jobs << []
    end

    sorted_jobs.each {|file_name, timing|
      load =  timing['total']
      minloadproc_indx = minloadproc(loads)
      scheduled_jobs[minloadproc_indx] << file_name
      loads[minloadproc_indx] += load
    }

    return [scheduled_jobs, loads]
  end

  def minloadproc(loads)
    return loads.each_with_index.min[1] # return index of minimum load
  end
end
