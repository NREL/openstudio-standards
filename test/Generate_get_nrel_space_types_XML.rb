
require 'rubygems'
require 'json'
require 'builder'
require 'uuid'

# load the data from the JSON file into a ruby hash
nrel_spc_types = {}
# setup paths
Dir.chdir('..')
root_path = "#{Dir.pwd}/"

temp = File.read("#{root_path}nrel_ref_bldg_space_type/lib/nrel_ref_bldg_space_types.json")
nrel_spc_types = JSON.parse(temp)

f = File.open("#{root_path}nrel_ref_bldg_space_type/get_nrel_ref_bldg_space_type.xml", 'w')

xml = Builder::XmlMarkup.new(indent: 2)

xml.instruct! :xml, version: '1.0', encoding: 'UTF-8'
xml.onDemandGeneratorDescription('xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                                 'xsi:noNamespaceSchemaLocation' => '\\\\nrel.gov\\shared\\5500\\5500 HPBldg\\PROJECTS\\SoftwareDevelopment\\WebDevelopment\\BCL\\schemas\\generatorDescription_2012_05_21.xsd')do
  xml.name 'get_NREL_reference_building_space_types'
  xml.uid 'bb8aa6a0-6a25-012f-9521-00ff10704b07'
  xml.version_id UUID.new.generate
  xml.description 'On-demand generator takes 4 arguments and returns a space type .osm and .osc'
  xml.fidelity_level 2

  xml.provenances do
    xml.provenance do
      xml.author 'aparker'
      xml.datetime '2012-04-25T09:00:00Z'
    end
  end

  xml.tags do
    xml.tag 'Space Type'
  end

  def write_standard_values(xml, nrel_spc_types)
    xml.values do
      for standard in nrel_spc_types.keys.sort
        next if standard == 'todo'
        puts "#{standard}"

        xml.value do
          xml.name standard
          xml.nested_arguments do
            xml.nested_argument do
              xml.name 'Climate_zone'
              xml.displayname 'Climate Zone'
              xml.datatype 'string'
              xml.required 1
              xml.input_type 'select'
              write_climate_values(xml, nrel_spc_types, standard)
            end
          end
        end
      end
    end
  end

  def write_climate_values(xml, nrel_spc_types, standard)
    xml.values do
      for climate in nrel_spc_types[standard].keys.sort
        puts "**#{climate}"

        xml.value do
          xml.name climate
          xml.nested_arguments do
            xml.nested_argument do
              xml.name 'NREL_reference_building_primary_space_type'
              xml.displayname 'Primary Space Type'
              xml.datatype 'string'
              xml.required 1
              xml.input_type 'select'
              write_pri_spc_type_values(xml, nrel_spc_types, standard, climate)
            end
          end
        end
      end
    end
  end

  def write_pri_spc_type_values(xml, nrel_spc_types, standard, climate)
    xml.values do
      for pri_spc_type in nrel_spc_types[standard][climate].keys.sort
        puts "****#{pri_spc_type}"

        xml.value do
          xml.name pri_spc_type
          xml.nested_arguments do
            xml.nested_argument do
              xml.name 'NREL_reference_building_secondary_space_type'
              xml.displayname 'Secondary Space Type'
              xml.datatype 'string'
              xml.required 1
              xml.input_type 'select'
              write_sec_spc_type_values(xml, nrel_spc_types, standard, climate, pri_spc_type)
            end
          end
        end
      end
    end
  end

  def write_sec_spc_type_values(xml, nrel_spc_types, standard, climate, pri_spc_type)
    xml.values do
      for sec_spc_type in nrel_spc_types[standard][climate][pri_spc_type].keys.sort
        puts "******#{sec_spc_type}"

        xml.value do
          xml.name sec_spc_type
        end
      end
    end
  end

  xml.arguments do
    xml.argument do
      xml.name 'NREL_reference_building_vintage'
      xml.displayname 'Standard'
      xml.datatype 'string'
      xml.required 1
      xml.input_type 'select'
      write_standard_values(xml, nrel_spc_types)
    end
  end

  xml.files do
    xml.file do
      xml.version do
        xml.software_program 'OpenStudio'
        xml.identifier '0.7.6'
      end
      xml.filename 'nrel_ref_bldg_space_type.osm'
      xml.filetype 'osm'
    end
    xml.file do
      xml.version do
        xml.software_program 'OpenStudio'
        xml.identifier '0.7.6'
      end
      xml.filename 'nrel_ref_bldg_space_type.osc'
      xml.filetype 'osc'
    end
  end

  xml.resources do
    xml.resource do
      xml.filename 'nrel_ref_bldg_space_types.json'
      xml.filetype 'json'
      xml.uid 'TODO create uid'
      xml.version_id 'TODO create version id'
    end
    xml.resource do
      xml.filename 'MasterTemplate.osm'
      xml.filetype 'osm'
      xml.uid 'TODO create uid'
      xml.version_id 'TODO create version id'
    end
  end

  xml.dependencies do
    xml.dependency do
      xml.software_program 'OpenStudio'
      xml.identifier '0.7.6'
    end
  end

end # close the onDemandGeneratorDescription tag

xml_data = xml.target!

f.write(xml_data)

# puts xml_data

f.close

puts 'successfully generated .xml file'
