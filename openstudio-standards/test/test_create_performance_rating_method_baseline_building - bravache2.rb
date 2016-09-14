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