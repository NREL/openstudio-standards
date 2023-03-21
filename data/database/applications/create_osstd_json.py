import json
import sqlite3

from database_tables.level_2_electric_equipment import (
    RECORD_TEMPLATE as plug_load_record_template,
)
from query.fetch.space import fetch_space_data
from query.fetch.database_table import (
    fetch_table,
    fetch_records_from_table_by_key_values,
)
from query.fetch.template import fetch_templates


def create_osstd_space_data_json(conn: sqlite3.Connection, json_data_dir: str):
    """
    Extract osstd building data to a json file.
    :param conn: database connection
    :param json_data_dir: directory
    :return:
    """
    space_data = []

    # Step 1, we need to get the template table and loop in the table
    standard_templates = fetch_templates(conn)
    # Step 2, get all building -> light and vent map table
    space_map_table = fetch_space_data(conn)
    # Step 3, create an empty data holder to serve a memoize storage for standard tables
    standard_data_tables = dict()

    for template in standard_templates:
        lighting_standard_table = template["lighting_standard_table"]
        ventilation_standard_table = template["ventilation_standard_table"]
        # filter out the matching lighting standard table and ventilation standard table
        subset_space_map_table = filter(
            lambda bldg: bldg["level_3_lighting_definition_table"]
            == lighting_standard_table
            and bldg["level_3_ventilation_definition_table"]
            == ventilation_standard_table,
            space_map_table,
        )
        for space in subset_space_map_table:
            # WX: I tried to avoid having queries inside the loop but this seems to be a decision to make either loop
            # the queries or pre-query each standard version tables outside the loop but increase the maintenance effort
            sp_data = dict()
            sp_data["template"] = template["template"]
            sp_data["lighting_standard"] = template["lighting_standard"]
            sp_data["ventilation_standard"] = template["ventilation_standard"]
            sp_data["space_type"] = space["space_type"]

            lpd_id = int(space["level_3_lighting_defintion_id"])
            vent_id = int(space["level_3_ventilation_defintion_id"])
            if lighting_standard_table not in standard_data_tables.keys():
                light_table = fetch_table(conn, lighting_standard_table)
                standard_data_tables[lighting_standard_table] = light_table
            if ventilation_standard_table not in standard_data_tables.keys():
                vent_table = fetch_table(conn, ventilation_standard_table)
                standard_data_tables[ventilation_standard_table] = vent_table
            if space.get("electric_equipment_space_type_name"):
                plug_load_record = fetch_records_from_table_by_key_values(
                    conn,
                    "equip_load",
                    {
                        "electric_equipment_space_type_name": space[
                            "electric_equipment_space_type_name"
                        ]
                    },
                )
                if plug_load_record:
                    # Get the first record in the list.
                    plug_load_record = plug_load_record[0]
            else:
                plug_load_record = plug_load_record_template
            light = next(
                ltg
                for ltg in standard_data_tables[lighting_standard_table]
                if ltg["id"] == lpd_id
            )
            vent = next(
                vt
                for vt in standard_data_tables[ventilation_standard_table]
                if vt["id"] == vent_id
            )
            sp_data.update(light)
            sp_data.update(vent)
            sp_data.update(plug_load_record)
            # delete ID parameter, the ID is database specific and does not need
            # included in the json
            sp_data.pop("id", None)

            space_data.append(sp_data)

    with open(json_data_dir, "w") as output_report:
        output_report.write(json.dumps(space_data, indent=4))
