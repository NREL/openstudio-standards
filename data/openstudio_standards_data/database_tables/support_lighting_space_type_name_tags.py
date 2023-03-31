from database_engine.database import DBOperation
from database_engine.database_util import getattr_either

TABLE_NAME = "support_lighting_space_type_name_tags"

RECORD_HELP = """
Must provide a dict that contains following key value pairs:
lighting_space_type_name: TEXT
"""

CREATE_LIGHTING_SPACE_TAG = f"""
CREATE TABLE IF NOT EXISTS %s
(
lighting_space_type_name TEXT UNIQUE NOT NULL PRIMARY KEY
);
"""

INSERT_SPACE_TAG = f"""
    INSERT INTO %s
    (lighting_space_type_name)
    VALUES (?);
"""


RECORD_TEMPLATE = {
    "lighting_space_type_name": "",
}


class LightingSpaceTagTable(DBOperation):
    def __init__(self):
        super(LightingSpaceTagTable, self).__init__(
            table_name=TABLE_NAME,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=f"database_files/{TABLE_NAME}",
            create_table_query=CREATE_LIGHTING_SPACE_TAG % TABLE_NAME,
            insert_record_query=INSERT_SPACE_TAG % TABLE_NAME,
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
        return (getattr_either("lighting_space_type_name", record),)
