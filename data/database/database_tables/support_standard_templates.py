import sqlite3

from database_engine.database import DBOperation
from database_engine.database_util import getattr_either

TABLE_NAME = "support_standard_templates"

RECORD_HELP = """
Must provide a tuple that contains:
template,TEXT
lighting_standard,TEXT
ventilation_standard, TEXT
"""

CREATE_support_standard_templates = """
CREATE TABLE IF NOT EXISTS support_standard_templates
(id INTEGER PRIMARY KEY, 
template TEXT NOT NULL UNIQUE, 
lighting_standard TEXT,
lighting_standard_table TEXT,
ventilation_standard TEXT,
ventilation_standard_table TEXT);
"""

INSERT_A_TEMPLATE_RECORD = """
    INSERT INTO support_standard_templates (template, 
lighting_standard, lighting_standard_table, ventilation_standard, ventilation_standard_table) 
VALUES (?, ?, ?, ? , ?);
"""

RECORD_TEMPLATE = {
    "template": "",
    "lighting_standard": "",
    "lighting_standard_table": "",
    "ventilation_standard": "",
    "ventilation_standard_table": "",
}


class StandardTemplateTable(DBOperation):
    def __init__(self):
        super(StandardTemplateTable, self).__init__(
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
            getattr_either("template", record),
            getattr_either("lighting_standard", record),
            getattr_either("lighting_standard_table", record),
            getattr_either("ventilation_standard", record),
            getattr_either("ventilation_standard_table", record),
        )

    def _get_create_table_query(self):
        return CREATE_support_standard_templates

    def _get_insert_record_query(self):
        return INSERT_A_TEMPLATE_RECORD
