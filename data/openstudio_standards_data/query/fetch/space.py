"""
This module contains a number of functions to fetch building data
building data includes:
lighting, ventilation (and more...)
"""
import sqlite3
from query.util import _convert_list_tuple_to_list_dict

SPACE_DATA_HEADER = [
    "space_type_name",
    "LS.lighting_space_type_name",
    "VS.ventilation_space_type_name",
    "level_3_lighting_code_definition_table",
    "level_3_lighting_code_definition_id",
    "level_3_ventilation_definition_table",
    "level_3_ventilation_definition_id",
    "ES.electric_equipment_space_type_name",
    "EGS.natural_gas_equipment_space_type_name",
    "schedule_set_name",
]


SPACE_JOIN_QUERY = f"""
SELECT {','.join(SPACE_DATA_HEADER)}
    FROM level_1_space_types as BS
        LEFT JOIN level_2_lighting_space_types as LS
            ON BS.lighting_space_type_name = LS.lighting_space_type_name
        LEFT JOIN level_2_ventilation_space_types as VS
            ON BS.ventilation_space_type_name = VS.ventilation_space_type_name
        LEFT JOIN level_2_electric_equipment as ES
            ON BS.electric_equipment_space_type_name = ES.electric_equipment_space_type_name
        LEFT JOIN level_2_natural_gas_equipment as EGS
            ON BS.natural_gas_equipment_space_type_name = EGS.natural_gas_equipment_space_type_name
"""


def fetch_space_data(connection: sqlite3.Connection):
    """
    Fetch building data table
    :param connection:
    :return:
    """

    return _convert_list_tuple_to_list_dict(
        connection.execute(SPACE_JOIN_QUERY).fetchall(), SPACE_DATA_HEADER
    )
