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

require 'csv'

module BTAP

  module Visualization
    class GraphEmbedder
      @destination_file
      @html_file
      Embedded_Definition_Start = "var EMBEDDED_ARRAY = "
      Embedded_Function_Call = "processEmbeddedArray(EMBEDDED_ARRAY);\n"

      #This method sets the global parameters for the GraphicEmbedder destination file and html file.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params dest_file [String] sets the global parameters for the GraphicEmbedder destination file
      #@params html_file [String] sets the global parameters for the GraphicEmbedder html file
      def initialize(dest_file,html_file)
        @destination_file = dest_file
        @html_file = html_file
      end

      #This method will create embedding.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params csv_file [String] path to csv file
      def create_embedding(csv_file)
        newfile = File.open(@destination_file, 'w')
        File.open(@html_file,'r').each do |line|
          if line.include? "!!Ruby Anchor!!"
            newfile.write(Embedded_Definition_Start + GraphEmbedder.get_array_as_string(csv_file) + ";\n")
            newfile.write(Embedded_Function_Call)
          else
            newfile.write(line)
          end
        end
        newfile.close
      end

      #This method will return an array as a string.
      #@author phylroy.lopez@nrcan.gc.ca
      #@params csv_file [String] path to csv file
      #@return [string_array<String>]
      def self.get_array_as_string(csv_file)
        csv = CSV.open(csv_file,'r')
        string_array = csv.to_a.inspect
        string_array = string_array.sub(/nil/,"\"\"")
        return string_array
      end

    end

    g = GraphEmbedder.new("C:\\OSRuby\\visualization\\graph\\embedded.html","C:\\OSRuby\\visualization\\graph\\pc-graph.html")
    g.create_embedding("C:\\OSRuby\\visualization\\graph\\datatest.csv")
  end
end