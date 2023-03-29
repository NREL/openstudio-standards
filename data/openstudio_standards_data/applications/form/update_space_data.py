import sqlite3

from database_engine.assertions import getattr_
from database_tables.level_2_electric_equipment import EquipLoadTable
from query.fetch.database_table import fetch_records_from_table_by_key_values
from query.fetch.template import fetch_template_data_by_template_first
from database_tables.level_1_space_types import (
    TABLE_NAME as GENERAL_SPACE_TYPE_TABLE_NAME,
)
from database_tables.level_2_lighting_space_types import (
    TABLE_NAME as LIGHT_SUBSPACES_TABLE_NAME,
)
from database_tables.level_2_ventilation_space_types import (
    TABLE_NAME as VENT_SUBSPACES_TABLE_NAME,
)
from query.update.update_a_table import update_a_table
import database_tables as tables
from query.util import match_dict_data_by_key

SPACE_TABLE_HEADER = [
    "space_type",
    "level_3_lighting_code_definition_id",
    "level_3_ventilation_defintion_id",
]

FETCH_SPACE_TO_TABLE_QUEYR = f"""
SELECT {','.join(SPACE_TABLE_HEADER)} FROM {GENERAL_SPACE_TYPE_TABLE_NAME}
    LEFT JOIN {LIGHT_SUBSPACES_TABLE_NAME} ON {GENERAL_SPACE_TYPE_TABLE_NAME}.lighting_space_type_name = {LIGHT_SUBSPACES_TABLE_NAME}.lighting_space_type_name
    LEFT JOIN {VENT_SUBSPACES_TABLE_NAME} ON {GENERAL_SPACE_TYPE_TABLE_NAME}.ventilation_space_type_name = {VENT_SUBSPACES_TABLE_NAME}.ventilation_space_type_name
    WHERE space_type = '%s' AND level_3_lighting_code_definition_table = '%s' AND level_3_ventilation_definition_table = '%s'
"""


def update_openstudio_standards_space_data(
    conn: sqlite3.Connection, json_data: list[dict]
):
    """
    update existing openstudio_standards space_data
    :param conn:
    :param json_data:
    :return:
    """
    for space_data in json_data:
        template = getattr_(space_data, "space", "template")
        space_type = getattr_(space_data, "space", "space_type")

        # mandatory
        lighting_primary_space_type = getattr_(
            space_data, "space", "lighting_primary_space_type"
        )
        lighting_secondary_space_type = getattr_(
            space_data, "space", "lighting_secondary_space_type"
        )
        ventilation_primary_space_type = getattr_(
            space_data, "space", "ventilation_primary_space_type"
        )
        ventilation_secondary_space_type = getattr_(
            space_data, "space", "ventilation_secondary_space_type"
        )

        # Step 1, we need to get the template table and loop in the table
        standard_template = fetch_template_data_by_template_first(conn, template)
        lighting_standard_table = standard_template["lighting_standard_table"]
        ventilation_standard_table = standard_template["ventilation_standard_table"]

        fetch_query = FETCH_SPACE_TO_TABLE_QUEYR % (
            space_type,
            lighting_standard_table,
            ventilation_standard_table,
        )
        cur = conn.cursor()
        cur.execute(fetch_query)

        assert (
            cur.arraysize > 0
        ), f"Cannot find data match the criteria of space_type='{space_type}', lighting_standard_table='{lighting_standard_table}', ventilation_standard_table='{ventilation_standard_table}'"

        # loop through the rows in table
        for row in cur:
            level_3_lighting_code_definition_id = row[
                SPACE_TABLE_HEADER.index("level_3_lighting_code_definition_id")
            ]
            level_3_ventilation_definition_id = row[
                SPACE_TABLE_HEADER.index("level_3_ventilation_definition_id")
            ]

            # update lighting
            light_tables = tables.__get_light_tables__()
            # Find the matching data table and initialize it.
            light_table = next(
                filter(
                    lambda t: t[1]().data_table_name == lighting_standard_table,
                    light_tables,
                )
            )[1]()
            light_table.validate_record_datatype(space_data)

            lighting_update_dict = match_dict_data_by_key(
                space_data, light_table.record_template
            )

            search_condition = (
                "id=%s AND lighting_primary_space_type='%s' AND lighting_secondary_space_type='%s'"
                % (
                    level_3_lighting_code_definition_id,
                    lighting_primary_space_type,
                    lighting_secondary_space_type,
                )
            )
            update_a_table(
                conn, lighting_standard_table, lighting_update_dict, search_condition
            )

            # update ventilation
            ventilation_update_dict = {
                "ventilation_rate": space_data.get("ventilation_rate"),
                "ventilation_rate_occupant_unit": space_data.get(
                    "ventilation_rate_occupant_unit"
                ),
                "ventilation_rate_area": space_data.get("ventilation_rate_area"),
                "ventilation_rate_area_unit": space_data.get(
                    "ventilation_rate_area_unit"
                ),
                "occupancy_per_area": space_data.get("occupancy_per_area"),
                "occupancy_per_area_unit": space_data.get("occupancy_per_area_unit"),
                "air_class": space_data.get("air_class"),
                "os": space_data.get("os"),
            }
            search_condition = (
                "id=%s AND ventilation_primary_space_type='%s' AND ventilation_secondary_space_type='%s'"
                % (
                    level_3_ventilation_definition_id,
                    ventilation_primary_space_type,
                    ventilation_secondary_space_type,
                )
            )
            update_a_table(
                conn,
                ventilation_standard_table,
                ventilation_update_dict,
                search_condition,
            )

            # update plug load table
            if space_data.get("electric_equipment_space_type_name"):
                plug_load_table = EquipLoadTable()
                plug_load_update = match_dict_data_by_key(
                    space_data, plug_load_table.record_template
                )
                search_condition = "electric_equipment_space_type_name='%s'" % (
                    space_data["electric_equipment_space_type_name"]
                )
                update_a_table(
                    conn,
                    plug_load_table.data_table_name,
                    plug_load_update,
                    search_condition,
                )
