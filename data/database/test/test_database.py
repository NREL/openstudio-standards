from unittest import TestCase
from unittest import mock
import os
import sqlite3
from applications.database_maintenance import create_osstd_database_from_csv


class TestDatabaseQuries(TestCase):
    """
    Test database - unfinished
    """

    def fix_dbc(self):
        dbc = mock.MagicMock(spec=["cursor"])
        dbc.autocommit = True
        return dbc

    def fix_rows(self):
        rows = [{"id": 1, "name": "John"}, {"id": 2, "name": "Jane"}]
        return rows

    def test_insert_rows_calls_cursor_method(self):
        dbc = self.fix_dbc()
        rows = self.fix_rows()
        pass


def test_create_database():
    db_name = "openstudio_standards_data"
    if os.path.isfile(f"{db_name}.db"):
        os.remove(f"{db_name}.db")
    conn = sqlite3.connect(f"{db_name}.db")
    create_osstd_database_from_csv(conn)
    conn.close()
    assert os.path.isfile(f"{db_name}.db")
