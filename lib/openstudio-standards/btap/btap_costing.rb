require "#{File.dirname(__FILE__)}/btap"
require 'json'
require 'singleton'
require 'roo'
require 'openssl'
require 'aes'
require 'rest-client'


class BTAPCosting

  PATH_TO_COSTING_DATA = "../../../data/costing"
  include Singleton
  attr_accessor :costing_database
  def initialize()
    #paths to files all set here.
    @rs_means_auth_hash_path = "#{File.dirname(__FILE__)}/#{PATH_TO_COSTING_DATA}/rs_means_auth"
    @xlsx_path = "#{File.dirname(__FILE__)}/#{PATH_TO_COSTING_DATA}/national_average_cost_information.xlsm"
    @keyfile = "#{File.dirname(__FILE__)}/#{PATH_TO_COSTING_DATA}/keyfile"
    @encrypted_file = "#{File.dirname(__FILE__)}/#{PATH_TO_COSTING_DATA}/costing_e.json"
    @plaintext_file = "#{File.dirname(__FILE__)}/#{PATH_TO_COSTING_DATA}/costing.json"
    @error_log = "#{File.dirname(__FILE__)}/#{PATH_TO_COSTING_DATA}/errors.json"
    @cost_output_file = "#{File.dirname(__FILE__)}/#{PATH_TO_COSTING_DATA}/cost_output.json"
  end

  #Initialize the singleton costing object.
  def load(key = nil, aws = false)
    @key = key
    if @key.nil?
      #load local keyfile for debugging.
      @key = load_local_keyfile()
    end
    if aws
      # Always use encrypted costing database when running in cloud (Amazon Web Service)
      @costing_database = decrypt_hash(@key, File.read(@encrypted_file))
    else
      if FileUtils.uptodate?(@encrypted_file, [@xlsx_path])
        puts "National Costing Excel Sheet is older than database, using stored encrypted database."
        @costing_database = decrypt_hash(@key, File.read(@encrypted_file))
      else
        puts "National Costing Excel Sheet is newer than database, recreating database using RSMeans..."
        self.recreate_database()
      end
    end
  end

  def load_local_keyfile()
    puts "loading local key"
    @key = nil
    if File.exist?(@keyfile)
      @key = File.read(@keyfile)
    end
    #If file could not be found or the key was black raise exception.
    puts @key
    if not File.exist?(@keyfile) or @key.nil? or @key.strip == ""
      raise("could not find nrcan's secret keyfile hash. Place secret hash key in this file:#{@keyfile}")
    end
    puts "this is the key #{@key}"
    return @key
  end

  def recreate_database()
    #Keeping track of start time.
    start = Time.now
    #set rs-means auth hash to nil.
    @auth_hash = nil
    #Create a hash to store items in excel database that could not be found in RSMeans api.
    @not_found_in_rsmeans_api = Array.new
    #Create costing database hash.
    @costing_database = Hash.new()
    #read secret rsmeans hash if already run.
    if File.exist?(@rs_means_auth_hash_path)
      @auth_hash = File.read(@rs_means_auth_hash_path).strip
    else
      #Try to authenticate with rs-means.
      self.authenticate_rs_means_v1()
    end

    #Load all data from excel
    self.load_data_from_excel()
    #Get materials costing from rs-means and adjust using costing scaling factors for material and labour.
    self.generate_materials_cost_database()
    #Generate construction cost database for all regions.
    self.generate_construction_cost_database()

    #Some user information.
    puts "the decryption key is:#{@key}"
    puts "Cost Database regenerated in #{Time.now - start} seconds"
    puts "#{@costing_database['rsmean_api_data'].size} Unique RSMeans items."
    puts "#{@costing_database['constructions_costs'].size} Costed Constructions."
    puts "#{@costing_database['raw']['rsmeans_locations'].size} Canadian Locations."

    #If there are errors, write to @error_log
    unless @costing_database['rs_mean_errors'].empty?
      File.open(@error_log, "w") do |f|
        f.write(JSON.pretty_generate(@costing_database['rs_mean_errors']))
      end
      puts "#{@costing_database['rs_mean_errors'].size} Errors in Parsing Costing! See #{@error_log} for listing of errors."
    end
    #Encrypt the database for public.
    self.encrypt_database(@key)
  end

  def authenticate_rs_means_v1()
    puts '
       Your RSMeans Bearer code is out of date. It usually lasts 60 minutes.  Please do the following.
       1. Use Chrome and go here https://dataapi-sb.gordian.com/swagger/ui/index.html#!/CostData-Assembly-Catalogs/CostdataAssemblyCatalogsGet
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
    #if m[:bearer].to_s.size != 934
    #  puts "this is the bearer #{m[:bearer]}"
    #  puts "this is the bearer #{m[:bearer].size}"
    #  abort "Bearer key is not 934 charecters long. Please ensure that you copied the full curl string from the API Explorer."
    #else
      #store auth_key in class variable
      @auth_hash = m[:bearer].to_s
      #Store to disk to subsequent runs if required.
      File.write(@rs_means_auth_hash_path, @auth_hash)
    #end
  end

  def load_data_from_excel
    @costing_database = {} if @costing_database.nil?
    unless File.exist?(@xlsx_path)
      raise("could not find the national_average_cost_information.xlsm in location #{@xlsx_path}. This is a proprietary file manage by Natural resources Canada.")
    end

    #Get Raw Data from files.
    @costing_database['rsmean_api_data']= Array.new
    @costing_database['constructions_costs']= Array.new
    @costing_database['raw'] = {}
    @costing_database['rs_mean_errors']=[]
    ['rsmeans_locations',
     'rsmeans_local_factors',
     'construction_sets',
     'constructions_opaque',
     'materials_opaque',
     'constructions_glazing',
     'materials_glazing',
     'Constructions',
     'ConstructionProperties',
     'lighting',
     'materials_lighting'
    ].each do |sheet|
      @costing_database['raw'][sheet] = convert_workbook_sheet_to_array_of_hashes(@xlsx_path, sheet)
    end

  end

  def generate_materials_cost_database

    [@costing_database['raw']['materials_glazing'], @costing_database['raw']['materials_opaque'], @costing_database['raw']['materials_lighting']].each do |mat_lib|
      [mat_lib].each do |materials|

        lookup_list = materials.map {|material|
          {'type' => material['type'],
           'catalog_id' => material['catalog_id'],
           'id' => material['id']}
        }

        lookup_list.each do |material|
          # check if it's already in our database with right catalog year.
          api_return = @costing_database['rsmean_api_data'].detect {|rs_means|
            rs_means['id'] == material['id'] and rs_means['catalog']['id'] == material['catalog_id']
          }
          unless api_return.nil?
            puts "skipping duplicate entry #{material["id"]}"
            next
          end

          auth = {:Authorization => "bearer #{@auth_hash}"}
          path = "https://dataapi-sb.gordian.com/v1/costdata/#{material['type'].downcase.strip}/catalogs/#{material['catalog_id'].strip}/costlines/#{material['id'].strip}"
          begin
            api_return = JSON.parse(RestClient.get(path, auth).body)
            @costing_database['rsmean_api_data'] << api_return

          rescue Exception => e
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
          raise('rs_means_database empty! ') if @costing_database['rsmean_api_data'].empty?
        end
      end

    end

  end

  def generate_construction_cost_database()
    @costing_database['constructions_costs']= Array.new
    counter = 0
    @costing_database['raw']['rsmeans_locations'].each do |location|
      puts "Costing for: #{location["province-state"]},#{location['city']}"
      @costing_database["raw"]['constructions_opaque'].each do |construction|
        cost_construction(construction, counter, location, 'opaque')
      end
      @costing_database["raw"]['constructions_glazing'].each do |construction|
        cost_construction(construction, counter, location, 'glazing')
      end
    end
  end

  def cost_audit_all(model)
    # JTB: This procedure in progress and not yet fully developed (or called)


    # Create a Hash to collect costing data.
    costing_report = {}
    # Create a Hash in the hash for categories of costing.
    costing_report["Building"] = {}
    costing_report["Envelope"] = {}
    costing_report["Lighting"] = {}
    costing_report["HVAC"] = {}
    costing_report["Totals"] = {}

    # Check to see if standards building type and the number of stories has been defined.  The former may be omitted in the future.
    if model.getBuilding.standardsBuildingType.empty? or model.getBuilding.standardsNumberOfAboveGroundStories.empty?
      raise("Building information is not complete, please ensure that the standardsBuildingType and standardsNumberOfAboveGroundStories are entered in the model. ")
    end

    # Store number of stories. Required for envelope costing logic.
    num_of_above_ground_stories = model.getBuilding.standardsNumberOfAboveGroundStories.to_i

    closest_loc = get_closest_cost_location(model.getWeatherFile.latitude, model.getWeatherFile.longitude)
    closest_city = closest_loc['city']
    closest_prov = closest_loc['province-state']

    costing_report["Building"]["BuildingType"] = model.getBuilding.standardsBuildingType.to_s
    costing_report["Building"]["WeatherProv"] = model.getWeatherFile.stateProvinceRegion
    costing_report["Building"]["WeatherCity"] = model.getWeatherFile.city
    costing_report["Building"]["ClosestProv"] = closest_prov
    costing_report["Building"]["ClosestCity"] = closest_city

    #envelope_cost = cost_audit_envelope(model, costing_report)

    #lighting_cost = cost_audit_lighting(model, costing_report)

  end

  def cost_audit_envelope(model)

    # Create a Hash to collect costing data.
    costing_report = {}
    # Create a Hash in the hash for categories of costing.
    costing_report["Building"] = {}
    costing_report["Envelope"] = {}
    costing_report["Lighting"] = {}
    costing_report["HVAC"] = {}
    costing_report["Totals"] = {}

    # Check to see if standards building type and the number of stories has been defined.  The former may be omitted in the future.
    if model.getBuilding.standardsBuildingType.empty? or model.getBuilding.standardsNumberOfAboveGroundStories.empty?
      raise("Building information is not complete, please ensure that the standardsBuildingType and standardsNumberOfAboveGroundStories are entered in the model. ")
    end

    # Store number of stories. Required for envelope costing logic.
    num_of_above_ground_stories = model.getBuilding.standardsNumberOfAboveGroundStories.to_i

    closest_loc = get_closest_cost_location(model.getWeatherFile.latitude, model.getWeatherFile.longitude)
    closest_city = closest_loc['city']
    closest_prov = closest_loc['province-state']

    costing_report["Building"]["BuildingType"] = model.getBuilding.standardsBuildingType.to_s
    costing_report["Building"]["WeatherProv"] = model.getWeatherFile.stateProvinceRegion
    costing_report["Building"]["WeatherCity"] = model.getWeatherFile.city
    costing_report["Building"]["ClosestProv"] = closest_prov
    costing_report["Building"]["ClosestCity"] = closest_city

    totEnvCost = 0

    # Iterate through the thermal zones.
    model.getThermalZones.each do |zone|
      # Iterate through spaces.
      zone.spaces.each do |space|
        # Get SpaceType defined for space.. if not defined it will skip the spacetype. May have to deal with Attic spaces.
        if space.spaceType.empty? or space.spaceType.get.standardsSpaceType.empty? or space.spaceType.get.standardsBuildingType.empty?
          raise ("standards Space type and building type is not defined for space:#{space.name.get}. Skipping this space for costing.")
        end

        # Get space type standard names.
        space_type = space.spaceType.get.standardsSpaceType
        building_type = space.spaceType.get.standardsBuildingType

        # Get standard constructions based on collected information (spacetype, no of stories, etc..)
        # This is a standard way to search a hash.
        construction_set = @costing_database['raw']['construction_sets'].select {|data|
          data['building_type'].to_s == building_type.to_s and
              data['space_type'].to_s == space_type.to_s and
              data['min_stories'].to_i <= num_of_above_ground_stories and
              data['max_stories'].to_i >= num_of_above_ground_stories
        }.first


        # Create Hash to store surfaces for this space by surface type
        surfaces = {}
        #Exterior
        exterior_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(space.surfaces, "Outdoors")
        surfaces["ExteriorWall"] = BTAP::Geometry::Surfaces::filter_by_surface_types(exterior_surfaces, "Wall")
        surfaces["ExteriorRoof"]= BTAP::Geometry::Surfaces::filter_by_surface_types(exterior_surfaces, "RoofCeiling")
        surfaces["ExteriorFloor"] = BTAP::Geometry::Surfaces::filter_by_surface_types(exterior_surfaces, "Floor")
        # Exterior Subsurface
        exterior_subsurfaces = BTAP::Geometry::Surfaces::get_subsurfaces_from_surfaces(exterior_surfaces)
        surfaces["ExteriorFixedWindow"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["FixedWindow"])
        surfaces["ExteriorOperableWindow"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["OperableWindow"])
        surfaces["ExteriorSkylight"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["Skylight"])
        surfaces["ExteriorTubularDaylightDiffuser"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["TubularDaylightDiffuser"])
        surfaces["ExteriorTubularDaylightDome"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["TubularDaylightDome"])
        surfaces["ExteriorDoor"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["Door"])
        surfaces["ExteriorGlassDoor"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["GlassDoor"])
        surfaces["ExteriorOverheadDoor"] = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(exterior_subsurfaces, ["OverheadDoor"])

        # Ground Surfaces
        ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(space.surfaces, "Ground")
        surfaces["GroundContactWall"] = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "Wall")
        surfaces["GroundContactRoof"] = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "RoofCeiling")
        surfaces["GroundContactFloor"] = BTAP::Geometry::Surfaces::filter_by_surface_types(ground_surfaces, "Floor")

        # These are the only envelope costing items we are considering for envelopes..
        costed_surfaces = [
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
        ]

        # Iterate through
        costed_surfaces.each do |surface_type|
          # Get Costs for this construction type. This will get the cost for the particular construction type
          # for all rsi levels for this location. This has been collected by RS means. Note that a space_type
          # of "- undefined -" will create a nil construction_set!
          if construction_set.nil?
            cost_range_hash = {}
          else
            cost_range_hash = @costing_database['constructions_costs'].select {|construction|
              construction['construction_type_name'] == construction_set[surface_type] &&
                  construction['province-state'] == closest_prov &&
                  construction['city'] == closest_city
            }
          end

          # We don't need all the information, just the rsi and cost. However, for windows rsi = 1/u_w_per_m2_k
          surfaceIsGlazing = (surface_type == 'ExteriorFixedWindow' || surface_type == 'ExteriorOperableWindow' ||
                          surface_type == 'ExteriorSkylight' || surface_type == 'ExteriorTubularDaylightDiffuser' ||
                          surface_type == 'ExteriorTubularDaylightDome' || surface_type == 'ExteriorGlassDoor')
          if surfaceIsGlazing
            cost_range_array = cost_range_hash.map {|cost|
              [
                  (1.0/cost['u_w_per_m2_k'].to_f),
                  cost['total_cost_with_op']
              ]
            }
          else
            cost_range_array = cost_range_hash.map {|cost|
              [
                  cost['rsi_k_m2_per_w'],
                  cost['total_cost_with_op']
              ]
            }
          end
          # Sorted based on rsi.
          cost_range_array.sort! {|a, b| a[0] <=> b[0]}

          # Iterate through actual surfaces in the model of surface_type.
          numSurfType = 0
          surfaces[surface_type].each do |surface|
            numSurfType = numSurfType + 1

            # Get RSI of existing model surface (actually returns rsi for glazings too!).
            rsi = BTAP::Resources::Envelope::Constructions::get_rsi(OpenStudio::Model::getConstructionByName(surface.model, surface.construction.get.name.to_s).get)

            # Use the cost_range_array to interpolate the estimated cost for the given rsi.
            # Note that window costs in RS Means use U-value, which was converted to rsi for cost_range_array above
            cost = interpolate(cost_range_array, rsi)

            # If the cost is nil, that means the rsi is out of range. Flag in the report.
            if cost.nil?
              if !cost_range_array.empty?
                notes = "RSI out of the range (#{'%.2f' % rsi}) or cost is 0!. Range for #{construction_set[surface_type]} is #{'%.2f' % cost_range_array.first[0]}-#{'%.2f' % cost_range_array.last[0]}."
                cost = 0.0
              else
                notes = "Cost is 0!"
                cost = 0.0
              end
            else
              notes = "OK"
            end

            surfArea = (surface.netArea * zone.multiplier)
            surfCost = cost * surface.netArea * zone.multiplier
            totEnvCost = totEnvCost + surfCost

            # Bin the costing by construction standard type and rsi
            if construction_set.nil?
              name = "undefined space type_#{rsi}"
            else
              name = "#{construction_set[surface_type]}_#{rsi}"
            end
            if costing_report['Envelope'].has_key?(name)
              costing_report['Envelope'][name]['area'] += surfArea
              costing_report['Envelope'][name]['cost'] += surfCost
              costing_report['Envelope'][name]['note'] += " / #{numSurfType}: #{notes}"
            else
              costing_report['Envelope'][name]={'area' => surfArea,
                                                'cost' => surfCost}
              costing_report['Envelope'][name]['note'] = "Surf ##{numSurfType}: #{notes}"
            end
          end # surfaces of surface type
        end # surface_type
      end # spaces
    end # thermalzone

    costing_report['Envelope']['TotalEnvelopeCost'] = totEnvCost

    # Save the costing_report to a file.
    File.open(@cost_output_file, "w") do |f|
      f.write(JSON.pretty_generate(costing_report))
    end

    puts "\nCost report file cost_output.json successfully generated.\nLocation: #{@cost_output_file}"

    return totEnvCost

  end

  def cost_audit_lighting(model, costing_report)



  end


  #This will convert a sheet in a given workbook into an array of hashes with the headers as symbols.
  def convert_workbook_sheet_to_array_of_hashes(xlsx_path, sheet_name)
    #Load Constructions data sheet from workbook and convert to a csv object.
    data = Roo::Spreadsheet.open(xlsx_path).sheet(sheet_name).to_csv
    csv = CSV.new(data, {headers: true})
    return csv.to_a.map {|row| row.to_hash}
  end

  def cost_construction(construction, counter, location, type = 'opaque')

    material_layers = "material_#{type}_id_layers"
    material_id = "materials_#{type}_id"
    materials_database = @costing_database["raw"]["materials_#{type}"]

    total_with_op = 0.0
    material_cost_pairs = []
    construction[material_layers].split(',').reject {|c| c.empty?}.each do |material_index|
      material = materials_database.find { |data| data[material_id].to_s == material_index.to_s }
      if material.nil?
        puts "material error..could not find material #{material_index} in #{materials_database}"
        raise()
      else
        rs_means_data = @costing_database['rsmean_api_data'].detect {|data| data['id'].to_s.upcase == material['id'].to_s.upcase}
        if rs_means_data.nil?
          puts "This material id #{material['id']} was not found in the rs-means api. Skipping. This construction will be inaccurate. "
          raise()
        else
          regional_material, regional_installation = get_regional_cost_factors(location['province-state'], location['city'], material)

          # Get RSMeans cost information from lookup.
          # Note that "glazing" types don't have a 'quantity' hash entry!
          # Don't need "and" below but using in-case this hash field is added in the future.
          if type == 'glazing' and material['quantity'].to_f == 0.0
            material['quantity'] = '1.0'
          end
          material_cost = rs_means_data['baseCosts']['materialOpCost'].to_f * material['quantity'].to_f * material['material_mult'].to_f
          labour_cost = rs_means_data['baseCosts']['labourOpCost'].to_f * material['labour_mult'].to_f
          equipment_cost = rs_means_data['baseCosts']['equipmentOpCost'].to_f
          layer_cost = ((material_cost * regional_material / 100.0) + (labour_cost * regional_installation / 100.0) + equipment_cost).round(2)
          material_cost_pairs << {material_id.to_s => material_index,
                                  'cost' => layer_cost}
          total_with_op += layer_cost
        end
      end
    end
    new_construction = {
        'index' => counter,
        'province-state' => location['province-state'],
        'city' => location['city'],
        "construction_type_name" => construction["construction_type_name"],
        'description' => construction["description"],
        'intended_surface_type' => construction["intended_surface_type"],
        'standards_construction_type' => construction["standards_construction_type"],
        'rsi_k_m2_per_w' => construction['rsi_k_m2_per_w'].to_f,
        'zone' => construction['climate_zone'],
        'fenestration_type' => construction['fenestration_type'],
        'u_w_per_m2_k' => construction['u_w_per_m2_k'],
        'materials' => material_cost_pairs,
        'total_cost_with_op' => total_with_op}

    @costing_database['constructions_costs'] << new_construction
  end

  def get_regional_cost_factors(provinceState, city, material)
    @costing_database['raw']['rsmeans_local_factors'].select { |code|
      code['province-state'] == provinceState && code['city'] == city }.each do |code|
      id = material['id'].to_s
      prefixes = code['code_prefixes'].split(',')
      prefixes.each do |prefix|
        if id.start_with?(prefix.strip)
          return code['material'].to_f, code['installation'].to_f
        end
      end
    end
    error = [material, "Could not find regional adjustment factor for rs-means material used in #{city}, #{provinceState}."]
    @costing_database['rs_mean_errors'] << error unless @costing_database['rs_mean_errors'].include?(error)
    return 100.0, 100.0
  end

  def encrypt_database(key)
    #Write public cost information to a json file. This will be used by the standards and measures. To create
    #create the openstudio construction names and costing objects.
    File.open(@encrypted_file, "w") do |f|
      f.write(encrypt_hash(key, @costing_database))
    end
    File.open(@plaintext_file, "w") do |f|
      f.write( JSON.pretty_generate(@costing_database))
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

  # Interpolate array of hashes that contain 2 values (key=rsi, data=cost)
  def interpolate(x_y_array, x2)
    array = x_y_array.sort { |a, b| a[0] <=> b[0] }

    # Check if value x2 is within range of array for interpolation
    # Extrapolate when x2 is out-of-range by +/- 10% of end values.
    if array.empty? || x2 < (0.9 * array.first[0].to_f) || x2 > (1.1 * array.last[0].to_f)
      return nil
    elsif x2 < array.first[0].to_f
      # Extrapolate down using first cost value to this out-of-range input
      return array.first[1].to_f
    elsif x2 > array.last[0].to_f
      # Extrapolate up using last cost value to this out-of-range input
      return array.last[1].to_f
    else
      array.each_index do |counter|

        # skip last value.
        next if array[counter] == array.last

        x0 = array[counter][0]
        y0 = array[counter][1]
        x1 = array[counter + 1][0]
        y1 = array[counter + 1][1]

        # skip to next if x2 is not between x0 and x1
        next if x2 < x0 || x2 > x1

        # Do interpolation
        y2 = y0 # just in-case x0, x1 and x2 are identical!
        if(x1 - x0) > 0.0
          y2 = y0.to_f + ((y1 - y0).to_f * (x2 - x0).to_f / (x1 - x0).to_f)
        end
        return y2
      end
    end
  end

  # Enter in [latitude, longitude] for each loc and this method will return the distance.
  def distance(loc1, loc2)
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

  def get_closest_cost_location(lat, long)
    dist = 1000000000000000000000.0
    closest_loc = nil
    # province-state	city	latitude	longitude	source
    @costing_database['raw']['rsmeans_locations'].each do |location|
      if distance([lat, long], [location['latitude'].to_f, location['longitude'].to_f]) < dist
        closest_loc = location
        dist = distance([lat, long], [location['latitude'].to_f, location['longitude'].to_f])
      end
    end
    return closest_loc
  end

  # This will expand the two letter province abbreviation to a full uppercase province name
  def expandProvAbbrev(abbrev)

    # Note that the proper abbreviation for Quebec is QC not PQ. However, we've used PQ in openstudio-standards!
    Hash provAbbrev = {"AB" => "ALBERTA",
                       "BC" => "BRITISH COLUMBIA",
                       "MB" => "MANITOBA",
                       "NB" => "NEW BRUNSWICK",
                       "NL" => "NEWFOUNDLAND AND LABRADOR",
                       "NT" => "NORTHWEST TERRITORIES",
                       "NS" => "NOVA SCOTIA",
                       "NU" => "NUNAVUT",
                       "ON" => "ONTARIO",
                       "PE" => "PRINCE EDWARD ISLAND",
                       "PQ" => "QUEBEC",
                       "SK" => "SASKATCHEWAN",
                       "YT" => "YUKON"
    }
    return provAbbrev[abbrev]
  end

end











