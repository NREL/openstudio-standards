require_relative './libs.rb'
WEATHER_FILE = 'CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw'
# Create NECB2011 objects
NECB = NECB2011.new
$base_model = nil
$failures = []
$successes = []

def create_model()
        # create model
        standard = Standard.build('NECB2011') 
        if $base_model.nil?  
            $base_model = standard.load_building_type_from_library(building_type: 'SmallOffice')
            standard.apply_weather_data(model: $base_model, epw_file: WEATHER_FILE)
            standard.apply_loads(model: $base_model)
            standard.apply_envelope(model: $base_model)
            standard.apply_fdwr_srr_daylighting(model: $base_model)
            standard.apply_auto_zoning(model: $base_model)
        end
        return BTAP::FileIO.deep_copy($base_model)
end

def system1()
    create_model()
    mau_type = [true]
    mau_heating_types = ["DX","Hot Water", "Electric"]
    necb_reference_hp_types = [true, false] 
    necb_reference_hp_supp_fuel_types = ["NaturalGas", "Electricity"]
    baseboard_types = ["Hot Water", "Electric"]
    # Generate all possible combinations of the above arrays
    mau_type.product(mau_heating_types, necb_reference_hp_types, necb_reference_hp_supp_fuel_types, baseboard_types).each do |mau_type, mau_heating_type, necb_reference_hp, necb_reference_hp_supp_fuel, baseboard_type|
        model = create_model()

        # Create hot water loop
        hw_loop = OpenStudio::Model::PlantLoop.new(model)


        # Create NECB2011 objects
        necb = NECB2011.new
        
        
        if (mau_type == false and necb_reference_hp == true) or 
            (necb_reference_hp == true and mau_heating_type != 'DX') or 
            (necb_reference_hp == false and mau_heating_type == 'DX')
            next
        end
        arguments = Hash[
                            "mau_type", mau_type, 
                            "mau_heating_type", mau_heating_type, 
                            "necb_reference_hp", necb_reference_hp, 
                            "necb_reference_hp_supp_fuel", necb_reference_hp_supp_fuel, 
                            "baseboard_type", baseboard_type
                        ]

        old_name, new_name = necb.add_sys1_unitary_ac_baseboard_heating_single_speed(
            model: model,
            necb_reference_hp: necb_reference_hp,
            necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
            zones: model.getThermalZones,
            mau_type: mau_type,
            mau_heating_coil_type: mau_heating_type,
            baseboard_type: baseboard_type,
            hw_loop: hw_loop
            )
        if old_name == new_name
            $successes.push([arguments,old_name,new_name])
        else
            $failures.push([arguments,old_name,new_name])
        end
    end
end

def system2_5()
    fan_coil_types = ['FPFC','TPFC']
    chiller_types = ["Scroll","Centrifugal","RotaryScrew","Reciprocating"]
    mau_cooling_types = ["DX","Hydronic"]
    # Generate all possible combinations of the above arrays
    mau_cooling_types.product( chiller_types, fan_coil_types).each do |mau_cooling_type, chiller_type, fan_coil_type|
        puts("mau_cooling_type: #{mau_cooling_type}, chiller_types: #{chiller_type}, fan_coil_types: #{fan_coil_type}")
        arguments = Hash[
            "mau_cooling_type", mau_cooling_type, 
            "chiller_type", chiller_type, 
            "fan_coil_type", fan_coil_type, 
        ]

        #Create model
        model = create_model

        # Create hot water loop
        hw_loop = OpenStudio::Model::PlantLoop.new(model)

        # Create NECB2011 objects
        old_name, new_name = NECB2011.new.add_sys2_FPFC_sys5_TPFC( model: model,
                                                zones:model.getThermalZones,
                                                chiller_type: chiller_type,
                                                fan_coil_type: fan_coil_type,
                                                mau_cooling_type: mau_cooling_type,
                                                hw_loop: hw_loop)
        if old_name == new_name
            $successes.push([arguments,old_name,new_name])
        else
            $failures.push([arguments,old_name,new_name])
        end
end
end

def system3()
    mau_type = [true]
    heating_coil_types = ["DX","Gas", "Electric"]
    necb_reference_hp_types = [true, false] 
    necb_reference_hp_supp_fuel_types = ["NaturalGas", "Electricity"]
    baseboard_types = ["Hot Water", "Electric"]
    # Generate all possible combinations of the above arrays
    mau_type.product(heating_coil_types, necb_reference_hp_types, necb_reference_hp_supp_fuel_types, baseboard_types).each do |mau_type, heating_coil_type, necb_reference_hp, necb_reference_hp_supp_fuel, baseboard_type|
        arguments = Hash[
            "mau_type", mau_type, 
            "heating_coil_type", heating_coil_type, 
            "necb_reference_hp", necb_reference_hp, 
            "necb_reference_hp_supp_fuel", necb_reference_hp_supp_fuel, 
            "baseboard_type", baseboard_type
        ]


        #Create model
        model = create_model

        hw_loop = nil
        if (baseboard_type == "Hot Water")
            hw_loop = OpenStudio::Model::PlantLoop.new(model)
            NECB.setup_hw_loop_with_components(model, hw_loop, 'Electricity', model.alwaysOnDiscreteSchedule)
        end

        if (mau_type == false and necb_reference_hp == true) or 
            (necb_reference_hp == true and heating_coil_type != 'DX') or 
            (necb_reference_hp == false and heating_coil_type == 'DX')
            next
        end
        old_name, new_name = NECB.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(
            model: model,
            necb_reference_hp: necb_reference_hp,
            necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
            zones: model.getThermalZones,
            heating_coil_type: heating_coil_type,
            baseboard_type: baseboard_type,
            hw_loop: hw_loop,
            new_auto_zoner: true)
            if old_name == new_name
                $successes.push([arguments,old_name,new_name])
            else
                $failures.push([arguments,old_name,new_name])
            end
    end
    
end

def system6()
    heating_coil_types = ["Electric" , "Hot Water"]
    baseboard_types = ["Electric", "Hot Water"]
    chiller_types = ["Scroll","Centrifugal","RotaryScrew","Reciprocating"]
    fan_types = ["AF_or_BI_rdg_fancurve","AF_or_BI_inletvanes","fc_inletvanes","var_speed_drive"]
    # Generate all possible combinations of the above arrays
    heating_coil_types.product( baseboard_types, chiller_types, fan_types).each do |heating_coil_type, baseboard_type, chiller_type, fan_type|
            puts("heating_coil_type: #{heating_coil_type}  baseboard_type: #{baseboard_type}, chiller_type: #{chiller_type}, fan_type : #{fan_type}")
            arguments = Hash[
                "heating_coil_type", heating_coil_type, 
                "baseboard_type", baseboard_type, 
                "chiller_type", chiller_type, 
                "fan_type", fan_type, 
            ]
    
            #Create model
            model = create_model

            # Create hot water loop
            hw_loop = OpenStudio::Model::PlantLoop.new(model)

            # Create NECB2011 objects
            old_name,new_name = NECB2011.new.add_sys6_multi_zone_built_up_system_with_baseboard_heating(
                    model:model,
                    zones:model.getThermalZones,
                    heating_coil_type: heating_coil_type,
                    baseboard_type: baseboard_type,
                    chiller_type: chiller_type,
                    fan_type: fan_type,
                    hw_loop: hw_loop
                    )

            if old_name == new_name
                $successes.push([arguments,old_name,new_name])
            else
                $failures.push([arguments,old_name,new_name])
            end
        end
end



system1()
system2_5()
system3()
system6()
puts ("Successes: #{$successes}")
puts("Failures: #{$failures}")
#Save $failures hash to the csv file.
CSV.open('failures.csv', 'w') do |csv|
    csv << ["arguments","old_name","new_name"]
    $failures.each do |failure|
        csv << failure
    end
end
#Save $successes hash to the csv file.
CSV.open('successes.csv', 'w') do |csv|
    csv << ["arguments","old_name","new_name"]
    $successes.each do |success|
        csv << success
    end
end

