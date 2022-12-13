""" Space Types Test Sets Generator

This script generates the test sets required to execute an NECB iterative regression test. This script
only exists as a reference, as the test sets for a NECB release only need to be generated once.

This script supports generation for NECB releases of 2011, 2015, 2017 and 2020.

"""
__author__ = "Leonardo Saavedra"


import random
import json

def shuffle_list(input_list):
    """
    Helper method that shuffles a python list. Seed is manually set for consistency.
    """
    shuffled_list = list(input_list)
    random.seed(132625)
    random.shuffle(shuffled_list)
    return shuffled_list

def is_spacetype_equivalent(st1: str, st2:str):
    """
    Compares 2 space type names, and determines if they are equivalent (same type, different schedule)
    :return: bool
    """
    return st1[:-6] == st2[:-6]

def parse_and_output_spacetype_names(template, name_file_output = True):
    """
    Helper method to parse space_types.json file from NECB, and outputs a .json file with all the space function
    names.
    Supoorts NECB 2011, 2015, 2017 and 2020.
    :param template: NECB Template string.
    :return: list: List of space function space type names.
    """

    # NECB space_types.json paths for all releases
    NECBs = {
        "NECB2011" : "../../../../lib/openstudio-standards/standards/necb/NECB2011/data/space_types.json",
        "NECB2015" : "../../../../lib/openstudio-standards/standards/necb/NECB2015/data/space_types.json",
        "NECB2017" : "../../../../lib/openstudio-standards/standards/necb/NECB2017/data/space_types.json",
        "NECB2020" : "../../../../lib/openstudio-standards/standards/necb/NECB2020/data/space_types.json"
    }
    # Validate template input
    if NECBs.get(template) is None:
        raise IndexError("Invalid template. Use one of NECB 2011, 2015, 2017 or 2020.")
    filepath = NECBs[template]

    with open(filepath) as file:
        space_type_names = {}
        data = json.load(file)
        for space_type in data["tables"]["space_types"]["table"]:
            building_type = space_type["building_type"]
            space_type_name = space_type["space_type"]
            if space_type_names.get(building_type) == None:
                space_type_names[building_type] = []
            space_type_names[building_type].append(space_type_name)

    ## TODO: adding mkdir code might be useful here.
    if name_file_output:
        dict_to_json(space_type_names, f'./space_types_data/{template}-space-type-names.json')

    return space_type_names["Space Function"]

def generate_spacetypes_test_sets(n_spaces: int, buffer_size: int, n_iterations = None, template: str = 'NECB2011',
                                  name_file_output: bool = True):
    """

    :param n_spaces: Number of space types per iteration (number of spaces in target model).
    :param buffer_size: Size of the scrolling window size.
    :param n_iterations: Number of test sets. Default value is the minimum amount that uses all space types.
    :return: 2D Matrix, every row is a test set.
    """
    spacefunction_names_list = parse_and_output_spacetype_names(template, name_file_output)
    shuffled_list = shuffle_list(spacefunction_names_list)
    completion_list = list(spacefunction_names_list)
    completion = False

    output_matrix = {}
    current_itr = []
    temp_list = []

    # Loop through iterations
    iteration = 0
    while ((not completion) or (iteration == n_iterations)):
        iteration_complete = False

        # Keeps a portion of the previous iteration (window size/delta size)
        if iteration != 0:
            index_window_change = n_spaces - buffer_size
            current_itr = list(current_itr[index_window_change:])

            for i in range(len(temp_list)):
                shuffled_list.append(temp_list.pop())

        # Loops until iteration test set has the correct length
        while (not iteration_complete):
            # Stores item from shuffled list it in temp_pop. If list is empty,
            #   shuffle list again and retry loop.
            try:
                temp_pop = shuffled_list.pop()
            except IndexError:
                shuffled_list = shuffle_list(spacefunction_names_list)
                continue

            # Algorithm won't add a space type to current test set, if there is an equivalent one.
            # An equivalent pair  means same space type, different schedule
            # Any spaces not added due to this rule are added to temp_list, and are prioritised to be added
            # in any following iterations.
            has_equivalent_spacetype = False
            for itr_element in current_itr:
                if is_spacetype_equivalent(temp_pop, itr_element):
                    has_equivalent_spacetype = True
            if has_equivalent_spacetype:
                temp_list.append(temp_pop)
            else:
                # Add current item to the current iteration.
                current_itr.append(temp_pop)
                try:
                    completion_list.remove(temp_pop)
                except:
                    pass

            if len(current_itr) == n_spaces:
                iteration_complete = True

        if (len(completion_list) == 0) and not completion:
            print(f"Test set reached completion at iteration {iteration+1}.")
            completion = True
        output_matrix[iteration] = list(current_itr)
        iteration += 1

    return output_matrix

def dict_to_json(input_dict, output_path):
    """
    Creates indented json output from python dictionary.
    :param input_dict: Input dictionary to be converted to json.
    :param output_path: Output path for .json file.
    """
    with open(output_path, "w") as output:
        json.dump(input_dict, output, indent=4)

if __name__ == '__main__':
    output_path = ''
    buffer_size = 6
    templates = [
        'NECB2011',
        'NECB2015',
        'NECB2017',
        'NECB2020'
    ]
    for template in templates:
        test_sets = generate_spacetypes_test_sets(20, buffer_size=buffer_size, template=template)
        dict_to_json(test_sets, f'./space_types_data/{template}-test-set-buffer-size-{buffer_size}.json')

