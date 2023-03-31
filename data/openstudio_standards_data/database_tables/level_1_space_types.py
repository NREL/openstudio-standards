from database_engine.database import DBOperation
from database_engine.database_util import getattr_either

TABLE_NAME = "level_1_space_types"

RECORD_HELP = """
Must provide a dict that contains following key value pairs:
space_type_name: TEXT
lighting_space_type_name: TEXT
ventilation_space_type_name: TEXT
electric_equipment_space_type_name: TEXT
natural_gas_equipment_space_type_name: TEXT
schedule_set_name: TEXT
annotation: TEXT
"""

CREATE_LEVEL_1_SPACE_TYPES = f"""
CREATE TABLE IF NOT EXISTS %s
(id INTEGER PRIMARY KEY, 
space_type_name TEXT NOT NULL,
lighting_space_type_name TEXT,
ventilation_space_type_name TEXT,
electric_equipment_space_type_name TEXT,
natural_gas_equipment_space_type_name TEXT,
schedule_set_name TEXT,
annotation TEXT,
FOREIGN KEY(lighting_space_type_name) REFERENCES support_lighting_space_type_name_tags(lighting_space_type_name)
FOREIGN KEY(ventilation_space_type_name) REFERENCES support_ventilation_space_type_name_tags(ventilation_space_type_name)
FOREIGN KEY(electric_equipment_space_type_name) REFERENCES support_electric_equipment_space_type_name_tags(support_electric_equipment_space_type_name_tags)
);
"""

INSERT_LEVEL_1_SPACE_TYPES = f"""
    INSERT INTO %s
    (
        space_type_name,
        lighting_space_type_name,
        ventilation_space_type_name,
        electric_equipment_space_type_name,
        natural_gas_equipment_space_type_name,
        schedule_set_name,
        annotation
    )
    VALUES (?, ?, ?, ?, ?, ?, ?);
"""


RECORD_TEMPLATE = {
    "space_type_name": "",
    "lighting_space_type_name": "",
    "ventilation_space_type_name": "",
    "electric_equipment_space_type_name": "",
    "natural_gas_equipment_space_type_name": "",
    "schedule_set_name": "",
    "annotation": "",
}


class GeneralBuildingSpaceTypeTable(DBOperation):
    def __init__(self):
        super(GeneralBuildingSpaceTypeTable, self).__init__(
            table_name=TABLE_NAME,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=f"database_files/{TABLE_NAME}",
            create_table_query=CREATE_LEVEL_1_SPACE_TYPES % TABLE_NAME,
            insert_record_query=INSERT_LEVEL_1_SPACE_TYPES % TABLE_NAME,
        )

    def get_record_info(self):
        """
        A function to return the record info of the table
        :return:
        """
        return RECORD_HELP

    def _get_weak_foreign_key_value(self, record):
        associate_table = getattr_either("support_schedules", record)
        key = "name"
        value = getattr_either("schedule_set_name", record)
        return associate_table, key, value

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
            getattr_either("natural_gas_equipment_space_type_name", record),
            getattr_either("schedule_set_name", record),
            getattr_either("annotation", record),
        )
