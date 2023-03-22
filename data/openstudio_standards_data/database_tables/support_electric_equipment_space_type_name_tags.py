from database_engine.database import DBOperation
from database_engine.database_util import getattr_either

TABLE_NAME = "support_electric_equipment_space_type_name_tags"

RECORD_HELP = """
Must provide a dict that contains following key value pairs:
support_electric_equipment_space_type_name_tags: TEXT
"""

CREATE_support_electric_equipment_space_type_name_tags = f"""
CREATE TABLE IF NOT EXISTS {TABLE_NAME}
(
support_electric_equipment_space_type_name_tags TEXT UNIQUE NOT NULL PRIMARY KEY
);
"""

INSERT_SPACE_TAG = f"""
    INSERT INTO {TABLE_NAME}
    (support_electric_equipment_space_type_name_tags)
    VALUES (?);
"""


RECORD_TEMPLATE = {
    "support_electric_equipment_space_type_name_tags": "",
}


class PlugLoadSpaceTagTable(DBOperation):
    def __init__(self):
        super(PlugLoadSpaceTagTable, self).__init__(
            table_name=TABLE_NAME,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=f"initial_data/{TABLE_NAME}",
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
        return (
            getattr_either("support_electric_equipment_space_type_name_tags", record),
        )

    def _get_create_table_query(self):
        return CREATE_support_electric_equipment_space_type_name_tags

    def _get_insert_record_query(self):
        return INSERT_SPACE_TAG
