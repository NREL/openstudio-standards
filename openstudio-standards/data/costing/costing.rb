require 'rubygems'
require 'json'
require 'roo'
require 'rest-client'
require 'openssl'
require 'aes'
require 'geocoder'
require 'singleton'

class BTAPCosting

  include Singleton
  attr_accessor :costing_database
# A list of the table and fields in the Excel database. Please keep up to date.
#RSMeansLocations
# province-state
# city
# latitude
# longitude
# source
#RSMeansLocalFactors
# province-state
# city
# division
# code_prefixes
# material
# installation
# total	source
#SpaceTypeRules
# template
# building_type
# space_type
# min_stories
# max_stories
# spandrel
# ext_wall_type
# ext_floor_type
# ext_roof_type
# ext_doors_type
# ground_contact_wall_type
# ground_contact_floor_type
# ground_contact_roof_type
# ext_fixed_window_type
# ext_operable_window_type
# ext_glass_door
# ext_skylight
# ext_tubular_domes
# ext_tubular_diffusers
#ConstructionsOpaque
# construction_opaque_id
# surface_type
# construction_type_name
# author
# intended_surface_type
# standards_construction_type
# type_index
# climate_zone
# rsi_k_m2_per_w
# u_w_per_m2_k
# description
# material_opaque_id_layers
# material_descriptions
#MaterialsOpaque
# materials_opaque_id
# source
# type
# material_type
# catalog_id
# id
# description
# unit
# quantity
# material_mult
# labour_mult	op_mult

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


#Enter in [latitude, logitude] for each loc and this method will return the distance.
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

  def initialize(key = nil)
    @key = key
    @xlsx_path = "#{File.dirname(__FILE__)}/national_average_cost_information.xlsm"
    @keyfile = "#{File.dirname(__FILE__)}/keyfile"
    @encrypted_file = "#{File.dirname(__FILE__)}/costing_e.json"
    if @key.nil?
      @key = load_local_keyfile()
    end
    load_encrypted_database(@key)
  end

#This will convert a sheet in a given workbook into an array of hashes with the headers as symbols.
  def convert_workbook_sheet_to_array_of_hashes(xlsx_path, sheet_name)
    #Load Constructions data sheet from workbook and convert to a csv object.
    data = Roo::Spreadsheet.open(xlsx_path).sheet(sheet_name).to_csv
    csv = CSV.new(data, {headers: true})
    return csv.to_a.map {|row| row.to_hash}
  end


  def get_costing_for_constructions_for_all_regions()
    @costing_database = JSON.parse(File.read('costing.json'))
    @costing_database['constructions_costs']= Array.new
    counter = 0
    @costing_database['raw']['RSMeansLocations'].each do |location|
      puts "#{location["province-state"]},#{location['city']}"
      @costing_database["raw"]['ConstructionsOpaque'].each do |construction|
        #puts "Getting cost for Construction type #{construction["construction_type_name"]} at RSI #{construction['rsi_k_m2_per_w']}"
        total_with_op = 0.0
        materials_string = ''
        material_cost_string = ''
        material_cost_pairs = []
        construction['material_opaque_id_layers'].split(',').reject {|c| c.empty?}.each do |material_index|
          material = @costing_database["raw"]['MaterialsOpaque'].find {|material| material['materials_opaque_id'].to_s == material_index.to_s}
          if material.nil?
            puts "material error..could not find material #{material_index} in #{@costing_database["raw"]['MaterialsOpaque']}"
            raise()
          else
            rs_means_data = @costing_database['rsmean_api_data'].select {|data| data['id'].to_s == material['id']}.first
            if rs_means_data.nil?
              #puts "This material id #{material['id']} was not found in the rs-means api. Skipping. This construction will be inaccurate. "
              next
            else
              regional_material, regional_installation = get_regional_cost_factors(location['province-state'], location['city'], material)
              #Get RSMeans cost information from lookup.
              material_cost = rs_means_data['baseCosts']['materialOpCost'].to_f * material['quantity'].to_f * material['material_mult'].to_f
              labour_cost = rs_means_data['baseCosts']['labourOpCost'].to_f * material['labour_mult'].to_f
              equipment_cost = rs_means_data['baseCosts']['equipmentOpCost'].to_f
              layer_cost = ((material_cost * regional_material / 100.0) + (labour_cost * regional_installation / 100.0) + equipment_cost).round(2)
              #materials_string += "\n#{material['description']}"
              #material_cost_string += "\n#{layer_cost.to_s}"
              material_cost_pairs << {'materials_opaque_id' => material_index,
                                      'cost' => layer_cost}
              total_with_op += layer_cost
            end
          end
        end
        new_construction = {'index' => counter,
                            'province-state' => location['province-state'],
                            'city' => location['city'],
                            "construction_type_name" => construction["construction_type_name"],
                            'description' => construction["description"],
                            'intended_surface_type' => construction["intended_surface_type"],
                            'standards_construction_type' => construction["standards_construction_type"],
                            'rsi_k_m2_per_w ' => construction['rsi_k_m2_per_w'].to_f,
                            'zone' => construction['climate_zone'],
                            'materials' => material_cost_pairs,
                            'total_cost_with_op' => total_with_op}

        @costing_database['constructions_costs'] << new_construction
        counter += 1
      end
    end
    puts "#{counter} contructions created for #{@costing_database['raw']['RSMeansLocations'].size} cities"
  end

  def get_regional_cost_factors(provincestate, city, material)
    @costing_database['raw']['RSMeansLocalFactors'].select {|code| code['province-state'] == provincestate and code['city'] == city}.each do |code|
      id = material['id'].to_s
      prefixes = code["code_prefixes"].split(',')
      prefixes.each do |prefix|
        # puts " #{id} == #{prefix}"
        if id.start_with?(prefix.strip)
          return code["material"].to_f, code["installation"].to_f
        end
      end
    end
    raise("Could not find regional adjustment factor for rs-means material #{material['id']}")
  end


  def generate_materials_database()
    @not_found_in_rsmeans_api = Array.new
    @costing_database = Hash.new()
    if File.exist?("rs_means_auth")
      auth_hash = File.read("rs_means_auth").strip
    else
      raise ("
       You will need to place your secret RS-Means hash into a file named rs_means_auth in your home folder as ruby sees it.
       Your hash will need to be updated as your swagger session expires (within an hour) otherwise you will get a
       401 not authorized error. The hash_id (the weird long piece of text) is the only thing required in the file.
      ")

    end

    # Path to the xlsx file


    unless File.exist?(@xlsx_path)
      raise("could not find the national_average_cost_information.xlsm in location #{@xlsx_path}. This is a proprietary file manage by Natural resources Canada.")
    end

    #Get Raw Data from files.
    @costing_database['raw'] = {}
    @costing_database['rs_mean_errors']=[]
    @costing_database['raw']['ConstructionSets'] = convert_workbook_sheet_to_array_of_hashes(@xlsx_path, 'ConstructionSets')
    @costing_database['raw']['RSMeansLocations'] = convert_workbook_sheet_to_array_of_hashes(@xlsx_path, 'RSMeansLocations')
    @costing_database['raw']['RSMeansLocalFactors'] = convert_workbook_sheet_to_array_of_hashes(@xlsx_path, 'RSMeansLocalFactors')
    @costing_database['raw']['MaterialsOpaque'] = convert_workbook_sheet_to_array_of_hashes(@xlsx_path, 'MaterialsOpaque')
    @costing_database['raw']['ConstructionsOpaque'] = convert_workbook_sheet_to_array_of_hashes("#{File.dirname(__FILE__)}/national_average_cost_information.xlsm", 'ConstructionsOpaque')
    @costing_database['rsmean_api_data']= Array.new
    @costing_database['constructions_costs']= Array.new

    #Get RSMeans Materials data and store errors if encountered
    [@costing_database['raw']['MaterialsOpaque']].each do |materials|
      lookup_list = materials.map {|material| {'type' => material['type'], 'catalog_id' => material['catalog_id'], 'id' => material['id']}}.uniq
      lookup_list.each do |material|

        puts "Trying to look up #{material}"

        auth = {:Authorization => "bearer #{auth_hash}"}
        path = "https://dataapi-sb.gordian.com/v1/costdata/#{material['type'].downcase.strip}/catalogs/#{material['catalog_id'].strip}/costlines/#{material['id'].strip}"
        value = nil
        begin
          api_return = JSON.parse(RestClient.get(path, auth).body)
          JSON.pretty_generate(api_return)
          puts api_return
          @costing_database['rsmean_api_data'] << api_return
        rescue Exception => e
          puts e
          if e.to_s.strip == "401 Unauthorized"
            raise("Authenication failed with RSMeans. Ensure you have created your secret hash from the website and saved it in your home folder as rs_means_auth")
          elsif e.to_s.strip == "404 Not Found"
            material['error'] = e
            @costing_database['rs_mean_errors'] << material
          else
            raise("Error Occured #{e}")
          end
        end
      end

    end
    self.get_costing_for_constructions_for_all_regions()
  end

  def encrypt_database(key)
    #Write public cost information to a json file. This will be used by the standards and measures. To create
    #create the openstudio construction names and costing objects.
    File.open("costing_ecrypted.json", "w") do |f|
      f.write(encrypt_hash(key, @costing_database))
    end
    #For debugging
    File.open("costing.json", "w") do |f|
      f.write(JSON.pretty_generate(@costing_database))
    end
    puts "the decryption key is:#{key}"
  end


  def encrypt_hash(key, hash)
    return b64 = AES.encrypt(Zlib::Deflate.deflate(JSON.pretty_generate(hash)), key)
  end

  def decrypt_hash(key, encrypted_string)
    json = nil
    begin
      json = JSON.parse(Zlib::Inflate.inflate(AES.decrypt(encrypted_string, key)))
        #puts JSON.pretty_generate(json)
    rescue OpenSSL::Cipher::CipherError => detail
      puts "Could not decrypt string, perhaps key is invalid? #{detail}"
    end
    return json
  end

  def load_encrypted_database(key, file = @encrypted_file)
    if FileUtils.uptodate?(file, [@xlsx_path])
      @costing_database = decrypt_hash(key, File.read(file))
    else
      self.recreate_database()
    end
  end


  def load_local_keyfile()
    puts "loading local key"
    @key = nil
    if File.exist?(@keyfile)
      @key = File.read(@keyfile)
    else
      puts "could not file nrcan's secret keyfile hash."
    end
    puts "this is the key #{@key}"
    return @key
  end

  def recreate_database()
    start = Time.now
    self.generate_materials_database()
    self.get_costing_for_constructions_for_all_regions()
    self.encrypt_database(@key)
  end
end

BTAPCosting.instance()
BTAPCosting.instance.costing_database




