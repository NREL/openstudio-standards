from database_engine.database import DBOperation
from database_engine.database_util import getattr_either

TABLE_NAME = "support_constructions"

RECORD_HELP = """
Must provide a dict that contains following key value pairs:
name: TEXT
intended_surface_type: TEXT
standards_construction_type: TEXT
insulation_layer: TEXT
skylight_framing: TEXT
material_1: TEXT
material_2: TEXT
material_3: TEXT
material_4: TEXT
material_5: TEXT
material_6: TEXT
"""

CREATE_CONSTRUCTIONS_TABLE = f"""
CREATE TABLE IF NOT EXISTS %s
(name TEXT UNIQUE NOT NULL PRIMARY KEY,
intended_surface_type TEXT,
standards_construction_type TEXT,
insulation_layer TEXT,
skylight_framing TEXT,
material_1 TEXT,
material_2 TEXT,
material_3 TEXT,
material_4 TEXT,
material_5 TEXT,
material_6 TEXT,
FOREIGN KEY(material_1) REFERENCES support_materials(name)
FOREIGN KEY(material_2) REFERENCES support_materials(name)
FOREIGN KEY(material_3) REFERENCES support_materials(name)
FOREIGN KEY(material_4) REFERENCES support_materials(name)
FOREIGN KEY(material_5) REFERENCES support_materials(name)
FOREIGN KEY(material_6) REFERENCES support_materials(name)
);
"""

INSERT_CONSTRUCTION = f"""
    INSERT INTO %s
    (name,
intended_surface_type,
standards_construction_type,
insulation_layer,
skylight_framing,
material_1,
material_2,
material_3,
material_4,
material_5,
material_6)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
"""


RECORD_TEMPLATE = {
    "name": "",
    "intended_surface_type": "",
    "standards_construction_type": "",
    "insulation_layer": "",
    "skylight_framing": "",
    "material_1": "",
    "material_2": "",
    "material_3": "",
    "material_4": "",
    "material_5": "",
    "material_6": "",
}


class SupportConstructionsTable(DBOperation):
    def __init__(self):
        super(SupportConstructionsTable, self).__init__(
            table_name=TABLE_NAME,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=f"database_files/{TABLE_NAME}",
            create_table_query=CREATE_CONSTRUCTIONS_TABLE % TABLE_NAME,
            insert_record_query=INSERT_CONSTRUCTION % TABLE_NAME,
        )

    def get_record_info(self):
        """
        A function to return the record info of the table
        :return:
        """
        return RECORD_HELP

    def validate_record_datatype(self, record):
        str_expected = [
            "name",
            "intended_surface_type",
            "standards_construction_type",
            "insulation_layer",
            "skylight_framing",
            "material_1",
            "material_2",
            "material_3",
            "material_4",
            "material_5",
            "material_6",
        ]

        for f in str_expected:
            if record.get(f):
                assert isinstance(
                    record[f], str
                ), f"{f} requires to be a string, instead got {record[f]}"
        return True

    def _preprocess_record(self, record):
        """

        :param record: dict
        :return:
        """

        return (
            getattr_either("name", record),
            getattr_either("intended_surface_type", record),
            getattr_either("standards_construction_type", record),
            getattr_either("insulation_layer", record),
            getattr_either("skylight_framing", record),
            getattr_either("material_1", record),
            getattr_either("material_2", record),
            getattr_either("material_3", record),
            getattr_either("material_4", record),
            getattr_either("material_5", record),
            getattr_either("material_6", record),
        )
