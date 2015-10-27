# *********************************************************************
# *  Copyright (c) 2008-2015, Natural Resources Canada
# *  All rights reserved.
# *
# *  This library is free software; you can redistribute it and/or
# *  modify it under the terms of the GNU Lesser General Public
# *  License as published by the Free Software Foundation; either
# *  version 2.1 of the License, or (at your option) any later version.
# *
# *  This library is distributed in the hope that it will be useful,
# *  but WITHOUT ANY WARRANTY; without even the implied warranty of
# *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# *  Lesser General Public License for more details.
# *
# *  You should have received a copy of the GNU Lesser General Public
# *  License along with this library; if not, write to the Free Software
# *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
# **********************************************************************/



require 'open-uri'
module BTAP
  module Environment
    WeatherData =  
      {  
      "CAN_AB_Calgary.718770_CWEC.epw" => { "country" => "CAN", "state_province" => "AB", "city" => "Calgary Int'l","hdd18" => 5146.0,"cdd18" => 40.0,"latitude" => 51.12, "longitude" => -114.02, "elevation" => 1084.0, "monthly_dry_bulb" => "[-8.2, -6.4, -3.8, 4.3, 9.4, 14.6, 16.8, 16.0, 10.2, 5.9, -3.6, -7.9]", "delta_dry_bulb" => 25.0 },
      "CAN_AB_Edmonton.711230_CWEC.epw" => { "country" => "CAN", "state_province" => "AB", "city" => "Edmonton Stony Plain","hdd18" => 5583.0,"cdd18" => 22.0,"latitude" => 53.53, "longitude" => -114.1, "elevation" => 723.0, "monthly_dry_bulb" => "[-11.8, -9.4, -2.7, 3.9, 10.9, 14.4, 15.7, 14.7, 8.7, 3.5, -6.5, -9.1]", "delta_dry_bulb" => 27.5 },
      "CAN_AB_Fort.McMurray.719320_CWEC.epw" => { "country" => "CAN", "state_province" => "AB", "city" => "Fort McMurray","hdd18" => 6191.0,"cdd18" => 65.0,"latitude" => 56.65, "longitude" => -111.22, "elevation" => 369.0, "monthly_dry_bulb" => "[-16.1, -12.7, -8.2, 1.7, 11.6, 15.1, 17.4, 14.8, 8.7, 3.8, -8.8, -13.8]", "delta_dry_bulb" => 33.5 },
      "CAN_AB_Grande.Prairie.719400_CWEC.epw" => { "country" => "CAN", "state_province" => "AB", "city" => "Grand Prairie","hdd18" => 5897.0,"cdd18" => 26.0,"latitude" => 55.18, "longitude" => -118.88, "elevation" => 669.0, "monthly_dry_bulb" => "[-13.3, -10.7, -6.3, 2.6, 9.7, 14.0, 15.6, 15.3, 9.7, 4.2, -6.4, -12.2]", "delta_dry_bulb" => 28.9 },
      "CAN_AB_Lethbridge.712430_CWEC.epw" => { "country" => "CAN", "state_province" => "AB", "city" => "Lethbridge","hdd18" => 4432.0,"cdd18" => 126.0,"latitude" => 49.63, "longitude" => -112.8, "elevation" => 921.0, "monthly_dry_bulb" => "[-6.8, -7.6, 0.2, 6.8, 11.1, 16.6, 18.9, 17.6, 12.3, 7.5, 0.8, -3.9]", "delta_dry_bulb" => 26.5 },
      "CAN_AB_Medicine.Hat.718720_CWEC.epw" => { "country" => "CAN", "state_province" => "AB", "city" => "Medicine Hat","hdd18" => 4678.0,"cdd18" => 199.0,"latitude" => 50.02, "longitude" => -110.72, "elevation" => 716.0, "monthly_dry_bulb" => "[-11.8, -7.1, 0.4, 6.0, 12.1, 17.1, 19.6, 19.8, 12.8, 8.1, -2.4, -6.8]", "delta_dry_bulb" => 31.6 },
      "CAN_BC_Abbotsford.711080_CWEC.epw" => { "country" => "CAN", "state_province" => "BC", "city" => "Abbotsford","hdd18" => 3134.0,"cdd18" => 33.0,"latitude" => 49.03, "longitude" => -122.37, "elevation" => 58.0, "monthly_dry_bulb" => "[2.8, 3.9, 5.4, 8.4, 12.3, 14.4, 16.8, 17.1, 13.5, 10.2, 5.3, 3.5]", "delta_dry_bulb" => 14.3 },
      "CAN_BC_Comox.718930_CWEC.epw" => { "country" => "CAN", "state_province" => "BC", "city" => "Comox","hdd18" => 3177.0,"cdd18" => 30.0,"latitude" => 49.72, "longitude" => -124.9, "elevation" => 24.0, "monthly_dry_bulb" => "[2.1, 4.6, 5.6, 8.6, 11.3, 14.4, 17.1, 17.3, 13.5, 9.2, 5.5, 3.3]", "delta_dry_bulb" => 15.200000000000001 },
      "CAN_BC_Cranbrook.718800_CWEC.epw" => { "country" => "CAN", "state_province" => "BC", "city" => "Cranbrook","hdd18" => 4645.0,"cdd18" => 118.0,"latitude" => 49.6, "longitude" => -115.78, "elevation" => 940.0, "monthly_dry_bulb" => "[-7.9, -3.2, 2.4, 6.0, 10.5, 14.4, 18.7, 17.3, 11.7, 5.4, -2.0, -6.6]", "delta_dry_bulb" => 26.6 },
      "CAN_BC_Fort.St.John.719430_CWEC.epw" => { "country" => "CAN", "state_province" => "BC", "city" => "Fort St John","hdd18" => 5863.0,"cdd18" => 25.0,"latitude" => 56.23, "longitude" => -120.73, "elevation" => 695.0, "monthly_dry_bulb" => "[-13.8, -10.8, -5.0, 4.1, 9.8, 14.0, 15.3, 14.6, 8.9, 4.2, -6.7, -11.3]", "delta_dry_bulb" => 29.1 },
      "CAN_BC_Kamloops.718870_CWEC.epw" => { "country" => "CAN", "state_province" => "BC", "city" => "Kamloops","hdd18" => 3629.0,"cdd18" => 287.0,"latitude" => 50.7, "longitude" => -120.45, "elevation" => 346.0, "monthly_dry_bulb" => "[-4.3, -1.2, 3.9, 9.2, 14.7, 18.4, 21.3, 20.3, 15.5, 8.0, 2.9, -3.4]", "delta_dry_bulb" => 25.6 },
      "CAN_BC_Port.Hardy.711090_CWEC.epw" => { "country" => "CAN", "state_province" => "BC", "city" => "Port Hardy","hdd18" => 3712.0,"cdd18" => 0.0,"latitude" => 50.68, "longitude" => -127.37, "elevation" => 22.0, "monthly_dry_bulb" => "[2.5, 3.8, 4.7, 6.6, 9.5, 11.5, 13.3, 13.3, 11.2, 8.3, 5.4, 3.6]", "delta_dry_bulb" => 10.8 },
      "CAN_BC_Prince.George.718960_CWEC.epw" => { "country" => "CAN", "state_province" => "BC", "city" => "Prince George","hdd18" => 5070.0,"cdd18" => 15.0,"latitude" => 53.88, "longitude" => -122.68, "elevation" => 691.0, "monthly_dry_bulb" => "[-10.8, -5.3, 0.1, 5.0, 10.2, 13.2, 14.5, 15.2, 10.8, 4.8, -2.4, -6.1]", "delta_dry_bulb" => 26.0 },
      "CAN_BC_Prince.Rupert.718980_CWEC.epw" => { "country" => "CAN", "state_province" => "BC", "city" => "Prince Rupert","hdd18" => 4151.0,"cdd18" => 0.0,"latitude" => 54.3, "longitude" => -130.43, "elevation" => 34.0, "monthly_dry_bulb" => "[-0.2, 1.4, 3.1, 5.7, 8.6, 10.7, 12.9, 13.3, 11.0, 7.9, 3.3, 1.3]", "delta_dry_bulb" => 13.5 },
      "CAN_BC_Sandspit.711010_CWEC.epw" => { "country" => "CAN", "state_province" => "BC", "city" => "Sandspit","hdd18" => 3644.0,"cdd18" => 0.0,"latitude" => 53.25, "longitude" => -131.82, "elevation" => 6.0, "monthly_dry_bulb" => "[1.4, 3.2, 5.0, 5.8, 9.0, 11.5, 13.6, 14.5, 12.7, 9.1, 6.4, 3.6]", "delta_dry_bulb" => 13.1 },
      "CAN_BC_Smithers.719500_CWEC.epw" => { "country" => "CAN", "state_province" => "BC", "city" => "Smithers","hdd18" => 5265.0,"cdd18" => 22.0,"latitude" => 54.82, "longitude" => -127.18, "elevation" => 523.0, "monthly_dry_bulb" => "[-8.4, -3.9, -1.5, 4.6, 8.5, 12.2, 15.8, 14.1, 9.0, 4.6, -3.8, -8.0]", "delta_dry_bulb" => 24.200000000000003 },
      "CAN_BC_Summerland.717680_CWEC.epw" => { "country" => "CAN", "state_province" => "BC", "city" => "Summerland","hdd18" => 3388.0,"cdd18" => 199.0,"latitude" => 49.57, "longitude" => -119.65, "elevation" => 479.0, "monthly_dry_bulb" => "[-1.7, 1.5, 4.2, 8.7, 13.8, 17.9, 20.1, 19.2, 14.7, 8.9, 3.9, -0.5]", "delta_dry_bulb" => 21.8 },
      "CAN_BC_Vancouver.718920_CWEC.epw" => { "country" => "CAN", "state_province" => "BC", "city" => "Vancouver Int'l","hdd18" => 3019.0,"cdd18" => 4.0,"latitude" => 49.18, "longitude" => -123.17, "elevation" => 2.0, "monthly_dry_bulb" => "[3.2, 5.1, 6.1, 8.7, 11.8, 15.1, 17.0, 17.1, 13.8, 9.8, 5.3, 3.6]", "delta_dry_bulb" => 13.900000000000002 },
      "CAN_BC_Victoria.717990_CWEC.epw" => { "country" => "CAN", "state_province" => "BC", "city" => "Victoria Int'l","hdd18" => 3075.0,"cdd18" => 8.0,"latitude" => 48.65, "longitude" => -123.43, "elevation" => 19.0, "monthly_dry_bulb" => "[3.8, 4.9, 6.2, 8.5, 11.7, 14.3, 15.8, 16.1, 13.1, 9.8, 6.5, 4.3]", "delta_dry_bulb" => 12.3 },
      "CAN_MB_Brandon.711400_CWEC.epw" => { "country" => "CAN", "state_province" => "MB", "city" => "Brandon","hdd18" => 5912.0,"cdd18" => 95.0,"latitude" => 49.92, "longitude" => -99.95, "elevation" => 409.0, "monthly_dry_bulb" => "[-18.0, -14.7, -7.0, 3.7, 11.4, 16.1, 18.7, 17.8, 11.3, 4.9, -5.2, -15.2]", "delta_dry_bulb" => 36.7 },
      "CAN_MB_Churchill.719130_CWEC.epw" => { "country" => "CAN", "state_province" => "MB", "city" => "Churchill","hdd18" => 9114.0,"cdd18" => 3.0,"latitude" => 58.75, "longitude" => -94.07, "elevation" => 29.0, "monthly_dry_bulb" => "[-23.4, -25.8, -19.8, -11.1, -1.2, 5.4, 11.9, 11.1, 5.5, -2.0, -12.1, -23.4]", "delta_dry_bulb" => 37.7 },
      "CAN_MB_The.Pas.718670_CWEC.epw" => { "country" => "CAN", "state_province" => "MB", "city" => "The Pas","hdd18" => 6442.0,"cdd18" => 106.0,"latitude" => 53.97, "longitude" => -101.1, "elevation" => 271.0, "monthly_dry_bulb" => "[-19.4, -15.8, -8.6, -0.2, 10.7, 14.7, 18.5, 17.6, 9.8, 2.8, -6.2, -17.4]", "delta_dry_bulb" => 37.9 },
      "CAN_MB_Winnipeg.718520_CWEC.epw" => { "country" => "CAN", "state_province" => "MB", "city" => "Winnipeg Int'l","hdd18" => 5754.0,"cdd18" => 197.0,"latitude" => 49.9, "longitude" => -97.23, "elevation" => 239.0, "monthly_dry_bulb" => "[-17.3, -14.3, -6.9, 4.2, 11.3, 16.9, 20.5, 18.6, 12.3, 5.7, -4.6, -14.1]", "delta_dry_bulb" => 37.8 },
      "CAN_NB_Fredericton.717000_CWEC.epw" => { "country" => "CAN", "state_province" => "NB", "city" => "Fredericton","hdd18" => 4734.0,"cdd18" => 132.0,"latitude" => 45.87, "longitude" => -66.53, "elevation" => 20.0, "monthly_dry_bulb" => "[-10.0, -8.0, -2.3, 3.5, 11.3, 16.0, 19.5, 18.2, 13.5, 7.7, 0.9, -6.6]", "delta_dry_bulb" => 29.5 },
      "CAN_NB_Miramichi.717440_CWEC.epw" => { "country" => "CAN", "state_province" => "NB", "city" => "Miramichi","hdd18" => 4921.0,"cdd18" => 141.0,"latitude" => 47.02, "longitude" => -65.45, "elevation" => 33.0, "monthly_dry_bulb" => "[-10.4, -8.9, -3.3, 2.9, 10.5, 16.1, 19.2, 18.1, 12.5, 7.0, 1.4, -7.0]", "delta_dry_bulb" => 29.6 },
      "CAN_NB_Saint.John.716090_CWEC.epw" => { "country" => "CAN", "state_province" => "NB", "city" => "Saint John","hdd18" => 4695.0,"cdd18" => 12.0,"latitude" => 45.32, "longitude" => -65.88, "elevation" => 109.0, "monthly_dry_bulb" => "[-7.4, -6.4, -2.4, 3.5, 9.1, 13.4, 16.4, 16.2, 13.2, 8.0, 2.4, -4.7]", "delta_dry_bulb" => 23.799999999999997 },
      "CAN_NF_Battle.Harbour.718170_CWEC.epw" => { "country" => "CAN", "state_province" => "NF", "city" => "Battle Harbour","hdd18" => 6462.0,"cdd18" => 0.0,"latitude" => 52.3, "longitude" => -55.83, "elevation" => 8.0, "monthly_dry_bulb" => "[-11.2, -10.2, -5.3, -1.6, 1.9, 5.0, 9.6, 10.4, 7.7, 3.3, -0.3, -6.6]", "delta_dry_bulb" => 21.6 },
      "CAN_NF_Gander.718030_CWEC.epw" => { "country" => "CAN", "state_province" => "NF", "city" => "Gander Int'l","hdd18" => 5101.0,"cdd18" => 25.0,"latitude" => 48.95, "longitude" => -54.57, "elevation" => 151.0, "monthly_dry_bulb" => "[-6.1, -6.7, -3.7, 1.5, 6.9, 11.5, 15.9, 15.1, 11.0, 5.5, 1.1, -3.7]", "delta_dry_bulb" => 22.6 },
      "CAN_NF_Goose.718160_CWEC.epw" => { "country" => "CAN", "state_province" => "NF", "city" => "Goose","hdd18" => 6558.0,"cdd18" => 38.0,"latitude" => 53.32, "longitude" => -60.37, "elevation" => 49.0, "monthly_dry_bulb" => "[-17.0, -15.2, -8.9, -0.9, 4.6, 11.9, 16.0, 14.3, 9.1, 2.7, -3.2, -12.9]", "delta_dry_bulb" => 33.0 },
      "CAN_NF_St.Johns.718010_CWEC.epw" => { "country" => "CAN", "state_province" => "NF", "city" => "St John's","hdd18" => 4886.0,"cdd18" => 24.0,"latitude" => 47.62, "longitude" => -52.73, "elevation" => 140.0, "monthly_dry_bulb" => "[-3.3, -5.5, -2.1, 1.1, 5.7, 11.3, 15.0, 14.7, 11.4, 6.6, 2.4, -2.0]", "delta_dry_bulb" => 20.5 },
      "CAN_NF_Stephenville.718150_CWEC.epw" => { "country" => "CAN", "state_province" => "NF", "city" => "Stephenville","hdd18" => 4724.0,"cdd18" => 10.0,"latitude" => 48.53, "longitude" => -58.55, "elevation" => 26.0, "monthly_dry_bulb" => "[-5.2, -6.7, -2.2, 3.4, 7.1, 11.3, 16.3, 16.4, 12.5, 7.3, 2.2, -2.4]", "delta_dry_bulb" => 23.099999999999998 },
      "CAN_NS_Greenwood.713970_CWEC.epw" => { "country" => "CAN", "state_province" => "NS", "city" => "Greenwood","hdd18" => 4131.0,"cdd18" => 128.0,"latitude" => 44.98, "longitude" => -64.92, "elevation" => 28.0, "monthly_dry_bulb" => "[-4.7, -3.9, -0.7, 4.6, 10.9, 16.1, 19.1, 18.8, 13.5, 7.9, 4.2, -2.0]", "delta_dry_bulb" => 23.8 },
      "CAN_NS_Sable.Island.716000_CWEC.epw" => { "country" => "CAN", "state_province" => "NS", "city" => "Sable Island","hdd18" => 3860.0,"cdd18" => 14.0,"latitude" => 43.93, "longitude" => -60.02, "elevation" => 4.0, "monthly_dry_bulb" => "[-0.7, -0.9, 0.6, 3.6, 6.4, 11.2, 15.1, 17.4, 15.5, 11.3, 7.0, 2.3]", "delta_dry_bulb" => 18.299999999999997 },
      "CAN_NS_Shearwater.716010_CWEC.epw" => { "country" => "CAN", "state_province" => "NS", "city" => "Shearwater","hdd18" => 4197.0,"cdd18" => 58.0,"latitude" => 44.63, "longitude" => -63.5, "elevation" => 51.0, "monthly_dry_bulb" => "[-4.1, -4.2, -0.8, 3.9, 8.8, 13.7, 17.6, 17.8, 14.3, 9.3, 4.8, -1.9]", "delta_dry_bulb" => 22.0 },
      "CAN_NS_Sydney.717070_CWEC.epw" => { "country" => "CAN", "state_province" => "NS", "city" => "Sydney","hdd18" => 4634.0,"cdd18" => 51.0,"latitude" => 46.17, "longitude" => -60.05, "elevation" => 62.0, "monthly_dry_bulb" => "[-5.3, -6.5, -3.1, 2.0, 7.3, 12.4, 17.5, 17.3, 13.0, 8.8, 3.0, -2.0]", "delta_dry_bulb" => 24.0 },
      "CAN_NS_Truro.713980_CWEC.epw" => { "country" => "CAN", "state_province" => "NS", "city" => "Truro","hdd18" => 4537.0,"cdd18" => 35.0,"latitude" => 45.37, "longitude" => -63.27, "elevation" => 40.0, "monthly_dry_bulb" => "[-6.0, -7.5, -2.5, 2.4, 8.3, 14.6, 17.7, 17.0, 13.7, 8.4, 3.7, -2.7]", "delta_dry_bulb" => 25.2 },
      "CAN_NT_Inuvik.719570_CWEC.epw" => { "country" => "CAN", "state_province" => "NT", "city" => "Inuvik Ua","hdd18" => 9952.0,"cdd18" => 17.0,"latitude" => 68.3, "longitude" => -133.48, "elevation" => 68.0, "monthly_dry_bulb" => "[-28.2, -27.5, -23.9, -12.9, -0.1, 10.4, 12.4, 10.4, 3.3, -8.9, -21.0, -25.9]", "delta_dry_bulb" => 40.6 },
      "CAN_NU_Resolute.719240_CWEC.epw" => { "country" => "CAN", "state_province" => "NU", "city" => "Resolute","hdd18" => 12570.0,"cdd18" => 0.0,"latitude" => 74.72, "longitude" => -94.98, "elevation" => 67.0, "monthly_dry_bulb" => "[-30.6, -30.7, -32.2, -25.0, -10.8, -1.2, 3.7, 2.0, -4.2, -14.6, -24.7, -30.1]", "delta_dry_bulb" => 35.900000000000006 },
      "CAN_ON_Kingston.716200_CWEC.epw" => { "country" => "CAN", "state_province" => "ON", "city" => "Kingston","hdd18" => 4287.0,"cdd18" => 187.0,"latitude" => 44.22, "longitude" => -76.6, "elevation" => 93.0, "monthly_dry_bulb" => "[-6.3, -7.1, -2.0, 3.5, 11.2, 16.0, 20.3, 20.6, 15.3, 10.5, 3.3, -5.2]", "delta_dry_bulb" => 27.700000000000003 },
      "CAN_ON_London.716230_CWEC.epw" => { "country" => "CAN", "state_province" => "ON", "city" => "London","hdd18" => 4111.0,"cdd18" => 211.0,"latitude" => 43.03, "longitude" => -81.15, "elevation" => 278.0, "monthly_dry_bulb" => "[-7.1, -6.2, -0.7, 6.4, 11.7, 17.8, 20.8, 19.0, 15.3, 9.8, 3.2, -3.2]", "delta_dry_bulb" => 27.9 },
      "CAN_ON_Mount.Forest.716310_CWEC.epw" => { "country" => "CAN", "state_province" => "ON", "city" => "Mount Forest","hdd18" => 4578.0,"cdd18" => 121.0,"latitude" => 43.98, "longitude" => -80.75, "elevation" => 415.0, "monthly_dry_bulb" => "[-9.2, -8.4, -2.6, 5.2, 10.4, 16.3, 18.5, 17.8, 14.3, 9.1, 1.6, -4.3]", "delta_dry_bulb" => 27.7 },
      "CAN_ON_Muskoka.716300_CWEC.epw" => { "country" => "CAN", "state_province" => "ON", "city" => "Muskoka","hdd18" => 4774.0,"cdd18" => 97.0,"latitude" => 44.97, "longitude" => -79.3, "elevation" => 282.0, "monthly_dry_bulb" => "[-10.8, -9.6, -3.0, 4.7, 12.4, 16.4, 18.5, 17.3, 12.3, 6.9, 1.9, -5.8]", "delta_dry_bulb" => 29.3 },
      "CAN_ON_North.Bay.717310_CWEC.epw" => { "country" => "CAN", "state_province" => "ON", "city" => "North Bay","hdd18" => 5341.0,"cdd18" => 103.0,"latitude" => 46.35, "longitude" => -79.43, "elevation" => 371.0, "monthly_dry_bulb" => "[-13.8, -11.1, -6.0, 3.5, 11.2, 16.0, 18.4, 17.0, 12.2, 6.9, -1.5, -10.1]", "delta_dry_bulb" => 32.2 },
      "CAN_ON_Ottawa.716280_CWEC.epw" => { "country" => "CAN", "state_province" => "ON", "city" => "Ottawa Int'l","hdd18" => 4664.0,"cdd18" => 189.0,"latitude" => 45.32, "longitude" => -75.67, "elevation" => 114.0, "monthly_dry_bulb" => "[-11.5, -9.3, -2.1, 5.6, 12.2, 18.1, 20.3, 19.3, 14.2, 7.4, 1.2, -7.4]", "delta_dry_bulb" => 31.8 },
      "CAN_ON_Sault.Ste.Marie.712600_CWEC.epw" => { "country" => "CAN", "state_province" => "ON", "city" => "Sault Ste Marie","hdd18" => 4993.0,"cdd18" => 75.0,"latitude" => 46.48, "longitude" => -84.52, "elevation" => 192.0, "monthly_dry_bulb" => "[-10.4, -10.0, -5.1, 3.9, 10.0, 14.3, 17.9, 17.0, 13.4, 7.8, 0.8, -6.4]", "delta_dry_bulb" => 28.299999999999997 },
      "CAN_ON_Simcoe.715270_CWEC.epw" => { "country" => "CAN", "state_province" => "ON", "city" => "Simcoe","hdd18" => 4066.0,"cdd18" => 190.0,"latitude" => 42.85, "longitude" => -80.27, "elevation" => 241.0, "monthly_dry_bulb" => "[-6.3, -6.1, -0.3, 5.1, 11.6, 18.3, 20.1, 19.6, 14.3, 9.6, 3.8, -2.1]", "delta_dry_bulb" => 26.400000000000002 },
      "CAN_ON_Thunder.Bay.717490_CWEC.epw" => { "country" => "CAN", "state_province" => "ON", "city" => "Thunder Bay","hdd18" => 5624.0,"cdd18" => 60.0,"latitude" => 48.37, "longitude" => -89.32, "elevation" => 199.0, "monthly_dry_bulb" => "[-15.8, -10.7, -5.9, 1.9, 9.9, 14.1, 18.0, 16.2, 11.0, 5.8, -1.7, -10.8]", "delta_dry_bulb" => 33.8 },
      "CAN_ON_Timmins.717390_CWEC.epw" => { "country" => "CAN", "state_province" => "ON", "city" => "Timmins","hdd18" => 5952.0,"cdd18" => 63.0,"latitude" => 48.57, "longitude" => -81.37, "elevation" => 295.0, "monthly_dry_bulb" => "[-16.4, -13.0, -7.8, 1.3, 9.9, 14.5, 17.4, 15.9, 10.8, 5.2, -3.6, -12.8]", "delta_dry_bulb" => 33.8 },
      "CAN_ON_Toronto.716240_CWEC.epw" => { "country" => "CAN", "state_province" => "ON", "city" => "Toronto Int'l","hdd18" => 4088.0,"cdd18" => 231.0,"latitude" => 43.67, "longitude" => -79.63, "elevation" => 173.0, "monthly_dry_bulb" => "[-5.8, -5.7, -0.7, 5.7, 12.0, 17.7, 20.8, 19.8, 15.0, 8.5, 3.5, -2.5]", "delta_dry_bulb" => 26.6 },
      "CAN_ON_Trenton.716210_CWEC.epw" => { "country" => "CAN", "state_province" => "ON", "city" => "Trenton","hdd18" => 4176.0,"cdd18" => 207.0,"latitude" => 44.12, "longitude" => -77.53, "elevation" => 86.0, "monthly_dry_bulb" => "[-6.9, -6.4, -0.8, 5.8, 12.4, 17.4, 20.8, 19.3, 15.0, 9.0, 2.8, -3.8]", "delta_dry_bulb" => 27.700000000000003 },
      "CAN_ON_Windsor.715380_CWEC.epw" => { "country" => "CAN", "state_province" => "ON", "city" => "Windsor","hdd18" => 3570.0,"cdd18" => 367.0,"latitude" => 42.27, "longitude" => -82.97, "elevation" => 190.0, "monthly_dry_bulb" => "[-4.5, -4.0, 1.0, 8.4, 13.1, 19.9, 22.6, 21.1, 17.4, 11.6, 4.7, -1.5]", "delta_dry_bulb" => 27.1 },
      "CAN_PE_Charlottetown.717060_CWEC.epw" => { "country" => "CAN", "state_province" => "PE", "city" => "Charlottetown CDA","hdd18" => 4647.0,"cdd18" => 72.0,"latitude" => 46.28, "longitude" => -63.13, "elevation" => 54.0, "monthly_dry_bulb" => "[-7.5, -6.8, -3.5, 2.8, 9.0, 14.1, 18.1, 18.1, 14.2, 7.7, 3.2, -4.7]", "delta_dry_bulb" => 25.6 },
      "CAN_PQ_Bagotville.717270_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "Bagotville","hdd18" => 5781.0,"cdd18" => 49.0,"latitude" => 48.33, "longitude" => -71.0, "elevation" => 159.0, "monthly_dry_bulb" => "[-14.8, -12.9, -5.7, 2.1, 8.7, 15.7, 17.6, 15.4, 10.3, 5.4, -2.2, -13.1]", "delta_dry_bulb" => 32.400000000000006 },
      "CAN_PQ_Baie.Comeau.711870_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "Baie Comeau","hdd18" => 5889.0,"cdd18" => 3.0,"latitude" => 49.13, "longitude" => -68.2, "elevation" => 22.0, "monthly_dry_bulb" => "[-13.8, -11.6, -6.2, 0.7, 7.0, 12.3, 16.0, 14.3, 9.9, 4.4, -1.7, -9.8]", "delta_dry_bulb" => 29.8 },
      "CAN_PQ_Grindstone.Island_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "Grindstone Island","hdd18" => 4941.0,"cdd18" => 18.0,"latitude" => 47.38, "longitude" => -61.87, "elevation" => 59.0, "monthly_dry_bulb" => "[-7.0, -7.0, -2.2, 0.0, 5.1, 11.7, 15.9, 16.8, 12.3, 6.6, 3.2, -2.1]", "delta_dry_bulb" => 23.8 },
      "CAN_PQ_Kuujjuarapik.719050_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "Kuujjuarapik","hdd18" => 7986.0,"cdd18" => 12.0,"latitude" => 55.28, "longitude" => -77.77, "elevation" => 12.0, "monthly_dry_bulb" => "[-21.0, -20.4, -16.8, -6.9, 1.3, 6.5, 10.3, 11.0, 7.4, 2.0, -4.2, -16.2]", "delta_dry_bulb" => 32.0 },
      "CAN_PQ_Kuujuaq.719060_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "Kuujuaq","hdd18" => 8491.0,"cdd18" => 0.0,"latitude" => 58.1, "longitude" => -68.42, "elevation" => 37.0, "monthly_dry_bulb" => "[-20.7, -20.8, -19.0, -8.9, -0.3, 6.8, 11.0, 10.8, 4.7, -0.8, -8.2, -18.8]", "delta_dry_bulb" => 31.8 },
      "CAN_PQ_La.Grande.Riviere.718270_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "La Grande Riviere","hdd18" => 7616.0,"cdd18" => 11.0,"latitude" => 53.63, "longitude" => -77.7, "elevation" => 195.0, "monthly_dry_bulb" => "[-21.8, -21.6, -14.3, -5.3, 6.1, 10.1, 13.4, 12.0, 7.6, 1.9, -5.9, -17.4]", "delta_dry_bulb" => 35.2 },
      "CAN_PQ_Lake.Eon.714210_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "Lake Eon","hdd18" => 7383.0,"cdd18" => 8.0,"latitude" => 51.87, "longitude" => -63.28, "elevation" => 561.0, "monthly_dry_bulb" => "[-20.3, -14.7, -9.8, -5.1, 2.0, 9.2, 13.6, 11.6, 6.7, 0.1, -6.3, -14.2]", "delta_dry_bulb" => 33.9 },
      "CAN_PQ_Mont.Joli.717180_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "Mont Joli","hdd18" => 5522.0,"cdd18" => 65.0,"latitude" => 48.6, "longitude" => -68.22, "elevation" => 52.0, "monthly_dry_bulb" => "[-12.8, -10.4, -5.2, 1.8, 7.8, 14.1, 18.0, 16.2, 10.8, 5.2, -0.5, -9.1]", "delta_dry_bulb" => 30.8 },
      "CAN_PQ_Montreal.Intl.AP.716270_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "Montreal Int'l","hdd18" => 4493.0,"cdd18" => 234.0,"latitude" => 45.47, "longitude" => -73.75, "elevation" => 36.0, "monthly_dry_bulb" => "[-9.8, -9.4, -2.7, 6.5, 13.0, 18.4, 20.4, 20.0, 14.6, 8.2, 2.6, -6.8]", "delta_dry_bulb" => 30.2 },
      "CAN_PQ_Montreal.Jean.Brebeuf.716278_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "Montreal Jean Brebeuf","hdd18" => 4616.0,"cdd18" => 209.0,"latitude" => 45.5, "longitude" => -73.62, "elevation" => 133.0, "monthly_dry_bulb" => "[-10.5, -9.4, -3.4, 5.2, 12.9, 18.6, 20.7, 19.6, 14.6, 7.8, 1.2, -6.8]", "delta_dry_bulb" => 31.2 },
      "CAN_PQ_Montreal.Mirabel.716278_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "Montreal Mirabel","hdd18" => 4861.0,"cdd18" => 102.0,"latitude" => 45.68, "longitude" => -74.03, "elevation" => 82.0, "monthly_dry_bulb" => "[-13.9, -7.2, -3.2, 5.7, 12.4, 17.0, 19.5, 17.7, 13.1, 6.7, 0.7, -9.5]", "delta_dry_bulb" => 33.4 },
      "CAN_PQ_Nitchequon.CAN270_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "Nitchequon","hdd18" => 7922.0,"cdd18" => 6.0,"latitude" => 53.2, "longitude" => -70.9, "elevation" => 536.0, "monthly_dry_bulb" => "[-22.5, -21.4, -14.2, -4.2, 2.7, 9.6, 13.3, 11.8, 6.4, -0.1, -7.8, -19.0]", "delta_dry_bulb" => 35.8 },
      "CAN_PQ_Quebec.717140_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "Quebec City","hdd18" => 4964.0,"cdd18" => 111.0,"latitude" => 46.8, "longitude" => -71.38, "elevation" => 73.0, "monthly_dry_bulb" => "[-11.6, -10.4, -3.9, 3.6, 11.4, 16.2, 19.4, 18.0, 12.9, 7.1, -0.2, -7.2]", "delta_dry_bulb" => 31.0 },
      "CAN_PQ_Riviere.du.Loup.717150_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "Riviere Du Loup","hdd18" => 5424.0,"cdd18" => 82.0,"latitude" => 47.8, "longitude" => -69.55, "elevation" => 148.0, "monthly_dry_bulb" => "[-12.3, -10.9, -5.2, 1.0, 8.7, 14.4, 17.8, 16.9, 10.0, 6.0, 0.8, -7.7]", "delta_dry_bulb" => 30.1 },
      "CAN_PQ_Roberval.717280_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "Roberval","hdd18" => 5757.0,"cdd18" => 97.0,"latitude" => 48.52, "longitude" => -72.27, "elevation" => 179.0, "monthly_dry_bulb" => "[-17.1, -12.7, -6.3, 2.1, 10.5, 15.7, 18.5, 16.2, 10.6, 5.6, -1.0, -13.1]", "delta_dry_bulb" => 35.6 },
      "CAN_PQ_Schefferville.718280_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "Schefferville","hdd18" => 8057.0,"cdd18" => 7.0,"latitude" => 54.8, "longitude" => -66.82, "elevation" => 521.0, "monthly_dry_bulb" => "[-21.6, -20.1, -14.1, -5.0, 1.3, 8.5, 13.0, 11.1, 5.3, -1.1, -9.3, -17.7]", "delta_dry_bulb" => 34.6 },
      "CAN_PQ_Sept-Iles.718110_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "Sept-Iles","hdd18" => 6134.0,"cdd18" => 4.0,"latitude" => 50.22, "longitude" => -66.27, "elevation" => 55.0, "monthly_dry_bulb" => "[-15.2, -14.5, -5.9, 1.0, 6.3, 11.6, 15.7, 14.1, 9.3, 3.8, -1.8, -11.1]", "delta_dry_bulb" => 30.9 },
      "CAN_PQ_Sherbrooke.716100_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "Sherbrooke","hdd18" => 5068.0,"cdd18" => 93.0,"latitude" => 45.43, "longitude" => -71.68, "elevation" => 241.0, "monthly_dry_bulb" => "[-10.0, -9.7, -3.6, 4.0, 11.3, 16.2, 18.2, 16.7, 11.6, 6.2, -0.9, -8.6]", "delta_dry_bulb" => 28.2 },
      "CAN_PQ_St.Hubert.713710_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "St Hubert","hdd18" => 4566.0,"cdd18" => 251.0,"latitude" => 45.52, "longitude" => -73.42, "elevation" => 27.0, "monthly_dry_bulb" => "[-10.0, -8.7, -2.8, 5.3, 13.4, 18.3, 21.2, 19.5, 14.9, 7.8, 1.4, -7.2]", "delta_dry_bulb" => 31.2 },
      "CAN_PQ_Ste.Agathe.des.Monts.717200_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "Ste Agathe Des Monts","hdd18" => 5350.0,"cdd18" => 45.0,"latitude" => 46.05, "longitude" => -74.28, "elevation" => 395.0, "monthly_dry_bulb" => "[-11.9, -11.0, -5.4, 2.9, 10.9, 15.3, 17.7, 16.4, 11.2, 5.1, -1.0, -9.6]", "delta_dry_bulb" => 29.6 },
      "CAN_PQ_Val.d.Or.717250_CWEC.epw" => { "country" => "CAN", "state_province" => "PQ", "city" => "Val d'Or","hdd18" => 6129.0,"cdd18" => 79.0,"latitude" => 48.07, "longitude" => -77.78, "elevation" => 337.0, "monthly_dry_bulb" => "[-17.7, -15.2, -7.4, 0.8, 9.8, 14.6, 17.3, 15.5, 10.6, 3.8, -2.3, -13.9]", "delta_dry_bulb" => 35.0 },
      "CAN_SK_Estevan.718620_CWEC.epw" => { "country" => "CAN", "state_province" => "SK", "city" => "Estevan","hdd18" => 5370.0,"cdd18" => 189.0,"latitude" => 49.22, "longitude" => -102.97, "elevation" => 581.0, "monthly_dry_bulb" => "[-14.9, -11.4, -5.6, 4.9, 11.9, 17.1, 20.2, 18.8, 12.2, 6.0, -3.4, -11.0]", "delta_dry_bulb" => 35.1 },
      "CAN_SK_North.Battleford.718760_CWEC.epw" => { "country" => "CAN", "state_province" => "SK", "city" => "North Battleford","hdd18" => 5962.0,"cdd18" => 75.0,"latitude" => 52.77, "longitude" => -108.25, "elevation" => 548.0, "monthly_dry_bulb" => "[-17.3, -13.1, -8.6, 3.3, 11.1, 15.9, 18.1, 16.7, 11.0, 4.7, -6.2, -14.0]", "delta_dry_bulb" => 35.400000000000006 },
      "CAN_SK_Regina.718630_CWEC.epw" => { "country" => "CAN", "state_province" => "SK", "city" => "Regina","hdd18" => 5646.0,"cdd18" => 129.0,"latitude" => 50.43, "longitude" => -104.67, "elevation" => 577.0, "monthly_dry_bulb" => "[-16.0, -11.4, -6.6, 3.2, 12.1, 16.5, 19.4, 17.6, 10.9, 4.1, -4.9, -11.1]", "delta_dry_bulb" => 35.4 },
      "CAN_SK_Saskatoon.718660_CWEC.epw" => { "country" => "CAN", "state_province" => "SK", "city" => "Saskatoon","hdd18" => 5812.0,"cdd18" => 84.0,"latitude" => 52.17, "longitude" => -106.68, "elevation" => 504.0, "monthly_dry_bulb" => "[-15.6, -12.8, -7.8, 3.8, 11.8, 16.2, 18.8, 16.5, 10.5, 4.9, -5.9, -13.7]", "delta_dry_bulb" => 34.4 },
      "CAN_SK_Swift.Current.718700_CWEC.epw" => { "country" => "CAN", "state_province" => "SK", "city" => "Swift Current","hdd18" => 5227.0,"cdd18" => 96.0,"latitude" => 50.28, "longitude" => -107.68, "elevation" => 818.0, "monthly_dry_bulb" => "[-12.6, -9.1, -5.1, 4.9, 11.2, 15.9, 18.2, 17.4, 11.2, 6.5, -3.3, -8.8]", "delta_dry_bulb" => 30.799999999999997 },
      "CAN_YT_Whitehorse.719640_CWEC.epw" => { "country" => "CAN", "state_province" => "YT", "city" => "Whitehorse","hdd18" => 6946.0,"cdd18" => 2.0,"latitude" => 60.72, "longitude" => -135.07, "elevation" => 703.0, "monthly_dry_bulb" => "[-20.5, -11.3, -6.3, 0.1, 6.7, 11.5, 14.0, 11.6, 7.1, 0.2, -10.3, -15.8]", "delta_dry_bulb" => 34.5 },
      "USA_CO_Denver.Intl.AP.725650_TMY3.epw" => { "country" => "USA", "state_province" => "CO", "city" => "Denver Intl Ap","hdd18" => 3131.0,"cdd18" => 528.0,"latitude" => 39.83, "longitude" => -104.65, "elevation" => 1650.0, "monthly_dry_bulb" => "[0.8, -0.1, 6.1, 5.8, 15.5, 23.1, 22.3, 22.6, 19.2, 10.0, 2.9, 1.4]", "delta_dry_bulb" => 23.200000000000003 },
      "USA_MA_Boston-Logan.Intl.AP.725090_TMY3.epw" => { "country" => "USA", "state_province" => "MA", "city" => "Boston Logan IntL Arpt","hdd18" => 3121.0,"cdd18" => 420.0,"latitude" => 42.37, "longitude" => -71.02, "elevation" => 6.0, "monthly_dry_bulb" => "[-3.0, -0.5, 3.8, 8.6, 14.9, 18.9, 23.4, 21.7, 18.1, 12.2, 6.3, 2.2]", "delta_dry_bulb" => 26.4 },
    }
    
    #This method will look up the weather data.
    #@author phylroy.lopez@nrcan.gc.ca
    #@params file [String] 
    def self.weather_data_lookup(file)
      
    end
    
    #This method will create a climate index file.
    #@author phylroy.lopez@nrcan.gc.ca
    #@params folder [String]
    #@params output_file [String]
    def self.create_climate_index_file(folder = '../weather/', output_file = "C:/test/phylroy.csv"  )
      counter = 0
      File.open(output_file, 'w') { |file|
        file.write( "file,country,state_province_region,city,hdd18,cdd18,latitude,longitude,elevation, monthlyDB, deltaDB\n" )
        BTAP::FileIO::get_find_files_from_folder_by_extension(folder, 'epw').each do |wfile|
          wf = BTAP::Environment::WeatherFile.new(wfile)
          file.write( "\"#{File.basename(wfile)}\" => { \"country\" => \"#{wf.country}\", \"state_province\" => \"#{wf.state_province_region}\", \"city\" => \"#{wf.city}\",\"hdd18\" => #{wf.hdd18},\"cdd18\" => #{wf.cdd18},\"latitude\" => #{wf.latitude}, \"longitude\" => #{wf.longitude}, \"elevation\" => #{wf.elevation}, \"monthly_dry_bulb\" => \"#{wf.monthly_dry_bulb}\", \"delta_dry_bulb\" => #{wf.delta_dry_bulb} },\n" )
          counter += 1
        end
        
      }
      puts "parsed #{counter} weather files."
    end


    class StatFile
      attr_accessor :path
      attr_accessor :valid
      attr_accessor :lat
      attr_accessor :lon
      attr_accessor :elevation
      attr_accessor :gmt
      attr_accessor :monthly_dry_bulb
      attr_accessor :hdd18
      attr_accessor :cdd18
      attr_accessor :hdd10
      attr_accessor :cdd10
      attr_accessor :heating_design_info
      attr_accessor :cooling_design_info
      attr_accessor :extremes_design_info

      #This method initializes.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params path [String]
      def initialize(path)
        @path = Pathname.new(path)
        @valid = false
        @lat = []
        @lon = []
        @gmt = []
        @elevation = []
        @hdd18 = []
        @cdd18 = []
        @hdd10 = []
        @cdd10 = []
        @monthly_dry_bulb = []
        @delta_dry_bulb = []
        @heating_design_info = []
        @cooling_design_info  = []
        @extremes_design_info = []
        init
      end

      def valid?
        return @valid
      end

      # the mean of the mean monthly dry bulbs
      def mean_dry_bulb
        if not @monthly_dry_bulb.empty? then
          sum = 0
          @monthly_dry_bulb.each { |db| sum += db }
          mean = sum/@monthly_dry_bulb.size
        else
          mean = ""
        end
        mean
      end

      # max - min of the mean monthly dry bulbs
      def delta_dry_bulb
        if not @monthly_dry_bulb.empty? then
          delta_t = @monthly_dry_bulb.max-@monthly_dry_bulb.min
        else
          delta_t = ""
        end

        delta_t
      end

      private

      # initialize
      def init
        if @path.exist?
          text = File.read(@path).force_encoding("iso-8859-1")
          parse(text)
          #get HDD and CDD 18 in a better manner.
          unless File.exist?(@path)
            raise 'File does not exist: ' + @path.to_s
          end
          File.open(@path).each do |l|
            line = String.new(l)
            if line.include?("HDD base 18C")
              @hdd18 = line.split(' ')[3..14].map { |x| x.to_i }.inject{|sum,x| sum + x }.to_f
            end
            if line.include?("CDD base 18C")
              @cdd18 = line.split(' ')[3..14].map { |x| x.to_i }.inject{|sum,x| sum + x }.to_f
              break
            end
          end
          raise ("Invalid Weather file: Could not determine HDD or CDD from weatherstatfile. @path") if @cdd18.nil? or @hdd18.nil?
        end
      end

      #This method  parses text.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params test [String]
      def parse(text)

        # get lat, lon, gmt
        regex = /\{(N|S)\s*([0-9]*).\s*([0-9]*)'\}\s*\{(E|W)\s*([0-9]*).\s*([0-9]*)'\}\s*\{GMT\s*(.*)\s*Hours\}/
        match_data = text.match(regex)
        if match_data.nil?
          puts "Can't find lat/lon/gmt"
          return
        else

          @lat = match_data[2].to_f + (match_data[3].to_f)/60.0
          if match_data[1] == 'S'
            @lat = -@lat
          end

          @lon = match_data[5].to_f + (match_data[6].to_f)/60.0
          if match_data[4] == 'W'
            @lon = -@lon
          end

          @gmt = match_data[7]
        end

        # get elevation
        regex = /Elevation --\s*(.*)m (above|below) sea level/
        match_data = text.match(regex)
        if match_data.nil?
          puts "Can't find elevation"
          return
        else
          @elevation = match_data[1].to_f
          if match_data[2] == 'below'
            @elevation = -@elevation
          end
        end







        # get heating and cooling degree days
        cdd10Regex = /-\s*(.*) annual \(standard\) cooling degree-days \(10.*C baseline\)/
        match_data = text.match(cdd10Regex)
        if match_data.nil?
          puts "Can't find CDD 10"
        else
          @cdd10 = match_data[1].to_f
        end

        hdd10Regex = /-\s*(.*) annual \(standard\) heating degree-days \(10.*C baseline\)/
        match_data = text.match(hdd10Regex)
        if match_data.nil?
          puts "Can't find HDD 10"
        else
          @hdd10 = match_data[1].to_f
        end

        cdd18Regex = /-\s*(.*) annual \(standard\) cooling degree-days \(18.3.*C baseline\)/
        match_data = text.match(cdd18Regex)
        if match_data.nil?
          puts "Can't find CDD 18"
        else
          @cdd18 = match_data[1].to_f
        end
        
        hdd18Regex = /-\s*(.*) annual \(standard\) heating degree-days \(18.3.*C baseline\)/
        match_data = text.match(hdd18Regex)
        if match_data.nil?
          puts "Can't find HDD 18"
        else
          @hdd18 = match_data[1].to_f
        end
        
        
        #      Design Stat	ColdestMonth	DB996	DB990	DP996	HR_DP996	DB_DP996	DP990	HR_DP990	DB_DP990	WS004c	DB_WS004c	WS010c	DB_WS010c	WS_DB996	WD_DB996	
        #    	Units	{}	{�C}	{�C}	{�C}	{}	{�C}	{�C}	{}	{�C}	{m/s}	{�C}	{m/s}	{�C}	{m/s}	{deg}	
        #    	Heating	12	-7	-4	-13.9	1.1	-5	-9.6	1.7	-2.9	14.2	5.9	11.9	6.8	2.9	100
        #use regex to get the temperatures
        regex = /\s*Heating(\s*\d+.*)\n/
        match_data = text.match(regex)
        if match_data.nil?
          puts "Can't find heating design information"
        else
          # first match is outdoor air temps
          
          heating_design_info_raw = match_data[1].strip.split(/\s+/)

          # have to be 14 data points
          if heating_design_info_raw.size != 15
            puts "Can't find cooling design info, found #{heating_design_info_raw.size}"
          end

          # insert as numbers
          heating_design_info_raw.each do |value| 
            @heating_design_info << value.to_f 
          end
          #puts @heating_design_info
        end
        
        regex = /\s*Cooling(\s*\d+.*)\n/ 
        match_data = text.match(regex)
        if match_data.nil?
          puts "Can't find cooling design information"
        else
          # first match is outdoor air temps
          
          design_info_raw = match_data[1].strip.split(/\s+/)

          # have to be 14 data points
          if design_info_raw.size != 32
            puts "Can't find cooling design info, found #{design_info_raw.size} "
          end

          # insert as numbers
          design_info_raw.each do |value| 
            @cooling_design_info << value 
          end
          #puts @cooling_design_info
        end
        
        regex = /\s*Extremes\s*(.*)\n/
        match_data = text.match(regex)
        if match_data.nil?
          puts "Can't find extremes design information"
        else
          # first match is outdoor air temps
          
          design_info_raw = match_data[1].strip.split(/\s+/)

          # have to be 14 data points
          if design_info_raw.size != 16
            #puts "Can't find extremes design info"
          end

          # insert as numbers
          design_info_raw.each do |value| 
            @extremes_design_info << value 
          end
          #puts @extremes_design_info
        end
        
        


        #use regex to get the temperatures
        regex = /Daily Avg(.*)\n/
        match_data = text.match(regex)
        if match_data.nil?
          puts "Can't find outdoor air temps"
        else
          # first match is outdoor air temps
          monthly_temps = match_data[1].strip.split(/\s+/)

          # have to be 12 months
          if monthly_temps.size != 12
            puts "Can't find outdoor air temps"
          end

          # insert as numbers
          monthly_temps.each { |temp| @monthly_dry_bulb << temp.to_f }
          #puts "#{@monthly_dry_bulb}"
        end

        # now we are valid
        @valid = true
      end

    end
    class WeatherFile

      attr_accessor :location_name,
        :latitude,
        :longitude,
        :elevation,
        :city,
        :state_province_region,
        :country,
        :hdd18,
        :cdd18,
        :hdd10,
        :cdd10,
        :monthly_dry_bulb,
        :delta_dry_bulb
      
      attr_accessor :heating_design_info
      attr_accessor :cooling_design_info
      attr_accessor :extremes_design_info

      Year = 0
      Month = 1
      Day = 2
      Hour= 3
      Minute = 4
      Data_Source = 5
      Dry_Bulb_Temperature = 6
      Dew_Point_Temperature = 7
      Relative_Humidity = 8
      Atmospheric_Station_Pressure = 9
      Extraterrestrial_Horizontal_Radiation = 10 #not used
      Extraterrestrial_Direct_Normal_Radiation = 11 #not used
      Horizontal_Infrared_Radiation_Intensity = 12
      Global_Horizontal_Radiation = 13 #not used
      Direct_Normal_Radiation = 14
      Diffuse_Horizontal_Radiation = 15
      Global_Horizontal_Illuminance = 16 #not used
      Direct_Normal_Illuminance = 17#not used
      Diffuse_Horizontal_Illuminance = 18#not used
      Zenith_Luminance = 19#not used
      Wind_Direction = 20
      Wind_Speed = 21
      Total_Sky_Cover = 22#not used
      Opaque_Sky_Cover = 23#not used
      Visibility = 24#not used
      Ceiling_Height = 25#not used
      Present_Weather_Observation = 26
      Present_Weather_Codes = 27
      Precipitable_Water = 28 #not used
      Aerosol_Optical_Depth = 29 #not used
      Snow_Depth = 30
      Days_Since_Last_Snowfall = 31#not used
      Albedo = 32 #not used
      Liquid_Precipitation_Depth = 33
      Liquid_Precipitation_Quantity = 34

      #This method initializes and returns self.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params weather_file [String]
      #@return self [String]
      def initialize(weather_file)
        #Check to see if all files exist.
        @epw_filepath = weather_file.to_s.sub(/[^.]+\z/,"epw")
        @ddy_filepath = weather_file.to_s.sub(/[^.]+\z/,"ddy")
        @stat_filepath = weather_file.to_s.sub(/[^.]+\z/,"stat")
        raise("Weather file #{@epw_filepath} not found.") unless File.exists?(@epw_filepath) and @epw_filepath.downcase.include? ".epw"
        raise("Weather file ddy #{@ddy_filepath} not found.") unless File.exists?(@ddy_filepath) and @ddy_filepath.downcase.include? ".ddy"
        raise("Weather file stat #{@stat_filepath} not found.") unless File.exists?(@stat_filepath) and @stat_filepath.downcase.include? ".stat"

        #load file objects.
        @epw_file = OpenStudio::EpwFile.new(OpenStudio::Path.new(weather_file))
        if OpenStudio::EnergyPlus.loadAndTranslateIdf(@ddy_filepath).empty?
          raise ("Unable to load ddy idf file#{@ddy_filepath}.")
        else
          @ddy_file = OpenStudio::EnergyPlus.loadAndTranslateIdf(@ddy_filepath).get
        end
        @stat_file = StatFile.new( @stat_filepath )

        #assign variables.
        
        @latitude = @epw_file.latitude
        @longitude = @epw_file.longitude
        @elevation = @epw_file.elevation
        @city = @epw_file.city
        @state_province_region =  @epw_file.stateProvinceRegion
        @country = @epw_file.country
        @hdd18 = @stat_file.hdd18
        @cdd18 = @stat_file.cdd18
        @hdd10 = @stat_file.hdd10
        @cdd10 = @stat_file.cdd10
        @monthly_dry_bulb = @stat_file.monthly_dry_bulb
        @mean_dry_bulb = @stat_file.mean_dry_bulb
        @delta_dry_bulb = @stat_file.delta_dry_bulb
        @location_name = "#{@country}-#{@state_province_region}-#{@city}"
        @heating_design_info = @stat_file.heating_design_info 
        @cooling_design_info  = @stat_file.cooling_design_info
        @extremes_design_info = @stat_file.extremes_design_info
        

        return self
      end

      #This method will set the weather file and returns a log string.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params model [OpenStudio::model::Model] A model object
      #@return log [String]
      def set_weather_file(model, runner = nil)
        BTAP::runner_register("Info", "BTAP::Environment::WeatherFile::set_weather",runner)
        OpenStudio::Model::WeatherFile::setWeatherFile(model, @epw_file)
        BTAP::runner_register("Info", "Set model \"#{model.building.get.name}\" to weather file #{model.weatherFile.get.path.get}.\n",runner)

        # Add or update site data
        site = model.getSite
        site.setName("#{@epw_file.city}_#{@epw_file.stateProvinceRegion}_#{@epw_file.country}")
        site.setLatitude(@epw_file.latitude)
        site.setLongitude(@epw_file.longitude)
        site.setTimeZone(@epw_file.timeZone)
        site.setElevation(@epw_file.elevation)

        BTAP::runner_register("Info","Setting water main temperatures via parsing of STAT file.", runner ) 
        water_temp = model.getSiteWaterMainsTemperature
        water_temp.setAnnualAverageOutdoorAirTemperature(@stat_file.mean_dry_bulb)
        water_temp.setMaximumDifferenceInMonthlyAverageOutdoorAirTemperatures(@stat_file.delta_dry_bulb)
        BTAP::runner_register("Info","SiteWaterMainsTemperature.AnnualAverageOutdoorAirTemperature = #{@stat_file.mean_dry_bulb}.", runner ) 
        BTAP::runner_register("Info","SiteWaterMainsTemperature.MaximumDifferenceInMonthlyAverageOutdoorAirTemperatures = #{@stat_file.delta_dry_bulb}.", runner ) 

        # Remove all the Design Day objects that are in the file
        model.getObjectsByType("OS:SizingPeriod:DesignDay".to_IddObjectType).each { |d| d.remove }

        # Load in the ddy file based on convention that it is in the same directory and has the same basename as the weather
        @ddy_file.getObjectsByType("OS:SizingPeriod:DesignDay".to_IddObjectType).each do |d|
          # grab only the ones that matter
          ddy_list = /(Htg 99.6. Condns DB)|(Clg .4. Condns WB=>MDB)|(Clg .4% Condns DB=>MWB)/
          if d.name.get =~ ddy_list
            BTAP::runner_register("Info","Adding design day '#{d.name}'.",runner)
            # add the object to the existing model
            model.addObject(d.clone)
          end
        end
        return true
      end

      #This method scans.
      #@author phylroy.lopez@nrcan.gc.ca
      def scan()
        @filearray = Array.new()
        file = File.new(@epw_filepath, "r")
        while (line = file.gets)
          @filearray.push(line.split(","))
        end
        file.close
      end

      #This method will sets column to a value.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params column [String]
      #@params value [Fixnum]
      def setcolumntovalue(column,value)
        @filearray.each do |line|
          unless line.first =~ /\D(.*)/
            line[column] = value
          end
        end
      end

      #This method will eliminate all radiation and returns self.
      #@author phylroy.lopez@nrcan.gc.ca
      #@return self [String]
      def eliminate_all_radiation()
        self.scan() if @filearray == nil
        setcolumntovalue(Extraterrestrial_Horizontal_Radiation,"0")#not used
        setcolumntovalue(Extraterrestrial_Direct_Normal_Radiation,"0")#not used
        setcolumntovalue(Horizontal_Infrared_Radiation_Intensity,"315")
        setcolumntovalue(Global_Horizontal_Radiation,"0")#not used
        setcolumntovalue(Direct_Normal_Radiation,"0")
        setcolumntovalue(Diffuse_Horizontal_Radiation,"0")
        setcolumntovalue(Total_Sky_Cover,"10")#not used
        setcolumntovalue(Opaque_Sky_Cover,"10")#not used
        setcolumntovalue(Visibility,"0")#not used
        setcolumntovalue(Ceiling_Height,"0")#not used
        #lux values
        setcolumntovalue(Global_Horizontal_Illuminance,"0")#not used
        setcolumntovalue(Direct_Normal_Illuminance,"0")#not used
        setcolumntovalue(Diffuse_Horizontal_Illuminance,"0")#not used
        setcolumntovalue(Zenith_Luminance,"0")#not used
        return self
      end

      #This method will eliminate solar radiation and returns self.
      #@author phylroy.lopez@nrcan.gc.ca
      #@return self [String]
      def eliminate_only_solar_radiation()
        self.scan() if @filearray == nil
        setcolumntovalue(Global_Horizontal_Radiation,"0")#not used
        setcolumntovalue(Direct_Normal_Radiation,"0")
        setcolumntovalue(Diffuse_Horizontal_Radiation,"0")
        return self
      end

      #This method will eliminate all radiation except solar and returns self.
      #@author phylroy.lopez@nrcan.gc.ca
      #@return self [String]
      def eliminate_all_radiation_except_solar()
        self.scan() if @filearray == nil
        setcolumntovalue(Extraterrestrial_Horizontal_Radiation,"0")#not used
        setcolumntovalue(Extraterrestrial_Direct_Normal_Radiation,"0")#not used
        setcolumntovalue(Horizontal_Infrared_Radiation_Intensity,"315")
        setcolumntovalue(Total_Sky_Cover,"10")#not used
        setcolumntovalue(Opaque_Sky_Cover,"10")#not used
        setcolumntovalue(Visibility,"0")#not used
        setcolumntovalue(Ceiling_Height,"0")#not used
        #lux values
        setcolumntovalue(Global_Horizontal_Illuminance,"0")#not used
        setcolumntovalue(Direct_Normal_Illuminance,"0")#not used
        setcolumntovalue(Diffuse_Horizontal_Illuminance,"0")#not used
        setcolumntovalue(Zenith_Luminance,"0")#not used
        return self
      end

      #This method will eliminate percipitation and returns self.
      #@author phylroy.lopez@nrcan.gc.ca
      #@return self [String]
      def eliminate_percipitation
        self.scan() if @filearray == nil
        setcolumntovalue(Present_Weather_Observation, "0")
        setcolumntovalue(Present_Weather_Codes,"999999999") #no weather. Clear day.
        setcolumntovalue(Snow_Depth,"0")
        setcolumntovalue(Liquid_Precipitation_Depth,"0")
        setcolumntovalue(Liquid_Precipitation_Quantity,"0")
        return self
      end

      #This method eliminates wind and returns self.
      #@author phylroy.lopez@nrcan.gc.ca
      #@return self [String]
      def eliminate_wind
        self.scan() if @filearray == nil
        setcolumntovalue(Wind_Direction,"0")
        setcolumntovalue(Wind_Speed,"0")
        return self
      end

      #This method sets Constant Dry and Dew Point Temperature Humidity And Pressure and returns self.
      #@author phylroy.lopez@nrcan.gc.ca
      #@return dbt [Float] dry bulb temperature
      #@return dpt [Float] dew point temperature
      #@return hum [Fixnum] humidity
      #@return press [Fixnum] pressure
      #@return self [String]
      def setConstantDryandDewPointTemperatureHumidityAndPressure(dbt = "0.0",dpt="-1.1",hum="92",press="98500")
        self.scan() if @filearray == nil
        setcolumntovalue(Dry_Bulb_Temperature,dbt)
        setcolumntovalue(Dew_Point_Temperature,dpt)
        setcolumntovalue(Relative_Humidity,hum)
        setcolumntovalue(Atmospheric_Station_Pressure,press)
        return self
      end

      #This method writes to a file.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params filename [String]
      def writetofile(filename)
        self.scan() if @filearray == nil

        begin
          FileUtils.mkdir_p(File.dirname(filename))
          file = File.open(filename, "w")
          @filearray.each do |line|
            firstvalue = true
            newline = ""
            line.each do |value|
              if firstvalue == true
                firstvalue = false
              else
                newline = newline +","
              end
              newline = newline + value
            end
            file.puts(newline)
          end
        rescue IOError => e
          #some error occur, dir not writable etc.
        ensure
          file.close unless file == nil
        end
        #copies original file
        FileUtils.cp(@ddy_filepath, "#{File.dirname(filename)}/#{File.basename(filename,'.epw')}.ddy")
        FileUtils.cp(@stat_filepath, "#{File.dirname(filename)}/#{File.basename(filename,'.epw')}.stat")
      end

    end #Environment




  end
end

