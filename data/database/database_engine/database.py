import sqlite3
from sqlite3 import Error
import csv
import json

DB_FILE = "osstd_database.db"


def create_connect(db_file):
    """
    create a database_tables conection to the SQLite database_tables specified by db_file
    :param db_file: database_tables file or None (None uses default
    :return: Connection object or None
    """
    conn = None
    try:
        conn = sqlite3.connect(db_file if db_file else DB_FILE)
        # enable foreign keys execution
        conn.execute("PRAGMA foreign_keys = 1")
    except Error as e:
        print(e)
    return conn


class DBOperation:
    def __init__(self, table_name, record_template, initial_data_directory):
        """
        DB Operation class
        :param table_name: String name of the table
        :param record_template: dictionary record template
        :param initial_data_directory: String initial data directory
        """
        self.data_table_name = table_name
        self.record_template = record_template
        self.initial_data_directory = initial_data_directory

    def create_a_table(self, connection):
        """
        Create a table - no return
        :param connection:
        :return:
        """
        print(f"creating table: {self.data_table_name} from {self.initial_data_directory}")
        connection.execute(self._get_create_table_query())
        return True

    def add_a_record(self, connection, record: dict):
        """
        Add a record to a table
        :param connection:
        :param record: dict contains the dictionary of record
        :return: the index of the newly inserted record.
        """
        # run data validation, raise exception if data is not validated.
        cur = connection.cursor()

        self.validate_record_datatype(record)
        cur.execute(self._get_insert_record_query(), self._preprocess_record(record))
        connection.commit()
        return cur.lastrowid

    def get_all_records(self, connection):
        """
        Retrieve all data records
        :param connection:
        :return:
        """
        return connection.execute(self._get_retrieve_all_query()).fetchall()

    def get_record_info(self):
        """
        A function to return the record info of the table
        :return:
        """
        pass

    def get_record_template(self):
        """
        Get a record template of a table
        :return:
        """
        return self.record_template

    def validate_record_datatype(self, record):
        """
        Validate the data. This function shall be used to set special data requirement that SQLite schema cannot
        verify. e.g., a data's data type shall be int.

        :param record: dict
        A dictionary that contains a map column to value in a row.
        :return: boolean
        """
        return True

    def export_table_to_csv(self, conn, save_dir=""):
        """
        A function that exports the table into a .csv file

        :param conn: SQLite3Connection object
        :param save_dir: str, path that saves the csv file
        :return:
        """
        cursor = conn.cursor()
        cursor.execute(self._get_retrieve_all_query())
        csv_dir = f"{save_dir}{self.data_table_name}.csv"
        with open(csv_dir, "w", newline="") as csv_file:
            csv_writer = csv.writer(csv_file, delimiter=",")
            csv_writer.writerow([i[0] for i in cursor.description])
            csv_writer.writerows(cursor)

    def export_table_to_json(self, conn, save_dir=""):
        """
        A function that exports the table into a .json file

        :param conn: SQLite3Connection object
        :param save_dir: str, path that saves the json file
        :return:
        """
        cursor = conn.cursor()
        cursor.execute(self._get_retrieve_all_query())
        r = [
            dict((cursor.description[i][0], value) for i, value in enumerate(row))
            for row in cursor.fetchall()
        ]

        json_dir = f"{save_dir}{self.data_table_name}.json"
        json_output = json.dumps(r, indent=4)
        with open(json_dir, "w", newline="") as json_file:
            json_file.write(json_output)

    def _preprocess_record(self, record):
        """
        Function that pre-process a record before insert to Table.

        :param record:
        :return:
        """
        pass

    def _get_create_table_query(self):
        """
        Function to create a table
        :return:
        """
        pass

    def _get_insert_record_query(self):
        """
        Function to insert a query
        :return:
        """
        pass

    def _get_retrieve_all_query(self):
        """
        Function to retrieve all records in a table
        :return:
        """
        return f"SELECT * FROM {self.data_table_name}"
