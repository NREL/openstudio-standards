from database_engine.database import DBOperation
from database_engine.database_util import is_float, getattr_either

TABLE_NAME = "support_performance_curves"

RECORD_HELP = """
Must provide a dict that contains following key value pairs:
ventilation_space_type_name: TEXT
name: TEXT
category: TEXT
form: TEXT
dependent_variable: TEXT
independent_variable_1: TEXT
independent_variable_2: TEXT
coeff_1: NUMERIC
coeff_2: NUMERIC
coeff_3: NUMERIC
coeff_4: NUMERIC
coeff_5: NUMERIC
coeff_6: NUMERIC
coeff_7: NUMERIC
coeff_8: NUMERIC
coeff_9: NUMERIC
coeff_10: NUMERIC
minimum_independent_variable_1: NUMERIC
maximum_independent_variable_1: NUMERIC
minimum_independent_variable_2: NUMERIC
maximum_independent_variable_2: NUMERIC
minimum_dependent_variable_output: NUMERIC
maximum_dependent_variable_output: NUMERIC
annotation: TEXT
"""

CREATE_PERFORMANCE_CURVES_TABLE = f"""
CREATE TABLE IF NOT EXISTS %s
(
id INTEGER PRIMARY KEY, 
name TEXT NOT NULL,
category TEXT,
form TEXT NOT NULL,
dependent_variable TEXT,
independent_variable_1 TEXT,
independent_variable_2 TEXT,
coeff_1 NUMERIC,
coeff_2 NUMERIC,
coeff_3 NUMERIC,
coeff_4 NUMERIC,
coeff_5 NUMERIC,
coeff_6 NUMERIC,
coeff_7 NUMERIC,
coeff_8 NUMERIC,
coeff_9 NUMERIC,
coeff_10 NUMERIC,
minimum_independent_variable_1 NUMERIC,
maximum_independent_variable_1 NUMERIC,
minimum_independent_variable_2 NUMERIC,
maximum_independent_variable_2 NUMERIC,
minimum_dependent_variable_output NUMERIC,
maximum_dependent_variable_output NUMERIC,
annotation TEXT
);
"""

INSERT_PERFORMANCE_CURVE = f"""
    INSERT INTO %s
    (
name,
category,
form,
dependent_variable,
independent_variable_1,
independent_variable_2,
coeff_1,
coeff_2,
coeff_3,
coeff_4,
coeff_5,
coeff_6,
coeff_7,
coeff_8,
coeff_9,
coeff_10,
minimum_independent_variable_1,
maximum_independent_variable_1,
minimum_independent_variable_2,
maximum_independent_variable_2,
minimum_dependent_variable_output,
maximum_dependent_variable_output,
annotation)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
"""


RECORD_TEMPLATE = {
    "name": "",
    "category": "",
    "form": "",
    "dependent_variable": "",
    "independent_variable_1": "",
    "independent_variable_2": "",
    "coeff_1": 0.0,
    "coeff_2": 0.0,
    "coeff_3": 0.0,
    "coeff_4": 0.0,
    "coeff_5": 0.0,
    "coeff_6": 0.0,
    "coeff_7": 0.0,
    "coeff_8": 0.0,
    "coeff_9": 0.0,
    "coeff_10": 0.0,
    "minimum_independent_variable_1": 0.0,
    "maximum_independent_variable_1": 0.0,
    "minimum_independent_variable_2": 0.0,
    "maximum_independent_variable_2": 0.0,
    "minimum_dependent_variable_output": 0.0,
    "maximum_dependent_variable_output": 0.0,
    "annotation": "",
}


class VentSpaceTagTable(DBOperation):
    def __init__(self):
        super(VentSpaceTagTable, self).__init__(
            table_name=TABLE_NAME,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=f"database_files/{TABLE_NAME}",
            create_table_query=CREATE_PERFORMANCE_CURVES_TABLE % TABLE_NAME,
            insert_record_query=INSERT_PERFORMANCE_CURVE % TABLE_NAME,
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
            "form",
            "dependent_variable",
            "independent_variable_1",
            "independent_variable_2",
        ]

        for f in str_expected:
            if record.get(f):
                assert isinstance(
                    record[f], str
                ), f"{f} requires to be a string, instead got {record[f]}"

        float_expected = [
            "minimum_independent_variable_1",
            "minimum_independent_variable_2",
            "maximum_independent_variable_1",
            "maximum_independent_variable_2",
            "minimum_dependent_variable_output",
            "maximum_dependent_variable_output",
        ]

        for f in float_expected:
            if record.get(f):
                assert is_float(
                    record.get(f)
                ), f"{f} requires to be numeric data type, instead got {record[f]}"

        for i in range(10):
            if record.get(f"coeff_{i+1}"):
                coeff = f"coeff_{i+1}"
                record_id = record[f"{coeff}"]
                assert is_float(
                    record.get(coeff)
                ), f"{coeff} requires to be numeric data type, instead got {record_id}"
        return True

    def _preprocess_record(self, record):
        """

        :param record: dict
        :return:
        """

        return (
            getattr_either("name", record),
            getattr_either("category", record),
            getattr_either("form", record),
            getattr_either("dependent_variable", record),
            getattr_either("independent_variable_1", record),
            getattr_either("independent_variable_2", record),
            getattr_either("coeff_1", record),
            getattr_either("coeff_2", record),
            getattr_either("coeff_3", record),
            getattr_either("coeff_4", record),
            getattr_either("coeff_5", record),
            getattr_either("coeff_6", record),
            getattr_either("coeff_7", record),
            getattr_either("coeff_8", record),
            getattr_either("coeff_9", record),
            getattr_either("coeff_10", record),
            getattr_either("minimum_independent_variable_1", record),
            getattr_either("maximum_independent_variable_1", record),
            getattr_either("minimum_independent_variable_2", record),
            getattr_either("maximum_independent_variable_2", record),
            getattr_either("minimum_dependent_variable_output", record),
            getattr_either("maximum_dependent_variable_output", record),
            getattr_either("annotation", record),
        )
