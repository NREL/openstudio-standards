require "#{File.dirname(__FILE__)}/btap"
require 'rubygems'
require 'json'
require 'roo'
require 'rest-client'
require 'openssl'
require 'aes'
require 'geocoder'
require 'singleton'
require "highline/import"
require 'launchy'

class BTAPCosting

  PATH_TO_COSTING_DATA = "../../../data/costing"
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

#Brute force interpolation...Could be improved easily. Only use for small amount of points.
  def interpolate(x_y_array, x2)
    array = x_y_array.sort {|a, b| a[0] <=> b[0]}
    if x2 < array.first[0].to_f or x2 > array.last[0].to_f
      return nil
    else
      #ugly hack to interpolate...but it works.
      array.each_index do |counter|

        #skip last value.
        next if array[counter] == array.last

        x0 = array[counter][0]
        y0 = array[counter][1]
        x1 = array[counter+1][0]
        y1 = array[counter+1][1]

        #skip if x2 is not between x0 and x1
        next if x2 < x0 and x2 > x1

        #Do interpolation
        y2 = 0
        y2 = y0.to_f + ((y1-y0).to_f*(x2-x0).to_f/(x1-x0).to_f)
        log ("y2 = #{y2}")
        y2 = y2.ceil
        return y2
      end
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

  def get_closest_cost_city(lat, long)
    dist = 1000000000000000000000.0
    closest_city = nil
    #province-state	city	latitude	longitude	source
    @costing_database['raw']['RSMeansLocations'].each do |location|
      if distance([lat, long], [location['latitude'].to_f, location['longitude'].to_f]) < dist
        closest_city = location
        dist = distance([lat, long], [location['latitude'].to_f, location['longitude'].to_f])
      end
    end
    return closest_city
  end

  def initialize(key = nil)
    @key = key
    @rs_means_auth_hash_path = "#{File.dirname(__FILE__)}/#{PATH_TO_COSTING_DATA}/rs_means_auth"
    @xlsx_path = "#{File.dirname(__FILE__)}/#{PATH_TO_COSTING_DATA}/national_average_cost_information.xlsm"
    @keyfile = "#{File.dirname(__FILE__)}/#{PATH_TO_COSTING_DATA}/keyfile"
    @encrypted_file = "#{File.dirname(__FILE__)}/#{PATH_TO_COSTING_DATA}/costing_e.json"
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
                            'rsi_k_m2_per_w' => construction['rsi_k_m2_per_w'].to_f,
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
    error = [material, "Could not find regional adjustment factor for rs-means material"]
    @costing_database['rs_mean_errors'] << error unless @costing_database['rs_mean_errors'].include?(error)
    return 100.0, 100.0
  end


  def generate_materials_database()
    @auth_hash = nil
    @not_found_in_rsmeans_api = Array.new
    @costing_database = Hash.new()
    if File.exist?(@rs_means_auth_hash_path)
      @auth_hash = File.read(@rs_means_auth_hash_path).strip
    else
      self.authenticate_rs_means_v1()
    end


# Path to the xlsx file


    unless File.exist?(@xlsx_path)
      raise("could not find the national_average_cost_information.xlsm in location #{@xlsx_path}. This is a proprietary file manage by Natural resources Canada.")
    end

#Get Raw Data from files.
    @costing_database['raw'] = {}
    @costing_database['rs_mean_errors']=[]
    ['RSMeansLocations',
     'RSMeansLocalFactors',
     'ConstructionSets',
     'ConstructionsOpaque',
     'MaterialsOpaque',
     'ConstructionsGlazing',
     'MaterialsGlazing',
     'Constructions',
     'ConstructionProperties'
    ].each do |sheet|
      @costing_database['raw'][sheet] = convert_workbook_sheet_to_array_of_hashes(@xlsx_path, sheet)
    end
    @costing_database['rsmean_api_data']= Array.new
    @costing_database['constructions_costs']= Array.new

#Get RSMeans Materials data and store errors if encountered

    [@costing_database['raw']['MaterialsOpaque'], @costing_database['raw']['MaterialsGlazing']].each do |mat_lib|
      [mat_lib].each do |materials|
        lookup_list = materials.map {|material| {'type' => material['type'], 'catalog_id' => material['catalog_id'], 'id' => material['id']}}.uniq
        lookup_list.each do |material|

          auth = {:Authorization => "bearer #{@auth_hash}"}
          path = "https://dataapi-sb.gordian.com/v1/costdata/#{material['type'].downcase.strip}/catalogs/#{material['catalog_id'].strip}/costlines/#{material['id'].strip}"
          value = nil
          begin
            api_return = JSON.parse(RestClient.get(path, auth).body)

            @costing_database['rsmean_api_data'] << api_return
          rescue Exception => e
            puts e
            if e.to_s.strip == "401 Unauthorized"
              self.authenticate_rs_means_v1()
            elsif e.to_s.strip == "404 Not Found"
              material['error'] = e
              @costing_database['rs_mean_errors'] << [material, e.to_s.strip]
            else
              raise("Error Occured #{e}")
            end
          end
          puts "Obtained #{material['id']} costing"
        end
      end
    end
  end

  def encrypt_database(key)
    #Write public cost information to a json file. This will be used by the standards and measures. To create
    #create the openstudio construction names and costing objects.
    File.open(@encrypted_file, "w") do |f|
      f.write(encrypt_hash(key, @costing_database))
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
    puts JSON.pretty_generate(@costing_database['rs_mean_errors']) unless @costing_database['rs_mean_errors'].empty?
    self.encrypt_database(@key)
    puts "Cost Database regenerated in #{Time.now - start} seconds"
  end

  def cost_audit_envelope(model)
    costing_report = {}
    costing_report["Envelope"] = {}
    if model.getBuilding.standardsBuildingType.empty? or
        model.getBuilding.standardsNumberOfAboveGroundStories
      raise("Building information is not complete, please ensure that the standardsBuildingType and standardsNumberOfAboveGroundStories are entered in the model. ")
    end

    #collect building information required
    num_of_above_ground_stories = model.getBuilding.standardsNumberOfAboveGroundStories


    model.getThermalZones.each do |zone|
      zone.spaces.each do |space|

        #Get SpaceType
        if space.spaceType.empty? or space.spaceType.get.standardsSpaceType.empty? or space.spaceType.get.standardsBuildingType.empty?
          raise ("standards Space type and building type is not defined for space:#{space.name.get}. Skipping this space for costing.")
        end

        #Get Spacetype names.
        space_type = space.spaceType.get.standardsSpaceType
        building_type = space.spaceType.get.standardsBuildingType

        #Get standard constructions based on collected information (spacetype, no of stories, etc..)
        construction_set = @costing_database['raw']['ConstructionSets'].select {|data|
          data['building_type'].to_s == building_type and
              data['space_type'].to_s == space_type and
              data['min_stories'].to_i <= num_of_above_ground_stories and
              data['max_stories'].to_i >= num_of_above_ground_stories
        }.first


        surfaces = {}
        #Exterior
        exterior_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(space.surfaces, "Outdoors")
        surfaces["ExteriorWall"] = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Wall")
        surfaces["ExteriorRoof"]= BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "RoofCeiling")
        surfaces["ExteriorFloor"] = BTAP::Geometry::Surfaces::filter_by_surface_types(outdoor_surfaces, "Floor")
        #Exterior Subsurface
        exterior_subsurfaces = BTAP::Geometry::Surfaces::get_subsurfaces_from_surfaces(exterior_surfaces)
        surfaces["ExteriorFixedWindow"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["FixedWindow"])
        surfaces["ExteriorOperableWindow"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["OperableWindow"])
        surfaces["ExteriorSkylight"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["Skylight"])
        surfaces["ExteriorTubularDaylightDiffuser"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["TubularDaylightDiffuser"])
        surfaces["ExteriorTubularDaylightDome"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["TubularDaylightDome"])
        surfaces["ExteriorDoor"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["Door"])
        surfaces["ExteriorGlassDoor"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["GlassDoor"])
        surfaces["ExteriorOverheadDoor"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["OverheadDoor"])

        #Ground
        ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(space.surfaces, "Ground")
        surfaces["GroundContactWall"] = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "Wall")
        surfaces["GroundContactRoof"] = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "RoofCeiling")
        surfaces["GroundContactFloor"] = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "Floor")

        #These are the only envelope costing items we are considering.
        [
            "ExteriorWall",
            "ExteriorRoof",
            "ExteriorFloor",
            "ExteriorFixedWindow",
            "ExteriorOperableWindow",
            "ExteriorSkylight",
            "ExteriorTubularDaylightDiffuser",
            "ExteriorTubularDaylightDome",
            "ExteriorDoor",
            "ExteriorGlassDoor",
            "ExteriorOverheadDoor",
            "GroundContactWall",
            "GroundContactRoof",
            "GroundContactFloor"
        ].each do |surface_type|
          #Get Costs for this construction type. This will get the cost for the particular construction type for all rsi
          # levels for that city. This has been collected by RS means.
          cost_range_hash = @costing_database['constructions_costs'].select {|construction|
            construction['construction_type_name'] == construction_set[surface_type] and
                construction['province-state'] == province_state and
                construction['city'] == city
          }
          #We don't need all the information, just the rsi and cost....
          cost_range_array = cost_range_hash.map {|cost|
            [cost['rsi_k_m2_per_w'], cost['total_cost_with_op']]
          }
          #Sorted based on rsi.
          cost_range_array.sort! {|a, b| a[0] <=> b[0]}

          #Not we iterate through that actual surfaces in the model of surface_type.
          surfaces[surface_type].each do |surface|
            #get RSI of surface existing surface.
            rsi = BTAP::Resources::Envelope::Constructions::get_rsi(OpenStudio::Model::getConstructionByName(surface.model, surface.construction.get.name.to_s).get)

            #Use the cost_range_array to interpolate the estimated cost for the given rsi.
            cost = interpolate(cost_range_array, rsi)

            #If the cost is nil, that means the rsi is out of range. This should be flagged in the report.
            if cost.nil?
              notes = "The RSI of #{rsi} for this surface is out of the range of the NRCan Database. The range available
                     for #{construction_set[surface_type]} is between #{cost_range_array.first[0]}
                     and #{cost_range_array.last[0]} "
            end

            #bin costing by construction standard type and rsi
            name = "#{construction_set[surface_type]}_#{rsi}"
            if costing_report["Envelope"].has_key?(name)
              costing_report["Envelope"][name]['area'] += (surface.netArea * zone.multiplier)
              costing_report["Envelope"][name]['total_cost'] += (cost * surface.netArea * zone.multiplier)
            else
              costing_report["Envelope"][name]={'area' => (surface.netArea * zone.multiplier), 'total_cost' => (cost * surface.netArea * zone.multiplier)}
            end

          end #surfaces of surface type
        end #surface_type
      end #spaces
    end #thermalzone
    puts costing_report
  end


  def authenticate_rs_means_v1()
    puts '
       Your RSMeans Bearer code is out of date. It usually lasts 60 minutes.  Please do the following.
       1. Go to https://dataapi-sb.gordian.com/swagger/ui/index.html#!/CostData-Assembly-Catalogs/CostdataAssemblyCatalogsGet
       2. Click on the the off switch at the top right corner of the first table open.
       3. Select the checkbox rsm_api:costdata.
       4. Click authorize.
       5. Enter your rsmeans api username and password when prompted.
       6. When you return to the main page, click the "try it out" button at the bottom left of the first table.
       7. Copy the entire string in the curl command field.
       8. Paste it below.
      '
    rs_auth_bearer = ask "Paste RSMeans API Curl String and hit enter:"
    m = rs_auth_bearer.match(/.*Bearer (?<bearer>[^']+).*$/)
    if m[:bearer].to_s.size != 934
      abort "Bearer key is not 934 charecters long. Please ensure that you copied the full curl string from the API Explorer."
    else
      #store auth_key in class variable
      @auth_hash = m[:bearer].to_s
      #Store to disk to subsequent runs if required.
      File.write(@rs_means_auth_hash_path, @auth_hash)
    end
  end

end











