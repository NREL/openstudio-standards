import os

def create_output_dir(output_dir):
    # Helper method to create output directory
    try:
        os.mkdir(output_dir)
    except OSError as error:
        print(f"Found '{output_dir}', files will be generated there.")
        print(f"Any existing files in the output directory may be overwritten.")


def output_test_files(output_dir, iteration, template, primary_fuel):
    # Setup file name to be consistent with other tests
    filename = f'test_necb_bldg_EdgeCaseGeometry_{template}_{primary_fuel}_iteration{str(iteration).zfill(2)}.rb'
    print(f'Creating file at: {output_dir+filename}')

    # Create file in output directory
    with open(output_dir+filename, 'w') as f:
        # Define class name and main function name for better reaadability
        class_name = f"Test_EdgeCaseGeometry_{template}_{primary_fuel}_iteration{iteration}"
        main_func_name = f"test_{template}_EdgeCaseGeometry_regression_{primary_fuel}_iteration{iteration}()"



        # Write code to the file.
        f.write('''require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require_relative '../../../helpers/compare_models_helper'
require_relative '../resources/regression_helper' \n\n''')
        f.write(f'class {class_name} < NECBRegressionHelper \n')
        f.write('''
  def setup()
    super()
  end\n''')
        f.write(f'''
  def {main_func_name}
    result, diff = create_iterative_model_and_regression_test(building_type: 'EdgeCaseGeometry',
                                                              primary_heating_fuel: {primary_fuel},
                                                              epw_file:  'CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw',
                                                              template: {template},
                                                              run_simulation: true,
                                                              iteration: {iteration}
    )''')
        f.write(f'''
  if result == false
    puts "JSON terse listing of diff-errors."
    puts diff
    puts "Pretty listing of diff-errors for readability."
    puts JSON.pretty_generate( diff )
    puts "You can find the saved json diff file under the /expected_results folder.
    puts "outputing errors here. "
    puts diff["diffs-errors"] if result == false
  end
  assert(result, diff)''')
        f.write('''  end
end''')

def main():
    templates = ["NECB2011", "NECB2015", "NECB2017", "NECB2020"]
    primary_fuel_types = ["Electricity", "NaturalGas"]
    iterations_count = {
        "NECB2011" : 15,
        "NECB2015" : 22,
        "NECB2017" : 22,
        "NECB2020" : 21
    }
    output_dir = './generated-iterative-regression-tests/'
    create_output_dir(output_dir)
    for template in templates:
        for primary_fuel in primary_fuel_types:
            for iteration in range(iterations_count.get(template)):
                output_test_files(output_dir, iteration, template, primary_fuel)
    print(f'All generated tests were succesfully written to {output_dir}')


if __name__ == "__main__":
    main()
