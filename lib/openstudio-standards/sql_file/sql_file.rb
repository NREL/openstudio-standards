module OpenstudioStandards
  # The SqlFile module provides methods to get information from the EnergyPlus .sql file after a run
  module SqlFile
    # Load and return an sql file, or error if not found
    #
    # @param sql_file_path [String] path to the SQL file
    # @return [OpenStudio::SqlFile] An OpenStudio SqlFile object, boolean false if not found
    def self.sql_file_safe_load(sql_file_path)
      sql_path = OpenStudio::Path.new(sql_file_path)
      if OpenStudio.exists(sql_path)
        sql = OpenStudio::SqlFile.new(sql_path)
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.SqlFile', "Invalid file path #{sql_path}.")
        return false
      end
      return sql
    end

    # Write out a SQL query to retrieve simulation outputs
    # from the TabularDataWithStrings table in the SQL
    # database produced by OpenStudio/EnergyPlus after
    # running a simulation.
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param report_name [String] Name of the report as defined in the HTM simulation output file
    # @param table_name [String] Name of the table as defined in the HTM simulation output file
    # @param row_name [String] Name of the row as defined in the HTM simulation output file
    # @param column_name [String] Name of the column as defined in the HTM simulation output file
    # @param units [String] Unit of the value to be retrieved
    # @return [String, Double] Result of the query
    def self.model_tabular_data_query(model, report_name, table_name, row_name, column_name, units = '*')
      # get model sql file
      sql_file = OpenstudioStandards::SqlFile.model_get_sql_file(model)

      # Define the query
      query = "Select Value FROM TabularDataWithStrings WHERE
      ReportName = '#{report_name}' AND
      TableName = '#{table_name}' AND
      RowName = '#{row_name}' AND
      ColumnName = '#{column_name}' AND
      Units = '#{units}'"

      # Run the query if the expected output is a string
      return sql_file.execAndReturnFirstString(query).get if units.empty?

      # Run the query if the expected output is a double
      return sql_file.execAndReturnFirstDouble(query).get
    end

    # Get the weather run period for the model
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @return [<OpenStudio::EnvironmentType>] the weather run period environment type
    def self.model_get_weather_run_period(model)
      # get model sql file
      sql_file = OpenstudioStandards::SqlFile.model_get_sql_file(model)

      # get the weather file run period
      ann_env_pd = nil
      sql_file.availableEnvPeriods.each do |env_pd|
        env_type = sql_file.environmentType(env_pd)
        next unless env_type.is_initialized

        if env_type.get == OpenStudio::EnvironmentType.new('WeatherRunPeriod')
          ann_env_pd = env_pd
        end
      end

      # make sure the annual run exists
      unless ann_env_pd
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.SqlFile', 'Cannot find the annual simulation run period.')
        return false
      end

      return ann_env_pd
    end

    # Gets the sql file for the model, erroring if not found
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @return [OpenStudio::SqlFile] OpenStudio sqlFile associated with the model, boolean false if not found
    def self.model_get_sql_file(model)
      # Ensure that the model has a sql file associated with it
      if model.sqlFile.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.SqlFile', 'Failed to retrieve data because the sql file containing results is missing.')
        return false
      end

      return model.sqlFile.get
    end
  end
end
