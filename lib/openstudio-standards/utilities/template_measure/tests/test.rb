require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'fileutils'
require 'openstudio-standards'
begin
  require 'openstudio_measure_tester/test_helper'
rescue LoadError
  puts 'OpenStudio Measure Tester Gem not installed -- will not be able to aggregate and dashboard the results of tests'
end
require_relative '../measure.rb'
require_relative '../resources/BTAPMeasureHelper.rb'
require 'minitest/autorun'


class BTAPModelMeasure_Test < Minitest::Test
  # Brings in helper methods to simplify argument testing of json and standard argument methods.
  include(BTAPMeasureTestHelper)
  def setup()

    @use_json_package = false
    @use_string_double = true
    @measure_interface_detailed = [

        {
            "name" => "a_string_argument",
            "type" => "String",
            "display_name" => "A String Argument (string)",
            "default_value" => "The Default Value",
            "is_required" => false
        },
        {
            "name" => "a_double_argument",
            "type" => "Double",
            "display_name" => "A Double numeric Argument (double)",
            "default_value" => 0,
            "max_double_value" => 100.0,
            "min_double_value" => 0.0,
            "is_required" => false
        },
        {
            "name" => "a_string_double_argument",
            "type" => "StringDouble",
            "display_name" => "A String Double numeric Argument (double)",
            "default_value" => 23.0,
            "max_double_value" => 100.0,
            "min_double_value" => 0.0,
            "valid_strings" => ["NA"],
            "is_required" => false
        },
        {
            "name" => "a_choice_argument",
            "type" => "Choice",
            "display_name" => "A Choice String Argument ",
            "default_value" => "choice_1",
            "choices" => ["choice_1", "choice_2"],
            "is_required" => false
        },
        {
            "name" => "a_bool_argument",
            "type" => "Bool",
            "display_name" => "A Boolean Argument ",
            "default_value" => false,
            "is_required" => true
        }

    ]

    @good_input_arguments = {
        "a_string_argument" => "MyString",
        "a_double_argument" => 50.0,
        "a_string_double_argument" => "50.0",
        "a_choice_argument" => "choice_1",
        "a_bool_argument" => true
    }

  end

  def test_sample()
    ####### Test Model Creation######
    #You'll need a seed model to test against. You have a few options.
    # If you are only testing arguments, you can use an empty model like I am doing here.
    # Option 1: Model CreationCreate Empty Model object and start doing things to it. Here I am creating an empty model
    # and adding surface geometry to the model
    model = OpenStudio::Model::Model.new
    # and adding surface geometry to the model using the wizard.
    BTAP::Geometry::Wizards.create_shape_rectangle(model,
                                                   length = 100.0,
                                                   width = 100.0,
                                                   above_ground_storys = 3,
                                                   under_ground_storys = 1,
                                                   floor_to_floor_height = 3.8,
                                                   plenum_height = 1,
                                                   perimeter_zone_depth = 4.57,
                                                   initial_height = 0.0)
    # If we wanted to apply some aspects of a standard to our model we can by using a factory method to bring the
    # standards we want into our tests. So to bring the necb2011 we write.
    necb2011_standard = Standard.build('NECB2011')

    # could add some example contructions if we want. This method will populate the model with some
    # constructions and apply it to the model
    necb2011_standard.model_clear_and_set_example_constructions(model)

    # While debugging and testing, it is sometimes nice to make a copy of the model as it was.
    before_measure_model = copy_model(model)

    # You can save your file anytime you want here I am saving to the
    BTAP::FileIO::save_osm(model, File.join(File.dirname(__FILE__), "output", "saved_file.osm"))

    #We can even call the standard methods to apply to the model.
    necb2011_standard.model_add_design_days_and_weather_file(model, 'NECB HDD Method', 'CAN_BC_Vancouver.Intl.AP.718920_CWEC2016.epw')

    puts BTAP::FileIO.compare_osm_files(before_measure_model, model)
    necb2011_standard.apply_standard_construction_properties(model) # standards candidate


    # Another simple way is to create an NECB
    # building using the helper method below.
    #Option #2 NECB method.
    #   model = create_necb_protype_model(
    #      "LargeOffice",
    #     'NECB HDD Method',
    #      'CAN_BC_Vancouver.Intl.AP.718920_CWEC2016.epw',
    #      "NECB2011"
    #   )

    # You can also run annually the model directly.
    #   necb2011_standard.model_run_simulation_and_log_errors( model, File.join(File.dirname(__FILE__),"output" ))

    # Or a quick sizing run if you need something fast.
    #   necb2011_standard.model_run_sizing_run(model, File.join(File.dirname(__FILE__),"output" ))

    # Another simple way is to create an NECB
    # building using the helper method below.
    # Option #3 Load osm file.
    # model = BTAP::FileIO.load_osm(filepath)


    input_arguments = nil

    if @use_json_package
      input_arguments = {
          "json_input" => '{ "a_string_argument": "The Default Value",
                      "a_double_argument": 0.0,
                      "a_string_double_argument": 23.0,
                      "a_choice_argument": "choice_1",
                      "a_bool_argument": false }'
      }

    else
      # Set up your argument list to test.
      input_arguments = {
          "a_string_argument" => "MyString",
          "a_double_argument" => 10.0,
          "a_string_double_argument" => 75.3,
          "a_choice_argument" => "choice_1"
      }
    end

    # Create an instance of the measure
    runner = run_measure(input_arguments, model)
    puts show_output(runner.result)

    assert(runner.result.value.valueName == 'Success')
  end
end
