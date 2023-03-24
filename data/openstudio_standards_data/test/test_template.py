import sqlite3, os

from query.fetch.template import fetch_templates, fetch_template_data_by_template
from applications.database_maintenance import (
    create_openstudio_standards_database_from_csv,
)

db_name = "openstudio_standards_data"


def test_get_template_data__true():
    connection = sqlite3.connect(f"{db_name}.db")
    assert fetch_templates(connection)[0] == {
        "template": "90.1-2019",
        "lighting_standard": "ASHRAE 90.1-2019",
        "lighting_standard_table": "level_3_lighting_90_1_2019",
        "ventilation_standard": "ASHRAE 62.1-2019",
        "ventilation_standard_table": "level_3_ventilation_90_1_2019",
    }


def test_get_template_data_by_template__true():
    template = "90.1-2019"
    connection = sqlite3.connect(f"{db_name}.db")
    assert fetch_template_data_by_template(connection, template) == [
        {
            "template": "90.1-2019",
            "lighting_standard": "ASHRAE 90.1-2019",
            "lighting_standard_table": "level_3_lighting_90_1_2019",
            "ventilation_standard": "ASHRAE 62.1-2019",
            "ventilation_standard_table": "level_3_ventilation_90_1_2019",
        }
    ]
