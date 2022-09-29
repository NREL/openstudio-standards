#
# Get hash of object field names and values
# @author: Xuechen (Jerry) Lei, PNNL
# @param  obj [object]
#
# @return [Hash<String>] FieldName:Value
#
def getObjectHash(obj)
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
