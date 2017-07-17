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
import parasol:sql;

ref<sql.Environment> env = new sql.Environment();

env.setODBCVersion(sql.ODBCVersion.V3);

ref<sql.DBConnection> connection = env.getDBConnection();

assert(connection != null);

assert(connection.connect("ImagineDB", "root", "jrirba"));

ref<sql.Statement> statement = connection.getStatement();

assert(statement != null);

boolean success;
sql.SqlReturn retn;

(success, retn) = statement.execDirect("describe User");

assert(success);
assert(retn == sql.SqlReturn.SUCCESS);

for (int i = 1; i < 1000; i++) {
	string value;
	boolean success;

	(value, success) = statement.stringColumnAttribute(i, sql.FieldIdentifier.BASE_COLUMN_NAME);
	if (!success)
		break;
	long type;

	(type, success) = statement.integerColumnAttribute(i, sql.FieldIdentifier.TYPE);

	printf("[%d] %d %s\n", i, type, value);
}

int i = 0;
while (statement.fetch()) {
	i++;
	string s1;
	string s2;
	string s3;
	string s4;
	string s5;
	string s6;
	boolean success;

	(s1, success) = statement.getString(1);
	assert(success);
	(s2, success) = statement.getString(2);
	assert(success);
	(s3, success) = statement.getString(3);
	assert(success);
	(s4, success) = statement.getString(4);
	assert(success);
	(s5, success) = statement.getString(5);
	assert(success);
	(s6, success) = statement.getString(6);
	assert(success);

	printf("[%d] %s | %s | %s | %s | %s | %s\n", i, s1, s2, s3, s4, s5, s6);
}

printf("Fetched %d rows\n", i);
/*
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
