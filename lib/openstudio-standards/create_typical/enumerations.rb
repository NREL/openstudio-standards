# Methods to create available inputs for typical models
module OpenstudioStandards
  module CreateTypical
    # @!group CreateTypicalEnumerations

    # Get DOE building types
    #
    # @param extended [Boolean] set to true to return additional building types
    # @return [OpenStudio::StringVector] array of building type strings
    def self.get_doe_building_types(extended = false)
      # DOE Prototypes
      array = OpenStudio::StringVector.new
      array << 'SecondarySchool'
      array << 'PrimarySchool'
      array << 'SmallOffice'
      array << 'MediumOffice'
      array << 'LargeOffice'
      array << 'SmallHotel'
      array << 'LargeHotel'
      array << 'Warehouse'
      array << 'RetailStandalone'
      array << 'RetailStripmall'
      array << 'QuickServiceRestaurant'
      array << 'FullServiceRestaurant'
      array << 'MidriseApartment'
      array << 'HighriseApartment'
      array << 'Hospital'
      array << 'Outpatient'
      array << 'SuperMarket'
      array << 'Laboratory'
      array << 'LargeDataCenterLowITE'
      array << 'LargeDataCenterHighITE'
      array << 'SmallDataCenterLowITE'
      array << 'SmallDataCenterHighITE'
      array << 'Courthouse'
      array << 'College'

      return array
    end

    # Get DEER building types
    #
    # @param extended [Boolean] set to true to return additional building types
    # @return [OpenStudio::StringVector] array of building type strings
    def self.get_deer_building_types(extended = false)
      # DOE Prototypes
      array = OpenStudio::StringVector.new
      array << 'Asm'
      array << 'DMo'
      array << 'ECC'
      array << 'EPr'
      array << 'ERC'
      array << 'ESe'
      array << 'EUn'
      array << 'GHs'
      array << 'Gro'
      array << 'Hsp'
      array << 'Htl'
      array << 'MBT'
      array << 'MFm'
      array << 'MLI'
      array << 'Mtl'
      array << 'Nrs'
      array << 'OfL'
      array << 'OfS'
      array << 'RFF'
      array << 'RSD'
      array << 'Rt3'
      array << 'RtL'
      array << 'RtS'
      array << 'SCn'
      array << 'SFm'
      array << 'SUn'
      array << 'WRf'

      return array
    end

    # list of building types that are valid for get_space_types_from_building_type
    #
    # @param extended [Boolean] set to true to return additional building types
    # @return [OpenStudio::StringVector] array of building type strings
    def self.get_building_types(extended = false)
      # get building_types
      if extended
        doe = get_doe_building_types(true)
        deer = get_deer_building_types(true)
      else
        doe = get_doe_building_types
        deer = get_deer_building_types
      end

      # combine building_types
      array = OpenStudio::StringVector.new
      temp_array = doe.to_a + deer.to_a
      temp_array.each do |i|
        array << i
      end

      return array
    end

    # Get DOE templates
    #
    # @param extended [Boolean] set to true to return additional templates
    # @return [OpenStudio::StringVector] array of available standard templates as strings
    def self.get_doe_templates(extended = false)
      array = OpenStudio::StringVector.new
      array << 'DOE Ref Pre-1980'
      array << 'DOE Ref 1980-2004'
      array << '90.1-2004'
      array << '90.1-2007'
      array << '90.1-2010'
      array << '90.1-2013'
      array << '90.1-2016'
      array << '90.1-2019'
      array << 'ComStock DOE Ref Pre-1980'
      array << 'ComStock DOE Ref 1980-2004'
      array << 'ComStock 90.1-2004'
      array << 'ComStock 90.1-2007'
      array << 'ComStock 90.1-2010'
      array << 'ComStock 90.1-2013'
      array << 'ComStock 90.1-2016'
      array << 'ComStock 90.1-2019'
      if extended
        # array << '189.1-2009' # if turn this on need to update space_type_array for RetailStripmall
        array << 'NREL ZNE Ready 2017'
      end

      return array
    end

    # Get DEER templates
    #
    # @param extended [Boolean] set to true to return additional templates
    # @return [OpenStudio::StringVector] array of available standard templates as strings
    def self.get_deer_templates(extended = false)
      array = OpenStudio::StringVector.new
      array << 'DEER Pre-1975'
      array << 'DEER 1985'
      array << 'DEER 1996'
      array << 'DEER 2003'
      array << 'DEER 2007'
      array << 'DEER 2011'
      array << 'DEER 2014'
      array << 'DEER 2015'
      array << 'DEER 2017'
      array << 'DEER 2020'
      if extended
        array << 'DEER 2025'
        array << 'DEER 2030'
        array << 'DEER 2035'
        array << 'DEER 2040'
        array << 'DEER 2045'
        array << 'DEER 2050'
        array << 'DEER 2055'
        array << 'DEER 2060'
        array << 'DEER 2065'
        array << 'DEER 2070'
        array << 'DEER 2075'
      end

      return array
    end

    # list of templates that are valid for get_space_types_from_building_type
    #
    # @param extended [Boolean] set to true to return additional templates
    # @return [OpenStudio::StringVector] array of available standard templates as strings
    def self.get_templates(extended = false)
      # get templates
      if extended
        doe = get_doe_templates(true)
        deer = get_deer_templates(true)
      else
        doe = get_doe_templates
        deer = get_deer_templates
      end

      # combine templates
      array = OpenStudio::StringVector.new
      temp_array = doe.to_a + deer.to_a
      temp_array.each do |i|
        array << i
      end

      return array
    end

    # Get DOE climate zones
    #
    # @param extended [Boolean] set to true to return additional climate zones
    # @param extra [String] extra climate zone to append to list
    # @return [OpenStudio::StringVector] array of available climate zones as strings
    def self.get_doe_climate_zones(extended = false, extra = nil)
      # Lookup From Model should be added as an option where appropriate in the measure
      cz_choices = OpenStudio::StringVector.new
      if !extra.nil?
        cz_choices << extra
      end
      cz_choices << 'ASHRAE 169-2013-1A'
      cz_choices << 'ASHRAE 169-2013-1B'
      cz_choices << 'ASHRAE 169-2013-2A'
      cz_choices << 'ASHRAE 169-2013-2B'
      cz_choices << 'ASHRAE 169-2013-3A'
      cz_choices << 'ASHRAE 169-2013-3B'
      cz_choices << 'ASHRAE 169-2013-3C'
      cz_choices << 'ASHRAE 169-2013-4A'
      cz_choices << 'ASHRAE 169-2013-4B'
      cz_choices << 'ASHRAE 169-2013-4C'
      cz_choices << 'ASHRAE 169-2013-5A'
      cz_choices << 'ASHRAE 169-2013-5B'
      cz_choices << 'ASHRAE 169-2013-5C'
      cz_choices << 'ASHRAE 169-2013-6A'
      cz_choices << 'ASHRAE 169-2013-6B'
      cz_choices << 'ASHRAE 169-2013-7A'
      cz_choices << 'ASHRAE 169-2013-8A'
      if extended
        cz_choices << 'ASHRAE 169-2013-0A'
        cz_choices << 'ASHRAE 169-2013-0B'
      end

      return cz_choices
    end

    # Get DEER climate zones
    #
    # @param extended [Boolean] set to true to return additional climate zones
    # @param extra [String] extra climate zone to append to list
    # @return [OpenStudio::StringVector] array of available climate zones as strings
    def self.get_deer_climate_zones(extended = false, extra = nil)
      # Lookup From Model should be added as an option where appropriate in the measure
      cz_choices = OpenStudio::StringVector.new
      if !extra.nil?
        cz_choices << extra
      end
      cz_choices << 'CEC T24-CEC1'
      cz_choices << 'CEC T24-CEC2'
      cz_choices << 'CEC T24-CEC3'
      cz_choices << 'CEC T24-CEC4'
      cz_choices << 'CEC T24-CEC5'
      cz_choices << 'CEC T24-CEC6'
      cz_choices << 'CEC T24-CEC7'
      cz_choices << 'CEC T24-CEC8'
      cz_choices << 'CEC T24-CEC9'
      cz_choices << 'CEC T24-CEC10'
      cz_choices << 'CEC T24-CEC11'
      cz_choices << 'CEC T24-CEC12'
      cz_choices << 'CEC T24-CEC13'
      cz_choices << 'CEC T24-CEC14'
      cz_choices << 'CEC T24-CEC15'
      cz_choices << 'CEC T24-CEC16'

      return cz_choices
    end

    # Get climate zones
    #
    # @param extended [Boolean] set to true to return additional climate zones
    # @param extra [String] extra climate zone to append to list
    # @return [OpenStudio::StringVector] array of available climate zones as strings
    def self.get_climate_zones(extended = false, extra = nil)
      # get climate_zones
      if extended && !extra.nil?
        doe = get_doe_climate_zones(true, extra)
        deer = get_deer_climate_zones(true, nil)
      elsif extended
        doe = get_doe_climate_zones(true, nil)
        deer = get_deer_climate_zones(true, nil)
      elsif !extra.nil?
        doe = get_doe_climate_zones(false, extra)
        deer = get_deer_climate_zones(false, nil)
      else
        doe = get_doe_climate_zones
        deer = get_deer_climate_zones
      end

      # combine climate zones
      array = OpenStudio::StringVector.new
      temp_array = doe.to_a + deer.to_a
      temp_array.each do |i|
        array << i
      end

      return array
    end
  end
end
