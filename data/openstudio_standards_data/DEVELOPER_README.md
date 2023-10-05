# Notes for Developers
## Prerequisites
Below are listed the prerequisites to any of the database related code.
- Python 3.10
## Expanding the Database
Developers wishing to expand the database do not need advanced SQL knowledge to do so. The following tips should provide enough information to expand the database.
### Adding Tables and Data for a New Code Versions
#### Creating New Tables
Table definitions are located in `database_tables`. A good starting point is a copy of an existing table definition file that most closely match the content of the table that you wish to add. 
* If you are creating a table that inherits from a parent (e.g., `level_3_lighting_90_1_2004.py` which inherits from `level_3_lighting_90_1_definition.py`):
  * Rename the `table_name` variable
  * Rename the name of the class and subsequent mention of it in that file

  __Example__: Add a level 3 (code requirement) table for lighting power allowances 90.1-1975. One could copy the content of `level_3_lighting_90_1_2004.py` and modify it as follows:

       ```
       import sqlite3
       from database_tables.level_3_lighting_90_1_definition import LightDef901
       TABLE_NAME = "level_3_lighting_90_1_1975"
       class LightDef9011975Table(LightDef901):
           def __init__(self):
               super(LightDef9011975Table, self).__init__(
                   table_name=TABLE_NAME,
                   initial_data_directory=f"database_files/{TABLE_NAME}",
               )
       ```

  * If inherited attributes need to be modified, for example a new column needs to be added, the attribute can be overwritten in the new table definition file. Be mindful that it's possible that some attribute depend on others, for example if `record_template` is modified, then `insert_record_query` should be modified as well.
* If you are creating a table that does not inherit from a parent (e.g., support tables):
  * Rename the `table_name` variable and all other attributes (`record_template`, `initial_data_directory`, `create_table_query`, `insert_record_query`)
  * update the `_preprocess_record` function.
* When modifying `create_table_query` use either `TEXT` or `NUMERIC` when describing a column and use `NOT NULL` when a value in the column cannot be blank.
#### Space Type Data
* Start by adding tables for the lowest level of space type data. For instance, for lighting and ventilation, this is level 3, i.e., the data as represented in the code.
* Map data to the parent level. For instance, for lighting and ventilation this would be level 2.
Note that not all records for the lowest level should be necessarily mapped to a parent level.
#### Define Relationships
Relationship between column (or keys) from a table to another is established in the `create_table_query` attribute. In the example below the column (or key) `lighting_space_type_name` from a table that's being created is in relation with the `lighting_space_type_name` column (or key) from the `support_lighting_space_type_name_tags` table.
```
FOREIGN KEY(lighting_space_type_name) REFERENCES support_lighting_space_type_name_tags(lighting_space_type_name)
```
#### Adding Data
Data can be provided either in CSV or in the  JSON file format. The best approach is to:
1) Generate the database,
2) Export the content to CSV or JSON, 
3) Modify the database structure (see the Creating New Tables section above), 
4) Add a new CSV of JSON file in the data folder corresponding to the `initial_data_directory` attribute in the new table class,
5) Re-generate the database.
#### Tests
A small set of tests have been implemented, mostly to make sure that further edits to the data or database structure is valid, and that JSON and CSV files generated from the database include the same content. After modifying the database, it is good practice to run the tests locally to verify the integrity of the database. From the root directory one can run the following command:
```
pytest test
```
An error will be displayed if the tests failed.