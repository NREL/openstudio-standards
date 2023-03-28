from database_engine.database import DBOperation
from database_engine.database_util import getattr_either, is_float

TABLE_NAME = "support_materials"

RECORD_HELP = """
Must provide a dict that contains following key value pairs:
name: TEXT
material_type: TEXT
roughness: NUMERIC
thickness: NUMERIC
conductivity: NUMERIC
resistance: NUMERIC
density: NUMERIC
specific_heat: NUMERIC
thermal_absorptance: NUMERIC
solar_absorptance: NUMERIC
visible_absorptance: NUMERIC
u_factor: NUMERIC
solar_heat_gain_coefficient: NUMERIC
visible_transmittance: NUMERIC
gas_type: TEXT
optical_data_type: TEXT
solar_transmittance_at_normal_incidence: NUMERIC
front_side_solar_reflectance_at_normal_incidence: NUMERIC
back_side_solar_reflectance_at_normal_incidence: NUMERIC
visible_transmittance_at_normal_incidence: NUMERIC
front_side_visible_reflectance_at_normal_incidence: NUMERIC
back_side_visible_reflectance_at_normal_incidence: NUMERIC
infrared_transmittance_at_normal_incidence: NUMERIC
front_side_infrared_hemispherical_emissivity: NUMERIC
back_side_infrared_hemispherical_emissivity: NUMERIC
dirt_correction_factor_for_solar_and_visible_transmittance: NUMERIC
solar_diffusing: TEXT
frame_width: NUMERIC
annotation: TEXT
"""

CREATE_MATERIALS_TABLE = f"""
CREATE TABLE IF NOT EXISTS %s
(name TEXT UNIQUE NOT NULL PRIMARY KEY,
material_type TEXT,
roughness NUMERIC,
thickness NUMERIC,
conductivity NUMERIC,
resistance NUMERIC,
density NUMERIC,
specific_heat NUMERIC,
thermal_absorptance NUMERIC,
solar_absorptance NUMERIC,
visible_absorptance NUMERIC,
gas_type TEXT,
u_factor NUMERIC,
solar_heat_gain_coefficient NUMERIC,
visible_transmittance NUMERIC,
optical_data_type TEXT,
solar_transmittance_at_normal_incidence NUMERIC,
front_side_solar_reflectance_at_normal_incidence NUMERIC,
back_side_solar_reflectance_at_normal_incidence NUMERIC,
visible_transmittance_at_normal_incidence NUMERIC,
front_side_visible_reflectance_at_normal_incidence NUMERIC,
back_side_visible_reflectance_at_normal_incidence NUMERIC,
infrared_transmittance_at_normal_incidence NUMERIC,
front_side_infrared_hemispherical_emissivity NUMERIC,
back_side_infrared_hemispherical_emissivity NUMERIC,
dirt_correction_factor_for_solar_and_visible_transmittance NUMERIC,
solar_diffusing TEXT,
frame_width NUMERIC,
annotation TEXT
);
"""

INSERT_MATERIAL = f"""
    INSERT INTO %s
    (name,
material_type,
roughness,
thickness,
conductivity,
resistance,
density,
specific_heat,
thermal_absorptance,
solar_absorptance,
visible_absorptance,
gas_type,
u_factor,
solar_heat_gain_coefficient,
visible_transmittance,
optical_data_type,
solar_transmittance_at_normal_incidence,
front_side_solar_reflectance_at_normal_incidence,
back_side_solar_reflectance_at_normal_incidence,
visible_transmittance_at_normal_incidence,
front_side_visible_reflectance_at_normal_incidence,
back_side_visible_reflectance_at_normal_incidence,
infrared_transmittance_at_normal_incidence,
front_side_infrared_hemispherical_emissivity,
back_side_infrared_hemispherical_emissivity,
dirt_correction_factor_for_solar_and_visible_transmittance,
solar_diffusing,
frame_width,
annotation)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
"""


RECORD_TEMPLATE = {
    "name": "",
    "material_type": "",
    "roughness": "",
    "thickness": 0.0,
    "conductivity": 0.0,
    "resistance": 0.0,
    "density": 0.0,
    "specific_heat": 0.0,
    "thermal_absorptance": 0.0,
    "solar_absorptance": 0.0,
    "visible_absorptance": 0.0,
    "gas_type": "",
    "u_factor": 0.0,
    "solar_heat_gain_coefficient": 0.0,
    "visible_transmittance": 0.0,
    "optical_data_type": "",
    "solar_transmittance_at_normal_incidence": 0.0,
    "front_side_solar_reflectance_at_normal_incidence": 0.0,
    "back_side_solar_reflectance_at_normal_incidence": 0.0,
    "visible_transmittance_at_normal_incidence": 0.0,
    "front_side_visible_reflectance_at_normal_incidence": 0.0,
    "back_side_visible_reflectance_at_normal_incidence": 0.0,
    "infrared_transmittance_at_normal_incidence": 0.0,
    "front_side_infrared_hemispherical_emissivity": 0.0,
    "back_side_infrared_hemispherical_emissivity": 0.0,
    "dirt_correction_factor_for_solar_and_visible_transmittance": 0.0,
    "solar_diffusing": "",
    "frame_width": 0.0,
    "annotation": "",
}


class SupportMaterialTable(DBOperation):
    def __init__(self):
        super(SupportMaterialTable, self).__init__(
            table_name=TABLE_NAME,
            record_template=RECORD_TEMPLATE,
            initial_data_directory=f"database_files/{TABLE_NAME}",
            create_table_query=CREATE_MATERIALS_TABLE % TABLE_NAME,
            insert_record_query=INSERT_MATERIAL % TABLE_NAME,
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
            "material_type",
            "roughness",
            "annotation",
            "gas_type",
            "optical_data_type",
            "solar_diffusing",
        ]

        for f in str_expected:
            if record.get(f):
                assert isinstance(
                    record[f], str
                ), f"{f} requires to be a string, instead got {record[f]}"

        float_expected = [
            "thickness",
            "conductivity",
            "resistance",
            "density",
            "specific_heat",
            "thermal_absorptance",
            "solar_absorptance",
            "visible_absorptance",
            "u_factor",
            "solar_heat_gain_coefficient",
            "visible_transmittance",
            "frame_width",
            "solar_transmittance_at_normal_incidence",
            "front_side_solar_reflectance_at_normal_incidence",
            "back_side_solar_reflectance_at_normal_incidence",
            "visible_transmittance_at_normal_incidence",
            "front_side_visible_reflectance_at_normal_incidence",
            "back_side_visible_reflectance_at_normal_incidence",
            "infrared_transmittance_at_normal_incidence",
            "front_side_infrared_hemispherical_emissivity",
            "back_side_infrared_hemispherical_emissivity",
            "dirt_correction_factor_for_solar_and_visible_transmittance",
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
            getattr_either("material_type", record),
            getattr_either("roughness", record),
            getattr_either("thickness", record),
            getattr_either("conductivity", record),
            getattr_either("resistance", record),
            getattr_either("density", record),
            getattr_either("specific_heat", record),
            getattr_either("thermal_absorptance", record),
            getattr_either("solar_absorptance", record),
            getattr_either("visible_absorptance", record),
            getattr_either("gas_type", record),
            getattr_either("u_factor", record),
            getattr_either("solar_heat_gain_coefficient", record),
            getattr_either("visible_transmittance", record),
            getattr_either("optical_data_type", record),
            getattr_either("solar_transmittance_at_normal_incidence", record),
            getattr_either("front_side_solar_reflectance_at_normal_incidence", record),
            getattr_either("back_side_solar_reflectance_at_normal_incidence", record),
            getattr_either("visible_transmittance_at_normal_incidence", record),
            getattr_either(
                "front_side_visible_reflectance_at_normal_incidence", record
            ),
            getattr_either("back_side_visible_reflectance_at_normal_incidence", record),
            getattr_either("infrared_transmittance_at_normal_incidence", record),
            getattr_either("front_side_infrared_hemispherical_emissivity", record),
            getattr_either("back_side_infrared_hemispherical_emissivity", record),
            getattr_either(
                "dirt_correction_factor_for_solar_and_visible_transmittance", record
            ),
            getattr_either("solar_diffusing", record),
            getattr_either("frame_width", record),
            getattr_either("annotation", record),
        )
