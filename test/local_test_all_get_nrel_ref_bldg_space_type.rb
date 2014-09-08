# perform a local test of get_nrel_ref_bldg_space_type.rb using the same syntax that the server expects

# gem install json or gem install json_pure (pure ruby version has fewer dependencies)
require 'rubygems'
require 'json'
require 'fileutils'
require 'openstudio'

xmlPath = OpenStudio::Path.new('get_nrel_ref_bldg_space_type.xml')
generator = OpenStudio::OnDemandGenerator.load(xmlPath).get

failures = 0

vintageArgument = generator.getActiveArgument('NREL_reference_building_vintage').get
vintageArgument.valueRestrictions.each do |nrel_reference_building_vintage|
  generator.setArgumentValue('NREL_reference_building_vintage', nrel_reference_building_vintage.name)

  climateArgument = generator.getActiveArgument('Climate_zone').get
  climateArgument.valueRestrictions.each do |climate_zone|
    generator.setArgumentValue('Climate_zone', climate_zone.name)

    primaryArgument = generator.getActiveArgument('NREL_reference_building_primary_space_type').get
    primaryArgument.valueRestrictions.each do |nrel_reference_building_primary_space_type|
      generator.setArgumentValue('NREL_reference_building_primary_space_type', nrel_reference_building_primary_space_type.name)

      secondaryArgument = generator.getActiveArgument('NREL_reference_building_secondary_space_type').get
      secondaryArgument.valueRestrictions.each do |nrel_reference_building_secondary_space_type|
        generator.setArgumentValue('NREL_reference_building_secondary_space_type', nrel_reference_building_secondary_space_type.name)

        args = Hash.new
        args['NREL_reference_building_vintage'] = generator.getActiveArgument('NREL_reference_building_vintage').get.valueAsString.get
        args['Climate_zone'] = generator.getActiveArgument('Climate_zone').get.valueAsString.get
        args['NREL_reference_building_primary_space_type'] = generator.getActiveArgument('NREL_reference_building_primary_space_type').get.valueAsString.get
        args['NREL_reference_building_secondary_space_type'] = generator.getActiveArgument('NREL_reference_building_secondary_space_type').get.valueAsString.get
        args['ondemand_uid'] = 'uid'
        args['ondemand_vid'] = 'vid'
        args['apikey'] = 'apikey'

        cmd = "ruby 'get_nrel_ref_bldg_space_type.rb' '#{args.to_json}'"
        puts cmd
        test = system(cmd)
        result = 'success'
        unless test
          result = 'failure'
          failures += 1
        end

        puts "#{args['NREL_reference_building_vintage']},#{args['Climate_zone']}, #{args['NREL_reference_building_primary_space_type']}, #{args['NREL_reference_building_secondary_space_type']}, #{result}"

      end

    end

  end

end

puts "There were #{failures} failures"
