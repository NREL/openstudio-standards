from database_engine.database import DBOperation
from database_engine.database_util import getattr_either

TABLE_NAME = "level_2_lighting_space_types"

RECORD_HELP = """
Must provide a tuple that contains:
lighting_space_type_name: TEXT (unique)
level_3_lighting_definition_table: TEXT
level_3_lighting_definition_id: id from level_3_lighting_definition index
"""

CREATE_LIGHT_SUBSPACE_TABLE = """
CREATE TABLE IF NOT EXISTS %s 
(id INTEGER PRIMARY KEY,
lighting_space_type_name TEXT NOT NULL,
level_3_lighting_definition_table TEXT NOT NULL,
level_3_lighting_definition_id INTEGER NOT NULL,
FOREIGN KEY(lighting_space_type_name) REFERENCES support_lighting_space_type_name_tags(lighting_space_type_name)
);
"""

INSERT_LIGHT_SUBSPACE = f"""
    INSERT INTO %s
    (lighting_space_type_name, level_3_lighting_definition_table, level_3_lighting_definition_id)
    VALUES (?, ?, ?);
"""

RECORD_TEMPLATE = {
    "lighting_space_type_name": "",
    "level_3_lighting_definition_table": "",
    "level_3_lighting_definition_id": "",
}


class LightSubspaceTable(DBOperation):
    def __init__(self):
        super(LightSubspaceTable, self).__init__(
            table_name=TABLE_NAME,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=f"database_files/{TABLE_NAME}",
            create_table_query=CREATE_LIGHT_SUBSPACE_TABLE % TABLE_NAME,
            insert_record_query=INSERT_LIGHT_SUBSPACE % TABLE_NAME,
        )

    def get_record_info(self):
        """
        A function to return the record info of the table
        :return:
        """
        return RECORD_HELP

    def _get_weak_foreign_key_value(self, record):
        associate_table = (getattr_either("level_3_lighting_definition_table", record),)
        key = "id"
        value = (getattr_either("level_3_lighting_definition_id", record),)
        return associate_table, key, value

    def _preprocess_record(self, record):
        """

        :param record: dict
        :return:
        """
        record_list = (
            getattr_either("lighting_space_type_name", record),
            getattr_either("level_3_lighting_definition_table", record),
            getattr_either("level_3_lighting_definition_id", record),
        )

        return record_list
