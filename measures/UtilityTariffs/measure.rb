# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

require "csv"
release_mode = false
folder = "#{File.dirname(__FILE__)}/../../../../lib/btap/lib/"

if release_mode == true
  #Copy BTAP files to measure from lib folder. Use this to create independant measure. 
  Dir.glob("#{folder}/**/*rb").each do |file|
    FileUtils.cp(file, File.dirname(__FILE__))
  end
  require "#{File.dirname(__FILE__)}/btap.rb"
else
  #For only when using git hub development environment.
  require "#{File.dirname(__FILE__)}/../../../../lib/btap/lib/btap.rb"
end

#start the measure
class UtilityTariffsModelSetup < OpenStudio::Ruleset::WorkspaceUserScript

  # Define the name of the Measure.
  def name
    return "Utility Tariffs Model Setup"
  end

  #define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end
   
    # get city name from weather file station
    site_location_obj = workspace.getObjectsByType("Site:Location".to_IddObjectType)
    weather_station_line = site_location_obj[0].to_s.split(/\n/)[1]
    weather_station = weather_station_line.split(/,/)[0]

    # read tariffs template idf file 
    tariff_template_file = File.open("#{File.dirname(__FILE__)}/resources/Tariff_Template.idf")
    tariff_template_file_content = tariff_template_file.read

    # database of electricity utility data
    electricity_tariffs_file_csv = "#{File.dirname(__FILE__)}/resources/utility_electricity_tariffs.csv"
    
    # update content of electricity tariff idf file with tariff data for location
    energy_charges_blk_limit = []
    energy_charges_blk_rate = []
    demand_charges_blk_limit = []
    demand_charges_blk_rate = []
    elec_tariff_template_file_content = ""
    monthly_charges = ""
    elec_tariff = ""
    CSV.foreach(electricity_tariffs_file_csv, headers:true) do |tariff|
      if(weather_station.scan(tariff["City"]).size > 0)
        city = tariff["City"]
        BTAP::runner_register("INFO", "Found electricity tariff database match for weather_station :#{weather_station} and city:#{city}" ,runner)
        elec_tariff = tariff["Utility"]
        monthly_charges = tariff["Monthly_Charge_($)"]
        for i in 0..3 do
          energy_charges_blk_limit[i] = tariff["Energy_Charges_Block_#{i+1}_Limit_(kWh)"]
          energy_charges_blk_rate[i] = tariff["Energy_Charges_Block_#{i+1}_Rate_($)"]
          demand_charges_blk_limit[i] = tariff["Demand_Charges_Block_#{i+1}_Limit_(kW)"]
          demand_charges_blk_rate[i] = tariff["Demand_Charges_Block_#{i+1}_Rate_($)"]
        end
        energy_charges_blk_rate[4] = tariff["Energy_Charges_Block_5_Rate_($)"]
        demand_charges_blk_rate[4] = tariff["Demand_Charges_Block_5_Rate_($)"]
        elec_tariff_template_file_content = (tariff_template_file_content.gsub("%utility_tariff_name%",tariff["Utility"])).dup
        elec_tariff_template_file_content = elec_tariff_template_file_content.sub("%tariff_output_meter_name%","ElectricityPurchased:Facility")
        elec_tariff_template_file_content = elec_tariff_template_file_content.sub("%conv_factor%","kWh")
        elec_tariff_template_file_content = elec_tariff_template_file_content.sub("%monthly_charges%",monthly_charges)
        elec_tariff_template_file_content = elec_tariff_template_file_content.sub("%blocks_energy_charges_name%","ElectricityBlocksEnergyCharges")
        elec_tariff_template_file_content = elec_tariff_template_file_content.sub("%blocks_demand_charges_name%","ElectricityBlocksDemandCharges")
        for i in 0..3 do
          elec_tariff_template_file_content = elec_tariff_template_file_content.sub("%energy_charges_blk#{i+1}_limit%",energy_charges_blk_limit[i])
          elec_tariff_template_file_content = elec_tariff_template_file_content.sub("%energy_charges_blk#{i+1}_rate%",energy_charges_blk_rate[i])
          elec_tariff_template_file_content = elec_tariff_template_file_content.sub("%demand_charges_blk#{i+1}_limit%",demand_charges_blk_limit[i])
          elec_tariff_template_file_content = elec_tariff_template_file_content.sub("%demand_charges_blk#{i+1}_rate%",demand_charges_blk_rate[i])
        end
        elec_tariff_template_file_content = elec_tariff_template_file_content.sub("%energy_charges_blk5_rate%",energy_charges_blk_rate[4])
        elec_tariff_template_file_content = elec_tariff_template_file_content.sub("%demand_charges_blk5_rate%",demand_charges_blk_rate[4])
        break
      end
    end

    # read database of gas utility data
    gas_tariffs_file_csv = "#{File.dirname(__FILE__)}/resources/utility_gas_tariffs.csv"

    # update content of gas tariff idf file with tariff data for location
    energy_charges_blk_limit = []
    energy_charges_blk_rate = []
    demand_charges_blk_limit = []
    demand_charges_blk_rate = []
    gas_tariff_template_file_content = ""
    monthly_charges = ""
    gas_tariff = ""
    CSV.foreach(gas_tariffs_file_csv, headers:true) do |tariff|
      if(weather_station.scan(tariff["City"]).size > 0)
        city = tariff["City"]
        BTAP::runner_register("INFO", "Found gas tariff database match for weather_station :#{weather_station} and city:#{city}" ,runner)
        gas_tariff = tariff["Utility"]
        monthly_charges = tariff["Monthly_Charge_($)"]
        for i in 0..3 do
          energy_charges_blk_limit[i] = tariff["Energy_Charges_Block_#{i+1}_Limit_(MJ)"]
          energy_charges_blk_rate[i] = tariff["Energy_Charges_Block_#{i+1}_Rate_($)"]
          demand_charges_blk_limit[i] = tariff["Demand_Charges_Block_#{i+1}_Limit_(MJ_per_hr)"]
          demand_charges_blk_rate[i] = tariff["Demand_Charges_Block_#{i+1}_Rate_($)"]
        end
        energy_charges_blk_rate[4] = tariff["Energy_Charges_Block_5_Rate_($)"]
        demand_charges_blk_rate[4] = tariff["Demand_Charges_Block_5_Rate_($)"]
        gas_tariff_template_file_content = (tariff_template_file_content.gsub("%utility_tariff_name%",tariff["Utility"])).dup
        gas_tariff_template_file_content = gas_tariff_template_file_content.sub("%tariff_output_meter_name%","Gas:Facility")
        gas_tariff_template_file_content = gas_tariff_template_file_content.sub("%conv_factor%","MJ")
        gas_tariff_template_file_content = gas_tariff_template_file_content.sub("%monthly_charges%",monthly_charges)
        gas_tariff_template_file_content = gas_tariff_template_file_content.sub("%blocks_energy_charges_name%","GasBlocksEnergyCharges")
        gas_tariff_template_file_content = gas_tariff_template_file_content.sub("%blocks_demand_charges_name%","GasBlocksDemandCharges")
        for i in 0..3 do
          gas_tariff_template_file_content = gas_tariff_template_file_content.sub("%energy_charges_blk#{i+1}_limit%",energy_charges_blk_limit[i])
          gas_tariff_template_file_content = gas_tariff_template_file_content.sub("%energy_charges_blk#{i+1}_rate%",energy_charges_blk_rate[i])
          gas_tariff_template_file_content = gas_tariff_template_file_content.sub("%demand_charges_blk#{i+1}_limit%",demand_charges_blk_limit[i])
          gas_tariff_template_file_content = gas_tariff_template_file_content.sub("%demand_charges_blk#{i+1}_rate%",demand_charges_blk_rate[i])
        end
        gas_tariff_template_file_content = gas_tariff_template_file_content.sub("%energy_charges_blk5_rate%",energy_charges_blk_rate[4])
        gas_tariff_template_file_content = gas_tariff_template_file_content.sub("%demand_charges_blk5_rate%",demand_charges_blk_rate[4])
        break
      end
    end

    # read database of oil utility data
    oil_tariffs_file_csv = "#{File.dirname(__FILE__)}/resources/utility_oil_tariffs.csv"

    # update content of oil tariff idf file with tariff data for location
    energy_charges_blk_limit = []
    energy_charges_blk_rate = []
    demand_charges_blk_limit = []
    demand_charges_blk_rate = []
    oil_tariff_template_file_content = ""
    monthly_charges = ""
    oil_tariff = ""
    CSV.foreach(oil_tariffs_file_csv, headers:true) do |tariff|
      if(weather_station.scan(tariff["City"]).size > 0)
        city = tariff["City"]
        BTAP::runner_register("INFO", "Found oil tariff database match for weather_station :#{weather_station} and city:#{city}" ,runner)
        oil_tariff = tariff["Utility"]
        monthly_charges = tariff["Monthly_Charge_($)"]
        for i in 0..3 do
          energy_charges_blk_limit[i] = tariff["Energy_Charges_Block_#{i+1}_Limit_(MJ)"]
          energy_charges_blk_rate[i] = tariff["Energy_Charges_Block_#{i+1}_Rate_($)"]
          demand_charges_blk_limit[i] = tariff["Demand_Charges_Block_#{i+1}_Limit_(MJ_per_hr)"]
          demand_charges_blk_rate[i] = tariff["Demand_Charges_Block_#{i+1}_Rate_($)"]
        end
        energy_charges_blk_rate[4] = tariff["Energy_Charges_Block_5_Rate_($)"]
        demand_charges_blk_rate[4] = tariff["Demand_Charges_Block_5_Rate_($)"]
        oil_tariff_template_file_content = (tariff_template_file_content.gsub("%utility_tariff_name%",tariff["Utility"])).dup
        oil_tariff_template_file_content = oil_tariff_template_file_content.sub("%tariff_output_meter_name%","FuelOil#2:Facility")
        oil_tariff_template_file_content = oil_tariff_template_file_content.sub("%conv_factor%","MJ")
        oil_tariff_template_file_content = oil_tariff_template_file_content.sub("%monthly_charges%",monthly_charges)
        oil_tariff_template_file_content = oil_tariff_template_file_content.sub("%blocks_energy_charges_name%","OilBlocksEnergyCharges")
        oil_tariff_template_file_content = oil_tariff_template_file_content.sub("%blocks_demand_charges_name%","OilBlocksDemandCharges")
        for i in 0..3 do
          oil_tariff_template_file_content = oil_tariff_template_file_content.sub("%energy_charges_blk#{i+1}_limit%",energy_charges_blk_limit[i])
          oil_tariff_template_file_content = oil_tariff_template_file_content.sub("%energy_charges_blk#{i+1}_rate%",energy_charges_blk_rate[i])
          oil_tariff_template_file_content = oil_tariff_template_file_content.sub("%demand_charges_blk#{i+1}_limit%",demand_charges_blk_limit[i])
          oil_tariff_template_file_content = oil_tariff_template_file_content.sub("%demand_charges_blk#{i+1}_rate%",demand_charges_blk_rate[i])
        end
        oil_tariff_template_file_content = oil_tariff_template_file_content.sub("%energy_charges_blk5_rate%",energy_charges_blk_rate[4])
        oil_tariff_template_file_content = oil_tariff_template_file_content.sub("%demand_charges_blk5_rate%",demand_charges_blk_rate[4])
        break
      end
    end
    
    # if there was no matching electricity tariff for the city, then register the information
    if(elec_tariff == "")
      BTAP::runner_register("ERROR", "no electricity tariff in database for #{weather_station}",runner)
      #fail the measure
      return false
    end

    # if there was no matching Gas tariff for the city, then register the information
    if(gas_tariff == "")
      runner.registerInfo("")
      BTAP::runner_register("ERROR", "no gas tariff in database for #{weather_station}",runner)
      #fail the measure
      return false
    end

    # if there was no matching Oil tariff for the city, then register the information
    if(oil_tariff == "")
      runner.registerInfo("")
      BTAP::runner_register("ERROR", "no oil tariff in database for #{weather_station}",runner)
      #fail the measure
      return false
    end
    
    # save new tariff idf file
    tariff_file = File.new("#{File.dirname(__FILE__)}/resources/tariff.idf","w")
    tariff_file.puts(elec_tariff_template_file_content)
    tariff_file.puts(gas_tariff_template_file_content)
    tariff_file.puts(oil_tariff_template_file_content)
    tariff_file.close

    # load the idf file containing the electric tariff
    tar_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/resources/tariff.idf")
    tar_file = OpenStudio::IdfFile::load(tar_path)

    # in OpenStudio PAT in 1.1.0 and earlier all resource files are moved up a directory.
    # below is a temporary workaround for this before issuing an error.
    if tar_file.empty?
      tar_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/tariff.idf")
      tar_file = OpenStudio::IdfFile::load(tar_path)
    end

    if tar_file.empty?
      runner.registerError("Unable to find the file #{tar_path}")
      return false
    else
      tar_file = tar_file.get
    end

    # add the tariffs
    workspace.addObjects(tar_file.getObjectsByType("UtilityCost:Tariff".to_IddObjectType))
      
    # add the simple charges
    workspace.addObjects(tar_file.getObjectsByType("UtilityCost:Charge:Simple".to_IddObjectType))
      
    # add the block charges
    workspace.addObjects(tar_file.getObjectsByType("UtilityCost:Charge:Block".to_IddObjectType))
    
    # let the user know what happened
    runner.registerInfo("added a tariffs named #{elec_tariff}, #{gas_tariff}, and #{oil_tariff}")
    
    # set the simulation timestep to 15min (4 per hour) to match the demand window of the tariffs
    if not workspace.getObjectsByType("Timestep".to_IddObjectType).empty?
      workspace.getObjectsByType("Timestep".to_IddObjectType)[0].setString(0,"4")
      runner.registerInfo("set the simulation timestep to 15 min to match the demand window of the tariffs")
    else
      runner.registerError("there was no timestep object to alter")
    end

    # remove any existing lifecycle cost parameters
    workspace.getObjectsByType("LifeCycleCost:Parameters".to_IddObjectType).each do |object|
      runner.registerInfo("removed existing lifecycle parameters named #{object.name}")
      workspace.removeObjects([object.handle])
    end

    # and replace with the FEMP ones
    life_cycle_params_string = "    
    LifeCycleCost:Parameters,
      FEMP LifeCycle Cost Parameters,         !- Name
      EndOfYear,                              !- Discounting Convention
      ConstantDollar,                         !- Inflation Approach
      0.03,                                   !- Real Discount Rate
      ,                                       !- Nominal Discount Rate
      ,                                       !- Inflation
      ,                                       !- Base Date Month
      2011,                                   !- Base Date Year
      ,                                       !- Service Date Month
      2011,                                   !- Service Date Year
      25,                                     !- Length of Study Period in Years
      ,                                       !- Tax rate
      None;                                   !- Depreciation Method	  
    "  
    life_cycle_params = OpenStudio::IdfObject::load(life_cycle_params_string).get
    workspace.addObject(life_cycle_params)
    runner.registerInfo("added lifecycle cost parameters named #{life_cycle_params.name}")
  
    #remove any existing lifecycle cost parameters
    workspace.getObjectsByType("LifeCycleCost:UsePriceEscalation".to_IddObjectType).each do |object|
      runner.registerInfo("removed existing fuel escalation rates named #{object.name}")
      workspace.removeObjects([object.handle])
    end  
  
    elec_escalation_string = "
    LifeCycleCost:UsePriceEscalation,
      U.S. Avg  Commercial-Electricity,       !- Name
      Electricity,                            !- Resource
      2011,                                   !- Escalation Start Year
      January,                                !- Escalation Start Month
      0.9838,                                 !- Year Escalation 1
      0.9730,                                 !- Year Escalation 2
      0.9632,                                 !- Year Escalation 3
      0.9611,                                 !- Year Escalation 4
      0.9571,                                 !- Year Escalation 5
      0.9553,                                 !- Year Escalation 6
      0.9539,                                 !- Year Escalation 7
      0.9521,                                 !- Year Escalation 8
      0.9546,                                 !- Year Escalation 9
      0.9550,                                 !- Year Escalation 10
      0.9553,                                 !- Year Escalation 11
      0.9564,                                 !- Year Escalation 12
      0.9575,                                 !- Year Escalation 13
      0.9596,                                 !- Year Escalation 14
      0.9618,                                 !- Year Escalation 15
      0.9614,                                 !- Year Escalation 16
      0.9618,                                 !- Year Escalation 17
      0.9618,                                 !- Year Escalation 18
      0.9593,                                 !- Year Escalation 19
      0.9589,                                 !- Year Escalation 20
      0.9607,                                 !- Year Escalation 21
      0.9625,                                 !- Year Escalation 22
      0.9650,                                 !- Year Escalation 23
      0.9708,                                 !- Year Escalation 24
      0.9751,                                 !- Year Escalation 25
      0.9762,                                 !- Year Escalation 26
      0.9766,                                 !- Year Escalation 27
      0.9766,                                 !- Year Escalation 28
      0.9769,                                 !- Year Escalation 29
      0.9773;                                 !- Year Escalation 30
    "
    elec_escalation = OpenStudio::IdfObject::load(elec_escalation_string).get
    workspace.addObject(elec_escalation)  
    runner.registerInfo("added fuel escalation rates named #{elec_escalation.name}")    

    fuel_oil_1_escalation_string = "
    LifeCycleCost:UsePriceEscalation,
      U.S. Avg  Commercial-Distillate Oil,    !- Name
      FuelOil#1,                              !- Resource
      2011,                                   !- Escalation Start Year
      January,                                !- Escalation Start Month
      0.9714,                                 !- Year Escalation 1
      0.9730,                                 !- Year Escalation 2
      0.9942,                                 !- Year Escalation 3
      1.0164,                                 !- Year Escalation 4
      1.0541,                                 !- Year Escalation 5
      1.0928,                                 !- Year Escalation 6
      1.1267,                                 !- Year Escalation 7
      1.1580,                                 !- Year Escalation 8
      1.1792,                                 !- Year Escalation 9
      1.1967,                                 !- Year Escalation 10
      1.2200,                                 !- Year Escalation 11
      1.2333,                                 !- Year Escalation 12
      1.2566,                                 !- Year Escalation 13
      1.2709,                                 !- Year Escalation 14
      1.2826,                                 !- Year Escalation 15
      1.2985,                                 !- Year Escalation 16
      1.3102,                                 !- Year Escalation 17
      1.3250,                                 !- Year Escalation 18
      1.3261,                                 !- Year Escalation 19
      1.3282,                                 !- Year Escalation 20
      1.3324,                                 !- Year Escalation 21
      1.3356,                                 !- Year Escalation 22
      1.3431,                                 !- Year Escalation 23
      1.3510,                                 !- Year Escalation 24
      1.3568,                                 !- Year Escalation 25
      1.3606,                                 !- Year Escalation 26
      1.3637,                                 !- Year Escalation 27
      1.3674,                                 !- Year Escalation 28
      1.3706,                                 !- Year Escalation 29
      1.3743;                                 !- Year Escalation 30
    "
    fuel_oil_1_escalation = OpenStudio::IdfObject::load(fuel_oil_1_escalation_string).get
    workspace.addObject(fuel_oil_1_escalation)
    runner.registerInfo("added fuel escalation rates named #{fuel_oil_1_escalation.name}")    
      
    fuel_oil_2_escalation_string = "  
    LifeCycleCost:UsePriceEscalation,
      U.S. Avg  Commercial-Residual Oil,      !- Name
      FuelOil#2,                              !- Resource
      2011,                                   !- Escalation Start Year
      January,                                !- Escalation Start Month
      0.8469,                                 !- Year Escalation 1
      0.8257,                                 !- Year Escalation 2
      0.8681,                                 !- Year Escalation 3
      0.8988,                                 !- Year Escalation 4
      0.9289,                                 !- Year Escalation 5
      0.9604,                                 !- Year Escalation 6
      0.9897,                                 !- Year Escalation 7
      1.0075,                                 !- Year Escalation 8
      1.0314,                                 !- Year Escalation 9
      1.0554,                                 !- Year Escalation 10
      1.0861,                                 !- Year Escalation 11
      1.1278,                                 !- Year Escalation 12
      1.1497,                                 !- Year Escalation 13
      1.1620,                                 !- Year Escalation 14
      1.1743,                                 !- Year Escalation 15
      1.1852,                                 !- Year Escalation 16
      1.1948,                                 !- Year Escalation 17
      1.2037,                                 !- Year Escalation 18
      1.2071,                                 !- Year Escalation 19
      1.2119,                                 !- Year Escalation 20
      1.2139,                                 !- Year Escalation 21
      1.2194,                                 !- Year Escalation 22
      1.2276,                                 !- Year Escalation 23
      1.2365,                                 !- Year Escalation 24
      1.2420,                                 !- Year Escalation 25
      1.2461,                                 !- Year Escalation 26
      1.2509,                                 !- Year Escalation 27
      1.2550,                                 !- Year Escalation 28
      1.2591,                                 !- Year Escalation 29
      1.2638;                                 !- Year Escalation 30
    "
    fuel_oil_2_escalation = OpenStudio::IdfObject::load(fuel_oil_2_escalation_string).get
    workspace.addObject(fuel_oil_2_escalation)
    runner.registerInfo("added fuel escalation rates named #{fuel_oil_2_escalation.name}") 
      
    nat_gas_escalation_string = "
    LifeCycleCost:UsePriceEscalation,
      U.S. Avg  Commercial-Natural gas,       !- Name
      NaturalGas,                             !- Resource
      2011,                                   !- Escalation Start Year
      January,                                !- Escalation Start Month
      0.9823,                                 !- Year Escalation 1
      0.9557,                                 !- Year Escalation 2
      0.9279,                                 !- Year Escalation 3
      0.9257,                                 !- Year Escalation 4
      0.9346,                                 !- Year Escalation 5
      0.9412,                                 !- Year Escalation 6
      0.9512,                                 !- Year Escalation 7
      0.9645,                                 !- Year Escalation 8
      0.9856,                                 !- Year Escalation 9
      1.0067,                                 !- Year Escalation 10
      1.0222,                                 !- Year Escalation 11
      1.0410,                                 !- Year Escalation 12
      1.0610,                                 !- Year Escalation 13
      1.0787,                                 !- Year Escalation 14
      1.0942,                                 !- Year Escalation 15
      1.1098,                                 !- Year Escalation 16
      1.1220,                                 !- Year Escalation 17
      1.1308,                                 !- Year Escalation 18
      1.1386,                                 !- Year Escalation 19
      1.1486,                                 !- Year Escalation 20
      1.1619,                                 !- Year Escalation 21
      1.1763,                                 !- Year Escalation 22
      1.1918,                                 !- Year Escalation 23
      1.2118,                                 !- Year Escalation 24
      1.2284,                                 !- Year Escalation 25
      1.2439,                                 !- Year Escalation 26
      1.2605,                                 !- Year Escalation 27
      1.2772,                                 !- Year Escalation 28
      1.2938,                                 !- Year Escalation 29
      1.3115;                                 !- Year Escalation 30
    "
    nat_gas_escalation = OpenStudio::IdfObject::load(nat_gas_escalation_string).get
    workspace.addObject(nat_gas_escalation) 
    runner.registerInfo("added fuel escalation rates named #{nat_gas_escalation.name}")     
    
    coal_escalation_string = "  
    LifeCycleCost:UsePriceEscalation,
      U.S. Avg  Commercial-Coal,              !- Name
      Coal,                                   !- Resource
      2011,                                   !- Escalation Start Year
      January,                                !- Escalation Start Month
      0.9970,                                 !- Year Escalation 1
      1.0089,                                 !- Year Escalation 2
      1.0089,                                 !- Year Escalation 3
      0.9941,                                 !- Year Escalation 4
      0.9941,                                 !- Year Escalation 5
      1.0000,                                 !- Year Escalation 6
      1.0030,                                 !- Year Escalation 7
      1.0059,                                 !- Year Escalation 8
      1.0089,                                 !- Year Escalation 9
      1.0119,                                 !- Year Escalation 10
      1.0148,                                 !- Year Escalation 11
      1.0178,                                 !- Year Escalation 12
      1.0208,                                 !- Year Escalation 13
      1.0267,                                 !- Year Escalation 14
      1.0297,                                 !- Year Escalation 15
      1.0356,                                 !- Year Escalation 16
      1.0415,                                 !- Year Escalation 17
      1.0534,                                 !- Year Escalation 18
      1.0564,                                 !- Year Escalation 19
      1.0593,                                 !- Year Escalation 20
      1.0653,                                 !- Year Escalation 21
      1.0712,                                 !- Year Escalation 22
      1.0742,                                 !- Year Escalation 23
      1.0801,                                 !- Year Escalation 24
      1.0831,                                 !- Year Escalation 25
      1.0831,                                 !- Year Escalation 26
      1.0861,                                 !- Year Escalation 27
      1.0890,                                 !- Year Escalation 28
      1.0920,                                 !- Year Escalation 29
      1.0950;                                 !- Year Escalation 30
    "
    coal_escalation = OpenStudio::IdfObject::load(coal_escalation_string).get
    workspace.addObject(coal_escalation)             
    runner.registerInfo("added fuel escalation rates named #{coal_escalation.name}")                   
    
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
UtilityTariffsModelSetup.new.registerWithApplication
