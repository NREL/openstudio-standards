require_relative 'minitest_helper'

def create_baseline_model(model_name, standard, climate_zone, building_type, debug)

  # Make a directory to save the resulting models
  test_dir = "#{File.dirname(__FILE__)}/output"
  if !Dir.exists?(test_dir)
    Dir.mkdir(test_dir)
  end

  # Load the test model
  translator = OpenStudio::OSVersion::VersionTranslator.new
  path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/performance_rating_method/#{model_name}.osm")
  model = translator.loadModel(path)
  model = model.get

  # Check if there's a need to set the weather


  # 'ASHRAE 169-2006-6A', 'ASHRAE 169-2006-6B', 'ASHRAE 169-2006-7A',
  # 'ASHRAE 169-2006-7B', 'ASHRAE 169-2006-8A', 'ASHRAE 169-2006-8B'
  if model.weatherFile.empty?
    epw_name = nil
    base_rel_path = '../../data/weather/'
    case climate_zone
      when 'ASHRAE 169-2006-1A'
        epw_name = 'USA_FL_Miami.Intl.AP.722020_TMY3.epw'
      when 'ASHRAE 169-2006-1B'
        epw_name = 'USA_AZ_Phoenix-Sky.Harbor.Intl.AP.722780_TMY3.epw'
      when 'ASHRAE 169-2006-2A'
        epw_name = 'USA_TX_Houston-Bush.Intercontinental.AP.722430_TMY3.epw'
      when 'ASHRAE 169-2006-2B'
        epw_name = 'USA_AZ_Phoenix-Sky.Harbor.Intl.AP.722780_TMY3.epw'
      when 'ASHRAE 169-2006-3A'
        epw_name = 'USA_TN_Memphis.Intl.AP.723340_TMY3.epw' # or GA-Atlanta
      when 'ASHRAE 169-2006-3B'
        epw_name = 'USA_TX_El.Paso.Intl.AP.722700_TMY3.epw' # CA-Los Angeles or NV-Las Vegas
      when 'ASHRAE 169-2006-3C'
        epw_name = 'USA_CA_San.Francisco.Intl.AP.724940_TMY3.epw'
      when 'ASHRAE 169-2006-4A'
        epw_name = 'USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw' # or USA_OR_Salem-McNary.Field.726940_TMY3.epw
      when 'ASHRAE 169-2006-4B'
        epw_name = 'USA_NM_Albuquerque.Intl.AP.723650_TMY3.epw' # or USA_ID_Boise.Air.Terminal.726810_TMY3.epw
      when 'ASHRAE 169-2006-4C'
        epw_name = nil # WA-Seattle
      when 'ASHRAE 169-2006-5A'
        epw_name = 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw' # or USA_VT_Burlington.Intl.AP.726170_TMY3.epw
      when 'ASHRAE 169-2006-5B'
        epw_name = nil # CO Boulder
      when 'ASHRAE 169-2006-5C'
        epw_name = nil
      when 'ASHRAE 169-2006-6A'
        epw_name = nil # MN-Minneapolis
      when 'ASHRAE 169-2006-6B'
        epw_name = 'USA_MT_Helena.Rgnl.AP.727720_TMY3.epw'
      when 'ASHRAE 169-2006-7A'
        epw_name = 'USA_MN_Duluth.Intl.AP.727450_TMY3.epw'
      when 'ASHRAE 169-2006-7B'
        epw_name = nil
      when 'ASHRAE 169-2006-8A'
        epw_name = 'USA_AK_Fairbanks.Intl.AP.702610_TMY3.epw'
      when 'ASHRAE 169-2006-8B'
        epw_name = nil
      else
        puts "No Weather file set, and CANNOT locate #{climate_zone}"
        return false
    end
    if epw_name.nil?
      puts "No Weather file set, and CANNOT locate #{climate_zone}"
    else
      rel_path = base_rel_path + epw_name
      weather_file =  File.expand_path(rel_path, __FILE__)
      weather = BTAP::Environment::WeatherFile.new(weather_file)
      #Set Weather file to model.
      success = weather.set_weather_file(model)
      if success
        puts "Set Weather file to '#{weather_file}'"
      else
        puts "Failed to set the weather file"
        return false
      end
    end
  end


  # Create a directory for the test result
  osm_directory = "#{test_dir}/#{model_name}-#{standard}-#{climate_zone}"
  if !Dir.exists?(osm_directory)
    Dir.mkdir(osm_directory)
  end

  # Open a channel to log info/warning/error messages
  msg_log = OpenStudio::StringStreamLogSink.new
  if debug
    msg_log.setLogLevel(OpenStudio::Debug)
  else
    msg_log.setLogLevel(OpenStudio::Info)
  end

  # Create the baseline model from the
  # supplied proposed test model
  model.create_performance_rating_method_baseline_building(building_type,standard,climate_zone,osm_directory,debug = false)

  # Show the output messages
  msg_log.logMessages.each do |msg|
    # DLM: you can filter on log channel here for now
    if /openstudio.*/.match(msg.logChannel) #/openstudio\.model\..*/
      # Skip certain messages that are irrelevant/misleading
      next if msg.logMessage.include?("Skipping layer") || # Annoying/bogus "Skipping layer" warnings
          msg.logChannel.include?("runmanager") || # RunManager messages
          msg.logChannel.include?("setFileExtension") || # .ddy extension unexpected
          msg.logChannel.include?("Translator") || # Forward translator and geometry translator
          msg.logMessage.include?("UseWeatherFile") # 'UseWeatherFile' is not yet a supported option for YearDescription

      # Report the message in the correct way
      if msg.logLevel == OpenStudio::Info
        puts(msg.logMessage)
      elsif msg.logLevel == OpenStudio::Warn
        puts("WARNING - [#{msg.logChannel}] #{msg.logMessage}")
      elsif msg.logLevel == OpenStudio::Error
        puts("ERROR - [#{msg.logChannel}] #{msg.logMessage}")
      elsif msg.logLevel == OpenStudio::Debug && debug
        puts("DEBUG - #{msg.logMessage}")
      end
    end
  end

  # Save the test model
  model.save(OpenStudio::Path.new("#{osm_directory}/#{model_name}_baseline.osm"), true)

  return model

end

class TestRun01 < Minitest::Test
	#Standard Design Exterior Envelope Test
	#The prototype model is Small_Office, CZ2, with the following variations:
	#	- Low-Slope Concrete Roof with U-Value 0.065 IP, solar reflectance 0.75 and thermal emittance 0.78
	#	- Wood-framed wall with U-Value 0.095 IP
	#	- Windows with U-Value 0.25 IP, SHGC 0.2 and VT 0.45
	
	model_name = 'Run01_Prototype'
	standard = '90.1-2010'
	climate_zone = 'ASHRAE 169-2006-2A'
	building_type = 'SmallOffice'

	@@model = create_baseline_model(model_name, standard, climate_zone, building_type, false)
	
	def setup
		assert_instance_of OpenStudio::Model::Model, @@model
	end

	def test_901_2010_run01_test02
		#Testing the baseline roof, wall and floor U-Value
		
		extwall = @@model.getSurfaceByName('Perimeter_ZN_3_wall_north').get
		floor = @@model.getSurfaceByName('Perimeter_ZN_1_floor').get
		roof = @@model.getSurfaceByName('Perimeter_ZN_2_roof').get
		
		extwall_uFactor_SI = extwall.uFactor.get
		extwall_uFactor_IP = OpenStudio.convert(extwall_uFactor_SI, 'W/m^2*K','Btu/h*ft^2*R').get
		
		floor_uFactor_SI = floor.uFactor.get
		floor_uFactor_IP = OpenStudio.convert(floor_uFactor_SI, 'W/m^2*K','Btu/h*ft^2*R').get
		
		roof_uFactor_SI = roof.uFactor.get
		roof_uFactor_IP = OpenStudio.convert(roof_uFactor_SI, 'W/m^2*K','Btu/h*ft^2*R').get
		
		assert_in_delta(0.124, extwall_uFactor_IP, 0.001, "Exterior Walls have a U-Value of #{extwall_uFactor_IP} BTU/h.ft^2.R when 0.124 BTU/h.ft^2.R was expected (CZ2, Steel-Framed)")
		#Floor is slab-on-grade with an F-Factor of 0.73, which according to table A6.3 means no added insulation.
		#assert_in_delta(0.052, floor_uFactor_IP, 0.001, "Floor has a U-Value of #{floor_uFactor_IP} BTU/h.ft^2.R when 0.052 BTU/h.ft^2.R was expected (CZ2, Steel-Joist)")
		assert_in_delta(0.048, roof_uFactor_IP, 0.001, "Roof has a U-Value of #{roof_uFactor_IP} BTU/h.ft^2.R when 0.048 BTU/h.ft^2.R was expected (CZ2, IEAD)")		
	end
	
	def test_901_2010_run01_test04	
		#Testing the baseline roof solar reflectance and thermal emittance/absorptance
		
		roof = @@model.getSurfaceByName('Perimeter_ZN_2_roof').get
		roof_cons_name = roof.construction.get.name.get
		roof_cons = @@model.getConstructionByName(roof_cons_name).get
		
		roof_top_layer_name = roof_cons.getLayer(0).name.get
		roof_top_layer = @@model.getOpaqueMaterialByName(roof_top_layer_name).get
		
		roof_sol_ref = roof_top_layer.solarReflectance.get
		roof_th_em = roof_top_layer.thermalAbsorptance
		
		assert_in_delta(0.55, roof_sol_ref, 0.001, "Roof has a solar reflectance of #{roof_sol_ref} when 0.55 was expected.")
		assert_in_delta(0.75, roof_th_em, 0.001, "Roof has a thermal emittance of #{roof_th_em} when 0.75 was expected.")
	end
		
	def test_901_2010_run01_test05_1
		#Testing the baseline windows U-Value
		
		window_name = 'Perimeter_ZN_3_wall_north_Window_1'.upcase
		
		sql = @@model.sqlFile.get
		
		uFactor_query = "SELECT Value FROM TabularDataWithStrings WHERE (ReportName='EnvelopeSummary') AND (ColumnName='Glass U-Factor') AND (RowName = '#{window_name}')"		
		glass_uFactor_SI = sql.execAndReturnFirstDouble(uFactor_query).get
		
		glass_area_query = "SELECT Value FROM TabularDataWithStrings WHERE (ReportName='EnvelopeSummary') AND (ColumnName='Glass Area') AND (RowName = '#{window_name}')"
		glass_area = sql.execAndReturnFirstDouble(glass_area_query).get
		
		frame_area_query = "SELECT Value FROM TabularDataWithStrings WHERE (ReportName='EnvelopeSummary') AND (ColumnName='Frame Area') AND (RowName = '#{window_name}')"
		frame_area = sql.execAndReturnFirstDouble(frame_area_query).get
		
		frame_uFactor_query = "SELECT Value FROM TabularDataWithStrings WHERE (ReportName='EnvelopeSummary') AND (ColumnName='Frame Conductance') AND (RowName = '#{window_name}')"
		frame_uFactor_SI = sql.execAndReturnFirstDouble(frame_uFactor_query).get
		
		window_uFactor_SI = (glass_uFactor_SI * glass_area + frame_uFactor_SI * frame_area) / (glass_area + frame_area)
		window_uFactor_IP = OpenStudio.convert(window_uFactor_SI, 'W/m^2*K','Btu/h*ft^2*R').get
		
		assert_in_delta(0.75, window_uFactor_IP, 0.001, "Window has a U-Value of #{window_uFactor_IP} BTU/h.ft^2.R when 0.75 BTU/h.ft^2.R was expected (CZ2)")
		assert_in_delta(0.25, window_SHGC, 0.001, "Window has a SHGC of #{window_SHGC} when 0.25 was expected (CZ2")
	end
	
	def test_901_2010_run01_test05_2
		#Testing the baseline window SHGC
		
		window_name = 'Perimeter_ZN_3_wall_north_Window_1'.upcase
		
		sql = @@model.sqlFile.get
		
		shgc_query = "SELECT Value FROM TabularDataWithStrings WHERE (ReportName='EnvelopeSummary') AND (ColumnName='Glass SHGC') AND (RowName = '#{window_name}')"
		glass_SHGC = sql.execAndReturnFirstDouble(shgc_query).get
		
		window_SHGC = glass_SHGC
		#Have to find a way to get to the whole-window SHGC, although right now, the frame area is 0 so it might be the same as glass_SHGC.    
		
		assert_in_delta(0.25, window_SHGC, 0.001, "Window has a SHGC of #{window_SHGC} when 0.25 was expected (CZ2")
		
	end

end

class TestRun02 < Minitest::Test
	#Standard Design Exterior Envelope Test
	#The prototype model is Small_Office, CZ3, with the following variations:
	#	- Steep-Slope Metal Roof with U-Value 0.055 IP, solar reflectance 0.60 and thermal emittance 0.70
	#	- Metal-framed wall with U-Value 0.056 IP
	#	- Slab on grade floor F 0.261 (with assumed fully insulated slab with R20)
	#   - 2ft overhangs on south windows / 2ft fins on west windows
	
	model_name = 'Run02_Prototype'
	standard = '90.1-2010'
	climate_zone = 'ASHRAE 169-2006-3A'
	building_type = 'SmallOffice'

	@@model = create_baseline_model(model_name, standard, climate_zone, building_type, false)
	
	def setup
		assert_instance_of OpenStudio::Model::Model, @@model
	end

	def test_901_2010_run02_test03
		#Testing the baseline roof, wall and floor U-Value
		
		extwall = @@model.getSurfaceByName('Perimeter_ZN_3_wall_north').get
		floor = @@model.getSurfaceByName('Perimeter_ZN_1_floor').get
		roof = @@model.getSurfaceByName('Perimeter_ZN_2_roof_2').get
		
		extwall_uFactor_SI = extwall.uFactor.get
		extwall_uFactor_IP = OpenStudio.convert(extwall_uFactor_SI, 'W/m^2*K','Btu/h*ft^2*R').get
		
		floor_uFactor_SI = floor.uFactor.get
		floor_uFactor_IP = OpenStudio.convert(floor_uFactor_SI, 'W/m^2*K','Btu/h*ft^2*R').get
		
		roof_uFactor_SI = roof.uFactor.get
		roof_uFactor_IP = OpenStudio.convert(roof_uFactor_SI, 'W/m^2*K','Btu/h*ft^2*R').get
		
		assert_in_delta(0.084, extwall_uFactor_IP, 0.001, "Exterior Walls have a U-Value of #{extwall_uFactor_IP} BTU/h.ft^2.R when 0.084 BTU/h.ft^2.R was expected (CZ3, Steel-Framed)")
		#Floor is slab-on-grade with an F-Factor of 0.73, which according to table A6.3 means no added insulation.
		#assert_in_delta(0.038, floor_uFactor_IP, 0.001, "Floor has a U-Value of #{floor_uFactor_IP} BTU/h.ft^2.R when 0.052 BTU/h.ft^2.R was expected (CZ4, Steel-Joist)")
		assert_in_delta(0.048, roof_uFactor_IP, 0.001, "Roof has a U-Value of #{roof_uFactor_IP} BTU/h.ft^2.R when 0.048 BTU/h.ft^2.R was expected (CZ3, IEAD)")
	end
	
	def test_901_2010_run02_test04
		#Testing the F-factor of the floor. The floor has a F-Factor of 0.73, which according to table A6.3 means no added insulation.
		
		floor_cons = @@model.getLayeredConstructionByName('ext-slab-mass').get		
		num_layer = floor_cons.numLayers
		
		#The insulation should be removed from the construction, which means only 2 layers in the baseline model.
		assert_equal(2, num_layer, "Floor construction has #{num_layer} when only 2 were expected (no insulation).")
	end
	
	def test_901_2010_run02_test05	
		#Testing the baseline roof solar reflectance and thermal emittance/absorptance
		
		roof = @@model.getSurfaceByName('Perimeter_ZN_2_roof_2').get
		roof_cons_name = roof.construction.get.name.get
		roof_cons = @@model.getConstructionByName(roof_cons_name).get
		
		roof_top_layer_name = roof_cons.getLayer(0).name.get
		roof_top_layer = @@model.getOpaqueMaterialByName(roof_top_layer_name).get
		
		roof_sol_ref = roof_top_layer.solarReflectance.get
		roof_th_em = roof_top_layer.thermalAbsorptance
		
		assert_in_delta(0.30, roof_sol_ref, 0.001, "Roof has a solar reflectance of #{roof_sol_ref} when 0.30 was expected (steep roof).")
		assert_in_delta(0.90, roof_th_em, 0.001, "Roof has a thermal emittance of #{roof_th_em} when 0.90 was expected (steep roof).")
	end
		
	def test_901_2010_run02_test06
		#Testing that the overhangs on southern facade and fins on west facade have been removed
		shadings = @@model.getShadingSurfaces
		number_of_shading = shadings.count

		assert_empty(shadings, "There is/are #{number_of_shading} shading objects when 0 was expected.")
	end

end

class TestRun03 < Minitest::Test
	#Standard Design Exterior Envelope Test
	#The prototype model is Small_Hotel, CZ6, with the following variations:
	#	- Low-Slope Metal Roof U-Value 0.055 IP / Solar ref. 0.6 / Thermal Em. 0.70
	#	- Metal-framed wall with U-Value 0.8 IP
	#   - Mass floor with U-Value 0.052
	#	- Fixed Window with U-Value 0.25 / SHGC 0.2 / VT 0.47
	#   - Operable Window in guest room with U-Value 0.42 / SHGC 0.18 / VT 0.35
	
	model_name = 'Run03_Prototype'
	standard = '90.1-2010'
	climate_zone = 'ASHRAE 169-2006-6A'
	building_type = 'SmallHotel'

	@@model = create_baseline_model(model_name, standard, climate_zone, building_type, false)
	
	def setup
		assert_instance_of OpenStudio::Model::Model, @@model
	end
	
	def test_901_2010_run03_test03
		#Testing the baseline roof, wall and floor U-Value
		extwall = @@model.getSurfaceByName('W_FrontLoungeFlr1_5_0_0').get
		floor = @@model.getSurfaceByName('S_FrontLoungeFlr1_0_0_0').get
		roof = @@model.getSurfaceByName('SouthRoof').get
		
		extwall_uFactor_SI = extwall.uFactor.get
		extwall_uFactor_IP = OpenStudio.convert(extwall_uFactor_SI, 'W/m^2*K','Btu/h*ft^2*R').get
		
		floor_uFactor_SI = floor.uFactor.get
		floor_uFactor_IP = OpenStudio.convert(floor_uFactor_SI, 'W/m^2*K','Btu/h*ft^2*R').get
		
		roof_uFactor_SI = roof.uFactor.get
		roof_uFactor_IP = OpenStudio.convert(roof_uFactor_SI, 'W/m^2*K','Btu/h*ft^2*R').get
		
		assert_in_delta(0.064, extwall_uFactor_IP, 0.001, "Exterior Walls have a U-Value of #{extwall_uFactor_IP} BTU/h.ft^2.R when 0.064 BTU/h.ft^2.R was expected (CZ6, Steel-Framed)")
		#Floor is slab-on-grade with an F-Factor of 0.73, which according to table A6.3 means no added insulation.
		#assert_in_delta(0.038, floor_uFactor_IP, 0.001, "Floor has a U-Value of #{floor_uFactor_IP} BTU/h.ft^2.R when 0.052 BTU/h.ft^2.R was expected (CZ4, Steel-Joist)")
		assert_in_delta(0.048, roof_uFactor_IP, 0.001, "Roof has a U-Value of #{roof_uFactor_IP} BTU/h.ft^2.R when 0.048 BTU/h.ft^2.R was expected (CZ6, IEAD)")
	
	end
	
	def test_901_2010_run03_test04	
		#Testing the baseline roof solar reflectance and thermal emittance/absorptance
		
		roof = @@model.getSurfaceByName('SouthRoof').get
		roof_cons_name = roof.construction.get.name.get
		roof_cons = @@model.getConstructionByName(roof_cons_name).get
		
		roof_top_layer_name = roof_cons.getLayer(0).name.get
		roof_top_layer = @@model.getOpaqueMaterialByName(roof_top_layer_name).get
		
		roof_sol_ref = roof_top_layer.solarReflectance.get
		roof_th_em = roof_top_layer.thermalAbsorptance
		
		assert_in_delta(0.30, roof_sol_ref, 0.001, "Roof has a solar reflectance of #{roof_sol_ref} when 0.30 was expected (building in CZ6).")
		assert_in_delta(0.90, roof_th_em, 0.001, "Roof has a thermal emittance of #{roof_th_em} when 0.90 was expected (building in CZ6).")
	end
	
	def test_901_2010_run03_test05
		#Testing the baseline windows U-Value
		
		windows = ['W_FrontLoungeFlr1_5_0_0_0_4'.upcase, 'W_GuestRoom302_305_5_0_0_0_2'.upcase]		
		
		sql = @@model.sqlFile.get
		
		windows.each do |window|
			uFactor_query = "SELECT Value FROM TabularDataWithStrings WHERE (ReportName='EnvelopeSummary') AND (ColumnName='Glass U-Factor') AND (RowName = '#{window}')"		
			glass_uFactor_SI = sql.execAndReturnFirstDouble(uFactor_query).get
			
			glass_area_query = "SELECT Value FROM TabularDataWithStrings WHERE (ReportName='EnvelopeSummary') AND (ColumnName='Glass Area') AND (RowName = '#{window}')"
			glass_area = sql.execAndReturnFirstDouble(glass_area_query).get
			
			frame_area_query = "SELECT Value FROM TabularDataWithStrings WHERE (ReportName='EnvelopeSummary') AND (ColumnName='Frame Area') AND (RowName = '#{window}')"
			frame_area = sql.execAndReturnFirstDouble(frame_area_query).get
			
			frame_uFactor_query = "SELECT Value FROM TabularDataWithStrings WHERE (ReportName='EnvelopeSummary') AND (ColumnName='Frame Conductance') AND (RowName = '#{window}')"
			frame_uFactor_SI = sql.execAndReturnFirstDouble(frame_uFactor_query).get
			
			window_uFactor_SI = (glass_uFactor_SI * glass_area + frame_uFactor_SI * frame_area) / (glass_area + frame_area)
			window_uFactor_IP = OpenStudio.convert(window_uFactor_SI, 'W/m^2*K','Btu/h*ft^2*R').get
			
			assert_in_delta(0.35, window_uFactor_IP, 0.001, "Window has a U-Value of #{window_uFactor_IP} BTU/h.ft^2.R when 0.35 BTU/h.ft^2.R was expected (CZ6)")
			assert_in_delta(0.40, window_SHGC, 0.001, "Window has a SHGC of #{window_SHGC} when 0.40 was expected (CZ6)")
		end
	end

end

class TestRun05 < Minitest::Test
	#Standard Design Fenestration Test
	#The prototype model is Large_Office, CZ2, with the following variations:
	#	- Window-to-wall Ratio 52%
	#	- Building rotated 15deg East
	
	model_name = 'Run05_Prototype'
	standard = '90.1-2010'
	climate_zone = 'ASHRAE 169-2006-2A'
	building_type = 'LargeOffice'

	@@model = create_baseline_model(model_name, standard, climate_zone, building_type, false)
	
	def setup
		assert_instance_of OpenStudio::Model::Model, @@model
	end
	
	def test_901_2010_run06_test01
		#Testing the WWR per orientation by checking the area of 4 windows (N/S/E/W)
		#This could be more explicit but here is the reasoning behind the area test
		#North and South Facade are 289.52m2. East and West Facade are 193.01m2.
		#WWR in baseline, to keep the same proportion should be: WWR_baseline = WWR_initial * 40/46
		
		north_window_name = "Perimeter_mid_ZN_3_Wall_North_Window"
		east_window_name = "Perimeter_mid_ZN_2_Wall_East_Window"
		south_window_name = "Perimeter_mid_ZN_1_Wall_South_Window"
		west_window_name = "Perimeter_mid_ZN_4_Wall_West_Window"
		
		north_window = @@model.getSubSurfaceByName(north_window_name).get
		east_window = @@model.getSubSurfaceByName(east_window_name).get
		south_window = @@model.getSubSurfaceByName(south_window_name).get
		west_window = @@model.getSubSurfaceByName(west_window_name).get
		
		north_window_WWR = north_window.grossArea / 289.52
		east_window_WWR = east_window.grossArea / 193.01
		south_window_WWR = south_window.grossArea / 289.52
		west_window_WWR = west_window.grossArea / 193.01
		
		total_WWR = (north_window.grossArea+east_window.grossArea+south_window.grossArea+west_window.grossArea)/(289.52*2+193.01*2)
		
		assert_in_delta(0.40, north_window_WWR, 0.01, "North facade have a WWR of #{north_window_WWR} when 0.4 was expected.")
		assert_in_delta(0.40, east_window_WWR, 0.01, "East facade have a WWR of #{north_window_WWR} when 0.4 was expected.")
		assert_in_delta(0.40, south_window_WWR, 0.01, "South facade have a WWR of #{north_window_WWR} when 0.4 was expected.")
		assert_in_delta(0.40, west_window_WWR, 0.01, "West facade have a WWR of #{north_window_WWR} when 0.4 was expected.")
		
		assert_in_delta(total_WWR, 0.4, 0.01, "Whole building has a WWR of #{total_WWR} when 0.4 was expected.")
	
	end
	
end

class TestRun06 < Minitest::Test
	#Standard Design Fenestration Test
	#The prototype model is Large_Office, CZ2, with the following variations:
	#WWR per orientation: North 50%, West 50%, South 40%, East 45% (Total of 46%)
	#South facade have overhangs with projection factor or 0.5
	
	model_name = 'Run06_Prototype'
	standard = '90.1-2010'
	climate_zone = 'ASHRAE 169-2006-2A'
	building_type = 'LargeOffice'
	
	@@model = create_baseline_model(model_name, standard, climate_zone, building_type, false)
	
	def setup
		assert_instance_of OpenStudio::Model::Model, @@model
	end
	
	def test_901_2010_run06_test01
		#Testing the WWR per orientation by checking the area of 4 windows (N/S/E/W)
		#This could be more explicit but here is the reasoning behind the area test
		#North and South Facade are 289.52m2. East and West Facade are 193.01m2.
		#WWR in baseline, to keep the same proportion should be: WWR_baseline = WWR_initial * 40/46
		
		north_window_name = "Perimeter_mid_ZN_3_Wall_North_Window"
		east_window_name = "Perimeter_mid_ZN_2_Wall_East_Window"
		south_window_name = "Perimeter_mid_ZN_1_Wall_South_Window"
		west_window_name = "Perimeter_mid_ZN_4_Wall_West_Window"
		
		north_window = @@model.getSubSurfaceByName(north_window_name).get
		east_window = @@model.getSubSurfaceByName(east_window_name).get
		south_window = @@model.getSubSurfaceByName(south_window_name).get
		west_window = @@model.getSubSurfaceByName(west_window_name).get
		
		north_window_WWR = north_window.grossArea / 289.52
		east_window_WWR = east_window.grossArea / 193.01
		south_window_WWR = south_window.grossArea / 289.52
		west_window_WWR = west_window.grossArea / 193.01
		
		total_WWR = (north_window.grossArea+east_window.grossArea+south_window.grossArea+west_window.grossArea)/(289.52*2+193.01*2)
		
		puts "North: #{north_window_WWR}"
		puts "East: #{east_window_WWR}"
		puts "South: #{south_window_WWR}"
		puts "West: #{west_window_WWR}"
		
		north_required_WWR = 0.5 * 40/46 #43.48%
		east_required_WWR = 0.45 * 40/46 #39.13%
		south_required_WWR = 0.4 * 40/46 #34.78%
		west_required_WWR = 0.5 * 40/46 #43.48%
		
		assert_in_delta(north_required_WWR, north_window_WWR, 0.01, "North facade have a WWR of #{north_window_WWR} when #{north_required_WWR} was expected.")
		assert_in_delta(east_required_WWR, east_window_WWR, 0.01, "East facade have a WWR of #{north_window_WWR} when #{north_required_WWR} was expected.")
		assert_in_delta(south_required_WWR, south_window_WWR, 0.01, "South facade have a WWR of #{north_window_WWR} when #{north_required_WWR} was expected.")
		assert_in_delta(west_required_WWR, west_window_WWR, 0.01, "West facade have a WWR of #{north_window_WWR} when #{north_required_WWR} was expected.")
		
		assert_in_delta(total_WWR, 0.4, 0.01, "Whole building has a WWR of #{total_WWR} when 0.4 was expected.")
	
	end
	
	def test_901_2010_run06_test02
		#Testing that the overhangs on southern facade have been removed
		shadings = @@model.getShadingSurfaces
		number_of_shading = shadings.count

		assert_empty(shadings, "There is/are #{number_of_shading} shading objects when 0 was expected.")
	end
end

class TestRun08 < Minitest::Test
	#Standard Design Skylight Test
	#The prototype model is Warehouse, CZ2, with the following variations:
	#6ft ceiling height
	#Uncurbed skylight with SRR 15%
	#LPD of 0.8W/ft²
	#Skylight U-Value: 1.0 IP / SHGC: 0.1
	
	model_name = 'Run08_Prototype'
	standard = '90.1-2010'
	climate_zone = 'ASHRAE 169-2006-2A'
	building_type = 'Warehouse'
	
	@@model = create_baseline_model(model_name, standard, climate_zone, building_type, false)
	
	def setup
		assert_instance_of OpenStudio::Model::Model, @@model
	end
	
	def test_901_2010_run08_test01
		#Testing the SRR
		sub_surfaces = @@model.getSubSurfaces
		
		fine_ceiling_skylight = 0
		bulk_ceiling_skylight = 0
		
		sub_surfaces.each do |sub_surface|
			if "#{sub_surface.surface.get.name}" == "BulkStorage_Ceiling"
				bulk_ceiling_skylight = bulk_ceiling_skylight + sub_surface.grossArea
			end
			if "#{sub_surface.surface.get.name}" == "FineStorage_Ceiling"
				fine_ceiling_skylight = fine_ceiling_skylight + sub_surface.grossArea
			end
		end
		
		total_skylight = bulk_ceiling_skylight + fine_ceiling_skylight
		total_SRR = total_skylight / 4598.25
		
		assert_in_delta(total_SRR, 0.05, 0.01, "Whole building has a SRR of #{total_SRR} when 0.05 was expected.")
		
		ratio_fine_bulk = bulk_ceiling_skylight/fine_ceiling_skylight
		assert_in_delta(ratio_fine_bulk, 2.5, 0.01, "The ratio of skylights between the fine storage and bulk storage space is #{ratio_fine_bulk} when 2.5 was expected (conserved ratio)")
	
	end
	
	def test_901_2010_run08_test03
		#Testing skylight U-Value
		
		skylight_name = 'Sub Surface 4'.upcase
		
		sql = @@model.sqlFile.get
		
		uFactor_query = "SELECT Value FROM TabularDataWithStrings WHERE (ReportName='EnvelopeSummary') AND (ColumnName='Glass U-Factor') AND (RowName = '#{skylight_name}')"
		glass_uFactor_SI = sql.execAndReturnFirstDouble(uFactor_query).get
		
		glass_area_query = "SELECT Value FROM TabularDataWithStrings WHERE (ReportName='EnvelopeSummary') AND (ColumnName='Glass Area') AND (RowName = '#{skylight_name}')"
		glass_area = sql.execAndReturnFirstDouble(glass_area_query).get
		
		frame_area_query = "SELECT Value FROM TabularDataWithStrings WHERE (ReportName='EnvelopeSummary') AND (ColumnName='Frame Area') AND (RowName = '#{skylight_name}')"
		frame_area = sql.execAndReturnFirstDouble(frame_area_query).get
		
		frame_uFactor_query = "SELECT Value FROM TabularDataWithStrings WHERE (ReportName='EnvelopeSummary') AND (ColumnName='Frame Conductance') AND (RowName = '#{skylight_name}')"
		frame_uFactor_SI = sql.execAndReturnFirstDouble(frame_uFactor_query).get
		
		skylight_uFactor_SI = (glass_uFactor_SI * glass_area + frame_uFactor_SI * frame_area) / (glass_area + frame_area)
		skylight_uFactor_IP = OpenStudio.convert(skylight_uFactor_SI, 'W/m^2*K','Btu/h*ft^2*R').get
		
		assert_in_delta(1.36, skylight_uFactor_IP, 0.001, "Skylight has a U-Value of #{skylight_uFactor_IP} BTU/h.ft^2.R when 1.36 BTU/h.ft^2.R was expected (CZ2)")
		assert_in_delta(0.19, window_SHGC, 0.001, "Skylight has a SHGC of #{window_SHGC} when 0.19 was expected (CZ2")
		
	end
	
	def test_901_2010_run08_test04
		#Testing LPD in fine storage and bulk storage room
		fine_storage_space = @@model.getSpaceByName("Zone2 Fine Storage").get
		lpd_w_per_m2 = fine_storage_space.lightingPowerPerFloorArea
		lpd_w_per_ft2 = OpenStudio.convert(lpd_w_per_m2,'W/m^2','W/ft^2').get
		assert_in_delta(0.95, lpd_w_per_ft2, 0.01, "'#{fine_storage_space.name.get}' has a LPD of #{lpd_w_per_ft2} W/ft^2 while 0.95 was expected.")
		
		bulk_storage_space = @@model.getSpaceByName("Zone3 Bulk Storage").get
		lpd_w_per_m2 = bulk_storage_space.lightingPowerPerFloorArea
		lpd_w_per_ft2 = OpenStudio.convert(lpd_w_per_m2,'W/m^2','W/ft^2').get
		assert_in_delta(0.58, lpd_w_per_ft2, 0.01, "'#{bulk_storage_space.name.get}' has a LPD of #{lpd_w_per_ft2} W/ft^2 while 0.58 was expected.")
	end
end

class TestRun09 < Minitest::Test
	#Standard Design Skylight Test
	#The prototype model is Warehouse, CZ2, with the following variations:
	#6ft ceiling height
	#Uncurbed skylight with SRR 5% (lots of small openings)
	
	model_name = 'Run09_Prototype'
	standard = '90.1-2010'
	climate_zone = 'ASHRAE 169-2006-2A'
	building_type = 'Warehouse'
	
	@@model = create_baseline_model(model_name, standard, climate_zone, building_type, false)
	
	def setup
		assert_instance_of OpenStudio::Model::Model, @@model
	end
	
	def test_901_2010_run09_test01
		#Testing the SRR
		sub_surfaces = @@model.getSubSurfaces
		
		fine_ceiling_skylight = 0
		bulk_ceiling_skylight = 0
		
		sub_surfaces.each do |sub_surface|
			if "#{sub_surface.surface.get.name}" == "BulkStorage_Ceiling"
				bulk_ceiling_skylight = bulk_ceiling_skylight + sub_surface.grossArea
			end
			if "#{sub_surface.surface.get.name}" == "FineStorage_Ceiling"
				fine_ceiling_skylight = fine_ceiling_skylight + sub_surface.grossArea
			end
		end
		
		total_skylight = bulk_ceiling_skylight + fine_ceiling_skylight
		total_SRR = total_skylight / 4598.25
		
		assert_in_delta(total_SRR, 0.05, 0.01, "Whole building has a SRR of #{total_SRR} when 0.05 was expected.")
		
		ratio_fine_bulk = bulk_ceiling_skylight/fine_ceiling_skylight
		assert_in_delta(ratio_fine_bulk, 2.429, 0.01, "The ratio of skylights between the fine storage and bulk storage space is #{ratio_fine_bulk} when 2.429 was expected (conserved ratio)")
	
	end
end

class TestRun12 < Minitest::Test
	#Standard Design Space-by-Space Lighting Method Test
	#The prototype model is Medium_Office, CZ2, with the following variations:
	#	- Perimeter Zones are Lobby with LPD 0.5W/ft^2
	#	- Core Zones are Breakroom with LPD 0.75W/ft^2
	
	model_name = 'Run12_Prototype'
	standard = '90.1-2010'
	climate_zone = 'ASHRAE 169-2006-2A'
	building_type = 'MediumOffice'

	@@model = create_baseline_model(model_name, standard, climate_zone, building_type, false)
	
	def setup
		assert_instance_of OpenStudio::Model::Model, @@model
	end

	def test_901_2010_run12_test01	
		#Testing the baseline LPD in the perimeter zones (lobby)
		
		space = @@model.getSpaceByName("Perimeter_mid_ZN_4").get
		lpd_w_per_m2 = space.lightingPowerPerFloorArea
		lpd_w_per_ft2 = OpenStudio.convert(lpd_w_per_m2,'W/m^2','W/ft^2').get
		assert_in_delta(0.90, lpd_w_per_ft2, 0.01, "'#{space.name.get}' has a LPD of #{lpd_w_per_ft2} W/ft^2 while 0.90 was expected.")
	end
	
	def test_901_2010_run12_test02
		#Testing the baseline LPD in the core zones (breakroom)
		
		space = @@model.getSpaceByName("Core_bottom").get
		lpd_w_per_m2 = space.lightingPowerPerFloorArea
		lpd_w_per_ft2 = OpenStudio.convert(lpd_w_per_m2,'W/m^2','W/ft^2').get
		#(expected, actual, tolerance, message to show if it fails) 
		assert_in_delta(0.73, lpd_w_per_ft2, 0.01, "'#{space.name.get}' has a LPD of #{lpd_w_per_ft2} W/ft^2 while 0.73 was expected.")	
	end

end

class TestRun18 < Minitest::Test
	#Standard Design HVAC Test
	#The prototype model is Small_Office, CZ2, with the following variations:
	#	- Single Air Loop with DX Cooling Coil with COP 3.84, Heat Furnace with Efficiency 0.8 and constant volume fan.

	model_name = 'Run18_Prototype'
	standard = '90.1-2010'
	climate_zone = 'ASHRAE 169-2006-5A'
	building_type = 'SmallOffice'
	
	@@model = create_baseline_model(model_name, standard, climate_zone, building_type, false)
	
	def setup
		assert_instance_of OpenStudio::Model::Model, @@model
	end
	
	def test_901_2010_run18_test01
		#Testing if there are one air loop per thermal blocks (G3.1.1, System 3)
		air_loops = @@model.getLoops
		assert_equal(5, air_loops.size, "Model has #{air_loops.size} air loops when 5 where expected (one per thermal block)")
	end
	
	def test_901_2010_run19_test02_1
		#Types and number of heating coil
		heating_coil = @@model.getCoilHeatingGass
		assert_equal(5, heating_coil.size, "Model has #{heating_coil.size} furnace, when 5 where expected. (System 3, 5 air loops)")
	end
	
	def test_901_2010_run19_test02_2
		#Types and number of cooling coil
		cooling_coils = @@model.getCoilCoolingDXSingleSpeeds
		assert_equal(5, cooling_coils.size, "Model has #{cooling_coils.size} direct expansion cooling coil, when 5 where expected. (System 3, 5 air loops)")
	end
	
	def test_901_2010_run19_test02_3
		#Types and number of fans
		fans = @@model.getFanConstantVolumes
		assert_equal(5, fans.size, "Model has #{fans.size} constant volume fans, when 5 where expected. (System 3, 5 air loops)")
	end
	
	def test_901_2010_run19_test02_4
		#Economizer type
		outdoorair_controllers = @@model.getControllerOutdoorAirs
		outdoorair_controllers.each do |outdoorair_controller|
			assert_equal("FixedDryBulb", outdoorair_controller.getEconomizerControlType, "The economizer control type is set to #{outdoorair_controller.getEconomizerControlType} when FixedDryBulb was expected. (G3.1.2.7, System 5, CZ5A)")
			
			shutoff_limit_C = outdoorair_controller.getEconomizerMaximumLimitDryBulbTemperature.get
			shutoff_limit_F = OpenStudio.convert(shutoff_limit_C, 'C','F').get
			assert_in_delta(70, shutoff_limit_F, 0.1, "The High Limit Shutoff for the economizer is #{shutoff_limit_F}° when 70° was expected (G3.1.2.6B, CZ5A)")
		end
	end
	
	def test_901_2010_run18_test03_1
		#Testing the cooling equipment efficiency
		
		sql = @@model.sqlFile.get
		
		cooling_coils = @@model.getCoilCoolingDXSingleSpeeds
		cooling_coils.each do |cooling_coil|			
			coil_name = cooling_coil.name.get
			
			coils_query = "SELECT RowName FROM TabularDataWithStrings WHERE (ReportName='ComponentSizingSummary') AND (ColumnName='Design Size Gross Rated Total Cooling Capacity')"
			
			sql_coils = sql.execAndReturnVectorOfString(coils_query).get
			
			# The coil names are different between the SQL and the model. I take under assumption that the model coils contains the sql coil (i.e. that it has been appended)
			sql_coils.each do |sql_coil|
			  if coil_name.upcase.include? sql_coil
			    @coil_name_in_sql = sql_coil
			  end
			end
						
			capacity_query = "SELECT Value FROM TabularDataWithStrings WHERE (ReportName='ComponentSizingSummary') AND (ColumnName='Design Size Gross Rated Total Cooling Capacity') AND (RowName = '"+@coil_name_in_sql+"')"

			coil_capacity_SI = sql.execAndReturnFirstDouble(capacity_query).get
			coil_capacity_IP = OpenStudio.convert(coil_capacity_SI, 'W','Btu/h').get
			
			coil_COP = cooling_coil.getRatedCOP.get
			coil_EER = OpenStudio.convert(coil_COP, 'W/W', 'Btu/h*W').get
			coil_SEER = (1.12-(1.2544-0.08*coil_EER)**0.5) / 0.04
			
			case
			when coil_capacity_IP < 65000
				assert_in_delta(13.0, coil_SEER, 0.1, "The Cooling Coil #{coil_name} has a SEER of #{coil_SEER} when 13 was expected (capacity = #{coil_capacity_IP}  BTU/h < 65000 BTU/h)")
			when coil_capacity_IP >= 65000 && coil_capacity_IP < 135000
				assert_in_delta(11.0, coil_EER, 0.1, "The Cooling Coil #{coil_name} has a EER of #{coil_EER} when 11 was expected (65000 <= capacity = #{coil_capacity_IP}  BTU/h < 135000 BTU/h)")
			when coil_capacity_IP >= 135000 && coil_capacity_IP < 240000
				assert_in_delta(10.8, coil_EER, 0.1, "The Cooling Coil #{coil_name} has a EER of #{coil_EER} when 10.8 was expected (135000 <= capacity = #{coil_capacity_IP}  BTU/h < 240000 BTU/h)")
			when coil_capacity_IP >= 240000 && coil_capacity_IP < 760000
				assert_in_delta(10.0, coil_EER, 0.1, "The Cooling Coil #{coil_name} has a EER of #{coil_EER} when 10.0 was expected (240000 <= capacity = #{coil_capacity_IP}  BTU/h < 760000 BTU/h)")
			else
				assert_in_delta(9.7, coil_EER, 0.1, "The Cooling Coil #{coil_name} has a EER of #{coil_EER} when 9.7 was expected (capacity = #{coil_capacity_IP}  BTU/h >= 760000 BTU/h)")
			end
		end			
	end
	
	def test_901_2010_run18_test03_2
		#Testing the heating equipment efficiency
		furnaces = @@model.getCoilHeatingGass
		
		furnaces.each do |furnace|
			furnace_name = furnace.name.get
			assert_in_delta(0.8, furnace.gasBurnerEfficiency, 0.1, "The furnace #{furnace_name} has an efficiency of #{furnace.gasBurnerEfficiency} when 0.8 was expected (gas furnace)")
		end
	end
end

class TestRun19 < Minitest::Test
	#Standard Design HVAC Test
	#The prototype model is Medium_Office, CZ2, with the following variations:
	#	- Core zones are Computer Rooms with a load of 110000 BTUh
	#	- Core zones have PSZ-AC, COP 4, Constant Volume Fan
	#	- Perimeter zones have one HVAC loop per floor
	#	- Perimeter HVAC is DX Cooling COP 3.8, Boiler  82% eff, VAV

	model_name = 'Run19_Prototype'
	standard = '90.1-2010'
	climate_zone = 'ASHRAE 169-2006-2A'
	building_type = 'MediumOffice'
	
	@@model = create_baseline_model(model_name, standard, climate_zone, building_type, false)
	
	def setup
		assert_instance_of OpenStudio::Model::Model, @@model
	end
	
	def test_901_2010_run19_test01
		#Testing if there are one air loop per floor (G3.1.1, System 5)
		air_loops = @@model.getAirLoopHVACs
		assert_equal(3, air_loops.size, "Model has #{air_loops.size} air loops when 3 where expected (one per floor)")
	end
	
	def test_901_2010_run19_test02_1
		#Types and number of boilers (G3.1.3.2, System 5)
		boilers = @@model.getBoilerHotWaters
		assert_equal(2, boilers.size, "Model has #{boilers.size} boilers, when 2 where expected. (G3.1.3.2, building 53000sqft)")
		boilers.each do |boiler|
			assert_equal("NaturalGas", boiler.fuelType, "Boiler uses #{boiler.fuelType} when Natural Gas was expected. (G3.1.3.2, design uses Natural Gas)")
		end
	end
	
	def test_901_2010_run19_test02_2
		#Types and number of cooling coil
		cooling_coils = @@model.getCoilCoolingDXSingleSpeeds
		assert_equal(3, cooling_coils.size, "Model has #{cooling_coils.size} direct expansion cooling coil, when 3 where expected. (System 5, 3 air loops)")
	end
	
	def test_901_2010_run19_test02_3
		#Types and number of fans
		fans = @@model.getFanVariableVolumes
		assert_equal(3, fans.size, "Model has #{fans.size} variable volume fans, when 3 where expected. (System 5, 3 air loops)")
	end
	
	def test_901_2010_run19_test02_4
		#Economizer type
		outdoorair_controllers = @@model.getControllerOutdoorAirs
		outdoorair_controllers.each do |outdoorair_controller|
			assert_equal("NoEconomizer", outdoorair_controller.getEconomizerControlType, "The economizer control type is set to #{outdoorair_controller.getEconomizerControlType} when no economizer was expected. (G3.1.2.7, System 5, CZ2A)")
		end
	end
	
	def test_901_2010_run19_test02_5
		#Air terminal type
		air_terminals = @@model.getAirTerminalSingleDuctVAVReheats
		assert_equal(15, air_terminals.size, "Model has #{air_terminals.size} VAV air terminal with reheat, when 15 where expected. (System 5, 15 thermal zones)")
	end
	
	def test_901_2010_run19_test03_1
		#Testing the cooling equipment efficiency		
		sql = @@model.sqlFile.get
		
		cooling_coils = @@model.getCoilCoolingDXSingleSpeeds
		cooling_coils.each do |cooling_coil|			
			coil_name = cooling_coil.name.get
			
			coils_query = "SELECT RowName FROM TabularDataWithStrings WHERE (ReportName='ComponentSizingSummary') AND (ColumnName='Design Size Gross Rated Total Cooling Capacity')"
			
			sql_coils = sql.execAndReturnVectorOfString(coils_query).get
			
			# The coil names are different between the SQL and the model. I take under assumption that the model coils contains the sql coil name (i.e. that it has been appended)
			sql_coils.each do |sql_coil|
			  if coil_name.upcase.include? sql_coil
			    @coil_name_in_sql = sql_coil
			  end
			end
						
			capacity_query = "SELECT Value FROM TabularDataWithStrings WHERE (ReportName='ComponentSizingSummary') AND (ColumnName='Design Size Gross Rated Total Cooling Capacity') AND (RowName = '"+@coil_name_in_sql+"')"

			coil_capacity_SI = sql.execAndReturnFirstDouble(capacity_query).get
			coil_capacity_IP = OpenStudio.convert(coil_capacity_SI, 'W','Btu/h').get
			
			coil_COP = cooling_coil.getRatedCOP.get
			coil_EER = OpenStudio.convert(coil_COP, 'W/W', 'Btu/h*W').get
			coil_SEER = (1.12-(1.2544-0.08*coil_EER)**0.5) / 0.04
			
			case
			when coil_capacity_IP < 65000
				assert_in_delta(13.0, coil_SEER, 0.1, "The Cooling Coil #{coil_name} has a SEER of #{coil_SEER} when 13 was expected (capacity = #{coil_capacity_IP}  BTU/h < 65000 BTU/h)")
			when coil_capacity_IP >= 65000 && coil_capacity_IP < 135000
				assert_in_delta(11.0, coil_EER, 0.1, "The Cooling Coil #{coil_name} has a EER of #{coil_EER} when 11 was expected (65000 <= capacity = #{coil_capacity_IP}  BTU/h < 135000 BTU/h)")
			when coil_capacity_IP >= 135000 && coil_capacity_IP < 240000
				assert_in_delta(10.8, coil_EER, 0.1, "The Cooling Coil #{coil_name} has a EER of #{coil_EER} when 10.8 was expected (135000 <= capacity = #{coil_capacity_IP}  BTU/h < 240000 BTU/h)")
			when coil_capacity_IP >= 240000 && coil_capacity_IP < 760000
				assert_in_delta(10.0, coil_EER, 0.1, "The Cooling Coil #{coil_name} has a EER of #{coil_EER} when 10.0 was expected (240000 <= capacity = #{coil_capacity_IP}  BTU/h < 760000 BTU/h)")
			else
				assert_in_delta(9.7, coil_EER, 0.1, "The Cooling Coil #{coil_name} has a EER of #{coil_EER} when 9.7 was expected (capacity = #{coil_capacity_IP}  BTU/h >= 760000 BTU/h)")
			end
		end			
	end
	
	def test_901_2010_run19_test03_2
		#Testing the heating efficiency
		sql = @@model.sqlFile.get
		
		boilers = @@model.getBoilerHotWaters
		boilers.each do |boiler|
			boiler_name = boiler.name.get
			
			boiler_query = "SELECT RowName FROM TabularDataWithStrings WHERE (ReportName='ComponentSizingSummary') AND (ColumnName='Design Size Nominal Capacity') AND (TableName='Boiler:HotWater')"
			sql_boilers = sql.execAndReturnVectorOfString(boiler_query).get
			
			# The boiler names are different between the SQL and the model. I take under assumption that the model boilers contains the sql boiler name (i.e. that it has been appended)
			sql_boilers.each do |sql_boiler|
			  if boiler_name.upcase.include? sql_boiler
			    @boiler_name_in_sql = sql_boiler
			  end
			end
			
			capacity_query = "SELECT Value FROM TabularDataWithStrings WHERE (ReportName='ComponentSizingSummary') AND (ColumnName='Design Size Nominal Capacity') AND (RowName = '"+@boiler_name_in_sql+"')"
			
			boiler_capacity_SI = sql.execAndReturnFirstDouble(capacity_query).get
			boiler_capacity_IP = OpenStudio.convert(boiler_capacity_SI, 'W','Btu/h').get
			
			boiler_eff = boiler.nominalThermalEfficiency
			
			case
			when boiler_capacity_IP < 300000
				assert_in_delta(0.8, boiler_eff, 0.1, "The Boiler #{boiler_name} has an efficiency of #{boiler_eff} when 0.8 was expected (gas-fired, capacity = #{boiler_capacity_IP}  BTU/h < 300,000 BTU/h)")
			when boiler_capacity_IP >= 300000 && boiler_capacity_IP < 2500000
				assert_in_delta(0.75, boiler_eff, 0.1, "The Boiler #{coil_name} has an efficiency of #{boiler_eff} when 0.75 was expected (gas-fired, 300,000 <= capacity = #{boiler_capacity_IP}  BTU/h < 2,500,000 BTU/h)")
			else
				assert_in_delta(0.8, boiler_eff, 0.1, "The Boiler #{coil_name} has an efficiency of #{boiler_eff} when 0.8 was expected (gas-fired, 2,500,000 <= capacity = #{boiler_capacity_IP}  BTU/h)")
			end
		end
		
	end
	
	def test_901_2010_run19_test04_1
		#Testing air terminal minimum air flow fraction (G3.1.3.13)
		air_terminals = @@model.getAirTerminalSingleDuctVAVReheats
		air_terminals.each do |air_terminal|
			assert_in_delta(0.3, air_terminal.constantMinimumAirFlowFraction, "The air terminal minimum air flow fraction is set to #{air_terminal.constantMinimumAirFlowFraction} when 0.3 was expected (G3.1.3.13)")		
		end
	end
	
	def test_901_2010_run19_test04_2
		#Testing hot water loop design supply and return temperature (G3.1.3.3)
		plant_sizings = @@model.getSizingPlants
		plant_sizings.each do |plant_sizing|
			if "#{plant_sizing.loopType}" == "Heating"
				supply_temperature_C = plant_sizing.designLoopExitTemperature
				supply_temperature_F = OpenStudio.convert(supply_temperature_C, 'C','F').get
				assert_in_delta(180, supply_temperature_F, 0.1, "Design supply temperature in hot water loop is #{supply_temperature_F}°F when 180°F was expected (G3.1.3.3)")
				
				return_temperature_C = supply_temperature_C - plant_sizing.loopDesignTemperatureDifference
				return_temperature_F = OpenStudio.convert(return_temperature_C, 'C','F').get
				
				assert_in_delta(130, return_temperature_F, 0.1, "Design return temperature in hot water loop is #{return_temperature_F}°F when 130°F was expected (G3.1.3.3)")
			end
		end
	end
end

class TestRun20 < Minitest::Test
	#Standard Design Exterior Envelope Test
	#The prototype model is Large_Office, CZ3B, with the following variations:
	#	- Heating Source: Electricity
	#	- Chiller COP 4
	#	- Air loops for bottom and mid floors are combined
	#	- Basement has DX Cooling Coil COP 6.2
	#	- Heating Only, Electric Heater 92% eff

	model_name = 'Run20_Prototype'
	standard = '90.1-2010'
	climate_zone = 'ASHRAE 169-2006-3B'
	building_type = 'LargeOffice'
	
	@@model = create_baseline_model(model_name, standard, climate_zone, building_type, false)
	
	def setup
		assert_instance_of OpenStudio::Model::Model, @@model
	end
	
	def test_901_2010_run20_test01
		#Testing if there are one air loop per floor (G3.1.1, System 8)
		air_loops = @@model.getAirLoopHVACs
		assert_equal(3, air_loops.size, "Model has #{air_loops.size} air loops when 3 where expected (one per floor)")
	end
	
	def test_901_2010_run20_test02_1
		#Types and number of heating coil (System 8)
		heating_coils = @@model.getCoilHeatingElectrics
		assert_equal(3, heating_coils.size, "Model has #{heating_coils.size} electrical heating coil, when 3 where expected. (System 8, 3 air loops)")
	end
	
	def test_901_2010_run20_test02_2
		#Types and number of cooling coil (System 8)
		cooling_coils = @@model.getCoilCoolingWaters
		assert_equal(3, cooling_coils.size, "Model has #{cooling_coils.size} water cooling coil, when 3 where expected. (System 8, 3 air loops)")
	end
	
	def test_901_2010_run20_test02_3
		#Types and number of fans
		fans = @@model.getFanVariableVolumes
		assert_equal(3, fans.size, "Model has #{fans.size} variable volume fans, when 3 where expected. (System 8, 3 air loops)")
	end
	
	def test_901_2010_run20_test02_4
		#Economizer type
		outdoorair_controllers = @@model.getControllerOutdoorAirs
		outdoorair_controllers.each do |outdoorair_controller|
			assert_equal("FixedDryBulb", outdoorair_controller.getEconomizerControlType, "The economizer control type is set to #{outdoorair_controller.getEconomizerControlType} when FixedDryBulb was expected. (G3.1.2.7, System 8, CZ3B)")
		end
	end
	
	def test_901_2010_run20_test02_5
		#Air terminal type
		air_terminals = @@model.getAirTerminalSingleDuctParallelPIUReheats
		assert_equal(15, air_terminals.size, "Model has #{air_terminals.size} parallel fan-powered boxes with reheat, when 15 where expected. (System 8, 15 thermal zones)")
	end
	
	def test_901_2010_run20_test03_1
		#Testing the cooling equipment efficiency				
	end
	
	def test_901_2010_run20_test03_2
		#Testing the heating equipment efficiency		
	end
	
	def test_901_2010_run20_test04_2
		#Testing chilled water loop design supply and return temperature (G3.1.3.8)
		plant_sizings = @@model.getSizingPlants
		plant_sizings.each do |plant_sizing|
			if "#{plant_sizing.loopType}" == "Cooling"
				supply_temperature_C = plant_sizing.designLoopExitTemperature
				supply_temperature_F = OpenStudio.convert(supply_temperature_C, 'C','F').get
				assert_in_delta(44, supply_temperature_F, 0.1, "Design supply temperature in chilled water loop is #{supply_temperature_F}°F when 44°F was expected (G3.1.3.8)")
				
				return_temperature_C = supply_temperature_C + plant_sizing.loopDesignTemperatureDifference
				return_temperature_F = OpenStudio.convert(return_temperature_C, 'C','F').get
				
				assert_in_delta(56, return_temperature_F, 0.1, "Design return temperature in chilled water loop is #{return_temperature_F}°F when 56°F was expected (G3.1.3.8)")
			end
		end
	end
end

class TestRun21 < Minitest::Test
	#Standard Design Exterior Envelope Test
	#The prototype model is Warehouse, CZ8A, with the following variations:
	#	- Heating Only, source: Electricity

	model_name = 'Run21_Prototype'
	standard = '90.1-2010'
	climate_zone = 'ASHRAE 169-2006-8A'
	building_type = 'Warehouse'
	
	@@model = create_baseline_model(model_name, standard, climate_zone, building_type, false)
	
	def setup
		assert_instance_of OpenStudio::Model::Model, @@model
	end
	
	def test_901_2010_run21_test01
		#Testing if there are one air loop per floor (G3.1.1, System 6)
		air_loops = @@model.getAirLoopHVACs
		assert_equal(1, air_loops.size, "Model has #{air_loops.size} air loops when 1 where expected (one per floor)")
	end
	
	def test_901_2010_run21_test02_1
		#Types and number of heating coil (System 6)
		heating_coils = @@model.getCoilHeatingElectrics
		assert_equal(1, heating_coils.size, "Model has #{heating_coils.size} electrical heating coil, when 1 where expected. (System 6, 1 air loop)")
	end
	
	def test_901_2010_run21_test02_2
		#Types and number of cooling coil (System 6)
		cooling_coils = @@model.getCoilCoolingDXSingleSpeeds
		assert_equal(1, cooling_coils.size, "Model has #{cooling_coils.size} direct expansion cooling coil, when 1 where expected. (System 6, 1 air loop)")
	end
	
	def test_901_2010_run21_test02_3
		#Types and number of fans
		fans = @@model.getFanVariableVolumes
		assert_equal(1, fans.size, "Model has #{fans.size} variable volume fans, when 1 where expected. (System 6, 1 air loop)")
	end
	
	def test_901_2010_run21_test02_4
		#Economizer type
		outdoorair_controllers = @@model.getControllerOutdoorAirs
		outdoorair_controllers.each do |outdoorair_controller|
			assert_equal("FixedDryBulb", outdoorair_controller.getEconomizerControlType, "The economizer control type is set to #{outdoorair_controller.getEconomizerControlType} when FixedDryBulb was expected. (G3.1.2.7, System 6, CZ8A)")
		end
	end
	
	def test_901_2010_run21_test02_5
		#Air terminal type
		air_terminals = @@model.getAirTerminalSingleDuctParallelPIUReheats
		assert_equal(3, air_terminals.size, "Model has #{air_terminals.size} parallel fan-powered boxes with reheat, when 3 where expected. (System 6, 3 thermal zones)")
	end
	
	def test_901_2010_run21_test03_1
		#Testing the cooling equipment efficiency				
	end
	
	def test_901_2010_run21_test03_2
		#Testing the heating equipment efficiency		
	end
end