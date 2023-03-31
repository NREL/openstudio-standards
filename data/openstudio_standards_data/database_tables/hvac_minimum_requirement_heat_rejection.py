from database_engine.database import DBOperation
from database_engine.database_util import is_float, getattr_either

RECORD_HELP = """
Must provide a tuple that contains:
template: TEXT
equipment_type: TEXT
fan_type: TEXT
start_date: TEXT
end_date: TEXT
minimum_performance_gpm_per_hp: NUMERIC
annotation: TEXT (optional)
"""

CREATE_HVAC_REQUIREMENT_HEAT_REJECTION_TABLE = """
CREATE TABLE IF NOT EXISTS %s
(id INTEGER PRIMARY KEY, 
template TEXT NOT NULL, 
equipment_type TEXT NOT NULL,
fan_type TEXT NOT NULL,
start_date TEXT NOT NULL,
end_date TEXT NOT NULL,
minimum_performance_gpm_per_hp NUMERIC NOT NULL,
annotation TEXT);
"""

INSERT_A_HEAT_REJECTION_RECORD = """
    INSERT INTO %s (
template, 
equipment_type,
fan_type,
start_date,
end_date,
minimum_performance_gpm_per_hp,
annotation
) 
VALUES (?, ?, ?, ? ,? , ?, ?);
"""

RECORD_TEMPLATE = {
    "template": "",
    "equipment_type": "",
    "fan_type": "",
    "start_date": "",
    "end_date": "",
    "minimum_performance_gpm_per_hp": 0.0,
    "annotation": "",
}


class HVACMinimumRequirementHeatRejection(DBOperation):
    def __init__(self, table_name, initial_data_directory):
        super(HVACMinimumRequirementHeatRejection, self).__init__(
            table_name=table_name,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=initial_data_directory,
            create_table_query=CREATE_HVAC_REQUIREMENT_HEAT_REJECTION_TABLE
            % table_name,
            insert_record_query=INSERT_A_HEAT_REJECTION_RECORD % table_name,
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
            "equipment_type",
            "start_date",
            "end_date",
            "fan_type",
        ]

        for f in str_expected:
            if record.get(f):
                assert isinstance(
                    record[f], str
                ), f"{f} requires to be a string, instead got {record[f]}"

        if record.get("minimum_performance_gpm_per_hp"):
            assert is_float(
                record.get("minimum_performance_gpm_per_hp")
            ), f"minimum_performance_gpm_per_hp requires to be numeric data type, instead got {record['minimum_performance_gpm_per_hp']}"
        return True

    def _preprocess_record(self, record):
        """

        :param record: dict
        :return:
        """

        return (
            getattr_either("template", record),
            getattr_either("equipment_type", record),
            getattr_either("fan_type", record),
            getattr_either("start_date", record),
            getattr_either("end_date", record),
            getattr_either("minimum_performance_gpm_per_hp", record),
            getattr_either("annotation", record),
        )
