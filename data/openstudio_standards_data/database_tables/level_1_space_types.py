from database_engine.database import DBOperation
from database_engine.database_util import getattr_either

TABLE_NAME = "level_1_space_types"

RECORD_HELP = """
Must provide a dict that contains following key value pairs:
space_type_name: TEXT
lighting_space_type_name: TEXT
ventilation_space_type_name: TEXT
electric_equipment_space_type_name: TEXT
"""

CREATE_level_1_space_types = f"""
CREATE TABLE IF NOT EXISTS {TABLE_NAME}
(id INTEGER PRIMARY KEY, 
space_type_name TEXT NOT NULL,
lighting_space_type_name TEXT,
ventilation_space_type_name TEXT,
electric_equipment_space_type_name TEXT,
FOREIGN KEY(lighting_space_type_name) REFERENCES support_lighting_space_type_name_tags(lighting_space_type_name)
FOREIGN KEY(ventilation_space_type_name) REFERENCES support_ventilation_space_type_name_tags(ventilation_space_type_name)
FOREIGN KEY(electric_equipment_space_type_name) REFERENCES support_electric_equipment_space_type_name_tags(support_electric_equipment_space_type_name_tags)
);
"""

INSERT_level_1_space_types = f"""
    INSERT INTO {TABLE_NAME}
    (space_type_name, lighting_space_type_name, ventilation_space_type_name, electric_equipment_space_type_name)
    VALUES (?, ?, ?, ?);
"""


RECORD_TEMPLATE = {
    "space_type_name": "",
    "lighting_space_type_name": "",
    "ventilation_space_type_name": "",
    "electric_equipment_space_type_name": "",
}


class GeneralBuildingSpaceTypeTable(DBOperation):
    def __init__(self):
        super(GeneralBuildingSpaceTypeTable, self).__init__(
            table_name=TABLE_NAME,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=f"database_files/{TABLE_NAME}",
        )

    def get_record_info(self):
        """
        A function to return the record info of the table
        :return:
        """
        return RECORD_HELP

    def _preprocess_record(self, record):
        """

        :param record: dict
        :return:
        """
        assert bool(record.get("space_type_name")), "Missing space type"

        return (
            getattr_either("space_type_name", record),
            getattr_either("lighting_space_type_name", record),
            getattr_either("ventilation_space_type_name", record),
            getattr_either("electric_equipment_space_type_name", record),
        )

    def _get_create_table_query(self):
        return CREATE_level_1_space_types

    def _get_insert_record_query(self):
        return INSERT_level_1_space_types
