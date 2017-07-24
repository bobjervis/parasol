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
namespace parasol:sql;

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
		setODBCVersion(ODBCVersion.V3);
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

	SQLHENV environment() {
		return _environment;
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

	DBConnection(ref<Environment> env) {
		SQLAllocHandle(SQL_HANDLE_DBC, env.environment(), &_connection);
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

public enum FieldIdentifier {
	COUNT,
	TYPE,
	LENGTH,
	OCTET_LENGTH_PTR,
	PRECISION,
	SCALE,
	DATETIME_INTERVAL_CODE,
	NULLABLE,
	INDICATOR_PTR,
	DATA_PTR,
	NAME,
	UNNAMED,
	OCTET_LENGTH,
	ALLOC_TYPE,
	ARRAY_SIZE,
	ARRAY_STATUS_PTR,
	AUTO_UNIQUE_VALUE,
	BASE_COLUMN_NAME,
	BASE_TABLE_NAME,
	BIND_OFFSET_PTR,
	BIND_TYPE,
	CASE_SENSITIVE,
	CATALOG_NAME,
	CONCISE_TYPE,
	DATETIME_INTERVAL_PRECISION,
	DISPLAY_SIZE,
	FIXED_PREC_SCALE,
	LABEL,
	LITERAL_PREFIX,
	LITERAL_SUFFIX,
	LOCAL_TYPE_NAME,
	MAXIMUM_SCALE,
	MINIMUM_SCALE,
	NUM_PREC_RADIX,
	PARAMETER_TYPE,
	ROWS_PROCESSED_PTR,
	ROWVER,
	SCHEMA_NAME,
	SEARCHABLE,
	TYPE_NAME,
	TABLE_NAME,
	UNSIGNED,
	UPDATABLE,
}

private SQLUSMALLINT sqlField(FieldIdentifier fi) {
	switch (fi) {
	case COUNT: return SQL_DESC_COUNT;
	case TYPE: return SQL_DESC_TYPE;
	case LENGTH: return SQL_DESC_LENGTH;
	case OCTET_LENGTH_PTR: return SQL_DESC_OCTET_LENGTH_PTR;
	case PRECISION: return SQL_DESC_PRECISION;
	case SCALE: return SQL_DESC_SCALE;
	case DATETIME_INTERVAL_CODE: return SQL_DESC_DATETIME_INTERVAL_CODE;
	case NULLABLE: return SQL_DESC_NULLABLE;
	case INDICATOR_PTR: return SQL_DESC_INDICATOR_PTR;
	case DATA_PTR: return SQL_DESC_DATA_PTR;
	case NAME: return SQL_DESC_NAME;
	case UNNAMED: return SQL_DESC_UNNAMED;
	case OCTET_LENGTH: return SQL_DESC_OCTET_LENGTH;
	case ALLOC_TYPE: return SQL_DESC_ALLOC_TYPE;
	case ARRAY_SIZE: return SQL_DESC_ARRAY_SIZE;
	case ARRAY_STATUS_PTR: return SQL_DESC_ARRAY_STATUS_PTR;
	case AUTO_UNIQUE_VALUE: return SQL_DESC_AUTO_UNIQUE_VALUE;
	case BASE_COLUMN_NAME: return SQL_DESC_BASE_COLUMN_NAME;
	case BASE_TABLE_NAME: return SQL_DESC_BASE_TABLE_NAME;
	case BIND_OFFSET_PTR: return SQL_DESC_BIND_OFFSET_PTR;
	case BIND_TYPE: return SQL_DESC_BIND_TYPE;
	case CASE_SENSITIVE: return SQL_DESC_CASE_SENSITIVE;
	case CATALOG_NAME: return SQL_DESC_CATALOG_NAME;
	case CONCISE_TYPE: return SQL_DESC_CONCISE_TYPE;
	case DATETIME_INTERVAL_PRECISION: return SQL_DESC_DATETIME_INTERVAL_PRECISION;
	case DISPLAY_SIZE: return SQL_DESC_DISPLAY_SIZE;
	case FIXED_PREC_SCALE: return SQL_DESC_FIXED_PREC_SCALE;
	case LABEL: return SQL_DESC_LABEL;
	case LITERAL_PREFIX: return SQL_DESC_LITERAL_PREFIX;
	case LITERAL_SUFFIX: return SQL_DESC_LITERAL_SUFFIX;
	case LOCAL_TYPE_NAME: return SQL_DESC_LOCAL_TYPE_NAME;
	case MAXIMUM_SCALE: return SQL_DESC_MAXIMUM_SCALE;
	case MINIMUM_SCALE: return SQL_DESC_MINIMUM_SCALE;
	case NUM_PREC_RADIX: return SQL_DESC_NUM_PREC_RADIX;
	case PARAMETER_TYPE: return SQL_DESC_PARAMETER_TYPE;
	case ROWS_PROCESSED_PTR: return SQL_DESC_ROWS_PROCESSED_PTR;
	case ROWVER: return SQL_DESC_ROWVER;
	case SCHEMA_NAME: return SQL_DESC_SCHEMA_NAME;
	case SEARCHABLE: return SQL_DESC_SEARCHABLE;
	case TYPE_NAME: return SQL_DESC_TYPE_NAME;
	case TABLE_NAME: return SQL_DESC_TABLE_NAME;
	case UNSIGNED: return SQL_DESC_UNSIGNED;
	case UPDATABLE: return SQL_DESC_UPDATABLE;
	}
	return 0;
}

public enum DataType {
	CHAR,
	VARCHAR,
	LONGVARCHAR,
	WCHAR,
	WVARCHAR,
	WLONGVARCHAR,
	DECIMAL,
	NUMERIC,
	SMALLINT,
	INTEGER,
	REAL,
	FLOAT,
	DOUBLE,
	BIT,
	TINYINT,
	BIGINT,
	BINARY,
	VARBINARY,
	LONGVARBINARY,
	TYPE_DATE,
	TYPE_TIME,
	TYPE_TIMESTAMP,
//	UTCDATETIME,					- not in Linux version
//	TYPE_UTCTIME,					- not in Linux version
	INTERVAL_MONTH,
	INTERVAL_YEAR,
	INTERVAL_YEAR_TO_MONTH,
	INTERVAL_DAY,
	INTERVAL_HOUR,
	INTERVAL_MINUTE,
	INTERVAL_SECOND,
	INTERVAL_DAY_TO_HOUR,
	INTERVAL_DAY_TO_MINUTE,
	INTERVAL_DAY_TO_SECOND,
	INTERVAL_HOUR_TO_MINUTE,
	INTERVAL_HOUR_TO_SECOND,
	INTERVAL_MINUTE_TO_SECOND,
	GUID
}

public enum ParameterDirection {
	IN,
	INOUT,
	OUT
}

public enum Indicator {
	NO_ACTION,				// the Strlen_or_IndPtr argument is ignored, do not modify *lengthInfo.
	NTS,					// the ParameterValuePtr is a null-terminated string, set *lengthInfo to SQL_NTS
	NULL_DATA,				// the parameter value is NULL. Set *lengthInfo to SQL_NULL_DATA
	DEFAULT_PARAM,			// for IN and INOUT parameters, use the default value of the parameter inbound.
	LEN_DATA_AT_EXEC,		// set the *Strlen_or_IndPtr to the SQL_LEN_DATA_AT_EXEC macro value of the length value.
	DATA_AT_EXEC,			// for INOUT and OUT parameters, SQLPutData will be used to write the parameter value
}

public class Statement {
	private SQLHSTMT _statement;
	private ColumnInfo[string] _columnMap;
	private boolean _mapBuilt;
	private SQLUSMALLINT[] _paramStatusArray;
	private SQLINTEGER _paramsProcessed;

	Statement(SQLHSTMT stmt) {
		_statement = stmt;
	}

	~Statement() {
		SQLFreeHandle(SQL_HANDLE_STMT, _statement);
	}

	public boolean, SqlReturn execDirect(string statementText) {
		SQLRETURN ret = SQLExecDirect(_statement, &statementText[0], statementText.length());
		_mapBuilt = false;
		_columnMap.clear();
		printf("execDirect('%s') ret = %d (%s)\n", statementText, ret, string(fromSQLRETURN(ret)));
		return SQL_SUCCEEDED(ret), fromSQLRETURN(ret);
	}

	public boolean, SqlReturn fetch() {
		SQLRETURN ret = SQLFetch(_statement);
		printf("fetch ret = %d (%s)\n", ret, string(fromSQLRETURN(ret)));
		return SQL_SUCCEEDED(ret), fromSQLRETURN(ret);
	}

	public boolean, SqlReturn fetchScroll(FetchOrientation orientation, long fetchOffset) {
		SQLSMALLINT o;
		switch (orientation) {
		case NEXT:		o = SQL_FETCH_NEXT;		break;
		case PRIOR:		o = SQL_FETCH_PRIOR;	break;
		case FIRST:		o = SQL_FETCH_FIRST;	break;
		case LAST:		o = SQL_FETCH_LAST;		break;
		case ABSOLUTE:	o = SQL_FETCH_ABSOLUTE;	break;
		case RELATIVE:	o = SQL_FETCH_RELATIVE;	break;
		}
		SQLRETURN ret = SQLFetchScroll(_statement, o, fetchOffset);
		return SQL_SUCCEEDED(ret), fromSQLRETURN(ret);
	}

	public string, boolean, SqlReturn stringColumnAttribute(int column, FieldIdentifier field) {
		string buffer;
		buffer.resize(512);
		SQLSMALLINT slp;
		SQLRETURN ret = SQLColAttribute(_statement, SQLUSMALLINT(column), sqlField(field), &buffer[0], SQLSMALLINT(buffer.length()), &slp, null);
		if (SQL_SUCCEEDED(ret)) {
			buffer.resize(slp);
			return buffer, true, fromSQLRETURN(ret);
		} else
			return null, false, fromSQLRETURN(ret);
	}

	public long, boolean, SqlReturn integerColumnAttribute(int column, FieldIdentifier field) {
		string buffer;
		buffer.resize(512);
		SQLSMALLINT slp;
		SQLLEN n;
		SQLRETURN ret = SQLColAttribute(_statement, SQLUSMALLINT(column), sqlField(field), null, 0, null, &n);
		if (SQL_SUCCEEDED(ret)) {
			return n, true, fromSQLRETURN(ret);
		} else
			return 0, false, fromSQLRETURN(ret);
	}

	public long, boolean getLong(int column) {
		long v;
		SQLRETURN ret = SQLGetData(_statement, SQLUSMALLINT(column), SQL_C_SBIGINT, &v, v.bytes, null);
		return v, SQL_SUCCEEDED(ret);
	}

	public string, boolean getString(int column, int length) {
		string s;
		s.resize(length);
		SQLLEN actual;
		SQLRETURN ret;
		ret = SQLGetData(_statement, SQLUSMALLINT(column), SQL_C_CHAR, &s[0], s.length(), &actual);
		printf("getString %d ret = %d (%s)\n", column, ret, string(fromSQLRETURN(ret)));
		if (SQL_SUCCEEDED(ret)) {
			printf("actual = %d s = '%s'\n", actual, s);
			if (actual == -1)
				s = null;
			else
				s.resize(int(actual));
			return s, true;
		} else
			return null, false;
	}

	public Timestamp, boolean getTimestamp(int column) {
		Timestamp t;
		SQLLEN actual;
		SQLRETURN ret;
		ret = SQLGetData(_statement, SQLUSMALLINT(column), SQL_C_TIMESTAMP, &t, t.bytes, &actual);
		if (SQL_SUCCEEDED(ret)) {
			if (actual == -1)
				return Timestamp.NULL, true;
			else
				return t, true;
		} else
			return Timestamp.NULL, false;
	}


	/**
	 * Return true if the cursor for this statement is scrollable. If so, fetchScroll can do interesting
	 * things, otherwise only fetchScroll FetchOrientation.NEXT (which is equivalent to fetch()) is allowed.
	 */
	public boolean getCursorScrollable() {
		long v;
		SQLRETURN ret = SQLGetStmtAttr(_statement, SQL_ATTR_CURSOR_SCROLLABLE, &v, 0, null);
		if (SQL_SUCCEEDED(ret))
			return v == SQL_SCROLLABLE;
		else	// should perhaps throw an exception?
			return false;
	}

	public boolean setCursorScrollable(boolean scrollable) {
		return SQL_SUCCEEDED(SQLSetStmtAttr(_statement, SQL_ATTR_CURSOR_SCROLLABLE, 
								address(scrollable ? SQL_SCROLLABLE : SQL_NONSCROLLABLE), 0));
	}

	public int, boolean, SqlReturn numResultCols() {
		SQLSMALLINT columns;

		SQLRETURN ret = SQLNumResultCols(_statement, &columns);
		return columns, SQL_SUCCEEDED(ret), fromSQLRETURN(ret);
	}
	/**
	 * ODBC manages parameters through something called the Parameter Array. It is defined by several
	 * statement attributes. If you do not execute any stored procedures or statements that take parameters,
	 * you can ignore this method. If you do use stored procedures or have prepared statements that take
	 * parameters, you will need to set the array size to the maximum you will be using with this Statement
	 * object.
	 */
	public boolean setParameterArraySize(int n) {
		_paramStatusArray.resize(n);
		SQLRETURN ret;
		ret = SQLSetStmtAttr(_statement, SQL_ATTR_PARAMSET_SIZE, address(n), 0);
		if (!SQL_SUCCEEDED(ret))
			return false;
		ret = SQLSetStmtAttr(_statement, SQL_ATTR_PARAM_STATUS_PTR, &_paramStatusArray[0], n);
		if (!SQL_SUCCEEDED(ret))
			return false;
		if (n > 0)
			ret = SQLSetStmtAttr(_statement, SQL_ATTR_PARAMS_PROCESSED_PTR, &_paramsProcessed, 0);
		else
			ret = SQLSetStmtAttr(_statement, SQL_ATTR_PARAMS_PROCESSED_PTR, null, 0);
		return SQL_SUCCEEDED(ret);
	}
	/**
 	 * Binds a buffer to a parameter. Each parameter in a statement being executed must be bound to a memory location
	 * to hold that data while the statement is being processed.
	 *
	 * PARAMETERS
	 * 	indicator
	 */
	public boolean, SqlReturn bindParameter(int parameterNumber, ParameterDirection parameterDirection, DataType dataType, long columnSize,
					int decimalDigits, address parameterValuePtr, long bufferLength, Indicator indicator, ref<long> lengthInfo) {
		switch (indicator) {
		case	NTS:
		case	NULL_DATA:
		case	DEFAULT_PARAM:
		case	DATA_AT_EXEC:
			if (lengthInfo != null)
				*lengthInfo = indicatorMap[indicator];
			break;
		}
		printf("bp #%d %s %s %d %d %p %d %s %p\n", parameterNumber, string(parameterDirection), string(dataType), columnSize, decimalDigits, parameterValuePtr, bufferLength, string(indicator), lengthInfo);
		printf("vt %d pt %d *lengthInfo %d\n", valueType[dataType], parameterType[dataType], lengthInfo == null ? -7777 : *lengthInfo);
		SQLRETURN ret = SQLBindParameter(_statement, SQLUSMALLINT(parameterNumber), parameterDirectionMap[parameterDirection],
					valueType[dataType], parameterType[dataType], columnSize, SQLSMALLINT(decimalDigits), parameterValuePtr,
					bufferLength, lengthInfo);
		printf("bindParameter ret = %d (%s)\n", ret, string(fromSQLRETURN(ret)));
		return SQL_SUCCEEDED(ret), fromSQLRETURN(ret);
	}

	public SqlReturn moreResults() {
		SQLRETURN ret = SQLMoreResults(_statement);
		printf("moreResults ret = %d (%s)\n", ret, string(fromSQLRETURN(ret)));
		
		return fromSQLRETURN(ret);
	}

	public void inParameter(int param, DataType dataType, var value) {
	}

	public void inoutParameter(int param, DataType dataType, var value) {
		// Parameter binding is the same for in and inout parameters. The difference is that the code will extract
		// the out parameters after a call.
		inParameter(param, dataType, value);
	}

//	public void outParameter(int param, DataType dataType, class type) {
//	}
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
		SQLGetDiagRec(SQL_HANDLE_STMT, _statement, SQLSMALLINT(record), &sqlstate[0], &nativeError, 
								&messageText[0],SQLSMALLINT( messageText.length()), &actual);
		messageText.resize(actual);
		return sqlstate, nativeError, messageText;
	}
}

private class ColumnInfo {
	string name;
	int type;
	boolean isNullable;
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

public enum FetchOrientation {
	NEXT,
	PRIOR,
	FIRST,
	LAST,
	ABSOLUTE,
	RELATIVE,
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
	
public class Timestamp {
	public short year;
	public char month;
	public char day;
	public char hour;
	public char minute;
	public char second;
	public unsigned fraction;			// in nanoseconds;

	public Timestamp() {
		fraction = unsigned.MAX_VALUE;
	}

	public Timestamp(int year, int month, int day, int hour, int minute, int second, unsigned fraction) {
		this.year = short(year);
		this.month = char(month);
		this.day = char(day);
		this.hour = char(hour);
		this.minute = char(minute);
		this.second = char(second);
		this.fraction = fraction;
	}

	public boolean isNULL() {
		return fraction == unsigned.MAX_VALUE;
	}

	public static Timestamp NULL;
}

public class Date {
	short year;
	char month;
	char day;
}

public class Time {
	char hour;
	char minute;
	char second;
}

// From here on down is the ODBC interface definition, which is mostly not exposed in favor of the more
// 'classy' approach that would feel natural to a Parasol developer.

@Constant
private SQLSMALLINT SQL_HANDLE_ENV = 1;
@Constant
private SQLSMALLINT SQL_HANDLE_DBC = 2;
@Constant
private SQLSMALLINT SQL_HANDLE_STMT = 3;
@Constant
private SQLSMALLINT SQL_HANDLE_DESC = 4;

private SQLHANDLE SQL_NULL_HANDLE = null;

private class SQLSMALLINT = short;
private class SQLUSMALLINT = char;

private class SQLINTEGER = long;
private class SQLLEN = long;
private class SQLULEN = long;

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

// Environment attributes
private SQLINTEGER SQL_ATTR_ODBC_VERSION = 200;
private SQLINTEGER SQL_ATTR_CONNECTION_POOLING = 201;
private SQLINTEGER SQL_ATTR_CP_MATCH = 202;

// Statement attributes
private SQLINTEGER SQL_ATTR_CURSOR_SCROLLABLE = -1;
private SQLINTEGER SQL_ATTR_PARAM_STATUS_PTR			= 20;
private SQLINTEGER SQL_ATTR_PARAMS_PROCESSED_PTR		= 21;
private SQLINTEGER SQL_ATTR_PARAMSET_SIZE				= 22;

private long SQL_OV_ODBC2 = 2;
private long SQL_OV_ODBC3 = 3;

private long SQL_CP_OFF	= 0;
private long SQL_CP_ONE_PER_DRIVER = 1;
private long SQL_CP_ONE_PER_HENV = 2;

/* SQL_ATTR_CURSOR_SCROLLABLE values */
private long SQL_NONSCROLLABLE = 0;
private long SQL_SCROLLABLE = 1;

/* values for SQL_ATTR_CP_MATCH */
private long SQL_CP_STRICT_MATCH = 0;
private long SQL_CP_RELAXED_MATCH = 1;

@Constant
private SQLSMALLINT SQL_NTS = SQLSMALLINT(-3);

private SQLUSMALLINT SQL_DRIVER_NOPROMPT =             0;
private SQLUSMALLINT SQL_DRIVER_COMPLETE =             1;
private SQLUSMALLINT SQL_DRIVER_PROMPT =               2;
private SQLUSMALLINT SQL_DRIVER_COMPLETE_REQUIRED =    3;

/* Codes used for FetchOrientation in SQLFetchScroll(),
   and in SQLDataSources()
*/
private SQLSMALLINT SQL_FETCH_NEXT = 1;
private SQLSMALLINT SQL_FETCH_FIRST = 2;

/* Other codes used for FetchOrientation in SQLFetchScroll() */
private SQLSMALLINT SQL_FETCH_LAST = 3;
private SQLSMALLINT SQL_FETCH_PRIOR = 4;
private SQLSMALLINT SQL_FETCH_ABSOLUTE = 5;
private SQLSMALLINT SQL_FETCH_RELATIVE = 6;

private SQLSMALLINT SQL_SIGNED_OFFSET     =  SQLSMALLINT(-20);
private SQLSMALLINT SQL_UNSIGNED_OFFSET   =  SQLSMALLINT(-22);

/* SQL data type codes */
private SQLSMALLINT	SQL_UNKNOWN_TYPE	= 0;
private SQLSMALLINT SQL_CHAR            = 1;
private SQLSMALLINT SQL_NUMERIC   		= 2;
private SQLSMALLINT SQL_DECIMAL         = 3;
private SQLSMALLINT SQL_INTEGER  		= 4;
private SQLSMALLINT SQL_SMALLINT        = 5;
private SQLSMALLINT SQL_FLOAT           = 6;
private SQLSMALLINT SQL_REAL		    = 7;
private SQLSMALLINT SQL_DOUBLE          = 8;
private SQLSMALLINT SQL_DATETIME        = 9;
private SQLSMALLINT SQL_VARCHAR        = 12;

/* One-parameter shortcuts for date/time data types */
private SQLSMALLINT SQL_TYPE_DATE      = 91;
private SQLSMALLINT SQL_TYPE_TIME      = 92;
private SQLSMALLINT SQL_TYPE_TIMESTAMP = 93;

/* SQL extended datatypes */
private SQLSMALLINT SQL_DATE                                = 9;
private SQLSMALLINT SQL_INTERVAL							= 10;
private SQLSMALLINT SQL_TIME                                = 10;
private SQLSMALLINT SQL_TIMESTAMP                           = 11;
private SQLSMALLINT SQL_LONGVARCHAR                         = SQLSMALLINT(-1);
private SQLSMALLINT SQL_BINARY                              = SQLSMALLINT(-2);
private SQLSMALLINT SQL_VARBINARY                           = SQLSMALLINT(-3);
private SQLSMALLINT SQL_LONGVARBINARY                       = SQLSMALLINT(-4);
private SQLSMALLINT SQL_BIGINT                              = SQLSMALLINT(-5);
private SQLSMALLINT SQL_TINYINT                             = SQLSMALLINT(-6);
private SQLSMALLINT SQL_BIT                                 = SQLSMALLINT(-7);
private SQLSMALLINT SQL_GUID				= SQLSMALLINT(-11);

private SQLSMALLINT SQL_CODE_YEAR				= 1;
private SQLSMALLINT SQL_CODE_MONTH				= 2;
private SQLSMALLINT SQL_CODE_DAY				= 3;
private SQLSMALLINT SQL_CODE_HOUR				= 4;
private SQLSMALLINT SQL_CODE_MINUTE				= 5;
private SQLSMALLINT SQL_CODE_SECOND				= 6;
private SQLSMALLINT SQL_CODE_YEAR_TO_MONTH			= 7;
private SQLSMALLINT SQL_CODE_DAY_TO_HOUR			= 8;
private SQLSMALLINT SQL_CODE_DAY_TO_MINUTE			= 9;
private SQLSMALLINT SQL_CODE_DAY_TO_SECOND			= 10;
private SQLSMALLINT SQL_CODE_HOUR_TO_MINUTE			= 11;
private SQLSMALLINT SQL_CODE_HOUR_TO_SECOND			= 12;
private SQLSMALLINT SQL_CODE_MINUTE_TO_SECOND		= 13;

private SQLSMALLINT SQL_INTERVAL_YEAR					= SQLSMALLINT(100 + SQL_CODE_YEAR);
private SQLSMALLINT SQL_INTERVAL_MONTH					= SQLSMALLINT(100 + SQL_CODE_MONTH);
private SQLSMALLINT SQL_INTERVAL_DAY					= SQLSMALLINT(100 + SQL_CODE_DAY);
private SQLSMALLINT SQL_INTERVAL_HOUR					= SQLSMALLINT(100 + SQL_CODE_HOUR);
private SQLSMALLINT SQL_INTERVAL_MINUTE					= SQLSMALLINT(100 + SQL_CODE_MINUTE);
private SQLSMALLINT SQL_INTERVAL_SECOND                	= SQLSMALLINT(100 + SQL_CODE_SECOND);
private SQLSMALLINT SQL_INTERVAL_YEAR_TO_MONTH			= SQLSMALLINT(100 + SQL_CODE_YEAR_TO_MONTH);
private SQLSMALLINT SQL_INTERVAL_DAY_TO_HOUR			= SQLSMALLINT(100 + SQL_CODE_DAY_TO_HOUR);
private SQLSMALLINT SQL_INTERVAL_DAY_TO_MINUTE			= SQLSMALLINT(100 + SQL_CODE_DAY_TO_MINUTE);
private SQLSMALLINT SQL_INTERVAL_DAY_TO_SECOND			= SQLSMALLINT(100 + SQL_CODE_DAY_TO_SECOND);
private SQLSMALLINT SQL_INTERVAL_HOUR_TO_MINUTE			= SQLSMALLINT(100 + SQL_CODE_HOUR_TO_MINUTE);
private SQLSMALLINT SQL_INTERVAL_HOUR_TO_SECOND			= SQLSMALLINT(100 + SQL_CODE_HOUR_TO_SECOND);
private SQLSMALLINT SQL_INTERVAL_MINUTE_TO_SECOND		= SQLSMALLINT(100 + SQL_CODE_MINUTE_TO_SECOND);

private SQLSMALLINT SQL_WCHAR		 	= SQLSMALLINT(-8);
private SQLSMALLINT SQL_WVARCHAR	 	= SQLSMALLINT(-9);
private SQLSMALLINT SQL_WLONGVARCHAR 	= SQLSMALLINT(-10);

/* C datatype to SQL datatype mapping      SQL types
                                           ------------------- */
private SQLSMALLINT SQL_C_CHAR    = SQL_CHAR;             /* CHAR, VARCHAR, DECIMAL, NUMERIC */
private SQLSMALLINT SQL_C_WCHAR   = SQL_WCHAR;
private SQLSMALLINT SQL_C_LONG    = SQL_INTEGER;          /* INTEGER                      */
private SQLSMALLINT SQL_C_SHORT   = SQL_SMALLINT;         /* SMALLINT                     */
private SQLSMALLINT SQL_C_FLOAT   = SQL_REAL;             /* REAL                         */
private SQLSMALLINT SQL_C_DOUBLE  = SQL_DOUBLE;           /* FLOAT, DOUBLE                */
private SQLSMALLINT	SQL_C_NUMERIC	=	SQL_NUMERIC;
private SQLSMALLINT SQL_C_DEFAULT = 99;

/* C datatype to SQL datatype mapping */
private SQLSMALLINT SQL_C_DATE   =    SQL_DATE;
private SQLSMALLINT SQL_C_TIME   =    SQL_TIME;
private SQLSMALLINT SQL_C_TIMESTAMP = SQL_TIMESTAMP;
private SQLSMALLINT SQL_C_TYPE_DATE					= SQL_TYPE_DATE;
private SQLSMALLINT SQL_C_TYPE_TIME					= SQL_TYPE_TIME;
private SQLSMALLINT SQL_C_TYPE_TIMESTAMP			= SQL_TYPE_TIMESTAMP;
private SQLSMALLINT SQL_C_INTERVAL_YEAR				= SQL_INTERVAL_YEAR;
private SQLSMALLINT SQL_C_INTERVAL_MONTH			= SQL_INTERVAL_MONTH;
private SQLSMALLINT SQL_C_INTERVAL_DAY				= SQL_INTERVAL_DAY;
private SQLSMALLINT SQL_C_INTERVAL_HOUR				= SQL_INTERVAL_HOUR;
private SQLSMALLINT SQL_C_INTERVAL_MINUTE			= SQL_INTERVAL_MINUTE;
private SQLSMALLINT SQL_C_INTERVAL_SECOND			= SQL_INTERVAL_SECOND;
private SQLSMALLINT SQL_C_INTERVAL_YEAR_TO_MONTH	= SQL_INTERVAL_YEAR_TO_MONTH;
private SQLSMALLINT SQL_C_INTERVAL_DAY_TO_HOUR		= SQL_INTERVAL_DAY_TO_HOUR;
private SQLSMALLINT SQL_C_INTERVAL_DAY_TO_MINUTE	= SQL_INTERVAL_DAY_TO_MINUTE;
private SQLSMALLINT SQL_C_INTERVAL_DAY_TO_SECOND	= SQL_INTERVAL_DAY_TO_SECOND;
private SQLSMALLINT SQL_C_INTERVAL_HOUR_TO_MINUTE	= SQL_INTERVAL_HOUR_TO_MINUTE;
private SQLSMALLINT SQL_C_INTERVAL_HOUR_TO_SECOND	= SQL_INTERVAL_HOUR_TO_SECOND;
private SQLSMALLINT SQL_C_INTERVAL_MINUTE_TO_SECOND	= SQL_INTERVAL_MINUTE_TO_SECOND;
private SQLSMALLINT SQL_C_BINARY     = SQL_BINARY;
private SQLSMALLINT SQL_C_BIT        = SQL_BIT;
private SQLSMALLINT SQL_C_SBIGINT	= SQLSMALLINT(SQL_BIGINT+SQL_SIGNED_OFFSET);	   /* SIGNED BIGINT */
private SQLSMALLINT SQL_C_UBIGINT	= SQLSMALLINT(SQL_BIGINT+SQL_UNSIGNED_OFFSET);   /* UNSIGNED BIGINT */
private SQLSMALLINT SQL_C_TINYINT   = SQL_TINYINT;
private SQLSMALLINT SQL_C_SLONG      = SQLSMALLINT(SQL_C_LONG+SQL_SIGNED_OFFSET) ;   /* SIGNED INTEGER  */
private SQLSMALLINT SQL_C_SSHORT     = SQLSMALLINT(SQL_C_SHORT+SQL_SIGNED_OFFSET);   /* SIGNED SMALLINT */
private SQLSMALLINT SQL_C_STINYINT   = SQLSMALLINT(SQL_TINYINT+SQL_SIGNED_OFFSET);   /* SIGNED TINYINT  */
private SQLSMALLINT SQL_C_ULONG      = SQLSMALLINT(SQL_C_LONG+SQL_UNSIGNED_OFFSET);  /* UNSIGNED INTEGER*/
private SQLSMALLINT SQL_C_USHORT     = SQLSMALLINT(SQL_C_SHORT+SQL_UNSIGNED_OFFSET); /* UNSIGNED SMALLINT*/
private SQLSMALLINT SQL_C_UTINYINT   = SQLSMALLINT(SQL_TINYINT+SQL_UNSIGNED_OFFSET); /* UNSIGNED TINYINT*/

private SQLSMALLINT SQL_C_BOOKMARK   = SQL_C_UBIGINT;                     /* BOOKMARK        */

private SQLSMALLINT SQL_C_GUID	= SQL_GUID;

/* identifiers of fields in the SQL descriptor */
private SQLUSMALLINT SQL_DESC_COUNT                  = 1001;
private SQLUSMALLINT SQL_DESC_TYPE                   = 1002;
private SQLUSMALLINT SQL_DESC_LENGTH                 = 1003;
private SQLUSMALLINT SQL_DESC_OCTET_LENGTH_PTR       = 1004;
private SQLUSMALLINT SQL_DESC_PRECISION              = 1005;
private SQLUSMALLINT SQL_DESC_SCALE                  = 1006;
private SQLUSMALLINT SQL_DESC_DATETIME_INTERVAL_CODE = 1007;
private SQLUSMALLINT SQL_DESC_NULLABLE               = 1008;
private SQLUSMALLINT SQL_DESC_INDICATOR_PTR          = 1009;
private SQLUSMALLINT SQL_DESC_DATA_PTR               = 1010;
private SQLUSMALLINT SQL_DESC_NAME                   = 1011;
private SQLUSMALLINT SQL_DESC_UNNAMED                = 1012;
private SQLUSMALLINT SQL_DESC_OCTET_LENGTH           = 1013;
private SQLUSMALLINT SQL_DESC_ALLOC_TYPE             = 1099;

/* extended descriptor field */
private SQLUSMALLINT SQL_DESC_ARRAY_SIZE					= 20;
private SQLUSMALLINT SQL_DESC_ARRAY_STATUS_PTR				= 21;
private SQLUSMALLINT SQL_DESC_AUTO_UNIQUE_VALUE				= 11;
private SQLUSMALLINT SQL_DESC_BASE_COLUMN_NAME				= 22;
private SQLUSMALLINT SQL_DESC_BASE_TABLE_NAME				= 23;
private SQLUSMALLINT SQL_DESC_BIND_OFFSET_PTR				= 24;
private SQLUSMALLINT SQL_DESC_BIND_TYPE						= 25;
private SQLUSMALLINT SQL_DESC_CASE_SENSITIVE				= 12;
private SQLUSMALLINT SQL_DESC_CATALOG_NAME					= 17;
private SQLUSMALLINT SQL_DESC_CONCISE_TYPE					= 2;
private SQLUSMALLINT SQL_DESC_DATETIME_INTERVAL_PRECISION	= 26;
private SQLUSMALLINT SQL_DESC_DISPLAY_SIZE					= 6;
private SQLUSMALLINT SQL_DESC_FIXED_PREC_SCALE				= 9;
private SQLUSMALLINT SQL_DESC_LABEL							= 18;
private SQLUSMALLINT SQL_DESC_LITERAL_PREFIX				= 27;
private SQLUSMALLINT SQL_DESC_LITERAL_SUFFIX				= 28;
private SQLUSMALLINT SQL_DESC_LOCAL_TYPE_NAME				= 29;
private SQLUSMALLINT SQL_DESC_MAXIMUM_SCALE					= 30;
private SQLUSMALLINT SQL_DESC_MINIMUM_SCALE					= 31;
private SQLUSMALLINT SQL_DESC_NUM_PREC_RADIX				= 32;
private SQLUSMALLINT SQL_DESC_PARAMETER_TYPE				= 33;
private SQLUSMALLINT SQL_DESC_ROWS_PROCESSED_PTR			= 4;
private SQLUSMALLINT SQL_DESC_ROWVER						= 35;
private SQLUSMALLINT SQL_DESC_SCHEMA_NAME					= 16;
private SQLUSMALLINT SQL_DESC_SEARCHABLE					= 13;
private SQLUSMALLINT SQL_DESC_TYPE_NAME						= 14;
private SQLUSMALLINT SQL_DESC_TABLE_NAME					= 15;
private SQLUSMALLINT SQL_DESC_UNSIGNED						= 8;
private SQLUSMALLINT SQL_DESC_UPDATABLE						= 10;

@Constant
private SQLSMALLINT SQL_PARAM_INPUT = 1;
@Constant
private SQLSMALLINT SQL_PARAM_INPUT_OUTPUT = 2;
@Constant
private SQLSMALLINT SQL_PARAM_OUTPUT = 4;

@Constant
private SQLSMALLINT SQL_NULL_DATA = SQLSMALLINT(-1);
@Constant
private SQLSMALLINT SQL_DATA_AT_EXEC = SQLSMALLINT(-2);
@Constant
private SQLSMALLINT SQL_DEFAULT_PARAM = SQLSMALLINT(-5);

private boolean SQL_SUCCEEDED(SQLRETURN ret) {
	return (ret & ~1) == 0;
}

private SQLSMALLINT[ParameterDirection] parameterDirectionMap = [
	IN:		SQL_PARAM_INPUT,
	INOUT:	SQL_PARAM_INPUT_OUTPUT,
	OUT:	SQL_PARAM_OUTPUT
];

private SQLLEN[Indicator] indicatorMap = [
	NTS:			SQL_NTS,
	NULL_DATA:		SQL_NULL_DATA,
	DEFAULT_PARAM:	SQL_DEFAULT_PARAM,
	DATA_AT_EXEC:	SQL_DATA_AT_EXEC
];

SQLSMALLINT[DataType] parameterType = [
	CHAR:						SQL_CHAR,
	VARCHAR:					SQL_VARCHAR,
	LONGVARCHAR:				SQL_LONGVARCHAR,
	WCHAR:						SQL_WCHAR,
	WVARCHAR:					SQL_WVARCHAR,
	WLONGVARCHAR:				SQL_WLONGVARCHAR,
	DECIMAL:					SQL_DECIMAL,
	NUMERIC:					SQL_NUMERIC,
	SMALLINT:					SQL_SMALLINT,
	INTEGER:					SQL_INTEGER,
	REAL:						SQL_REAL,
	FLOAT:						SQL_FLOAT,
	DOUBLE:						SQL_DOUBLE,
	BIT:						SQL_BIT,
	TINYINT:					SQL_TINYINT,
	BIGINT:						SQL_BIGINT,
	BINARY:						SQL_BINARY,
	VARBINARY:					SQL_VARBINARY,
	LONGVARBINARY:				SQL_LONGVARBINARY,
	TYPE_DATE:					SQL_TYPE_DATE,
	TYPE_TIME:					SQL_TYPE_TIME,
	TYPE_TIMESTAMP:				SQL_TYPE_TIMESTAMP,
	INTERVAL_MONTH:				SQL_INTERVAL_MONTH,
	INTERVAL_YEAR:				SQL_INTERVAL_YEAR,
	INTERVAL_YEAR_TO_MONTH:		SQL_INTERVAL_YEAR_TO_MONTH,
	INTERVAL_DAY:				SQL_INTERVAL_DAY,
	INTERVAL_HOUR:				SQL_INTERVAL_HOUR,
	INTERVAL_MINUTE:			SQL_INTERVAL_MINUTE,
	INTERVAL_SECOND:			SQL_INTERVAL_SECOND,
	INTERVAL_DAY_TO_HOUR:		SQL_INTERVAL_DAY_TO_HOUR,
	INTERVAL_DAY_TO_MINUTE:		SQL_INTERVAL_DAY_TO_MINUTE,
	INTERVAL_DAY_TO_SECOND:		SQL_INTERVAL_DAY_TO_SECOND,
	INTERVAL_HOUR_TO_MINUTE:	SQL_INTERVAL_HOUR_TO_MINUTE,
	INTERVAL_HOUR_TO_SECOND:	SQL_INTERVAL_HOUR_TO_SECOND,
	INTERVAL_MINUTE_TO_SECOND:	SQL_INTERVAL_MINUTE_TO_SECOND,
	GUID:						SQL_GUID
];

SQLSMALLINT[DataType] valueType = [
	CHAR:						SQL_C_CHAR,
	VARCHAR:					SQL_C_CHAR,
	LONGVARCHAR:				SQL_C_CHAR,
	WCHAR:						SQL_C_WCHAR,
	WVARCHAR:					SQL_C_WCHAR,
	WLONGVARCHAR:				SQL_C_WCHAR,
	DECIMAL:					SQL_C_CHAR,
	NUMERIC:					SQL_C_NUMERIC,
	SMALLINT:					SQL_C_SSHORT,
	INTEGER:					SQL_C_SLONG,
	REAL:						SQL_C_FLOAT,
	FLOAT:						SQL_C_FLOAT,
	DOUBLE:						SQL_C_DOUBLE,
	BIT:						SQL_C_BIT,
	TINYINT:					SQL_C_STINYINT,
	BIGINT:						SQL_C_SBIGINT,
	BINARY:						SQL_C_BINARY,
	VARBINARY:					SQL_C_BINARY,
	LONGVARBINARY:				SQL_C_BINARY,
	TYPE_DATE:					SQL_C_TYPE_DATE,
	TYPE_TIME:					SQL_C_TYPE_TIME,
	TYPE_TIMESTAMP:				SQL_C_TYPE_TIMESTAMP,
	INTERVAL_MONTH:				SQL_C_INTERVAL_MONTH,
	INTERVAL_YEAR:				SQL_C_INTERVAL_YEAR,
	INTERVAL_YEAR_TO_MONTH:		SQL_C_INTERVAL_YEAR_TO_MONTH,
	INTERVAL_DAY:				SQL_C_INTERVAL_DAY,
	INTERVAL_HOUR:				SQL_C_INTERVAL_HOUR,
	INTERVAL_MINUTE:			SQL_C_INTERVAL_MINUTE,
	INTERVAL_SECOND:			SQL_C_INTERVAL_SECOND,
	INTERVAL_DAY_TO_HOUR:		SQL_C_INTERVAL_DAY_TO_HOUR,
	INTERVAL_DAY_TO_MINUTE:		SQL_C_INTERVAL_DAY_TO_MINUTE,
	INTERVAL_DAY_TO_SECOND:		SQL_C_INTERVAL_DAY_TO_SECOND,
	INTERVAL_HOUR_TO_MINUTE:	SQL_C_INTERVAL_HOUR_TO_MINUTE,
	INTERVAL_HOUR_TO_SECOND:	SQL_C_INTERVAL_HOUR_TO_SECOND,
	INTERVAL_MINUTE_TO_SECOND:	SQL_C_INTERVAL_MINUTE_TO_SECOND,
	GUID:						SQL_C_GUID
];

@Linux("libodbc.so", "SQLAllocHandle")
private abstract SQLRETURN SQLAllocHandle(SQLSMALLINT HandleType, SQLHANDLE InputHandle, ref<SQLHANDLE> OutputHandlePtr);

@Linux("libodbc.so", "SQLBindParameter")
private abstract SQLRETURN SQLBindParameter(SQLHSTMT StatementHandle, SQLUSMALLINT ParameterNumber, SQLSMALLINT InputOutputType,
						SQLSMALLINT ValueType, SQLSMALLINT ParameterType, SQLULEN ColumnSize, SQLSMALLINT DecimalDigits, 
						address ParameterValuePtr, SQLLEN BufferLength, ref<SQLLEN> Strlenor_IndPtr);

@Linux("libodbc.so", "SQLColAttribute")
private abstract SQLRETURN SQLColAttribute(SQLHSTMT StatementHandle, SQLUSMALLINT ColumnNumber, SQLUSMALLINT FieldIdentifier,
						SQLPOINTER CharacerAttributePtr, SQLSMALLINT BufferLength, ref<SQLSMALLINT> StringLengthPtr, 
						ref<SQLLEN> NumericAttributePtr);

@Linux("libodbc.so", "SQLConnect")
private abstract SQLRETURN SQLConnect(SQLHDBC ConnectionHadle, pointer<byte> ServerName, SQLSMALLINT NameLength1,
						pointer<byte> UserName, SQLSMALLINT NameLength2, pointer<byte> Authentication, SQLSMALLINT NameLength3);

@Linux("libodbc.so", "SQLDriverConnect")
private abstract SQLRETURN SQLDriverConnect(SQLHDBC ConnectionHadle, SQLHWND WindowHandle, pointer<byte> InConnectionString,
						SQLSMALLINT StringLength1, pointer<byte> OutConnectionString, SQLSMALLINT BufferLength, 
						ref<SQLSMALLINT> StringLength2Ptr, SQLUSMALLINT DriverCompletion);

@Linux("libodbc.so", "SQLExecDirect")
private abstract SQLRETURN SQLExecDirect(SQLHSTMT StatementHandle, pointer<byte> StatementText, SQLINTEGER TextLength);

@Linux("libodbc.so", "SQLFetch")
private abstract SQLRETURN SQLFetch(SQLHSTMT StatementHandle);

@Linux("libodbc.so", "SQLFetchScroll")
private abstract SQLRETURN SQLFetchScroll(SQLHSTMT StatementHandle, SQLSMALLINT FetchOrientation, SQLLEN FetchOffset);

@Linux("libodbc.so", "SQLFreeHandle")
private abstract SQLRETURN SQLFreeHandle(SQLSMALLINT HandleType, SQLHANDLE InputHandle);

@Linux("libodbc.so", "SQLGetData")
private abstract SQLRETURN SQLGetData(SQLHSTMT StatementHandle, SQLUSMALLINT Col_or_Param_Num, SQLSMALLINT TargetType,
						SQLPOINTER TargetValuePtr, SQLLEN BufferLength, ref<SQLLEN> Strlen_or_IndPtr);

@Linux("libodbc.so", "SQLGetDiagRec")
private abstract SQLRETURN SQLGetDiagRec(SQLSMALLINT HandleType, SQLHANDLE Handle, SQLSMALLINT RecNumber, pointer<byte> SQLState,
						ref<SQLINTEGER> NativeErrorPtr, pointer<byte> MessageText, SQLSMALLINT BufferLength, ref<SQLSMALLINT> TextLengthPtr);

@Linux("libodbc.so", "SQLGetStmtAttr")
private abstract SQLRETURN SQLGetStmtAttr(SQLHSTMT StatementHandle, SQLINTEGER Attribute, SQLPOINTER ValuePtr, SQLINTEGER BufferLength, 
						ref<SQLINTEGER> StringLengthPtr);

@Linux("libodbc.so", "SQLMoreResults")
private abstract SQLRETURN SQLMoreResults(SQLHSTMT StatementHandle);

@Linux("libodbc.so", "SQLNumResultCols")
private abstract SQLRETURN SQLNumResultCols(SQLHSTMT StatementHandle, ref<SQLSMALLINT> ColumnCountPtr);

@Linux("libodbc.so", "SQLSetEnvAttr")
private abstract SQLRETURN SQLSetEnvAttr(SQLHENV EnvironmentHandle, SQLINTEGER Attribute, SQLPOINTER ValuePtr, SQLINTEGER StringLength);

@Linux("libodbc.so", "SQLSetStmtAttr")
private abstract SQLRETURN SQLSetStmtAttr(SQLHSTMT StatementHandle, SQLINTEGER Attribute, SQLPOINTER ValuePtr, SQLINTEGER StringLength);
