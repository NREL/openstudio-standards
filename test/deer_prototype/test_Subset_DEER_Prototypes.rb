require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_deer_prototype_helper'

class TestSubsetDEERPrototypes < CreateDEERPrototypeBuildingTest
  
  building_types = [
      'Asm',
      'ECC',
      'EPr',
      'ERC',
      'ESe',
      'EUn',
      'Gro',
      'Hsp',
      'Nrs',
      'Htl',
      'Mtl',
      'MBT',
      'MLI',
      'OfL',
      'OfS',
      'RFF',
      'RSD',
      'Rt3',
      'RtL',
      'RtS',
      'SCn',
      'SUn',
      'WRf',
      'MFm'
  ]

  # DEER HVAC type defaults by building type
  building_to_hvac_system_defaults = {
      'Asm' => ['DXGF'],
      'ECC' => ['SVVG'],
      'EPr' => ['DXGF'],
      'ERC' => ['DXHP'],
      'ESe' => ['DXGF'],
      'EUn' => ['SVVG'],
      'Gro' => ['DXGF'],
      'Hsp' => ['SVVG'],
      'Nrs' => ['DXGF'],
      'Htl' => ['SVVG'],
      'Mtl' => ['DXHP'],
      'MBT' => ['DXGF'],
      'MFm' => ['DXGF'],
      'MLI' => ['DXGF'],
      'OfL' => ['SVVG'],
      'OfS' => ['DXGF'],
      'RFF' => ['DXGF'],
      'RSD' => ['DXGF'],
      'Rt3' => ['SVVG'],
      'RtL' => ['DXGF'],
      'RtS' => ['DXGF'],
      'SCn' => ['DXGF'],
      'SUn' => ['Unc'], # listed as cNCGF in DEER database
      'WRf' => ['DXGF']
  }
  
  templates = ['DEER 1996']
  climate_zones = ['CEC T24-CEC9']

  create_models = true
  run_models = true
  compare_results = false
  
  debug = true
  
  # Create a new set of tests for each building type because HVAC systems aren't all the same
  building_types.each do |building_type|
    hvacs = building_to_hvac_system_defaults[building_type]
    TestSubsetDEERPrototypes.create_run_model_tests([building_type], templates, hvacs, climate_zones, create_models, run_models, compare_results, debug)
  end

end
