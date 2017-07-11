/*
   Copyright 2015 Robert Jervis

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0
libodbc.so"
   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
 */
namespace parasol:odbc;

public enum ODBCVersion {
	V2,
	V3,
}

public enum ConnectionPooling {
	OFF,
	ONE_PER_DRIVER,
	ONE_PER_ENVIRONMENT,
}

public class Environment {
	private SQLHENV _environment;

	public Environment() {
		SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &_environment);
	}

	~Environment() {
		SQLFreeHandle(SQL_HANDLE_ENV, _environment);
	}

	public ref<DBConnection> getDBConnection() {
		SQLHDBC dbc;
		SQLAllocHandle(SQL_HANDLE_DBC, _environment, &dbc);
		return new DBConnection(dbc);
	}

	public boolean setConnnectionPooling(ConnectionPooling pooling, boolean strictMatch) {
		long p;

		switch (pooling) {
		case OFF:					p = SQL_CP_OFF;					break;
		case ONE_PER_DRIVER:		p = SQL_CP_ONE_PER_DRIVER;		break;
		case ONE_PER_ENVIRONMENT:	p = SQL_CP_ONE_PER_HENV;		break;
		}
		if (!SQL_SUCCEEDED(SQLSetEnvAttr(_environment, SQL_ATTR_CONNECTION_POOLING, address(p), 0)))
			return false;
		return SQL_SUCCEEDED(SQLSetEnvAttr(_environment, SQL_ATTR_CP_MATCH, 
								address(strictMatch ? SQL_CP_STRICT_MATCH : SQL_CP_RELAXED_MATCH), 0));
	}

	public boolean setODBCVersion(ODBCVersion version) {
		return SQL_SUCCEEDED(SQLSetEnvAttr(_environment, SQL_ATTR_ODBC_VERSION, 
								address(version == ODBCVersion.V2 ? SQL_OV_ODBC2 : SQL_OV_ODBC3), 0));
	}
	/**
	 * Collects the SQL diagnostic record information.
	 *
	 * RETURNS:
	 *	string - The SQLSTATE string.
	 *	long - The numeric native error code.
	 *	string - Tthe mssage text.
	 */
	public string, long, string getDiagnosticRecord(int record) {
		string sqlstate;
		sqlstate.resize(5);
		SQLINTEGER nativeError;
		string messageText;
		messageText.resize(512);
		SQLSMALLINT actual;
		SQLGetDiagRec(SQL_HANDLE_ENV, _environment, SQLSMALLINT(record), &sqlstate[0], &nativeError, 
								&messageText[0],SQLSMALLINT( messageText.length()), &actual);
		messageText.resize(actual);
		return sqlstate, nativeError, messageText;
	}
}

public enum DriverCompletion {
	PROMPT,								// prompt even if the connection string is correct and has enough information to connect
	COMPLETE,							// prompt if the connection string is incorrect or incomplete
	COMPLETE_REQUIRED,					// prompt if the connection string is incorrect or incomplete, only allow required info to be entered
	NOPROMPT,							// never prompt
}

public class DBConnection {
	private SQLHDBC _connection;

	DBConnection(SQLHDBC dbc) {
		_connection = dbc;
	}

	~DBConnection() {
		SQLFreeHandle(SQL_HANDLE_DBC, _connection);
	}
	/**
	 * This function connects to a data source using a name, a user id and a password.
	 *
	 * dataSourceName - A defined data source.
	 * userName - A user id.
	 * authenticaion - Authentication string (typically the password).
	 */
	public boolean, SqlReturn connect(string dataSourceName, string userName, string authentication) {
		SQLRETURN ret = SQLConnect(_connection, &dataSourceName[0], SQLSMALLINT(dataSourceName.length()), 
				&userName[0], SQLSMALLINT(userName.length()), &authentication[0], SQLSMALLINT(authentication.length()));
		return SQL_SUCCEEDED(ret), fromSQLRETURN(ret);
	}
	/**
	 * This function connects to a data source in coordination with the Data Manager. If
	 * specified to do so, the Data Manager will open a dialog to collect additional parameters.
	 *
	 * PARAMETERS:
	 * 	url - The connection string, with the DSN plus additional attributes as needed.
	 *	completion - Specifies the prompting behavior of the Data Manager (see DriverCompletion for details). 
	 */
	public boolean, string, SqlReturn driverConnect(string url, DriverCompletion completion) {
		string outstr;
		outstr.resize(1024);
		SQLSMALLINT outstrlen;
		SQLUSMALLINT completionCode;

		switch (completion) {
		case COMPLETE:			completionCode = SQL_DRIVER_COMPLETE;			break;
		case PROMPT:			completionCode = SQL_DRIVER_PROMPT;				break;
		case NOPROMPT:			completionCode = SQL_DRIVER_NOPROMPT;			break;
		case COMPLETE_REQUIRED:	completionCode = SQL_DRIVER_COMPLETE_REQUIRED;	break;
		}
	
		SQLRETURN ret = SQLDriverConnect(_connection, null, url.c_str(), SQL_NTS, &outstr[0], SQLSMALLINT(outstr.length()), 
											&outstrlen, completionCode);
		if (SQL_SUCCEEDED(ret)) {
			outstr.resize(outstrlen);
			printf("Resulting connection string is '%s'\n", outstr);
			return true, outstr, fromSQLRETURN(ret);
		} else {
			printf("return value = %d\n", ret);
			return false, null, fromSQLRETURN(ret);
		}
	}

	ref<Statement> getStatement() {
		SQLHSTMT stmt;
		SQLAllocHandle(SQL_HANDLE_STMT, _connection, &stmt);
		return new Statement(stmt);
	}
	/**
	 * Collects the SQL diagnostic record information.
	 *
	 * RETURNS:
	 *	string - The SQLSTATE string.
	 *	long - The numeric native error code.
	 *	string - Tthe mssage text.
	 */
	public string, long, string getDiagnosticRecord(int record) {
		string sqlstate;
		sqlstate.resize(5);
		SQLINTEGER nativeError;
		string messageText;
		messageText.resize(512);
		SQLSMALLINT actual;
		SQLGetDiagRec(SQL_HANDLE_DBC, _connection, SQLSMALLINT(record), &sqlstate[0], &nativeError, 
								&messageText[0],SQLSMALLINT( messageText.length()), &actual);
		messageText.resize(actual);
		return sqlstate, nativeError, messageText;
	}
}

public class Statement {
	private SQLHSTMT _statement;

	Statement(SQLHSTMT stmt) {
		_statement = stmt;
	}

	~Statement() {
		SQLFreeHandle(SQL_HANDLE_STMT, _statement);
	}

	public boolean, SqlReturn execDirect(string statementText) {
		SQLRETURN ret = SQLExecDirect(_statement, &statementText[0], statementText.length());
		return SQL_SUCCEEDED(ret), fromSQLRETURN(ret);
	}

}

public enum SqlReturn {
	UNKNOWN,					// Returned when the return value did not match any other in this enum
	SUCCESS,
	SUCCESS_WITH_INFO,
	ERROR,
	INVALID_HANDLE,
	NO_DATA,
	STILL_EXECUTING,
	NEED_DATA,
}

private SqlReturn fromSQLRETURN(SQLRETURN ret) {
	switch (ret) {
	case SQL_SUCCESS:				return SqlReturn.SUCCESS;
	case SQL_SUCCESS_WITH_INFO:		return SqlReturn.SUCCESS_WITH_INFO;
	case SQL_ERROR:					return SqlReturn.ERROR;
	case SQL_INVALID_HANDLE:		return SqlReturn.INVALID_HANDLE;
	case SQL_NO_DATA:				return SqlReturn.NO_DATA;
	case SQL_STILL_EXECUTING:		return SqlReturn.STILL_EXECUTING;
	case SQL_NEED_DATA:				return SqlReturn.NEED_DATA;
	}
	return SqlReturn.UNKNOWN;
}
	
// From here on down is the ODBC interface definition, which is mostly not exposed in favor of the more
// 'classy' approach that would feel natural to a Parasol developer.

private SQLSMALLINT SQL_HANDLE_ENV = 1;
private SQLSMALLINT SQL_HANDLE_DBC = 2;
private SQLSMALLINT SQL_HANDLE_STMT = 3;
private SQLSMALLINT SQL_HANDLE_DESC = 4;

private SQLHANDLE SQL_NULL_HANDLE = null;

private class SQLSMALLINT = short;
private class SQLUSMALLINT = char;

private class SQLINTEGER = long;

private class SQLPOINTER = address;

private class SQLRETURN = SQLSMALLINT;

private class SQLHANDLE = address;
private class SQLHENV = SQLHANDLE;
private class SQLHDBC = SQLHANDLE;
private class SQLHSTMT = SQLHANDLE;
private class SQLHWND = SQLHANDLE;

@Constant
private SQLRETURN SQL_SUCCESS = 0;
@Constant
private SQLRETURN SQL_SUCCESS_WITH_INFO = 1;
@Constant
private SQLRETURN SQL_ERROR = SQLRETURN(-1);
@Constant
private SQLRETURN SQL_INVALID_HANDLE = SQLRETURN(-2);
@Constant
private SQLRETURN SQL_NO_DATA = 100;
@Constant
private SQLRETURN SQL_STILL_EXECUTING = 2;
@Constant
private SQLRETURN SQL_NEED_DATA = 99;

private SQLINTEGER SQL_ATTR_ODBC_VERSION = 200;
private SQLINTEGER SQL_ATTR_CONNECTION_POOLING = 201;
private SQLINTEGER SQL_ATTR_CP_MATCH = 202;

private long SQL_OV_ODBC2 = 2;
private long SQL_OV_ODBC3 = 3;

private long SQL_CP_OFF	= 0;
private long SQL_CP_ONE_PER_DRIVER = 1;
private long SQL_CP_ONE_PER_HENV = 2;

/* values for SQL_ATTR_CP_MATCH */
private long SQL_CP_STRICT_MATCH = 0;
private long SQL_CP_RELAXED_MATCH = 1;

private SQLSMALLINT SQL_NTS = SQLSMALLINT(-3);

private SQLUSMALLINT SQL_DRIVER_NOPROMPT =             0;
private SQLUSMALLINT SQL_DRIVER_COMPLETE =             1;
private SQLUSMALLINT SQL_DRIVER_PROMPT =               2;
private SQLUSMALLINT SQL_DRIVER_COMPLETE_REQUIRED =    3;

private boolean SQL_SUCCEEDED(SQLRETURN ret) {
	return (ret & ~1) == 0;
}

@Linux("libodbc.so", "SQLAllocHandle")
private abstract SQLRETURN SQLAllocHandle(SQLSMALLINT HandleType, SQLHANDLE InputHandle, ref<SQLHANDLE> OutputHandlePtr);

@Linux("libodbc.so", "SQLConnect")
private abstract SQLRETURN SQLConnect(SQLHDBC ConnectionHadle, pointer<byte> ServerName, SQLSMALLINT NameLength1,
						pointer<byte> UserName, SQLSMALLINT NameLength2, pointer<byte> Authentication, SQLSMALLINT NameLength3);

@Linux("libodbc.so", "SQLDriverConnect")
private abstract SQLRETURN SQLDriverConnect(SQLHDBC ConnectionHadle, SQLHWND WindowHandle, pointer<byte> InConnectionString,
						SQLSMALLINT StringLength1, pointer<byte> OutConnectionString, SQLSMALLINT BufferLength, 
						ref<SQLSMALLINT> StringLength2Ptr, SQLUSMALLINT DriverCompletion);

@Linux("libodbc.so", "SQLExecDirect")
private abstract SQLRETURN SQLExecDirect(SQLHSTMT StatementHandle, pointer<byte> StatementText, SQLINTEGER TextLength);

@Linux("libodbc.so", "SQLFreeHandle")
private abstract SQLRETURN SQLFreeHandle(SQLSMALLINT HandleType, SQLHANDLE InputHandle);

@Linux("libodbc.so", "SQLGetDiagRec")
private abstract SQLRETURN SQLGetDiagRec(SQLSMALLINT HandleType, SQLHANDLE Handle, SQLSMALLINT RecNumber, pointer<byte> SQLState,
						ref<SQLINTEGER> NativeErrorPtr, pointer<byte> MessageText, SQLSMALLINT BufferLength, ref<SQLSMALLINT> TextLengthPtr);

@Linux("libodbc.so", "SQLSetEnvAttr")
private abstract SQLRETURN SQLSetEnvAttr(SQLHENV EnvironmentHandle, SQLINTEGER Attribute, SQLPOINTER ValuePtr, SQLINTEGER StringLength);

