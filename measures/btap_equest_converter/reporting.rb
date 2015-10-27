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


require "#{File.dirname(__FILE__)}/btap"
require 'fileutils'
require 'csv'

module BTAP
  module Reporting
    #This method will take the folder name and write out a result files to the input folder.
    #@author phylroy.lopez@nrcan.gc.ca
    #@params folder [String] Path too a folder where to write result files to.
    def self.get_all_annual_results_from_runmanger(folder)
      #output file name
      result_file_path = folder + "/annual_result_table.csv"
      File.delete(result_file_path) if File.exist?(result_file_path)
      error_file_path = folder + "/failed simulations.txt"
      File.delete(error_file_path) if File.exist?(error_file_path)
      annual_results = File.new( result_file_path,'a')
      error_file = File.new( error_file_path,'a')
      header_printed = false
      array = Array.new
      counter = 0
      osmfiles = BTAP::FileIO::get_find_files_from_folder_by_extension(folder,".osm")
      osmfiles.each do |osm|
        puts "Processing #{osm} results"
        simulation_folder = File.basename( osm, ".*" )
        sql = BTAP::FileIO::get_find_files_from_folder_by_extension("#{folder}/#{simulation_folder}",".sql").first
        htm = BTAP::FileIO::get_find_files_from_folder_by_extension("#{folder}/#{simulation_folder}",".htm").first
        unless sql.nil? or osm.nil? or htm.nil?
          puts "Processing #{osm} results with #{sql} and #{htm}."
                    array = BTAP::SimManager::ProcessManager::old_get_annual_results_model_results( osm, sql )
                    if header_printed == false
                      header_printed = true
                      header = ""
                      array.each do |value|
                        header = header + "#{value[1]} #{value[2]},"
                      end
                      annual_results.puts(header)
                    end
                    row_data = ""
                    array.each do |value|
                      row_data = row_data + "#{value[0]},"
                    end
                    annual_results.puts(row_data)
                    puts "#{counter} of #{osmfiles.size} remaining." 
                    counter = counter + 1
                    puts "annual results have been processed and added to #{result_file_path} for #{osm}. "
        else
          puts "***************************************ERROR!: #{osm} simulation failed to produce results\n"
          error_file.puts("ERROR!: #{osm} simulation failed to produce results\n Here is the resulting eplusout.err file:\n")
          err = BTAP::FileIO::get_find_files_from_folder_by_extension("#{folder}/#{simulation_folder}","eplusout.err").first
          errfile = File.open(err, "rb")
          errfile.readlines.each do |line|
            puts line
            error_file.puts( line )
            error_file.puts("\n")
          end
          errfile.close
        end
      end
      annual_results.close
      error_file.close
    end



  end
end
