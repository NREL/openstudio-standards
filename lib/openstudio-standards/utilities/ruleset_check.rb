module OpenStudioStandards
  module RulesetChecking
    # Export OpenStudio model to epJson file.
    #
    # @param model [OpenStudio::Model::Model]
    # @param save_dir [String] epJson save directory
    # @param model_name [String] the name of the epJson file.
    # @return [Boolean] returns true if successful, false if not
    def self.export_epjson(model, save_dir, model_name)
      forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
      workspace = forward_translator.translateModel(model)
      workspace_epjson_str = OpenStudio::EPJSON::toJSONString(workspace)
      begin
        output_path = "#{save_dir}/#{model_name}.json"
        epjson_model = File.open(output_path, 'w')
        epjson_model.puts(workspace_epjson_str)
      rescue StandardError => e
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.RulesetChecking', "Failed writing epjson file. Error message #{e}")
        return false
      ensure
        epjson_model.close if epjson_model
      end
      return true
    end

    def self.tag_spaces(model, ruleset_space_rule)
      42
    end

    def self.export_json_output(model)
      # clear out the output, output:variable, output:schedule, outputcontrol:table:style and output:table:summaryreports
      # reformt it a different set.
      output_json = model.getOutputJSON
      unless output_json
        output_json = OpenStudio::Model::OutputJSON.new(model)
      end
      output_json.setOptionType('TimeSeriesAndTabular')
      output_json.setOutputJSON(true)
      output_json.setOutputCBOR(false)
      output_json.setOutputMessagePack(false)

      output_schedules = model.getOutputSchedules
      unless output_schedules
        output_schedules = OpenStudio::Model::OutputSchedules.new(model)
      end
      output_schedules.setKeyField('Hourly')

      outputcontrol_table_style = model.getOutputControlTableStyle
      unless outputcontrol_table_style
        outputcontrol_table_style = OpenStudio::Model::OutputControlTableStyle.new(model)
      end
      outputcontrol_table_style.setColumnSeparator('HTML')
      outputcontrol_table_style.setUnitConversion('None')

      output_table_summaryreports = model.getOutputTableSummaryReports
      unless output_table_summaryreports
        output_table_summaryreports = OpenStudio::Model::OutputTableSummaryReports.new(model)
      end
      output_table_summaryreports.removeAllSummaryReports
      outputcontrol_table_style.addSummaryReport('AllSummaryAndMonthly')
    end
  end
end
