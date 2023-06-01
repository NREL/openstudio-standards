import logging

from applications.database_maintenance import (
    export_openstudio_standards_database_to_json,
    export_openstudio_standards_database_to_csv,
    create_openstudio_standards_database_from_csv,
    create_openstudio_standards_database_from_json,
)

# create_openstudio_standards_database()
# create_openstudio_standards_building_data_json("openstudio_standards_building_data.json", "openstudio_standards_database.db")
from applications.form.update_space_data import update_openstudio_standards_space_data
from database_engine.database import create_connect
from query.fetch.database_table import fetch_a_record_from_table_by_id

logging.basicConfig(
    filename="new_log",
    filemode="a",
    format="%(asctime)s,%(msecs)d %(name)s %(levelname)s %(message)s",
    datefmt="%H:%M:%S",
    level=logging.DEBUG,
)
conn = create_connect(None)
# create_openstudio_standards_database_from_csv(conn)
# a = fetch_a_record_from_table_by_id(conn, "level_3_lighting_90_1_2019", 1)
# export_openstudio_standards_database_to_csv(conn, "")
# export_openstudio_standards_database_to_json(conn, "database_files/")
# create_openstudio_standards_database_from_json(conn)
# create_openstudio_standards_building_data_json(conn, 'openstudio_standards_building_data.json')
update_json = [
    {
        "template": "2019",
        "lighting_standard": "ASHRAE 90.1-2019",
        "ventilation_standard": "ASHRAE 62.1-2019",
        "space_type": "audience seating - convention center",
        "method": "CS",
        "lighting_primary_space_type": "Audience Seating Area",
        "lighting_per_area": 0.23,
        "lighting_secondary_space_type": "All other audience seating areas",
        "lighting_per_area_unit": "W/ft2",
        "annotation": "",
        "ventilation_primary_space_type": "Public Assembly Spaces",
        "ventilation_secondary_space_type": "Auditorium seating area",
        "ventilation_rate": 5,
        "ventilation_rate_occupant_unit": "cfm/person",
        "ventilation_rate_area": 0.06,
        "ventilation_rate_area_unit": "cfm/ft2",
        "occupancy_per_area": 150,
        "occupancy_per_area_unit": "ppl/1000 ft2",
        "air_class": 1,
        "os": "yes",
        "electric_equipment_space_type_name": "audience seating - convention center",
        "electric_equipment_minimum_epd": 0.63,
        "electric_equipment_average_epd": 0.90,
        "electric_equipment_median_epd": 0.63,
        "electric_equipment_maximum_epd": 0.63,
        "electric_equipment_epd_unit": "W/ft2",
    }
]

# update_openstudio_standards_space_data(conn, update_json)
