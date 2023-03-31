from database_engine.database import DBOperation
from database_engine.database_util import is_float, getattr_either

RECORD_HELP = """
Must provide a tuple that contains:
template: TEXT
climate_zone: TEXT
under_8000_hours: TEXT
nontransient_dwelling: TEXT
percent_oa_0_to_10: NUMERIC
percent_oa_10_to_20: NUMERIC
percent_oa_20_to_30: NUMERIC
percent_oa_30_to_40: NUMERIC
percent_oa_40_to_50: NUMERIC
percent_oa_50_to_60: NUMERIC
percent_oa_60_to_70: NUMERIC
percent_oa_70_to_80: NUMERIC
percent_oa_greater_than_80: NUMERIC
enthalpy_recovery_ratio_design_conditions: TEXT
enthalpy_recovery_ratio: NUMERIC
annotation: TEXT (optional)
"""

CREATE_SYSTEM_REQUIREMENT_ENERGY_RECOVERY_TABLE = """
CREATE TABLE IF NOT EXISTS %s
(id INTEGER PRIMARY KEY, 
template TEXT NOT NULL, 
climate_zone TEXT NOT NULL,
under_8000_hours TEXT,
nontransient_dwelling TEXT,
percent_oa_0_to_10 NUMERIC,
percent_oa_10_to_20 NUMERIC,
percent_oa_20_to_30 NUMERIC,
percent_oa_30_to_40 NUMERIC,
percent_oa_40_to_50 NUMERIC,
percent_oa_50_to_60 NUMERIC,
percent_oa_60_to_70 NUMERIC,
percent_oa_70_to_80 NUMERIC,
percent_oa_greater_than_80 NUMERIC,
enthalpy_recovery_ratio_design_conditions TEXT,
enthalpy_recovery_ratio NUMERIC,
annotation TEXT);
"""

INSERT_A_SYSTEM_REQUIREMENT_ENERGY_RECOVERY_RECORD = """
    INSERT INTO %s (
template, 
climate_zone,
under_8000_hours,
nontransient_dwelling,
percent_oa_0_to_10,
percent_oa_10_to_20,
percent_oa_20_to_30,
percent_oa_30_to_40,
percent_oa_40_to_50,
percent_oa_50_to_60,
percent_oa_60_to_70,
percent_oa_70_to_80,
percent_oa_greater_than_80,
enthalpy_recovery_ratio_design_conditions,
enthalpy_recovery_ratio,
annotation
) 
VALUES (?, ?, ?, ? , ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
"""

RECORD_TEMPLATE = {
    "template": "",
    "climate_zone": "",
    "under_8000_hours": "",
    "nontransient_dwelling": "",
    "percent_oa_0_to_10": 0.0,
    "percent_oa_10_to_20": 0.0,
    "percent_oa_20_to_30": 0.0,
    "percent_oa_30_to_40": 0.0,
    "percent_oa_40_to_50": 0.0,
    "percent_oa_50_to_60": 0.0,
    "percent_oa_60_to_70": 0.0,
    "percent_oa_70_to_80": 0.0,
    "percent_oa_greater_than_80": 0.0,
    "enthalpy_recovery_ratio_design_conditions": "",
    "enthalpy_recovery_ratio": 0.0,
    "annotation": "",
}


class SystemRequirementEnergyRecovery(DBOperation):
    def __init__(self, table_name, initial_data_directory):
        super(SystemRequirementEnergyRecovery, self).__init__(
            table_name=table_name,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=initial_data_directory,
            create_table_query=CREATE_SYSTEM_REQUIREMENT_ENERGY_RECOVERY_TABLE
            % table_name,
            insert_record_query=INSERT_A_SYSTEM_REQUIREMENT_ENERGY_RECOVERY_RECORD
            % table_name,
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
            "climate_zone",
            "under_8000_hours",
            "nontransient_dwelling",
            "enthalpy_recovery_ratio_design_conditions",
        ]

        for f in str_expected:
            if record.get(f):
                assert isinstance(
                    record[f], str
                ), f"{f} requires to be a string, instead got {record[f]}"

        float_expected = [
            "percent_oa_0_to_10",
            "percent_oa_10_to_20",
            "percent_oa_20_to_30",
            "percent_oa_30_to_40",
            "percent_oa_40_to_50",
            "percent_oa_50_to_60",
            "percent_oa_60_to_70",
            "percent_oa_70_to_80",
            "percent_oa_greater_than_80",
            "enthalpy_recovery_ratio",
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
            getattr_either("template", record),
            getattr_either("climate_zone", record),
            getattr_either("under_8000_hours", record),
            getattr_either("nontransient_dwelling", record),
            getattr_either("percent_oa_0_to_10", record),
            getattr_either("percent_oa_10_to_20", record),
            getattr_either("percent_oa_20_to_30", record),
            getattr_either("percent_oa_30_to_40", record),
            getattr_either("percent_oa_40_to_50", record),
            getattr_either("percent_oa_50_to_60", record),
            getattr_either("percent_oa_60_to_70", record),
            getattr_either("percent_oa_70_to_80", record),
            getattr_either("percent_oa_greater_than_80", record),
            getattr_either("enthalpy_recovery_ratio_design_conditions", record),
            getattr_either("enthalpy_recovery_ratio", record),
            getattr_either("annotation", record),
        )
