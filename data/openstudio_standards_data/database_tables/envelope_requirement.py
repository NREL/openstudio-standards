from database_engine.assertions import assert_
from database_engine.database import DBOperation
from database_engine.database_util import is_float, getattr_either

TABLE_NAME = "envelope_requirement"

RECORD_HELP = """
Must provide a tuple that contains:
template: TEXT
climate_zone_set: TEXT
intended_surface_type: TEXT
standards_construction_type: TEXT
building_category: TEXT
construction: TEXT
orientation: TEXT
minimum_percent_of_surface: NUMERIC
maximum_percent_of_surface: NUMERIC
assembly_maximum_u_value: NUMERIC
assembly_maximum_u_value_unit: TEXT
u_value_includes_interior_film_coefficient: TEXT
u_value_includes_exterior_film_coefficient: TEXT
assembly_maximum_f_factor: NUMERIC
assembly_maximum_f_factor_unit: TEXT
assembly_maximum_c_factor: NUMERIC
assembly_maximum_c_factor_unit: TEXT
assembly_maximum_solar_heat_gain_coefficient: NUMERIC
assembly_minimum_vt_SHGC: NUMERIC
annotation: TEXT (optional)
"""

CREATE_ENVELOPE_REQUIREMENTS_TABLE = """
CREATE TABLE IF NOT EXISTS %s
(id INTEGER PRIMARY KEY, 
template TEXT NOT NULL, 
climate_zone_set TEXT NOT NULL,
intended_surface_type TEXT NOT NULL,
standards_construction_type TEXT,
building_category TEXT NOT NULL,
construction TEXT NOT NULL,
orientation TEXT,
minimum_percent_of_surface NUMERIC,
maximum_percent_of_surface NUMERIC,
assembly_maximum_u_value NUMERIC,
assembly_maximum_u_value_unit TEXT,
u_value_includes_interior_film_coefficient TEXT,
u_value_includes_exterior_film_coefficient TEXT,
assembly_maximum_f_factor NUMERIC,
assembly_maximum_f_factor_unit TEXT,
assembly_maximum_c_factor NUMERIC,
assembly_maximum_c_factor_unit TEXT,
assembly_maximum_solar_heat_gain_coefficient NUMERIC,
assembly_minimum_vt_shgc NUMERIC,
annotation TEXT,
FOREIGN KEY(construction) REFERENCES support_constructions(name)
);
"""

INSERT_A_ENVELOPE_REQUIREMENT_RECORD = """
    INSERT INTO %s (
template, 
climate_zone_set,
intended_surface_type,
standards_construction_type,
building_category,
construction,
orientation,
minimum_percent_of_surface,
maximum_percent_of_surface,
assembly_maximum_u_value,
assembly_maximum_u_value_unit,
u_value_includes_interior_film_coefficient,
u_value_includes_exterior_film_coefficient,
assembly_maximum_f_factor,
assembly_maximum_f_factor_unit,
assembly_maximum_c_factor,
assembly_maximum_c_factor_unit,
assembly_maximum_solar_heat_gain_coefficient,
assembly_minimum_vt_shgc,
annotation
) 
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? , ? , ?);
"""

RECORD_TEMPLATE = {
    "template": "",
    "climate_zone_set": "",
    "intended_surface_type": "",
    "standards_construction_type": "",
    "building_category": "",
    "construction": "",
    "orientation": "",
    "minimum_percent_of_surface": 0.0,
    "maximum_percent_of_surface": 0.0,
    "assembly_maximum_u_value": 0.0,
    "assembly_maximum_u_value_unit": "btu/h-ft2-F",
    "u_value_includes_interior_film_coefficient": 0.0,
    "u_value_includes_exterior_film_coefficient": 0.0,
    "assembly_maximum_f_factor": 0.0,
    "assembly_maximum_f_factor_unit": "btu/h-ft-F",
    "assembly_maximum_c_factor": 0.0,
    "assembly_maximum_c_factor_unit": "btu/h-ft2-F",
    "assembly_maximum_solar_heat_gain_coefficient": 0.0,
    "assembly_minimum_vt_shgc": 0.0,
    "annotation": "",
}


class EnvelopeRequirementTable(DBOperation):
    def __init__(self):
        super(EnvelopeRequirementTable, self).__init__(
            table_name=TABLE_NAME,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=f"database_files/{TABLE_NAME}",
            create_table_query=CREATE_ENVELOPE_REQUIREMENTS_TABLE % TABLE_NAME,
            insert_record_query=INSERT_A_ENVELOPE_REQUIREMENT_RECORD % TABLE_NAME,
        )

    def get_record_info(self):
        """
        A function to return the record info of the table
        :return:
        """
        return RECORD_HELP

    def validate_record_datatype(self, record):
        str_expected = [
            "template",
            "climate_zone_set",
            "intended_surface_type",
            "standards_construction_type",
            "building_category",
            "construction",
            "orientation",
            "value_includes_interior_film_coefficient",
            "value_includes_exterior_film_coefficient",
        ]

        for f in str_expected:
            if record.get(f):
                assert_(
                    isinstance(record[f], str),
                    f"{f} requires to be a string, instead got {record[f]}",
                )

        float_expected = [
            "minimum_percent_of_surface",
            "maximum_percent_of_surface",
            "assembly_maximum_u_value",
            "assembly_maximum_f_factor",
            "assembly_maximum_c_factor",
            "assembly_maximum_solar_heat_gain_coefficient",
            "assembly_minimum_vt_shgc",
        ]

        for f in float_expected:
            if record.get(f):
                assert_(
                    is_float(record.get(f)),
                    f"{f} requires to be numeric data type, instead got {record[f]}",
                )
        return True

    def _preprocess_record(self, record):
        """

        :param record: dict
        :return:
        """

        return (
            getattr_either("template", record),
            getattr_either("climate_zone_set", record),
            getattr_either("intended_surface_type", record),
            getattr_either("standards_construction_type", record),
            getattr_either("building_category", record),
            getattr_either("construction", record),
            getattr_either("orientation", record),
            getattr_either("minimum_percent_of_surface", record),
            getattr_either("maximum_percent_of_surface", record),
            getattr_either("assembly_maximum_u_value", record),
            getattr_either("assembly_maximum_u_value_unit", record, "btu/h-ft2-F"),
            getattr_either("u_value_includes_interior_film_coefficient", record),
            getattr_either("u_value_includes_exterior_film_coefficient", record),
            getattr_either("assembly_maximum_f_factor", record),
            getattr_either("assembly_maximum_f_factor_unit", record, "btu/h-ft-F"),
            getattr_either("assembly_maximum_c_factor", record),
            getattr_either("assembly_maximum_c_factor_unit", record, "btu/h-ft2-F"),
            getattr_either("assembly_maximum_solar_heat_gain_coefficient", record),
            getattr_either("assembly_minimum_vt_shgc", record),
            getattr_either("annotation", record),
        )
