from database_engine.database import DBOperation
from database_engine.database_util import is_float, getattr_either

RECORD_HELP = """
Must provide a tuple that contains:
template: TEXT
cooling_type: TEXT
subcategory: TEXT
minimum_capacity: NUMERIC
maximum_capacity: NUMERIC
start_date: TEXT
end_date: TEXT
minimum_heating_seasonal_performance_factor: NUMERIC
minimum_coefficient_of_performance_heating: NUMERIC
minimum_energy_efficiency_ratio: NUMERIC
pthp_cop_coefficient_1: NUMERIC
pthp_cop_coefficient_2: NUMERIC
heat_cap_ft: TEXT
heat_cap_fflow: TEXT
heat_eir_ft: TEXT
heat_eir_fflow: TEXT
heat_plf_fplr: TEXT
annotation: TEXT (optional)
"""

CREATE_HVAC_REQUIREMENT_HEAT_PUMP_HEATING_TABLE = """
CREATE TABLE IF NOT EXISTS %s
(id INTEGER PRIMARY KEY, 
template TEXT NOT NULL, 
cooling_type TEXT NOT NULL,
subcategory TEXT NOT NULL,
minimum_capacity NUMERIC,
maximum_capacity NUMERIC,
start_date TEXT,
end_date TEXT,
minimum_heating_seasonal_performance_factor NUMERIC,
minimum_coefficient_of_performance_heating NUMERIC,
minimum_energy_efficiency_ratio NUMERIC,
pthp_cop_coefficient_1 NUMERIC,
pthp_cop_coefficient_2 NUMERIC,
heat_cap_ft TEXT,
heat_cap_fflow TEXT,
heat_eir_ft TEXT,
heat_eir_fflow TEXT,
heat_plf_fplr TEXT,
annotation TEXT);
"""

INSERT_A_HEAT_PUMP_HEATING_RECORD = """
    INSERT INTO %s (
template, 
cooling_type,
subcategory,
minimum_capacity,
maximum_capacity,
start_date,
end_date,
minimum_heating_seasonal_performance_factor,
minimum_coefficient_of_performance_heating,
minimum_energy_efficiency_ratio,
pthp_cop_coefficient_1,
pthp_cop_coefficient_2,
heat_cap_ft,
heat_cap_fflow,
heat_eir_ft,
heat_eir_fflow,
heat_plf_fplr,
annotation
) 
VALUES (?, ?, ?, ? ,? , ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
"""

RECORD_TEMPLATE = {
    "template": "",
    "cooling_type": "",
    "subcategory": "",
    "minimum_capacity": 0.0,
    "maximum_capacity": 0.0,
    "start_date": "",
    "end_date": "",
    "minimum_heating_seasonal_performance_factor": 0.0,
    "minimum_coefficient_of_performance_heating": 0.0,
    "minimum_energy_efficiency_ratio": 0.0,
    "pthp_cop_coefficient_1": 0.0,
    "pthp_cop_coefficient_2": 0.0,
    "heat_cap_ft": "",
    "heat_cap_fflow": "",
    "heat_eir_ft": "",
    "heat_eir_fflow": "",
    "heat_plf_fplr": "",
    "annotation": "",
}


class HVACMinimumRequirementHeatPumpHeating(DBOperation):
    def __init__(self, table_name, initial_data_directory):
        super(HVACMinimumRequirementHeatPumpHeating, self).__init__(
            table_name=table_name,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=initial_data_directory,
            create_table_query=CREATE_HVAC_REQUIREMENT_HEAT_PUMP_HEATING_TABLE
            % table_name,
            insert_record_query=INSERT_A_HEAT_PUMP_HEATING_RECORD % table_name,
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
            "cooling_type",
            "subcategory",
            "start_date",
            "end_date",
            "heat_cap_ft",
            "heat_cap_fflow",
            "heat_eir_ft",
            "heat_eir_fflow",
            "heat_plf_fplr",
        ]

        for f in str_expected:
            if record.get(f):
                assert isinstance(
                    record[f], str
                ), f"{f} requires to be a string, instead got {record[f]}"

        float_expected = [
            "minimum_capacity",
            "maximum_capacity",
            "minimum_heating_seasonal_performance_factor",
            "minimum_coefficient_of_performance_heating",
            "minimum_energy_efficiency_ratio",
            "pthp_cop_coefficient_1",
            "pthp_cop_coefficient_2",
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
            getattr_either("cooling_type", record),
            getattr_either("subcategory", record),
            getattr_either("minimum_capacity", record),
            getattr_either("maximum_capacity", record),
            getattr_either("start_date", record),
            getattr_either("end_date", record),
            getattr_either("minimum_heating_seasonal_performance_factor", record),
            getattr_either("minimum_coefficient_of_performance_heating", record),
            getattr_either("minimum_energy_efficiency_ratio", record),
            getattr_either("pthp_cop_coefficient_1", record),
            getattr_either("pthp_cop_coefficient_2", record),
            getattr_either("heat_cap_ft", record),
            getattr_either("heat_cap_fflow", record),
            getattr_either("heat_eir_ft", record),
            getattr_either("heat_eir_fflow", record),
            getattr_either("heat_plf_fplr", record),
            getattr_either("annotation", record),
        )
