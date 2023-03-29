from database_engine.database import DBOperation
from database_engine.database_util import getattr_either, is_float

TABLE_NAME = "support_lighting_technologies"

RECORD_HELP = """
Must provide a tuple that contains:
lighting_technology_definition_name: TEXT (unique)
lighting_fraction_to_return_air: NUMERIC
lighting_fraction_radiant: NUMERIC
lighting_fraction_visible: NUMERIC
lighting_fraction_replaceable: NUMERIC
lpd_fraction_linear_fluorescent: NUMERIC
lpd_fraction_compact_fluorescent: NUMERIC
lpd_fraction_high_bay: NUMERIC
lpd_fraction_specialty_lighting: NUMERIC
lpd_fraction_exit_lighting: NUMERIC
compact_fluorescent_lighting_schedule: TEXT
high_bay_lighting_schedule: TEXT
specialty_lighting_schedule: TEXT
exit_lighting_schedule: TEXT
"""

LIGHT_TECHNOLOGIES_TABLE = f"""
CREATE TABLE IF NOT EXISTS %s 
(lighting_technology_definition_name TEXT UNIQUE NOT NULL PRIMARY KEY,
lighting_fraction_to_return_air NUMERIC,
lighting_fraction_radiant NUMERIC,
lighting_fraction_visible NUMERIC,
lighting_fraction_replaceable NUMERIC,
lpd_fraction_linear_fluorescent NUMERIC,
lpd_fraction_compact_fluorescent NUMERIC,
lpd_fraction_high_bay NUMERIC,
lpd_fraction_specialty_lighting NUMERIC,
lpd_fraction_exit_lighting NUMERIC,
compact_fluorescent_lighting_schedule TEXT,
high_bay_lighting_schedule TEXT,
specialty_lighting_schedule TEXT,
exit_lighting_schedule TEXT
);
"""

INSERT_LIGHT_TECHNOLOGY = f"""
    INSERT INTO %s
    (
lighting_technology_definition_name,
lighting_fraction_to_return_air,
lighting_fraction_radiant,
lighting_fraction_visible,
lighting_fraction_replaceable,
lpd_fraction_linear_fluorescent,
lpd_fraction_compact_fluorescent,
lpd_fraction_high_bay,
lpd_fraction_specialty_lighting,
lpd_fraction_exit_lighting,
compact_fluorescent_lighting_schedule,
high_bay_lighting_schedule,
specialty_lighting_schedule,
exit_lighting_schedule
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
"""

RECORD_TEMPLATE = {
    "lighting_technology_definition_name": "",
    "lighting_fraction_to_return_air": 0.0,
    "lighting_fraction_radiant": 0.0,
    "lighting_fraction_visible": 0.0,
    "lighting_fraction_replaceable": 0.0,
    "lpd_fraction_linear_fluorescent": 0.0,
    "lpd_fraction_compact_fluorescent": 0.0,
    "lpd_fraction_high_bay": 0.0,
    "lpd_fraction_specialty_lighting": 0.0,
    "lpd_fraction_exit_lighting": 0.0,
    "linear_fluorescent_lighting_schedule": "",
    "compact_fluorescent_lighting_schedule": "",
    "high_bay_lighting_schedule": "",
    "specialty_lighting_schedule": "",
    "exit_lighting_schedule": "",
}


class SupportLightTechnologiesTable(DBOperation):
    def __init__(self):
        super(SupportLightTechnologiesTable, self).__init__(
            table_name=TABLE_NAME,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=f"database_files/{TABLE_NAME}",
            create_table_query=LIGHT_TECHNOLOGIES_TABLE % TABLE_NAME,
            insert_record_query=INSERT_LIGHT_TECHNOLOGY % TABLE_NAME,
        )

    def get_record_info(self):
        """
        A function to return the record info of the table
        :return:
        """
        return RECORD_HELP

    def validate_record_datatype(self, record):
        str_expected = [
            "lighting_technology_definition_name",
            "compact_fluorescent_lighting_schedule",
            "high_bay_lighting_schedule",
            "specialty_lighting_schedule",
            "specialty_lighting_schedule",
            "exit_lighting_schedule",
        ]

        for f in str_expected:
            if record.get(f):
                assert isinstance(
                    record[f], str
                ), f"{f} requires to be a string, instead got {record[f]}"

        float_expected = [
            "lighting_fraction_to_return_air",
            "lighting_fraction_radiant",
            "lighting_fraction_visible",
            "lighting_fraction_replaceable",
            "lpd_fraction_linear_fluorescent",
            "lpd_fraction_compact_fluorescent",
            "lpd_fraction_high_bay",
            "lpd_fraction_specialty_lighting",
            "lpd_fraction_exit_lighting",
        ]

        for f in float_expected:
            if record.get(f):
                assert is_float(
                    record.get(f)
                ), f"{f} requires to be numeric data type, instead got {record[f]}"

        return True

    def _preprocess_record(self, record):
        """

        :param record: dict
        :return:
        """
        record_list = (
            getattr_either("lighting_technology_definition_name", record),
            getattr_either("lighting_fraction_to_return_air", record),
            getattr_either("lighting_fraction_radiant", record),
            getattr_either("lighting_fraction_visible", record),
            getattr_either("lighting_fraction_replaceable", record),
            getattr_either("lpd_fraction_linear_fluorescent", record),
            getattr_either("lpd_fraction_compact_fluorescent", record),
            getattr_either("lpd_fraction_high_bay", record),
            getattr_either("lpd_fraction_specialty_lighting", record),
            getattr_either("lpd_fraction_exit_lighting", record),
            getattr_either("compact_fluorescent_lighting_schedule", record),
            getattr_either("high_bay_lighting_schedule", record),
            getattr_either("specialty_lighting_schedule", record),
            getattr_either("exit_lighting_schedule", record),
        )

        return record_list
