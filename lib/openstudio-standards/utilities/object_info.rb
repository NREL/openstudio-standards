Standard.class_eval do
  # A set of method to manipulate objects

  # Get hash of object field names and values
  # @author: Xuechen (Jerry) Lei, PNNL
  # @param  obj [object]
  #
  # @return [Hash<String>] FieldName:Value
  #
  def model_get_object_hash(obj)
    fields_array = obj.to_s.split(/\n/)
    output_hash = { 'object type' => fields_array.shift.split(/,/)[0] }
    right = nil
    fields_array.each do |ori_field|
      left, right = ori_field.split(/[,;]/)
      left = left.strip
      right.slice!('!-')
      right = right.strip
      output_hash[right] = left
    end
    return output_hash
  end

  # This method is used to automatically cast a model
  # object based on its IDD object type
  #
  # @param [OpenStudio::Model::ModelObject]
  # @return Casted OpenStudio object or nil if the cast was not possible
  def model_cast_model_object(model_object)
    model_object_type = model_object.iddObjectType.valueName.to_s.sub('OS_', '').strip.sub('_', '')
    casting_method_name = "to_#{model_object_type}"
    casted_object = nil

    # Make sure that the the casting method can be applied
    if model_object.respond_to?(casting_method_name)
      casted_object = model_object.public_send(casting_method_name).get
    end

    return casted_object
  end
end
