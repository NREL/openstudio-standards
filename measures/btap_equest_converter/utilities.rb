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

# To change this template, choose Tools | Templates
# and open the template in the editor.
#require 'openstudio'
#require 'win32/registry'
require "#{File.dirname(__FILE__)}/btap"

class Utilities
  #this will determine which diff client to use.. Windows must use kdiff3
  #this method will get the path of Kdiff3 from the registry.
#  def self.get_diff_client
#    Win32::Registry::HKEY_LOCAL_MACHINE.open('Software\Kdiff3') do |reg|
#      reg_typ, reg_val = reg.read('')
#      return reg_val
#    end
#  end

  #This method checks the bounds and raise an exception if the value is out of bounds.
  #@author phylroy.lopez@nrcan.gc.ca
  #@params left_value [Number] 
  #@params left_operator [String] 
  #@params center_value [Number] 
  #@params right_operator [String] 
  #@params right_value [Number] 
  def self.check_bounds(left_value,left_operator,center_value,right_operator,right_value)
    operation = left_value.to_s + " " + left_operator.to_s + " " + center_value.to_s + " or " + center_value.to_s + " " + right_operator.to_s + " " + right_value.to_s
    raise("Error: in bounds." + operation_1  )  unless eval(operation +" ? true :false")
  end
 
  #This method will take 3 variables and will bring up Kdiff3 for a 2 or 3-way diff view of the OSM file.
  #argument model(s). This is handy for quickly viewing changes to the file during
  #runtime for debugging and QA.
  #@author phylroy.lopez@nrcan.gc.ca
  #@params model1 [OpenStudio::model::Model] A model object. 
  #@params model2 [OpenStudio::model::Model] A model object. 
  #@params model3 [OpenStudio::model::Model] A model object.
  def self.kdiff3_model_osm(model1, model2, model3 = "")
    Dir::mkdir("C:\\kdiff_test") unless File.exists?("C:\\kdiff_test")
    model1.save(OpenStudio::Path.new("c:\\kdiff_test\\diffA.osm"))
    model2.save(OpenStudio::Path.new("c:\\kdiff_test\\diffB.osm"))
    if model3 == ""
      system(self.get_diff_client + "\\kdiff3.exe", "c:\\kdiff_test\\diffA.osm", "c:\\kdiff_test\\diffB.osm")
    else
      model3.save(OpenStudio::Path.new("c:\\kdiff_test\\C.osm"))
      system(self.get_diff_client + "\\kdiff3.exe", "c:\\kdiff_test\\diffA.osm", "c:\\kdiff_test\\diffB.osm", "c:\\kdiff_test\\diffC.osm" )
    end
    FileUtils.rm_rf("C:\\kdiff_test")

  end

  #This method will take 3 variables and bring up Kdiff3 for a 2 or 3-way diff view of the OSM file.
  #The second argument is optional, it will compare the current model with the
  #argument model(s). This is handy for quickly viewing changes to the file during
  #runtime for debugging and QA.
  #@author phylroy.lopez@nrcan.gc.ca
  #@params model1 [OpenStudio::model::Model] A model object. 
  #@params model2 [OpenStudio::model::Model] A model object.
  #@params model3 [OpenStudio::model::Model] A model object. 
  def self.kdiff3_model_idf(model1, model2, model3 = "")
    Dir::mkdir("C:\\kdiff_test") unless File.exists?("C:\\kdiff_test")

    OpenStudio::EnergyPlus::ForwardTranslator.new().translateModel(model1).toIdfFile().save(OpenStudio::Path.new("c:\\kdiff_test\\diffA.idf"),true)
    self.sort_idf_file("c:\\kdiff_test\\diffA.idf")
    OpenStudio::EnergyPlus::ForwardTranslator.new().translateModel(model2).toIdfFile().save(OpenStudio::Path.new("c:\\kdiff_test\\diffB.idf"),true)
    self.sort_idf_file("c:\\kdiff_test\\diffB.idf")
    if model3 == ""
      system(self.get_diff_client + "\\kdiff3.exe", "c:\\kdiff_test\\diffA.idf.sorted", "c:\\kdiff_test\\diffB.idf.sorted")
    else
      OpenStudio::EnergyPlus::ForwardTranslator.new().translateModel(model3).toIdfFile().save(OpenStudio::Path.new("c:\\kdiff_test\\diffC.idf"),true)
      self.sort_idf_file("c:\\kdiff_test\\diffC.idf")
      system(self.get_diff_client + "\\kdiff3.exe", "c:\\kdiff_test\\diffA.idf.sorted", "c:\\kdiff_test\diffB.idf.sorted", "c:\\kdiff_test\diffC.idf.sorted" )
    end
  end

  #This method will sort an idf file and produce a sorted idf file. This is helpful for doing diffs on idf files. 
  #@author phylroy.lopez@nrcan.gc.ca
  #@params idf_file [String] 
  def self.sort_idf_file(idf_file)
    idf_model = OpenStudio::IdfFile::load(OpenStudio::Path.new(idf_file), "EnergyPlus".to_IddFileType).get
    save_filename = idf_file + ".sorted"

    # Iterate over all the IDF objects and put into a ruby array.
    # Note that you must strip the object name because for some reason it has
    # trailing characters
    sorted_idf = {}
    verobj = idf_model.versionObject
    if not verobj.empty?
      verobj = verobj.get
      objname = verobj.getString(0).get
      obj = verobj.to_s.gsub("!-", "!")
      sorted_idf["#{verobj.iddObject.name()} #{objname}"] = obj
    end
    idf_model.objects.each do |object|
      if object.iddObject.type != "CommentOnly".to_IddObjectType
        objname = object.name()
        objname = objname.to_s.strip
        if objname == ""
          # puts "[DEBUG] ObjectName is Blank, using first field"
          objname = object.getString(0).get
        end
        # puts "Class Name: #{object.iddObject.name()}    Object Name: #{objname}      Size: #{object.numFields()}"

        # Clean up the comment field. They comments flags change on translation!
        obj = object.to_s.gsub("!-", "!")
        sorted_idf["#{object.iddObject.name()} #{objname}"] = obj
      end
    end

    out = sorted_idf.sort #returns a nested array, 0 is key, 1 is value
    File.open(save_filename, 'w') do |file|
      out.each do |value|
        file << value[1]
      end
    end
  end
end