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
/**
 * Provides facilities for using ODBC to interact with SQL databases.
 *
 * You start your interaction with ODBC by creating an instance of an {@link Environment}
 * object.
 */
namespace parasol:sql;

import parasol:log;
import parasol:time;

private ref<log.Logger> logger = log.getLogger("parasol.sql");
/**
 * The ODBC Version to use.
 */
public enum ODBCVersion {
	/**
	 * This version shoulld only be used for backward compaticility with older drivers.
	 */
	V2,
	/**
	 * This is the preferred version to use.
	 */
	V3,
}
/**
 * Specifies the type of connection pooling to use.
 */
public enum ConnectionPooling {
	/**
	 * Do not use connection pooling.
	 */
	OFF(SQL_CP_OFF),
	/**
	 * Use one connection per driver.
	 */
	ONE_PER_DRIVER(SQL_CP_ONE_PER_DRIVER),
	/**
	 * Use one connection per environment.
	 */
	ONE_PER_ENVIRONMENT(SQL_CP_ONE_PER_HENV),
	;

	long _pooling;

	ConnectionPooling(long p) {
		_pooling = p;
	}

	address pooling() {
		return address(_pooling);
	}
}
/**
 * A configuration object that is used to obtain database connections.
 *
 * The configuration information contained in the environment are:
 *
 *<ul>
 *  <li> Connection Pooling. Whether and how to pool connections.
 *  <li> ODBC Version. Used to select drivers and protocol versions.
 *</ul>
 */
public class Environment {
	private SQLHENV _environment;
	/**
	 * Create a new ODBC environment.
	 *
	 * The new environment is set to use ODBC version 3.
	 */
	public Environment() {
		SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &_environment);
		setODBCVersion(ODBCVersion.V3);
	}

	~Environment() {
		SQLFreeHandle(SQL_HANDLE_ENV, _environment);
	}
	/**
	 * Get a new datbase connection.
	 *
	 * @return A reference to a database connection object, or null is a connection could not be obtained.
	 */
	public ref<DBConnection> getDBConnection() {
		SQLHDBC dbc;
		SQLAllocHandle(SQL_HANDLE_DBC, _environment, &dbc);
		return new DBConnection(dbc);
	}
	/**
	 * Set connection pooling parameters.
	 *
	 * If this operation failed because of strictMatch, the state of the connection pooling type may have
 	 * been changed.
	 *
	 * @param pooling The type of connection pooling to use.
	 * @param strictMatch If true, is strict matching on pooled connections, if false, use relaxed matching.
	 *
	 * @return true if the operation succeeded and the parameters have been set, false if the operation failed.
	 */
	public boolean setConnnectionPooling(ConnectionPooling pooling, boolean strictMatch) {
		if (!SQL_SUCCEEDED(SQLSetEnvAttr(_environment, SQL_ATTR_CONNECTION_POOLING, pooling.pooling(), 0)))
			return false;
		return SQL_SUCCEEDED(SQLSetEnvAttr(_environment, SQL_ATTR_CP_MATCH, 
								address(strictMatch ? SQL_CP_STRICT_MATCH : SQL_CP_RELAXED_MATCH), 0));
	}
	/**
	 * Set the ODBC Version
	 *
	 * @param version The new version to use.
	 *
	 * @return true if the operation succeeded, false otherwise.
	 */
	public boolean setODBCVersion(ODBCVersion version) {
		return SQL_SUCCEEDED(SQLSetEnvAttr(_environment, SQL_ATTR_ODBC_VERSION, 
								address(version == ODBCVersion.V2 ? SQL_OV_ODBC2 : SQL_OV_ODBC3), 0));
	}
	/**
	 * Collects the SQL diagnostic record information.
	 *
	 * This information can be extracted to obtain a more detailed explanation of the cause of an 
	 * operation's failure.
	 *
	 * @return The SQLSTATE string.
	 * @return The numeric native error code.
	 * @return The message text.
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
	/**
	 * prompt even if the connection string is correct and has enough information to connect
	 */
	PROMPT(SQL_DRIVER_PROMPT),
	/**
	 * prompt if the connection string is incorrect or incomplete
	 */
	COMPLETE(SQL_DRIVER_COMPLETE),
	/**
	 * prompt if the connection string is incorrect or incomplete, only allow required info to be entered
	 */
	COMPLETE_REQUIRED(SQL_DRIVER_COMPLETE_REQUIRED),
	/**
	 * never prompt
	 */
	NOPROMPT(SQL_DRIVER_NOPROMPT),
	;

	SQLUSMALLINT _completionCode;

	DriverCompletion(SQLUSMALLINT completionCode) {
		completionCode = _completionCode;
	}

	SQLUSMALLINT completionCode() {
		return _completionCode;
	}
}
/**
 * A Database Connection
 *
 * A series of queries and modification statements can be issued to a single database server
 * through one connection. Because database connections consume valuable resources in a server,
 * connections should be dropped (the object should be deleted) when not in use.
 */
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
	 * @param dataSourceName A defined data source.
	 * @param userName A user id.
	 * @param authenticaion Authentication string (typically the password).
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
	 * 	@param url The connection string, with the DSN plus additional attributes as needed.
	 *	@param completion Specifies the prompting behavior of the Data Manager (see DriverCompletion for details). 
	 */
	public boolean, string, SqlReturn driverConnect(string url, DriverCompletion completion) {
		string outstr;
		outstr.resize(1024);
		SQLSMALLINT outstrlen;
	
		SQLRETURN ret = SQLDriverConnect(_connection, null, url.c_str(), SQL_NTS, &outstr[0], SQLSMALLINT(outstr.length()), 
											&outstrlen, completion.completionCode());
		if (SQL_SUCCEEDED(ret)) {
			outstr.resize(outstrlen);
//			printf("Resulting connection string is '%s'\n", outstr);
			return true, outstr, fromSQLRETURN(ret);
		} else {
			printf("return value = %d\n", ret);
			return false, null, fromSQLRETURN(ret);
		}
	}
	/**
	 * Get a new statement for this connection.
	 *
	 * @return The new Statement object.
	 */
	public ref<Statement> getStatement() {
		SQLHSTMT stmt;
		SQLAllocHandle(SQL_HANDLE_STMT, _connection, &stmt);
		return new Statement(stmt);
	}
	/**
	 * Collects the SQL diagnostic record information.
	 *
	 * @return The SQLSTATE string.
	 * @return The numeric native error code.
	 * @return The message text.
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
	/**
	 * Commit a transaction.
	 *
	 * @return true if the transaction was committed.
	 */
	public boolean commit() {
		SQLRETURN ret = SQLEndTran(SQL_HANDLE_DBC, _connection, SQL_COMMIT);
		return SQL_SUCCEEDED(ret);	
	}
	/**
	 * Roll back a transaction
	 *
	 * @return true if the transaction was rolled back.
	 */
	public boolean rollback() {
		SQLRETURN ret = SQLEndTran(SQL_HANDLE_DBC, _connection, SQL_ROLLBACK);
		return SQL_SUCCEEDED(ret);	
	}
}

public enum FieldIdentifier {
	COUNT(SQL_DESC_COUNT),
	TYPE(SQL_DESC_TYPE),
	LENGTH(SQL_DESC_LENGTH),
	OCTET_LENGTH_PTR(SQL_DESC_OCTET_LENGTH_PTR),
	PRECISION(SQL_DESC_PRECISION),
	SCALE(SQL_DESC_SCALE),
	DATETIME_INTERVAL_CODE(SQL_DESC_DATETIME_INTERVAL_CODE),
	NULLABLE(SQL_DESC_NULLABLE),
	INDICATOR_PTR(SQL_DESC_INDICATOR_PTR),
	DATA_PTR(SQL_DESC_DATA_PTR),
	NAME(SQL_DESC_NAME),
	UNNAMED(SQL_DESC_UNNAMED),
	OCTET_LENGTH(SQL_DESC_OCTET_LENGTH),
	ALLOC_TYPE(SQL_DESC_ALLOC_TYPE),
	ARRAY_SIZE(SQL_DESC_ARRAY_SIZE),
	ARRAY_STATUS_PTR(SQL_DESC_ARRAY_STATUS_PTR),
	AUTO_UNIQUE_VALUE(SQL_DESC_AUTO_UNIQUE_VALUE),
	BASE_COLUMN_NAME(SQL_DESC_BASE_COLUMN_NAME),
	BASE_TABLE_NAME(SQL_DESC_BASE_TABLE_NAME),
	BIND_OFFSET_PTR(SQL_DESC_BIND_OFFSET_PTR),
	BIND_TYPE(SQL_DESC_BIND_TYPE),
	CASE_SENSITIVE(SQL_DESC_CASE_SENSITIVE),
	CATALOG_NAME(SQL_DESC_CATALOG_NAME),
	CONCISE_TYPE(SQL_DESC_CONCISE_TYPE),
	DATETIME_INTERVAL_PRECISION(SQL_DESC_DATETIME_INTERVAL_PRECISION),
	DISPLAY_SIZE(SQL_DESC_DISPLAY_SIZE),
	FIXED_PREC_SCALE(SQL_DESC_FIXED_PREC_SCALE),
	LABEL(SQL_DESC_LABEL),
	LITERAL_PREFIX(SQL_DESC_LITERAL_PREFIX),
	LITERAL_SUFFIX(SQL_DESC_LITERAL_SUFFIX),
	LOCAL_TYPE_NAME(SQL_DESC_LOCAL_TYPE_NAME),
	MAXIMUM_SCALE(SQL_DESC_MAXIMUM_SCALE),
	MINIMUM_SCALE(SQL_DESC_MINIMUM_SCALE),
	NUM_PREC_RADIX(SQL_DESC_NUM_PREC_RADIX),
	PARAMETER_TYPE(SQL_DESC_PARAMETER_TYPE),
	ROWS_PROCESSED_PTR(SQL_DESC_ROWS_PROCESSED_PTR),
	ROWVER(SQL_DESC_ROWVER),
	SCHEMA_NAME(SQL_DESC_SCHEMA_NAME),
	SEARCHABLE(SQL_DESC_SEARCHABLE),
	TYPE_NAME(SQL_DESC_TYPE_NAME),
	TABLE_NAME(SQL_DESC_TABLE_NAME),
	UNSIGNED(SQL_DESC_UNSIGNED),
	UPDATABLE(SQL_DESC_UPDATABLE),
	;

	SQLUSMALLINT _sqlField;

	FieldIdentifier(SQLUSMALLINT sqlField) {
		_sqlField = sqlField;
	}

	SQLUSMALLINT sqlField() {
		return _sqlField;
	}
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
//		printf("execDirect('%s') ret = %d (%s)\n", statementText, ret, string(fromSQLRETURN(ret)));
		return SQL_SUCCEEDED(ret), fromSQLRETURN(ret);
	}

	public boolean, SqlReturn fetch() {
		SQLRETURN ret = SQLFetch(_statement);
//		printf("fetch ret = %d (%s)\n", ret, string(fromSQLRETURN(ret)));
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
		SQLRETURN ret = SQLColAttribute(_statement, SQLUSMALLINT(column), field.sqlField(), &buffer[0], SQLSMALLINT(buffer.length()), &slp, null);
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
		SQLRETURN ret = SQLColAttribute(_statement, SQLUSMALLINT(column), field.sqlField(), null, 0, null, &n);
		if (SQL_SUCCEEDED(ret)) {
			return n, true, fromSQLRETURN(ret);
		} else
			return 0, false, fromSQLRETURN(ret);
	}
	/**
	 * Get an integer column's value from a record set.
	 *
	 * @param The column number.
	 *
	 * @return The integer value of the column.
	 * @return true if the fetch operation succeeded, false otherwise.
	 */
	public long, boolean getLong(int column) {
		long v;
		SQLRETURN ret = SQLGetData(_statement, SQLUSMALLINT(column), SQL_C_SBIGINT, &v, v.bytes, null);
		return v, SQL_SUCCEEDED(ret);
	}
	/**
	 * Get a nullable integer column's value from a record set.
	 *
	 * @param The column number.
	 *
	 * @return The integer value of the column, assuming the second return value is false. If the second reutrn value
	 * is true, then this value is undefined and should be ignored.
	 * @return true if the value is actually NULL. If false, the column's value is the first returned object.
	 * @return true if the fetch operation succeeded, false otherwise.
	 */
	public long, boolean, boolean getNullableLong(int column) {
		long v;
		SQLLEN indicator;
		SQLRETURN ret = SQLGetData(_statement, SQLUSMALLINT(column), SQL_C_SBIGINT, &v, v.bytes, &indicator);
		return v, indicator == SQL_NULL_DATA, SQL_SUCCEEDED(ret);
	}

	public string, boolean getString(int column, int length) {
		string s;
		s.resize(length);
		SQLLEN actual;
		SQLRETURN ret;
		ret = SQLGetData(_statement, SQLUSMALLINT(column), SQL_C_CHAR, &s[0], s.length(), &actual);
//		printf("getString %d ret = %d (%s)\n", column, ret, string(fromSQLRETURN(ret)));
		if (SQL_SUCCEEDED(ret)) {
//			printf("actual = %d s = %p '%s'\n", actual, *ref<address>(&s), s);
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
			if (actual == SQL_NULL_DATA)
				return Timestamp.NULL, true;
			else
				return t, true;
		} else {
			string sqlState;
			long nativeError;
			string message;
			(sqlState, nativeError, message) = getDiagnosticRecord(1);
			logger.error( "getTimestamp Error %s %d %s\n", sqlState, nativeError, message);
			return Timestamp.NULL, false;
		}
	}


	/**
	 * @return true if the cursor for this statement is scrollable. If so, fetchScroll can do interesting
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
//		printf("bp #%d %s %s %d %d %p %d %s %p\n", parameterNumber, string(parameterDirection), string(dataType), columnSize, decimalDigits, parameterValuePtr, bufferLength, string(indicator), lengthInfo);
//		printf("vt %d pt %d *lengthInfo %d\n", valueType[dataType], parameterType[dataType], lengthInfo == null ? -7777 : *lengthInfo);
		SQLRETURN ret = SQLBindParameter(_statement, SQLUSMALLINT(parameterNumber), parameterDirectionMap[parameterDirection],
					valueType[dataType], parameterType[dataType], columnSize, SQLSMALLINT(decimalDigits), parameterValuePtr,
					bufferLength, lengthInfo);
//		printf("bindParameter ret = %d (%s)\n", ret, string(fromSQLRETURN(ret)));
		return SQL_SUCCEEDED(ret), fromSQLRETURN(ret);
	}

	public SqlReturn moreResults() {
		SQLRETURN ret = SQLMoreResults(_statement);
//		printf("moreResults ret = %d (%s)\n", ret, string(fromSQLRETURN(ret)));
		
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
		this.month = char(month + 1);
		this.day = char(day);
		this.hour = char(hour);
		this.minute = char(minute);
		this.second = char(second);
		this.fraction = fraction;
	}

	public Timestamp(time.Time t) {
		time.Date d(t);
		this.year = short(d.year);
		this.month = char(d.month + 1);
		this.day = char(d.day);
		this.hour = char(d.hour);
		this.minute = char(d.minute);
		this.second = char(d.second);
		this.fraction = unsigned(d.nanosecond);
	}

	public Timestamp(time.Instant i) {
		time.Date d(i);
		this.year = short(d.year);
		this.month = char(d.month + 1);
		this.day = char(d.day);
		this.hour = char(d.hour);
		this.minute = char(d.minute);
		this.second = char(d.second);
		this.fraction = unsigned(d.nanosecond);
	}

	public Timestamp(time.Time t, ref<time.TimeZone> tz) {
		time.Date d(t, tz);
		this.year = short(d.year);
		this.month = char(d.month + 1);
		this.day = char(d.day);
		this.hour = char(d.hour);
		this.minute = char(d.minute);
		this.second = char(d.second);
		this.fraction = unsigned(d.nanosecond);
	}

	public Timestamp(time.Instant i, ref<time.TimeZone> tz) {
		time.Date d(i, tz);
		this.year = short(d.year);
		this.month = char(d.month + 1);
		this.day = char(d.day);
		this.hour = char(d.hour);
		this.minute = char(d.minute);
		this.second = char(d.second);
		this.fraction = unsigned(d.nanosecond);
	}

	public boolean isNULL() {
		return fraction == unsigned.MAX_VALUE;
	}

	public static Timestamp NULL = { fraction: unsigned.MAX_VALUE };

	public time.Time toTime() {
		time.Time t(toInstant());
		return t;
	}

	public time.Instant toInstant() {
		time.Date d;

		d.year = year;
		d.month = month;
		d.day = day;
		d.hour = hour;
		d.minute = minute;
		d.second = second;
		d.nanosecond = fraction;
		time.Instant i(&d, &time.UTC);
		return i;
	}
}

public class Date {
	public short year;
	public char month;
	public char day;
}

public class Time {
	public char hour;
	public char minute;
	public char second;
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

@Constant
private SQLSMALLINT SQL_COMMIT = 0;
@Constant
private SQLSMALLINT SQL_ROLLBACK = 1;

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
private abstract SQLRETURN SQLConnect(SQLHDBC ConnectionHandle, pointer<byte> ServerName, SQLSMALLINT NameLength1,
						pointer<byte> UserName, SQLSMALLINT NameLength2, pointer<byte> Authentication, SQLSMALLINT NameLength3);

@Linux("libodbc.so", "SQLDriverConnect")
private abstract SQLRETURN SQLDriverConnect(SQLHDBC ConnectionHandle, SQLHWND WindowHandle, pointer<byte> InConnectionString,
						SQLSMALLINT StringLength1, pointer<byte> OutConnectionString, SQLSMALLINT BufferLength, 
						ref<SQLSMALLINT> StringLength2Ptr, SQLUSMALLINT DriverCompletion);

@Linux("libodbc.so", "SQLEndTran")
private abstract SQLRETURN SQLEndTran(SQLSMALLINT HandleType, SQLHANDLE Handle, SQLSMALLINT CompletionType);

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
