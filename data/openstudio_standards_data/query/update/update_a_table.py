import sqlite3


def update_a_table(
    conn: sqlite3.Connection, table_name: str, update_dict: dict, search_condition: str
):
    """
    Update a table data based on search conditions and update values -
    there is no order by and limit.

    :param conn: sqlite3.Connection
    :param table_name: table name
    :param update_dict: dictionary contains the key-value data pair where key is the table column header and value is
    the new value. Note, None is allowed and will not add to the updates
    :param search_condition: str a search criteria string composed by the client end. e.g. "id = 11"
    :return: true update successfully, false failed
    """

    set_str_value = [
        f"{key}='{update_dict[key]}'" for key in update_dict.keys() if update_dict[key]
    ]

    UPDATE_QUERY = f"""
        UPDATE {table_name}
        SET {','.join(set_str_value)}
        WHERE {search_condition}
    """
    return conn.execute(UPDATE_QUERY) and conn.commit() if set_str_value else None
