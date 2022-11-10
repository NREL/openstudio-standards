import json

def read_json_names(filepath):
    """
    :param filepath: Input filepath should be space_types.json from NCEB2011.
    :return: Parsed dictionary containing only the space type buliding type and names associated.
    """
    with open(filepath) as file:

        # Initiate dictionary (to be converted to json) containing buliding types and space type name
        space_type_names = {}
        data = json.load(file)
        # Iterate through the table of space types in the json file
        for space_type in data["tables"]["space_types"]["table"]:
            building_type = space_type["building_type"]
            space_type_name = space_type["space_type"]

            # Verify the key,value of space_type_names dict. If not existant, create empty list.
            if space_type_names.get(building_type) == None:
                space_type_names[building_type] = []

            space_type_names[building_type].append(space_type_name)

        return space_type_names

def dict_to_json(input_dict, filepath):
    """
    :param input_dict: Input dictionary to be converted to json.
    :param filepath: Directory for output json.
    """
    with open(filepath, "w") as output:
        json.dump(input_dict, output, indent=4)



if __name__ == '__main__':
    input_filename = './space_types.json'
    output_filename = './spacetype_names_only.json'
    dict_to_json(read_json_names(input_filename), output_filename)
