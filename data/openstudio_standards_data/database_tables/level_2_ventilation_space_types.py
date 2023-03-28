from database_engine.database import DBOperation
from database_engine.database_util import getattr_either

TABLE_NAME = "level_2_ventilation_space_types"

RECORD_HELP = """
Must provide a tuple that contains:
ventilation_space_type_name: TEXT (unique)
level_3_ventilation_definition_table: TEXT
level_3_ventilation_definition_id: id from level_3_ventilation_definition index
"""

VENT_SUBSPACE_TABLE = """
CREATE TABLE IF NOT EXISTS level_2_ventilation_space_types 
(id INTEGER PRIMARY KEY,
ventilation_space_type_name TEXT NOT NULL,
level_3_ventilation_definition_table TEXT NOT NULL,
level_3_ventilation_definition_id INTEGER NOT NULL,
FOREIGN KEY(ventilation_space_type_name) REFERENCES support_ventilation_space_type_name_tags(ventilation_space_type_name)

);
"""

INSERT_VENT_SUBSPACE = f"""
    INSERT INTO {TABLE_NAME}
    (ventilation_space_type_name, level_3_ventilation_definition_table, level_3_ventilation_definition_id)
    VALUES (?, ?, ?);
"""

RECORD_TEMPLATE = {
    "ventilation_space_type_name": "",
    "level_3_ventilation_definition_table": "",
    "level_3_ventilation_definition_id": "",
}


class VentSubspaceTable(DBOperation):
    def __init__(self):
        super(VentSubspaceTable, self).__init__(
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

        record_list = (
            getattr_either("ventilation_space_type_name", record),
            getattr_either("level_3_ventilation_definition_table", record),
            getattr_either("level_3_ventilation_definition_id", record),
        )

        return record_list

    def _get_create_table_query(self):
        return VENT_SUBSPACE_TABLE

    def _get_insert_record_query(self):
        return INSERT_VENT_SUBSPACE
