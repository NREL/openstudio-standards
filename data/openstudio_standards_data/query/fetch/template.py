"""
This module contains a number of functions to fetch template
template specify the standard versions for each set of study

e.g. 2019 -> lighting: ASHRAE 90.1-2019, ventilation: ASHRAE 62.1-2019
"""
import sqlite3

from query.util import _convert_list_tuple_to_list_dict

DATA_HEADER = [
    "template",
    "lighting_standard",
    "lighting_standard_table",
    "ventilation_standard",
    "ventilation_standard_table",
]

TEMPLATE_QUERY = f"""
SELECT {','.join(DATA_HEADER)}
	FROM support_standard_templates
"""


def fetch_templates(conn: sqlite3.Connection):
    """
    Fetch all template data
    :param conn:
    :return:
    """
    return _convert_list_tuple_to_list_dict(
        conn.execute(TEMPLATE_QUERY).fetchall(), DATA_HEADER
    )


def fetch_template_data_by_template(conn: sqlite3.Connection, template: str):
    """
    Fetch a template record
    :param conn:
    :param template: string
    :return:
    """
    template_query = f"""{TEMPLATE_QUERY} WHERE template = ?;"""
    return _convert_list_tuple_to_list_dict(
        conn.execute(template_query, (template,)).fetchall(), DATA_HEADER
    )


def fetch_template_data_by_template_first(conn: sqlite3.Connection, template: str):
    """
    Fetch a template record
    :param conn:
    :param template: string
    :return:
    """
    template_query = f"""{TEMPLATE_QUERY} WHERE template = ?;"""
    fetched_data = _convert_list_tuple_to_list_dict(
        conn.execute(template_query, (template,)).fetchall(), DATA_HEADER
    )
    assert (
        len(fetched_data) > 0
    ), f"Cannot find matched template '{template}' in the openstudio_standards database"

    return fetched_data[0]
