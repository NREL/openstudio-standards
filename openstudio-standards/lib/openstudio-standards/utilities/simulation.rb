
# Extend the class
class OpenStudio::Model::Model
  
  def run_simulation_and_log_errors(run_dir = "#{Dir.pwd}/Run")
    
    # Make the directory if it doesn't exist
    if !Dir.exists?(run_dir)
      Dir.mkdir(run_dir)
    end
    
    # Save the model to energyplus idf
    idf_name = 'in.idf'
    osm_name = 'in.osm'
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "Starting simulation here: #{run_dir}.")
    forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
    idf = forward_translator.translateModel(self)
    idf_path = OpenStudio::Path.new("#{run_dir}/#{idf_name}")  
    osm_path = OpenStudio::Path.new("#{run_dir}/#{osm_name}")
    idf.save(idf_path,true)
    self.save(osm_path,true)
    
    # Set up the simulation
    # Find the weather file
    epw_path = self.get_full_weather_file_path
    if epw_path.empty?
      return false
    end
    epw_path = epw_path.get
    
    # If running on a regular desktop, use RunManager.
    # If running on OpenStudio Server, use WorkFlowMananger
    # to avoid slowdown from the run.   
    use_runmanager = true
    
    begin
      require 'openstudio-workflow'
      use_runmanager = false
    rescue LoadError
      use_runmanager = true
    end

    sql_path = nil
    if use_runmanager
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Running with RunManager.')

      # Find EnergyPlus
      ep_dir = OpenStudio.getEnergyPlusDirectory
      ep_path = OpenStudio.getEnergyPlusExecutable
      ep_tool = OpenStudio::Runmanager::ToolInfo.new(ep_path)
      idd_path = OpenStudio::Path.new(ep_dir.to_s + "/Energy+.idd")
      output_path = OpenStudio::Path.new("#{run_dir}/")
      
      # Make a run manager and queue up the run
      run_manager_db_path = OpenStudio::Path.new("#{run_dir}/run.db")
      # HACK: workaround for Mac with Qt 5.4, need to address in the future.
      OpenStudio::Application::instance().application(false)
      run_manager = OpenStudio::Runmanager::RunManager.new(run_manager_db_path, true, false, false, false)
      job = OpenStudio::Runmanager::JobFactory::createEnergyPlusJob(ep_tool,
                                                                   idd_path,
                                                                   idf_path,
                                                                   epw_path,
                                                                   output_path)
      
      run_manager.enqueue(job, true)

      # Start the run and wait for it to finish.
      while run_manager.workPending
        sleep 1
        OpenStudio::Application::instance.processEvents
      end
        
      sql_path = OpenStudio::Path.new("#{run_dir}/EnergyPlus/eplusout.sql")
      
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished run.')
      
    elsif OpenStudio::Workflow::VERSION >= '1.0.0' # Use the OS 2.0 openstudio-workflow gem
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Running with OS 2.0 openstudio-workflow gem.')

      # Write OSW file for the simulation
      require 'JSON'
      osw_hash = {
        run_dir: Dir.pwd,
        seed_model: File.absolute_path(idf_path.to_s),
        weather_file: File.absolute_path(epw_path.to_s),
        steps: []
      }
      osw_path = File.join(Dir.pwd, 'workflow.osw')
      File.open(osw_path, 'wb') { |f| f << JSON.pretty_generate(osw_hash) }

      # Create local adapters
      adapter_options = {workflow_filename: File.basename(osw_path), output_directory: File.join(Dir.pwd, 'run')}
      input_adapter = OpenStudio::Workflow.load_input_adapter 'local', adapter_options
      output_adapter = OpenStudio::Workflow.load_output_adapter 'local', adapter_options

      # Run workflow.osw
      run_options = Hash.new
      run_options[:jobs] = [
        { state: :queued, next_state: :initialization, options: { initial: true } },
        { state: :initialization, next_state: :preprocess, job: :RunInitialization,
          file: './jobs/run_initialization.rb', options: {} },
        { state: :preprocess, next_state: :simulation, job: :RunPreprocess,
          file: './jobs/run_preprocess.rb' , options: {} },
        { state: :simulation, next_state: :finished, job: :RunEnergyPlus,
          file: './jobs/run_energyplus.rb', options: {} },
        { state: :finished },
        { state: :errored }
      ]
      k = OpenStudio::Workflow::Run.new input_adapter, output_adapter, File.dirname(osw_path), run_options
      final_state = k.run

      # Check run status and return the sql_path
      if final_state == :finished
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished run.')
      else
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Run completed with errors.')
      end
      sql_path = OpenStudio::Path.new("#{Dir.pwd}/run/eplusout.sql")
      
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished simulation.')

    else # Use the pre OS 2.0 openstudio-workflow gem
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Running with pre OS 2.0 openstudio-workflow gem.')
      
      # Copy the weather file to this directory
      FileUtils.copy(epw_path.to_s, run_dir)

      # Run the simulation
      sim = OpenStudio::Workflow.run_energyplus('Local', run_dir)
      final_state = sim.run

      if final_state == :finished
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished run.')
      end
    
      sql_path = OpenStudio::Path.new("#{run_dir}/run/eplusout.sql")
    
    end
    
    # TODO Delete the eplustbl.htm and other files created
    # by the run for cleanliness.
    
    if OpenStudio::exists(sql_path)
      sql = OpenStudio::SqlFile.new(sql_path)
      # Check to make sure the sql file is readable,
      # which won't be true if EnergyPlus crashed during simulation.
      if !sql.connectionOpen
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "The run failed, cannot create model.  Look at the eplusout.err file in #{File.dirname(sql_path.to_s)} to see the cause.")
        return false
      end
      # Attach the sql file from the run to the model
      self.setSqlFile(sql)
    else 
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "Results for the run couldn't be found here: #{sql_path}.")
      return false
    end
    
    # Report severe errors in the run
    error_query = "SELECT ErrorMessage 
        FROM Errors 
        WHERE ErrorType in(1,2)"
    errs = self.sqlFile.get.execAndReturnVectorOfString(error_query)
    if errs.is_initialized
      errs = errs.get
    end

    # Check that the run completed
    completed_query = "SELECT Completed FROM Simulations"
    completed = self.sqlFile.get.execAndReturnFirstDouble(completed_query)
    if completed.is_initialized
      completed = completed.get
      if completed == 0
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "The run did not finish and had following errors: #{errs.join('\n')}")
        return false
      end
    end    
    
    # Check that the run completed with no severe errors
    completed_successfully_query = "SELECT CompletedSuccessfully FROM Simulations"
    completed_successfully = self.sqlFile.get.execAndReturnFirstDouble(completed_successfully_query)
    if completed_successfully.is_initialized
      completed_successfully = completed_successfully.get
      if completed_successfully == 0
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "The run failed with the following severe or fatal errors: #{errs.join('\n')}")
        return false
      end
    end    
    
    # Log any severe errors that did not cause simulation to fail
    if errs.size > 0
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.model.Model', "The run completed but had the following severe errors: #{errs.join('\n')}")
    end

    return true

  end
  
end  
