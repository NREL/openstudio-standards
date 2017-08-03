require 'rubygems'
require 'json'
require 'roo'
require 'rest-client'
require 'openssl'
require 'aes'
require 'geocoder'

class CostingDatabase


  def apply_baseline_constructions_based_on_rsi(model)
    #Scan for spacetypes and determine contructions used.
    model.getSpacesTypes.each do |space|
      #Ensure space type is of NECB type otherwise raise error.
      #Look up space type construction types based on building stories
      #Generate SpaceType Construction set, avoiding duplication of constructions
      ## The construction id type will match the cost construction id.
      # U-values will be set to reference levels by default.
      # assign construction set to space type.
      #Construction names should be now listed along with U values and m2 for costing.
    end
  end

  def distance (loc1, loc2)
    rad_per_deg = Math::PI/180 # PI / 180
    rkm = 6371 # Earth radius in kilometers
    rm = rkm * 1000 # Radius in meters

    dlat_rad = (loc2[0]-loc1[0]) * rad_per_deg # Delta, converted to rad
    dlon_rad = (loc2[1]-loc1[1]) * rad_per_deg

    lat1_rad, lon1_rad = loc1.map {|i| i * rad_per_deg}
    lat2_rad, lon2_rad = loc2.map {|i| i * rad_per_deg}

    a = Math.sin(dlat_rad/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad/2)**2
    c = 2 * Math::atan2(Math::sqrt(a), Math::sqrt(1-a))
    rm * c # Delta in meters
  end


# Method to obtain the unit costs from the New Construtions library via the RS-means API.
# You will need to place your secret hash into a file named rs_means_auth in your home folder as ruby sees it.
# Your hash will need to be updated as your swagger session expires (within an hour) otherwise you will get a
# 401 not authorized error. The hash_id (the weird long piece of text) is the only thing required in the file.
  def get_rsmeans_costs(rs_type, rs_catalog_id, rs_id)
    puts "Trying #{rs_catalog_id}, #{rs_id}"
    auth = File.read("#{Dir.home}/rs_means_auth").strip
    auth = {:Authorization => "bearer #{auth}"}
    path = "https://dataapi-sb.gordian.com/v1/costdata/#{rs_type.downcase.strip}/catalogs/#{rs_catalog_id.strip}/costlines/#{rs_id.strip}"
    begin
      values = JSON.parse(RestClient.get(path, auth).body)
      #puts JSON.pretty_generate(values)
      return values
    rescue Exception => e
      puts e
      if e.to_s.strip == "401 Unauthorized"
        raise("Authenication failed with RSMeans. Ensure you have created your secret hash from the website and saved it in your home folder as rs_means_auth")
      end
      @not_found_in_rsmeans_api << " #{rs_catalog_id}, #{rs_id}"
    end
    return values
  end


#This will convert a sheet in a given workbook into an array of hashes with the headers as symbols.
  def convert_workbook_sheet_to_array_of_hashes(xlsx_path, sheet_name)
    #Load Constructions data sheet from workbook and convert to a csv object.
    data = Roo::Spreadsheet.open(xlsx_path).sheet(sheet_name).to_csv
    csv = CSV.new(data, {headers: true, header_converters: :symbol})
    return csv.to_a.map {|row| row.to_hash}
  end

  def get_costs_for_materials(materials)
    new_materials = Array.new
    materials.each do |material|

      material['rs_means_api'] = get_rsmeans_costs(material[:type], material[:catalog_id], material[:id])
      material['btap_total_cost_op'] = material['rs_means_api']['baseCosts'][:materialOpCost].to_f * material[:material_mult].to_f +
          material['rs_means_api']['baseCosts'][:labourOpCost].to_f * material[:labour_mult].to_f +
          material['rs_means_api']['baseCosts'][:equipmentOpCost].to_f

      material['btap_total_cost'] = material['rs_means_api']['baseCosts'][:materialCost].to_f * material[:material_mult].to_f +
          material['rs_means_api']['baseCosts'][:labourCost].to_f * material[:labour_mult].to_f +
          material['rs_means_api']['baseCosts'][:equipmentCost].to_f
      new_materials << material
    end
    return new_materials
  end


  def generate_encrypted_costing_database()
    @not_found_in_rsmeans_api = Array.new
    @costing_database = Hash.new()
# Path to the xlsx file
    xlsx_path = "#{File.dirname(__FILE__)}/national_average_cost_information.xlsm"



    @costing_database[:constructions_opaque] = convert_workbook_sheet_to_array_of_hashes(xlsx_path, 'constructions-opaque')
    @costing_database[:materials_opaque] = get_costs_for_materials(convert_workbook_sheet_to_array_of_hashes(xlsx_path, 'materials-opaque'))
    @costing_database[:materials_glazing] = get_costs_for_materials(convert_workbook_sheet_to_array_of_hashes(xlsx_path, 'materials-glazing'))


        key = AES.key
#Write public cost information to a json file. This will be used by the standards and measures. To create
#create the openstudio construction names and costing objects.
    File.open("costing_e.json", "w") do |f|
      f.write(encrypt_hash(key, @costing_database))
    end
    puts "the decryption key is:#{key}"

  end


  def encrypt_hash(key, hash)
    return b64 = AES.encrypt(JSON.pretty_generate(hash), key)
  end

  def decrypt_hash(key, string)
    begin
      json = JSON.parse(AES.decrypt(b64, key))
    rescue OpenSSL::Cipher::CipherError => detail
      puts "Could not decrypt string, perhaps key is invalid? #{detail}"
    end
  end

end

CostingDatabase.new.generate_encrypted_costing_database()
