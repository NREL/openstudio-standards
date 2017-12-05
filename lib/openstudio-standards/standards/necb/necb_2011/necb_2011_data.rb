class NECB2011

  def load_standards_data

    load_standards_database


    #FDWR

    #SRR
    @standards_data['skylight_to_roof_ratio_max'] = {
        'data_type' => 'value',
        'refs' => ['NECB2011_S_3.2.1.4(2)'],
        'value' => 0.05,
        'units' => 'ratio'
    }
    # Surfaces
    @standards_data['surface_thermal_transmittance'] = {
        'data_type' => 'table',
        'ref' => ['NECB2011_S_3.2.2.2', 'NECB2011_S_3.2.2.3', 'NECB2011_S_3.2.2.4', 'NECB2011_S_3.2.3.1'],
        'units' => 'W_per_m2_K',
        'variable_ranges' => {
            'boundary_condition' => ['Outdoors', 'Ground'],
            'surface' => ['Wall', 'RoofCeiling','Floor'],
            'hdd' => [0.0,10000.0]
        },
        'table' => [
            {'boundary_condition' => 'Outdoors', 'surface' => 'Wall', 'formula' => "( hdd < 3000) ? 0.315 : ( hdd < 4000) ? 0.278 : ( hdd < 5000 ) ? 0.247 : ( hdd < 6000) ? 0.210 :( hdd < 7000) ? 0.210 : 0.183"},
            {'boundary_condition' => 'Outdoors', 'surface' => 'RoofCeiling', 'formula' => "( hdd < 3000) ? 0.227 : ( hdd < 4000) ? 0.183 : ( hdd < 5000 ) ? 0.183 : ( hdd < 6000) ? 0.162 :( hdd < 7000) ? 0.162 : 0.142"},
            {'boundary_condition' => 'Outdoors', 'surface' => 'Floor', 'formula' => "( hdd < 3000) ? 0.227 : ( hdd < 4000) ? 0.183 : ( hdd < 5000 ) ? 0.183 : ( hdd < 6000) ? 0.162 :( hdd < 7000) ? 0.162 : 0.142"},
            {'boundary_condition' => 'Outdoors', 'surface' => 'Window', 'formula' => " ( hdd < 3000) ? 2.400 : ( hdd < 7000) ? 2.200 : 1.600"},
            {'boundary_condition' => 'Outdoors', 'surface' => 'Door', 'formula' => "( hdd < 3000) ? 2.400 : ( hdd < 7000) ? 2.200 : 1.600"},
            {'boundary_condition' => 'Ground', 'surface' => 'Wall', 'formula' => "( hdd < 3000) ? 0.568 : ( hdd < 4000) ? 0.379 : ( hdd < 7000) ? 0.284 : 0.210"},
            {'boundary_condition' => 'Ground', 'surface' => 'RoofCeiling', 'formula' => "( hdd < 3000) ? 0.568 : ( hdd < 4000) ? 0.379 : ( hdd < 7000) ? 0.284 : 0.210"},
            {'boundary_condition' => 'Ground', 'surface' => 'Floor', 'formula' => "( hdd < 7000) ? 0.757 : 0.379"}
        ],
        'notes' => 'Requires hdd to be defined to be evaluated in code. Never have ground windows or doors.'
    }


    #Interior Surfaces
    @standards_data['interior_adiabatic_temperature_limit'] = {
        'data_type' => 'value',
        'refs' => ['NECB2011_S_8.4.2.6(1)'],
        'value' => 10.0,
        'units' => "C",
        'implemented' => false}

    @standards_data['interior_not_solid_partition_heat_transer_value'] = {
        'data_type' => 'value',
        'refs' => ['NECB2011_S_8.4.2.6(2)'],
        'value' => 0.35,
        'units' => "C",
        'implemented' => false}


    @standards_data['max_underheated_hours'] = {
        'data_type' => 'value',
        'value' => 100.0,
        'units' => 'hours',
        'ref' => 'NECB2011_S_8.4.1.2(3)',
        'implemented' => false
    }

    @standards_data['max_undercooled_percent_diff'] = {
        'data_type' => 'value',
        'ref' => 'NECB2011_S_8.4.1.2(4)',
        'value' => 10.0,
        'units' => '%',
        'implemented' => false}


    @standards_data['standard_system_by_space_catagory_formula'] = {
        'data_type' => 'formula',
        'ref' => ['NECB2011_8.4.4.8.A'],
        'formula' => "
           (space_category == '- undefined -') ? 0 :
           (space_category == 'Assembly Area') ? ( stories <= 4) ? 3 : 6 :
           (space_category == 'Automotive Area') ? 4 :
           (space_category == 'Data Processing Area') ? ( cooling_capacity < 20 ) ? 1 : 2 :
           (space_category == 'General Area') ? ( stories <= 2) ? 3 : 6 :
           (space_category == 'Historical Collections Area') ? 2 :
           (space_category == 'Hospital Area') ? 3 :
           (space_category == 'Indoor Arena') ? 7 :
           (space_category == 'Industrial Area') ? 3 :
           (space_category == 'Residential/Accomodation Area') ? 1 :
           (space_category == 'Supermarket/Food Services Area') ? (vented == true) ? 4 : 3 :
           (space_category == 'Warehouse Area') ? (refrigerated == true) : 5 :4 :
           (space_category == 'Wildcard') ? nil",
        'arguments' => 'space_category, stories, cooling_capacity'
    }

    # This is the formula that will be used in a ruby eval given the hdd variable.
    @standards_data['max_heating_sizing_factor'] = {'value' => 1.3, 'reference' => 'S_8.4.4.9(2)'}
    @standards_data['S_8.4.4.9(2)'] = {'max_cooling_sizing_factor' => 1.1}

    #Fan Information
    @standards_data['fan_variable_volume_pressure_rise'] = 1458.33
    @standards_data['fan_constant_volume_pressure_rise'] = 640.00
    @standards_data['fan_motors'] = [
        {'fan_type' => 'CONSTANT', 'number_of_poles' => 4.0, 'type' => 'Enclosed', 'synchronous_speed' => 1800.0, 'minimum_capacity' => 0.0, 'maximum_capacity' => 9999.0, 'nominal_full_load_efficiency' => 0.615, 'notes' => 'To get total fan efficiency of 40% (0.4/0.65)'},
        {'fan_type' => 'VARIABLE', 'number_of_poles' => 4.0, 'type' => 'Enclosed', 'synchronous_speed' => 1800.0, 'minimum_capacity' => 0.0, 'maximum_capacity' => 9999.0, 'nominal_full_load_efficiency' => 0.8461, 'notes' => 'To get total fan efficiency of 55% (0.55/0.65)'}
    ]
    # NECB Infiltration rate information for standard.
    @standards_data['infiltration'] = {}
    @standards_data['infiltration']['rate_m3_per_s_per_m2'] = 0.25 * 0.001 # m3/s/m2
    @standards_data['infiltration']['constant_term_coefficient'] = 0.0
    @standards_data['infiltration']['temperature_term_coefficient'] = 0.0
    @standards_data['infiltration']['velocity_term_coefficient'] = 0.224
    @standards_data['infiltration']['velocity_squared_term_coefficient'] = 0.0
    @standards_data['skylight_to_roof_ratio'] = 0.05
  end

end
workbook = RubyXL::Workbook.new()

