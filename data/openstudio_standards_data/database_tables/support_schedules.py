from database_engine.database import DBOperation
from database_engine.database_util import getattr_either, is_float

TABLE_NAME = "support_schedules"

RECORD_HELP = """
Must provide a dict that contains following key value pairs:
name: TEXT
category: TEXT
units: TEXT
day_types: TEXT
start_date: TEXT
end_date: TEXT
type: TEXT
hr_1: NUMERIC
hr_2: NUMERIC
hr_3: NUMERIC
hr_4: NUMERIC
hr_5: NUMERIC
hr_6: NUMERIC
hr_7: NUMERIC
hr_8: NUMERIC
hr_9: NUMERIC
hr_10: NUMERIC
hr_11: NUMERIC
hr_12: NUMERIC
hr_13: NUMERIC
hr_14: NUMERIC
hr_15: NUMERIC
hr_16: NUMERIC
hr_17: NUMERIC
hr_18: NUMERIC
hr_19: NUMERIC
hr_20: NUMERIC
hr_21: NUMERIC
hr_22: NUMERIC
hr_23: NUMERIC
hr_24: NUMERIC
annotation: TEXT
"""

CREATE_SCHEDULES_TABLE = f"""
CREATE TABLE IF NOT EXISTS %s
(id INTEGER PRIMARY KEY,
name TEXT NOT NULL,
category TEXT NOT NULL,
units TEXT,
day_types TEXT NOT NULL,
start_date TEXT NOT NULL,
end_date TEXT NOT NULL,
type TEXT NOT NULL,
hr_1 NUMERIC NOT NULL,
hr_2 NUMERIC NOT NULL,
hr_3 NUMERIC NOT NULL,
hr_4 NUMERIC NOT NULL,
hr_5 NUMERIC NOT NULL,
hr_6 NUMERIC NOT NULL,
hr_7 NUMERIC NOT NULL,
hr_8 NUMERIC NOT NULL,
hr_9 NUMERIC NOT NULL,
hr_10 NUMERIC NOT NULL,
hr_11 NUMERIC NOT NULL,
hr_12 NUMERIC NOT NULL,
hr_13 NUMERIC NOT NULL,
hr_14 NUMERIC NOT NULL,
hr_15 NUMERIC NOT NULL,
hr_16 NUMERIC NOT NULL,
hr_17 NUMERIC NOT NULL,
hr_18 NUMERIC NOT NULL,
hr_19 NUMERIC NOT NULL,
hr_20 NUMERIC NOT NULL,
hr_21 NUMERIC NOT NULL,
hr_22 NUMERIC NOT NULL,
hr_23 NUMERIC NOT NULL,
hr_24 NUMERIC NOT NULL,
annotation TEXT
);
"""

INSERT_SCHEDULE = f"""
    INSERT INTO %s
    (name,
category,
units,
day_types,
start_date,
end_date,
type,
hr_1,
hr_2,
hr_3,
hr_4,
hr_5,
hr_6,
hr_7,
hr_8,
hr_9,
hr_10,
hr_11,
hr_12,
hr_13,
hr_14,
hr_15,
hr_16,
hr_17,
hr_18,
hr_19,
hr_20,
hr_21,
hr_22,
hr_23,
hr_24,
annotation)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
"""


RECORD_TEMPLATE = {
    "name": "",
    "category": "",
    "units": "",
    "day_types": "",
    "start_date": "",
    "end_date": "",
    "type": "",
    "hr_1": 0.0,
    "hr_2": 0.0,
    "hr_3": 0.0,
    "hr_4": 0.0,
    "hr_5": 0.0,
    "hr_6": 0.0,
    "hr_7": 0.0,
    "hr_8": 0.0,
    "hr_9": 0.0,
    "hr_10": 0.0,
    "hr_11": 0.0,
    "hr_12": 0.0,
    "hr_13": 0.0,
    "hr_14": 0.0,
    "hr_15": 0.0,
    "hr_16": 0.0,
    "hr_17": 0.0,
    "hr_18": 0.0,
    "hr_19": 0.0,
    "hr_20": 0.0,
    "hr_21": 0.0,
    "hr_22": 0.0,
    "hr_23": 0.0,
    "hr_24": 0.0,
}


class SupportScheduleTable(DBOperation):
    def __init__(self):
        super(SupportScheduleTable, self).__init__(
            table_name=TABLE_NAME,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=f"database_files/{TABLE_NAME}",
            create_table_query=CREATE_SCHEDULES_TABLE % TABLE_NAME,
            insert_record_query=INSERT_SCHEDULE % TABLE_NAME,
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
            "category",
            "units",
            "day_types",
            "start_date",
            "end_date",
            "type",
        ]

        for f in str_expected:
            if record.get(f):
                assert isinstance(
                    record[f], str
                ), f"{f} requires to be a string, instead got {record[f]}"

        float_expected = [
            "hr_1",
            "hr_2",
            "hr_3",
            "hr_4",
            "hr_5",
            "hr_6",
            "hr_7",
            "hr_8",
            "hr_9",
            "hr_10",
            "hr_11",
            "hr_12",
            "hr_13",
            "hr_14",
            "hr_15",
            "hr_16",
            "hr_17",
            "hr_18",
            "hr_19",
            "hr_20",
            "hr_21",
            "hr_22",
            "hr_23",
            "hr_24",
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

        return (
            getattr_either("name", record),
            getattr_either("category", record),
            getattr_either("units", record),
            getattr_either("day_types", record),
            getattr_either("start_date", record),
            getattr_either("end_date", record),
            getattr_either("type", record),
            getattr_either("hr_1", record),
            getattr_either("hr_2", record),
            getattr_either("hr_3", record),
            getattr_either("hr_4", record),
            getattr_either("hr_5", record),
            getattr_either("hr_6", record),
            getattr_either("hr_7", record),
            getattr_either("hr_8", record),
            getattr_either("hr_9", record),
            getattr_either("hr_10", record),
            getattr_either("hr_11", record),
            getattr_either("hr_12", record),
            getattr_either("hr_13", record),
            getattr_either("hr_14", record),
            getattr_either("hr_15", record),
            getattr_either("hr_16", record),
            getattr_either("hr_17", record),
            getattr_either("hr_18", record),
            getattr_either("hr_19", record),
            getattr_either("hr_20", record),
            getattr_either("hr_21", record),
            getattr_either("hr_22", record),
            getattr_either("hr_23", record),
            getattr_either("hr_24", record),
            getattr_either("annotation", record),
        )
