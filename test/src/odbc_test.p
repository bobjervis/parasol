/*
   Copyright 2015 Robert Jervis

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
 */
import parasol:odbc;

ref<odbc.Environment> env = new odbc.Environment();

env.setODBCVersion(odbc.ODBCVersion.V3);

ref<odbc.DBConnection> connection = env.getDBConnection();

assert(connection != null);

assert(connection.connect("ImagineDB", "root", "jrirba"));

ref<Statement> statement = connection.getStatement();

assert(statement != null);

boolean success;
odbc.SqlReturn return;

(success, return) = statement.execDirect("describe User");

/*
if (mysql.mysql_query(&m, "describe User".c_str()) != 0)
	printf("Error number is %d\n", mysql.mysql_errno(&m));

ref<mysql.MYSQL_RES> result = mysql.mysql_store_result(&m);

if (result == null) {
	if (mysql.mysql_field_count(&m) != 0)
		printf("Query should have returned data. Error number is %d\n", mysql.mysql_errno(&m));
} else {
	int num_fields = mysql.mysql_num_fields(result);
	printf("num_fields is %d\n", num_fields);
	mysql.MYSQL_ROW row;
	int rowid = 0;
	while ((row = mysql.mysql_fetch_row(result)) != null) {
		pointer<long> lengths = mysql.mysql_fetch_lengths(result);
		printf("Row %d\n", rowid);
		rowid++;
		for (int i = 0; i < num_fields; i++) {
			printf("    Field %d: %s\n", i, row[i]);
		}
	}
	mysql.mysql_free_result(result);
}

mysql.mysql_close(&m);
*/
