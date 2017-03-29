
# Extend the class
class OpenStudio::Model::Model
  def run_simulation_and_log_errors(run_dir = "#{Dir.pwd}/Run")
    # Make the directory if it doesn't exist
    unless Dir.exist?(run_dir)
      FileUtils.mkdir_p(run_dir)
    end

    # Save the model to energyplus idf
    idf_name = 'in.idf'
    osm_name = 'in.osm'
    osw_name = 'in.osw'
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Model', "Starting simulation here: #{run_dir}.")
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Running simulation #{run_dir}.")
    forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
    idf = forward_translator.translateModel(self)
    idf_path = OpenStudio::Path.new("#{run_dir}/#{idf_name}")
    osm_path = OpenStudio::Path.new("#{run_dir}/#{osm_name}")
    osw_path = OpenStudio::Path.new("#{run_dir}/#{osw_name}")
    idf.save(idf_path, true)
    save(osm_path, true)

    # Set up the simulation
    # Find the weather file
    epw_path = get_full_weather_file_path
    if epw_path.empty?
      return false
    end
    epw_path = epw_path.get

    # close current sql file
    resetSqlFile

    # If running on a regular desktop, use RunManager.
    # If running on OpenStudio Server, use WorkFlowMananger
    # to avoid slowdown from the run.
    use_runmanager = true

    begin
      workflow = OpenStudio::WorkflowJSON.new
      use_runmanager = false
    rescue NameError
      use_runmanager = true
    end

    sql_path = nil
    if use_runmanager
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Model', 'Running with RunManager.')

      # Find EnergyPlus
      ep_dir = OpenStudio.getEnergyPlusDirectory
      ep_path = OpenStudio.getEnergyPlusExecutable
      ep_tool = OpenStudio::Runmanager::ToolInfo.new(ep_path)
      idd_path = OpenStudio::Path.new(ep_dir.to_s + '/Energy+.idd')
      output_path = OpenStudio::Path.new("#{run_dir}/")

      # Make a run manager and queue up the run
      run_manager_db_path = OpenStudio::Path.new("#{run_dir}/run.db")
      # HACK: workaround for Mac with Qt 5.4, need to address in the future.
      OpenStudio::Application.instance.application(false)
      run_manager = OpenStudio::Runmanager::RunManager.new(run_manager_db_path, true, false, false, false)
      job = OpenStudio::Runmanager::JobFactory.createEnergyPlusJob(ep_tool,
                                                                   idd_path,
                                                                   idf_path,
                                                                   epw_path,
                                                                   output_path)

      run_manager.enqueue(job, true)

      # Start the run and wait for it to finish.
      while run_manager.workPending
        sleep 1
        OpenStudio::Application.instance.processEvents
      end

      sql_path = OpenStudio::Path.new("#{run_dir}/EnergyPlus/eplusout.sql")

      OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished run.')

    else # method to running simulation within measure using OpenStudio 2.x WorkflowJSON

      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Model', 'Running with OS 2.x WorkflowJSON.')

      # Copy the weather file to this directory
      epw_name = 'in.epw'
      begin
        FileUtils.copy(epw_path.to_s, "#{run_dir}/#{epw_name}")
      rescue
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Due to limitations on Windows file path lengths, this measure won't work unless your project is located in a directory whose filepath is less than 90 characters long, including slashes.")
        return false
      end

      workflow.setSeedFile(osm_name)
      workflow.setWeatherFile(epw_name)
      workflow.saveAs(File.absolute_path(osw_path.to_s))

      cli_path = OpenStudio.getOpenStudioCLI
      cmd = "\"#{cli_path}\" run -w \"#{osw_path}\""
      puts cmd
      system(cmd)

      OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished run.')

      sql_path = OpenStudio::Path.new("#{run_dir}/run/eplusout.sql")

    end

    # TODO: Delete the eplustbl.htm and other files created
    # by the run for cleanliness.

    if OpenStudio.exists(sql_path)
      sql = OpenStudio::SqlFile.new(sql_path)
      # Check to make sure the sql file is readable,
      # which won't be true if EnergyPlus crashed during simulation.
      unless sql.connectionOpen
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "The run failed, cannot create model.  Look at the eplusout.err file in #{File.dirname(sql_path.to_s)} to see the cause.")
        return false
      end
      # Attach the sql file from the run to the model
      setSqlFile(sql)
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Results for the run couldn't be found here: #{sql_path}.")
      return false
    end

    # Report severe errors in the run
    error_query = "SELECT ErrorMessage
        FROM Errors
        WHERE ErrorType in(1,2)"
    errs = sqlFile.get.execAndReturnVectorOfString(error_query)
    if errs.is_initialized
      errs = errs.get
    end

    # Check that the run completed
    completed_query = 'SELECT Completed FROM Simulations'
    completed = sqlFile.get.execAndReturnFirstDouble(completed_query)
    if completed.is_initialized
      completed = completed.get
      if completed.zero?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "The run did not finish and had following errors: #{errs.join('\n')}")
        return false
      end
    end

    # Check that the run completed with no severe errors
    completed_successfully_query = 'SELECT CompletedSuccessfully FROM Simulations'
    completed_successfully = sqlFile.get.execAndReturnFirstDouble(completed_successfully_query)
    if completed_successfully.is_initialized
      completed_successfully = completed_successfully.get
      if completed_successfully.zero?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "The run failed with the following severe or fatal errors: #{errs.join('\n')}")
        return false
      end
    end

    # Log any severe errors that did not cause simulation to fail
    unless errs.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "The run completed but had the following severe errors: #{errs.join('\n')}")
    end

    return true
  end
end
