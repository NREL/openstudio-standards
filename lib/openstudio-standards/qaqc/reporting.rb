# Module to apply QAQC checks to a model
module OpenstudioStandards
  module QAQC
    # @!group QAQC HTML reporting

    # Cleanup and prepare HTML
    # measures calling this must add the following require calls:
    # require 'json'
    # require 'erb'
    #
    # @param html_in_path [String] HTML input path
    # @param sections [Array] sections from create_sections_from_check_attributes
    # @param name [String] the name that a user will see
    # @return [String] HTML output path
    def self.create_qaqc_html(html_in_path, sections, name)
      # read in template
      unless File.exist?(html_in_path)
        html_in_path = "#{File.dirname(__FILE__)}/report.html.erb"
      end
      html_in = ''
      File.open(html_in_path, 'r') do |file|
        html_in = file.read
      end

      # configure template with variable values
      # instance variables for erb
      @sections = sections
      @name = name
      renderer = ERB.new(html_in)
      html_out = renderer.result(binding)

      # write html file
      html_out_path = './report.html'
      File.open(html_out_path, 'w') do |file|
        file << html_out
        # make sure data is written to the disk one way or the other
        begin
          file.fsync
        rescue StandardError
          file.flush
        end
      end

      return html_out_path
    end

    # Make HTML sections from a collection of QAQC checks
    #
    # @param check_elems [OpenStudio::AttributeVector.new] vector of check elements
    # @return [Array] Array of HTML sections
    def self.create_sections_from_check_attributes(check_elems)
      # developer notes
      # method below is custom version of standard OpenStudio results methods. It passes an array of sections vs. a single section.
      # It doesn't use the model or SQL file. It just gets data form OpenStudio attributes passed in
      # It doesn't have a name_only section since it doesn't populate user arguments

      # inspecting check attributes
      # make single table with checks.
      # make second table with flag description (with column for where it came from)

      # array to hold sections
      sections = []

      # gather data for section
      qaqc_check_summary = {}
      qaqc_check_summary[:title] = 'List of Checks in Measure'
      qaqc_check_summary[:header] = ['Name', 'Category', 'Flags', 'Description']
      qaqc_check_summary[:data] = []
      qaqc_check_summary[:data_color] = []
      @qaqc_check_section = {}
      @qaqc_check_section[:title] = 'QAQC Check Summary'
      @qaqc_check_section[:tables] = [qaqc_check_summary]

      # add sections to array
      sections << @qaqc_check_section

      # counter for flags thrown
      num_flags = 0

      check_elems.each do |check|
        # gather data for section
        qaqc_flag_details = {}
        qaqc_flag_details[:title] = "List of Flags Triggered for #{check.valueAsAttributeVector.first.valueAsString}."
        qaqc_flag_details[:header] = ['Flag Detail']
        qaqc_flag_details[:data] = []
        @qaqc_flag_section = {}
        @qaqc_flag_section[:title] = check.valueAsAttributeVector.first.valueAsString.to_s
        @qaqc_flag_section[:tables] = [qaqc_flag_details]

        check_name = nil
        check_cat = nil
        check_desc = nil
        flags = []
        # loop through attributes (name,category,description,then optionally one or more flag attributes)
        check.valueAsAttributeVector.each_with_index do |value, index|
          case index
          when 0
            check_name = value.valueAsString
          when 1
            check_cat = value.valueAsString
          when 2
            check_desc = value.valueAsString
          else # should be flag
            flags << value.valueAsString
            qaqc_flag_details[:data] << [value.valueAsString]
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.QAQC', "#{check_name} - #{value.valueAsString}")
            num_flags += 1
          end
        end

        # add row to table for this check
        qaqc_check_summary[:data] << [check_name, check_cat, flags.size, check_desc]

        # add info message for check if no flags found (this way user still knows what ran)
        if check.valueAsAttributeVector.size < 4
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.QAQC', "#{check_name} - no flags.")
        end

        # color cells based and add logging messages based on flag status
        if flags.empty?
          qaqc_check_summary[:data_color] << ['', '', 'lightgreen', '']
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.QAQC', "#{check_name.downcase.tr(' ', '_')} #{flags.size} flags")
        else
          qaqc_check_summary[:data_color] << ['', '', 'indianred', '']
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.QAQC', "#{check_name.downcase.tr(' ', '_')} #{flags.size} flags")
        end

        # add table for this check if there are flags
        if !qaqc_flag_details[:data].empty?
          sections << @qaqc_flag_section
        end
      end

      # add total flags registerValue
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.QAQC', "total flags: #{num_flags}")

      return sections
    end
  end
end
