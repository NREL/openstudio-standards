require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_deer_prototype_helper'

class TestDefaultHVACDEERPrototypes < CreateDEERPrototypeBuildingTest
  
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

  # Only a subset of building type and HVAC type combinations are valid
  building_to_hvac_systems = {
      'Asm' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF'],
      'ECC' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF',
          'PVVE',
          'PVVG',
          'SVVE',
          'SVVG',
          'WLHP'],
      'EPr' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF',
          'WLHP'],
      'ERC' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF'],
      'ESe' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF',
          'PVVE',
          'PVVG',
          'SVVE',
          'SVVG',
          'WLHP'],
      'EUn' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF',
          'PVVE',
          'PVVG',
          'SVVE',
          'SVVG'],
      'Gro' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF'],
      'Hsp' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF',
          'PVVE',
          'PVVG',
          'SVVE',
          'SVVG'],
      'Nrs' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'FPFC',
          'NCEH',
          'NCGF',
          'PVVE',
          'PVVG',
          'SVVE',
          'SVVG'],
      'Htl' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF',
          'PVVE',
          'PVVG',
          'SVVE',
          'SVVG',
          'WLHP'],
      'Mtl' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF'],
      'MBT' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF',
          'PVVE',
          'PVVG',
          'SVVE',
          'SVVG',
          'WLHP'],
      'MFm' => [
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF'],
      'MLI' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF'],
      'OfL' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF',
          'PVVE',
          'PVVG',
          'SVVE',
          'SVVG',
          'WLHP'],
      'OfS' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF',
          'PVVE',
          'PVVG',
          'SVVE',
          'SVVG',
          'WLHP'],
      'RFF' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF'],
      'RSD' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF'],
      'Rt3' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF',
          'PVVE',
          'PVVG',
          'SVVE',
          'SVVG',
          'WLHP'],
      'RtL' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF'],
      'RtS' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF'],
      'SCn' => [
          'DXEH',
          'DXGF',
          'DXHP',
          'NCEH',
          'NCGF'],
      'SUn' => ['Unc'],
      'WRf' => ['DXGF']
  }
  
  building_to_hvac_system_defaults = {
      'Asm' => ['DXGF'],
      'ECC' => ['SVVG'],
      'EPr' => ['DXGF'],
      'ERC' => ['DXHP'],
      'ESe' => ['DXGF'],
      'EUn' => ['SVVG'],
      'Gro' => ['DXGF'],
      'Hsp' => ['SVVG'],
      'Nrs' => ['FPFC'],
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
  
  templates = ['DEER Pre-1975', 'DEER 1985', 'DEER 1996', 'DEER 2003', 'DEER 2007', 'DEER 2011', 'DEER 2014', 'DEER 2015', 'DEER 2017']
  climate_zones = ['CEC T24-CEC1', 'CEC T24-CEC2', 'CEC T24-CEC3', 'CEC T24-CEC4',
                  'CEC T24-CEC5', 'CEC T24-CEC6', 'CEC T24-CEC7', 'CEC T24-CEC8',
                  'CEC T24-CEC9', 'CEC T24-CEC10', 'CEC T24-CEC11', 'CEC T24-CEC12',
                  'CEC T24-CEC13', 'CEC T24-CEC14', 'CEC T24-CEC15', 'CEC T24-CEC16']

  create_models = true
  run_models = false
  compare_results = false
  
  debug = false
  
  # Create a new set of tests for each building type because HVAC systems aren't all the same
  building_types.each do |building_type|
    hvacs = building_to_hvac_system_defaults[building_type]
    TestDefaultHVACDEERPrototypes.create_run_model_tests(building_types, templates, hvacs, climate_zones, create_models, run_models, compare_results, debug)
  end

end
