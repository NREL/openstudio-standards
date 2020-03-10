require_relative '../helpers/minitest_helper'

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


  # 'ASHRAE 169-2013-6A', 'ASHRAE 169-2013-6B', 'ASHRAE 169-2013-7A',
  # 'ASHRAE 169-2013-7B', 'ASHRAE 169-2013-8A', 'ASHRAE 169-2013-8B'
  if model.weatherFile.empty?
    epw_name = nil
    base_rel_path = '../../data/weather/'
    case climate_zone
      when 'ASHRAE 169-2013-1A'
        epw_name = 'USA_FL_Miami.Intl.AP.722020_TMY3.epw'
      when 'ASHRAE 169-2013-1B'
        epw_name = 'USA_AZ_Phoenix-Sky.Harbor.Intl.AP.722780_TMY3.epw'
      when 'ASHRAE 169-2013-2A'
        epw_name = 'USA_TX_Houston-Bush.Intercontinental.AP.722430_TMY3.epw'
      when 'ASHRAE 169-2013-2B'
        epw_name = 'USA_AZ_Phoenix-Sky.Harbor.Intl.AP.722780_TMY3.epw'
      when 'ASHRAE 169-2013-3A'
        epw_name = 'USA_TN_Memphis.Intl.AP.723340_TMY3.epw' # or GA-Atlanta
      when 'ASHRAE 169-2013-3B'
        epw_name = 'USA_TX_El.Paso.Intl.AP.722700_TMY3.epw' # CA-Los Angeles or NV-Las Vegas
      when 'ASHRAE 169-2013-3C'
        epw_name = 'USA_CA_San.Francisco.Intl.AP.724940_TMY3.epw'
      when 'ASHRAE 169-2013-4A'
        epw_name = 'USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw' # or USA_OR_Salem-McNary.Field.726940_TMY3.epw
      when 'ASHRAE 169-2013-4B'
        epw_name = 'USA_NM_Albuquerque.Intl.AP.723650_TMY3.epw' # or USA_ID_Boise.Air.Terminal.726810_TMY3.epw
      when 'ASHRAE 169-2013-4C'
        epw_name = nil # WA-Seattle
      when 'ASHRAE 169-2013-5A'
        epw_name = 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw' # or USA_VT_Burlington.Intl.AP.726170_TMY3.epw
      when 'ASHRAE 169-2013-5B'
        epw_name = nil # CO Boulder
      when 'ASHRAE 169-2013-5C'
        epw_name = nil
      when 'ASHRAE 169-2013-6A'
        epw_name = nil # MN-Minneapolis
      when 'ASHRAE 169-2013-6B'
        epw_name = 'USA_MT_Helena.Rgnl.AP.727720_TMY3.epw'
      when 'ASHRAE 169-2013-7A'
        epw_name = 'USA_MN_Duluth.Intl.AP.727450_TMY3.epw'
      when 'ASHRAE 169-2013-7B'
        epw_name = nil
      when 'ASHRAE 169-2013-8A'
        epw_name = 'USA_AK_Fairbanks.Intl.AP.702610_TMY3.epw'
      when 'ASHRAE 169-2013-8B'
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

class TestRun12 < Minitest::Test
	#Standard Design Space-by-Space Lighting Method Test
	#The prototype model is Medium_Office, CZ2, with the following variations:
	#	- Perimeter Zones are Lobby with LPD 0.5W/ft^2
	#	- Core Zones are Breakroom with LPD 0.75W/ft^2

	@@model = create_baseline_model('Run12_Prototype', '90.1-2010', 'ASHRAE 169-2013-2A', 'MediumOffice', false)
	
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

class TestRun01 < Minitest::Test
	#Standard Design Exterior Envelope Test
	#The prototype model is Small_Office, CZ2, with the following variations:
	#	- Low-Slope Concrete Roof with U-Value 0.065 IP, solar reflectance 0.75 and thermal emittance 0.78
	#	- Wood-framed wall with U-Value 0.095 IP
	#	- Windows with U-Value 0.25 IP, SHGC 0.2 and VT 0.45

	@@model = create_baseline_model('Run01_Prototype', '90.1-2010', 'ASHRAE 169-2013-2A', 'SmallOffice', false)
	
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
		
		assert_in_delta(0.089, extwall_uFactor_IP, 0.001, "Exterior Walls have a U-Value of #{extwall_uFactor_IP} BTU/h.ft^2.R when 0.089 BTU/h.ft^2.R was expected (CZ2, Wood-Framed)")
		assert_in_delta(0.0107, floor_uFactor_IP, 0.001, "Floor has a U-Value of #{floor_uFactor_IP} BTU/h.ft^2.R when 0.0107 BTU/h.ft^2.R was expected (CZ2, Mass)")
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
		
	def test_901_2010_run01_test05
		#Testing the baseline windows U-Value, SHGC and VT.
		
		window = @@model.getSubSurfaceByName('Perimeter_ZN_3_wall_north_Window_1').get
		
		puts "#{window}"
		
		window_uFactor_SI = window.uFactor
		window_uFactor_IP = OpenStudio.convert(window_uFactor_SI, 'W/m^2*K','Btu/h*ft^2*R').get
		
		assert_in_delta(0.75, window_uFactor_IP, 0.001, "Window has a U-Value of #{window_uFactor_IP} BTU/h.ft^2.R when 0.75 BTU/h.ft^2.R was expected (CZ2)")
		
		window_cons_name = window.construction.get.name.get
		window_cons = @@model.getConstructionByName(window_cons_name).get
		
		puts "#{window_cons}"		
		
		glazing_name = window_cons.getLayer(0).name.get
		
		puts "#{glazing_name}"		
		
		glazing = @model.getSimpleGlazingByName(glazing_name).get
		
		puts "#{glazing}"		
	end

end

class TestRun18 < Minitest::Test
	#Standard Design Exterior Envelope Test
	#The prototype model is Small_Office, CZ2, with the following variations:
	#	- Single Air Loop with DX Cooling Coil with COP 3.84, Heat Furnace with Efficiency 0.8 and constant volume fan.

	@@model = create_baseline_model('Run18_Prototype', '90.1-2010', 'ASHRAE 169-2013-2A', 'SmallOffice', false)
	
	def setup
		assert_instance_of OpenStudio::Model::Model, @@model
	end
	
	def test_901_2010_run18_test01
		#Testing if there are one air loop per thermal blocks (G3.1.1, System 3)
		air_loops = @@model.getLoops
		assert_equal(5, air_loops.size, "Model has #{air_loops.size} air loops when 5 where expected (one per thermal block)")
	
	end
	
	def test_901_2010_run18_test02
		#Testing the type of HVAC System.
		
	end
	
	def test_901_2010_run18_test03
		#Testing the cooling and heating equipment efficiency
		#Fail to catch capacity (set to autosize in the model... to be fixed)
		cooling_coils = @@model.getCoilCoolingDXSingleSpeeds
		cooling_coils.each do |cooling_coil|
			puts "#{cooling_coil}"
			coil_capacity_SI = cooling_coil.ratedTotalCoolingCapacity.get
			
			puts "#{coil_capacity_SI}"
			
			coil_capacity_SI = coil_capacity_SI.split(" ").first.to_f
			
			puts "#{coil_capacity_SI}"
			
			coil_capacity_IP = OpenStudio.convert(coil_capacity_SI, 'W','Btu/h').get
			
			coil_name = cooling_coil.name.get
			
			coil_COP = cooling_coil.ratedCOP.get
			coil_EER = OpenStudio.convert(coil_COP, 'W/W', 'Btu/h*W').get
			coil_SEER = coil_EER / 0.875			
			
			case
			when coil_capacity_IP < 65000
				assert_in_delta(13.0, coil_SEER, 0.1, "The Cooling Coil #{coil_name} has a SEER of #{coil_SEER} when 13 was expected (capacity = #{coil_capacity_IP} < 65000 BTU/h)")
			when coil_capacity_IP >= 65000 && coil_capacity_IP < 135000
				assert_in_delta(11.0, coil_EER, 0.1, "The Cooling Coil #{coil_name} has a EER of #{coil_EER} when 11 was expected (65000 <= capacity = #{coil_capacity_IP} < 135000 BTU/h)")
			when coil_capacity_IP >= 135000 && coil_capacity_IP < 240000
				assert_in_delta(10.8, coil_EER, 0.1, "The Cooling Coil #{coil_name} has a EER of #{coil_EER} when 10.8 was expected (135000 <= capacity = #{coil_capacity_IP} < 240000 BTU/h)")
			when coil_capacity_IP >= 240000 && coil_capacity_IP < 760000
				assert_in_delta(10.0, coil_EER, 0.1, "The Cooling Coil #{coil_name} has a EER of #{coil_EER} when 10.0 was expected (240000 <= capacity = #{coil_capacity_IP} < 760000 BTU/h)")
			else
				assert_in_delta(9.7, coil_EER, 0.1, "The Cooling Coil #{coil_name} has a EER of #{coil_EER} when 9.7 was expected (capacity = #{coil_capacity_IP} >= 760000 BTU/h)")
			end
		end			
	end
		
	
	
end
