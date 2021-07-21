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
 * Provides a structured interface to MongoDB.
 */
namespace mongodb.org:mongo;

import parasol:json;
import parasol:net;
import parasol:time;
import native:C;
/**
 * Represents a connection to an external MongoDB server or cluster.
 *
 * A program can open an arbitrary number of such databases.
 */
public class MongoDB {
	private ref<mongoc_client_pool_t> _clientPool;
	private ref<mongoc_uri_t> _uri;

	public static ref<MongoDB> connect(string uri) {
		ref<mongoc_uri_t> parsed;
		parsed = mongoc_uri_new(uri.c_str());
		if (parsed == null)
			return null;
		ref<mongoc_client_pool_t> clientPool = mongoc_client_pool_new(parsed);
		if (clientPool == null) {
			mongoc_uri_destroy(parsed);
			return null;
		}
		return new MongoDB(parsed, clientPool);
	}

	MongoDB(ref<mongoc_uri_t> uri, ref<mongoc_client_pool_t> clientPool) {
		_uri = uri;
		_clientPool = clientPool;
	}

	~MongoDB() {
		mongoc_client_pool_destroy(_clientPool);
		mongoc_uri_destroy(_uri);
	}

	public ref<Client> getClient() {
		ref<mongoc_client_t> client = mongoc_client_pool_pop(_clientPool);
		if (client == null)
			return null;
		return new Client(_clientPool, client);
	}
}
/**
 * Represents a mongoc client object. It is specifically designed to work within
 * a threaded environment. Note that this object must be deleted before the
 * MongoDB object that created it.
 */
public class Client {
	private ref<mongoc_client_pool_t> _pool;
	private ref<mongoc_client_t> _client;

	Client(ref<mongoc_client_pool_t> pool, ref<mongoc_client_t> client) {
		_pool = pool;
		_client = client;
	}

	~Client() {
		mongoc_client_pool_push(_pool, _client);
	}

	public ref<Database> getDatabase(string name) {
		ref<mongoc_database_t> database = mongoc_client_get_database(_client, name.c_str());
		if (database == null)
			return null;
		else
			return new Database(database);
	}

	public ref<Collection> getCollection(string databaseName, string collectionName) {
		ref<mongoc_collection_t> coll = mongoc_client_get_collection(_client, databaseName.c_str(), collectionName.c_str());
		if (coll == null)
			return null;
		else
			return new Collection(coll);
	}
}

public class Database {
	private ref<mongoc_database_t> _database;

	Database(ref<mongoc_database_t> database) {
		_database = database;
	}

	~Database() {
		mongoc_database_destroy(_database);
	}
}
/**
 * This represents the mongoc collection object.
 *
 * Note that this object must be deleted before the Client object that created it.
 */
public class Collection {
	private ref<mongoc_collection_t> _collection;

	Collection(ref<mongoc_collection_t> collection) {
		_collection = collection;
	}

	~Collection() {
		mongoc_collection_destroy(_collection);
	}
	/**
	 * This inserts one document into the collection.
	 *
	 * @param document The Bson encoded document to be inserted.
	 * valid and causes the reply data to be discarded.
	 * @return true if the operation succeeded, false otherwise.
	 * @return the failing domain if the operation failed.
	 * @return the failure code if the operation failed.
	 * @return a text message describing the error if the operation failed.
	 */
	public boolean, unsigned, unsigned, string insert(ref<Bson> document) {
		bson_error_t error;

		boolean result = mongoc_collection_insert(_collection, MONGOC_INSERT_NONE, document, null, &error);
		return result, error.domain, error.code, error.message();
	}
	/**
	 * Find one or more documents in a collection.
	 *
	 * @param query The query to execute
	 * @param fields A list of fields
	 * @return A non-null cursor if the operation succeeded, null otherwise. The cursor may have an empty 
	 * document set, depending on the query.
	 * @return the failing domain if the operation failed.
	 * @return the failure code if the operation failed.
	 * @return a text message describing the error if the operation failed.
	 */
	public ref<Cursor>, unsigned, unsigned, string find(unsigned skip, unsigned limit, unsigned batchSize, ref<Bson> query, ref<Bson> fields) {
		ref<mongoc_cursor_t> cursor = mongoc_collection_find(_collection, 0, skip, limit, batchSize, query, fields, null);
		bson_error_t error;
		if (mongoc_cursor_error_document(cursor, &error, null)) {
			return null, error.domain, error.code, error.message();
		} else
			return new Cursor(cursor), 0, 0, null;
	}
	/**
	 * Find one or more documents in a collection.
	 *
	 * @param query The query to execute
	 * @param fields A list of fields
	 * @return A non-null cursor if the operation succeeded, null otherwise. The cursor may have an empty 
	 * document set, depending on the query.
	 * @return the failing domain if the operation failed.
	 * @return the failure code if the operation failed.
	 * @return a text message describing the error if the operation failed.
	 */
	public ref<Cursor>, unsigned, unsigned, string find(ref<Bson> query, ref<Bson> opts) {
		ref<mongoc_cursor_t> cursor = mongoc_collection_find_with_opts(_collection, query, opts, null);
		bson_error_t error;
		if (mongoc_cursor_error_document(cursor, &error, null)) {
			return null, error.domain, error.code, error.message();
		} else
			return new Cursor(cursor), 0, 0, null;
	}
	/**
	 * @return true if the operation succeeded, false otherwise.
	 * @return the failing domain if the operation failed.
	 * @return the failure code if the operation failed.
	 * @return a text message describing the error if the operation failed.
	 */
	public boolean, unsigned, unsigned, string drop() {
		bson_error_t error;

		boolean result = mongoc_collection_drop(_collection, &error);
		return result, error.domain, error.code, error.message();			      
	}
}

public class Cursor {
	private ref<mongoc_cursor_t> _cursor;

	Cursor(ref<mongoc_cursor_t> cursor) {
		_cursor = cursor;
	}

	~Cursor() {
		mongoc_cursor_destroy(_cursor);
	}

	public ref<Bson>, unsigned, unsigned, string next() {
		ref<Bson> document;
		if (mongoc_cursor_next(_cursor, &document))
			return document, 0, 0, null;
		else {
			bson_error_t error;

			mongoc_cursor_error(_cursor, &error);
			return null, error.domain, error.code, error.message();
		}
	}
}
/**
 * This is the equivalent of the mondoc driver bson_t class.
 *
 * It is a binary representation of mongo's extended JSON data format.
 *
 * The goal of this class is to provide a relatively thin wrapper for the
 * mongoc driver bson_t object, while providing a more Parasol-friendly
 * interface.
 */
public class Bson {
	/**
	 * This method creates a new, empty Bson document.
	 *
	 * @return A reference to the new Bson object.
	 */
	public static ref<Bson> create() {
		return bson_new();
	}
	/**
	 * This method creates a new Bson document that is a converted copy of the 
	 * Object passed.
	 *
	 * The argument is not modified.
	 *
	 * @param parsedJson A reference to an Object that is compatible with a
	 * parsed JSON string.
	 * @return A reference to the created BSON document, or null if any field
	 * could not be converted.
	 */
	public static ref<Bson> create(ref<Object> parsedJson) {
		ref<Bson> b = bson_new();
		for (key in (*parsedJson)) {
			var value = (*parsedJson)[key];
			if (!appendTo(b, key, value)) {
				dispose(b);
				return null;
			}
		}
		return b;
	}
	/**
	 * This method creates a new Bson document that is a converted copy of the 
	 * Array passed.
	 *
	 * The argument is not modified.
	 *
	 * @param array A reference to an Array that is compatible with a
	 * parsed JSON string.
	 * @return A reference to the created BSON document, or null if any field
	 * could not be converted.
	 */
	public static ref<Bson> create(ref<Array> array) {
		ref<Bson> a = Bson.create();
		for (i in *array) {
			var value = (*array)[i];
			if (!appendTo(a, string(i), value)) {
				dispose(a);
				return null;
			}
		}
		return a;
	}
	/**
	 * This method creates a new Bson document that is a converted copy of the 
	 * Object passed.
	 *
	 * The argument is freed using json.dispose.
	 *
	 * @param parsedJson A reference to an Object that is compatible with a
	 * parsed JSON string.
	 * @return A reference to the created BSON document, or null if any field
	 * could not be converted.
	 */
	public static ref<Bson> consume(ref<Object> parsedJson) {
		ref<Bson> b = create(parsedJson);
		json.dispose(parsedJson);
		return b;
	}
	/**
	 * This method creates a new Bson document that is a converted copy of the 
	 * Array passed.
	 *
	 * The argument is freed using json.dispose.
	 *
	 * @param array A reference to an Array that is compatible with a
	 * parsed JSON string.
	 * @return A reference to the created BSON document, or null if any field
	 * could not be converted.
	 */
	public static ref<Bson> consume(ref<Array> array) {
		ref<Bson> a = create(array);
		json.dispose(array);
		return a;
	}

	private static boolean appendTo(ref<Bson> output, string key, var value) {
		if (value.class == ref<Object>) {
			ref<Bson> f = create(ref<Object>(value));
			if (f == null)
				return false;
			if (output.append(key, f))
				return true;
			dispose(f);
			return false;
		} else if (value.class == string)
			return output.append(key, string(value));
		else if (value.class == long)
			return output.append(key, long(value)); 
		else if (value.class == boolean)
			return output.append(key, boolean(value));
		else if (value.class == double)
			return output.append(key, double(value));
		else if (value.class == ref<Array>) {
			ref<Bson> a = create(ref<Array>(value));
			if (a == null)
				return false;
			if (output.appendArray(key, a))
				return true;
			dispose(a);
			return false;
		} else
			return false;
	}
	/**
	 * This method disposes of a Bson document.
	 */
	public static void dispose(ref<Bson> bson) {
		bson_destroy(bson);
	}
	/**
	 * This appends a new field with a string value to the given document.
	 *
	 * @param key The key of the new field.
	 * @param value The value of the new field.
	 * @return true if the operation succeeded, false otherwise.
	 */
	public boolean append(string key, string value) {
		return bson_append_utf8(this, key.c_str(), key.length(), value.c_str(), value.length());
	}
	/**
	 * This appends a new field with a boolean value to the given document.
	 *
	 * @param key The key of the new field.
	 * @param value The value of the new field.
	 * @return true if the operation succeeded, false otherwise.
	 */
	public boolean append(string key, boolean value) {
		return bson_append_bool(this, key.c_str(), key.length(), value);
	}
	/**
	 * This appends a new field with a long value to the given document.
	 *
	 * @param key The key of the new field.
	 * @param value The value of the new field.
	 * @return true if the operation succeeded, false otherwise.
	 */
	public boolean append(string key, long value) {
		return bson_append_int64(this, key.c_str(), key.length(), value);
	}
	/**
	 * This appends a new field with a double value to the given document.
	 *
	 * @param key The key of the new field.
	 * @param value The value of the new field.
	 * @return true if the operation succeeded, false otherwise.
	 */
	public boolean append(string key, double value) {
		return bson_append_double(this, key.c_str(), key.length(), value);
	}
	/**
	 * This appends a new field with a Bson document value to the given document.
	 *
	 * @param key The key of the new field.
	 * @param value The value of the new field.
	 * @return true if the operation succeeded, false otherwise.
	 */
	public boolean append(string key, ref<Bson> value) {
		return bson_append_document(this, key.c_str(), key.length(), value);
	}
	/**
	 * This appends a new field with a Bson document value to the given document.
	 *
	 * @param key The key of the new field.
	 * @param value The value of the new field.
	 * @return true if the operation succeeded, false otherwise.
	 */
	public boolean appendArray(string key, ref<Bson> value) {
		return bson_append_array(this, key.c_str(), key.length(), value);
	}
	/**
	 * This appends the contents of the Object as if it had been constructed
	 * from parsing JSON text.
	 *
	 * @param parsedJson The Object whose contents should be copied to this
	 * BSON document.
	 * @return true if all the contents were copied, false if any contents 
	 * did not get copied.
	 */
	public boolean append(ref<Object> parsedJson) {
		boolean failed;
		for (key in (*parsedJson)) {
			var value = (*parsedJson)[key];
			if (value.class == ref<Object>) {
				ref<Bson> f = create(ref<Object>(value));
				if (!append(key, f))
					failed = true;
			} else if (value.class == string) {
				if (!append(key, string(value)))
					failed = true;
			} else if (value.class == long) {
				if (!append(key, long(value)))
					failed = true;
			} else if (value.class == boolean) {
				if (!append(key, boolean(value)))
					failed = true;
			} else if (value.class == double) {
				if (!append(key, double(value)))
					failed = true;
			} else if (value.class == ref<Array>) {
				if (!appendArray(key, create(ref<Array>(value))))
					failed = true;
			}
		}
		return !failed;
	}
	/**
	 * Append a Time object to a Bson document.
	 *
	 * @param key The key of the new field.
	 * @param value The value of the new field.
	 * @return true if the operation succeeded, false otherwise.
	 */
	public boolean appendDateTime(string key, time.Time value) {
		return bson_append_date_time(this, key.c_str(), key.length(), value.value());
	}
	/**
	 * Return this Bson document as a json string.
	 *
	 * @return The string representation of this Bson document as JSON.
	 */
	public string asJson() {
		string s;
		pointer<byte> cp;
		C.size_t length;

		cp = bson_as_canonical_extended_json(this, &length);
		s = string(cp, int(length));
		bson_free(cp);
		return s;
	}
}

class StaticInit {
	StaticInit() {
		mongoc_init();
	}

	~StaticInit() {
		mongoc_cleanup();
	}
}

private StaticInit init;

@Linux("libmongoc-1.0.so.0", "mongoc_init")
abstract void mongoc_init();
@Linux("libmongoc-1.0.so.0", "mongoc_cleanup")
abstract void mongoc_cleanup();

@Linux("libmongoc-1.0.so.0", "mongoc_uri_new")
abstract ref<mongoc_uri_t> mongoc_uri_new(pointer<byte> uri_string);
@Linux("libmongoc-1.0.so.0", "mongoc_uri_destroy")
abstract void mongoc_uri_destroy(ref<mongoc_uri_t> uri);

@Linux("libmongoc-1.0.so.0", "mongoc_client_pool_new")
abstract ref<mongoc_client_pool_t> mongoc_client_pool_new(ref<mongoc_uri_t> uri);
@Linux("libmongoc-1.0.so.0", "mongoc_client_pool_destroy")
abstract void mongoc_client_pool_destroy(ref<mongoc_client_pool_t> clientPool);
@Linux("libmongoc-1.0.so.0", "mongoc_client_pool_pop")
abstract ref<mongoc_client_t> mongoc_client_pool_pop(ref<mongoc_client_pool_t> clientPool);
@Linux("libmongoc-1.0.so.0", "mongoc_client_pool_push")
abstract void mongoc_client_pool_push(ref<mongoc_client_pool_t> clientPool, ref<mongoc_client_t> client);

@Linux("libmongoc-1.0.so.0", "mongoc_client_get_database")
abstract ref<mongoc_database_t> mongoc_client_get_database(ref<mongoc_client_t> client, pointer<byte> name);
@Linux("libmongoc-1.0.so.0", "mongoc_database_destroy")
abstract void mongoc_database_destroy(ref<mongoc_database_t> database);

@Linux("libmongoc-1.0.so.0", "mongoc_client_get_collection")
abstract ref<mongoc_collection_t> mongoc_client_get_collection(ref<mongoc_client_t> client, pointer<byte> databaseName, pointer<byte> collectionName);
@Linux("libmongoc-1.0.so.0", "mongoc_collection_destroy")
abstract void mongoc_collection_destroy(ref<mongoc_collection_t> collection);
@Linux("libmongoc-1.0.so.0", "mongoc_collection_insert")
abstract boolean mongoc_collection_insert(ref<mongoc_collection_t> collection, unsigned flag, ref<Bson> document, ref<mongoc_write_concern_t> writeConcern, ref<bson_error_t> error);
@Linux("libmongoc-1.0.so.0", "mongoc_collection_find")
abstract ref<mongoc_cursor_t> mongoc_collection_find(ref<mongoc_collection_t> collection, mongoc_query_flags_t flag, unsigned skip,
												unsigned limit, unsigned batch_size, ref<Bson> query,
												ref<Bson> fields, ref<mongoc_read_prefs_t> read_prefs);
@Linux("libmongoc-1.0.so.0", "mongoc_collection_find_with_opts")
abstract ref<mongoc_cursor_t> mongoc_collection_find_with_opts(ref<mongoc_collection_t> collection, ref<Bson> filter,
												ref<Bson> opts, ref<mongoc_read_prefs_t> read_prefs);
@Linux("libmongoc-1.0.so.0", "mongoc_collection_drop")
abstract boolean mongoc_collection_drop(ref<mongoc_collection_t> collection, ref<bson_error_t> error);

@Linux("libmongoc-1.0.so.0", "mongoc_cursor_next")
abstract boolean mongoc_cursor_next(ref<mongoc_cursor_t> cursor, ref<ref<Bson>> document);
@Linux("libmongoc-1.0.so.0", "mongoc_cursor_error_document")
abstract boolean mongoc_cursor_error_document(ref<mongoc_cursor_t> cursor, ref<bson_error_t> error, ref<ref<Bson>> reply);
@Linux("libmongoc-1.0.so.0", "mongoc_cursor_error")
abstract boolean mongoc_cursor_error(ref<mongoc_cursor_t> cursor, ref<bson_error_t> error);
@Linux("libmongoc-1.0.so.0", "mongoc_cursor_destroy")
abstract void mongoc_cursor_destroy(ref<mongoc_cursor_t> cursor);

@Linux("libmongoc-1.0.so.0", "bson_new")
abstract ref<Bson> bson_new();
@Linux("libmongoc-1.0.so.0", "bson_destroy")
abstract void bson_destroy(ref<Bson> bson);
@Linux("libmongoc-1.0.so.0", "bson_append_bool")
abstract boolean bson_append_bool(ref<Bson> bson, pointer<byte> key, int keyLength, boolean value);
@Linux("libmongoc-1.0.so.0", "bson_append_utf8")
abstract boolean bson_append_utf8(ref<Bson> bson, pointer<byte> key, int keyLength, pointer<byte> value, int valueLength);
@Linux("libmongoc-1.0.so.0", "bson_append_int64")
abstract boolean bson_append_int64(ref<Bson> bson, pointer<byte> key, int keyLength, long value);
@Linux("libmongoc-1.0.so.0", "bson_append_double")
abstract boolean bson_append_double(ref<Bson> bson, pointer<byte> key, int keyLength, double value);
@Linux("libmongoc-1.0.so.0", "bson_append_document")
abstract boolean bson_append_document(ref<Bson> bson, pointer<byte> key, int keyLength, ref<Bson> value);
@Linux("libmongoc-1.0.so.0", "bson_append_array")
abstract boolean bson_append_array(ref<Bson> bson, pointer<byte> key, int keyLength, ref<Bson> value);
@Linux("libmongoc-1.0.so.0", "bson_append_date_time")
abstract boolean bson_append_date_time(ref<Bson> bson, pointer<byte> key, int keyLength, long milliseconds);
@Linux("libmongoc-1.0.so.0", "bson_as_canonical_extended_json")
abstract pointer<byte> bson_as_canonical_extended_json(ref<Bson> bson, ref<C.size_t> lengthp);
@Linux("libmongoc-1.0.so.0", "bson_free")
abstract void bson_free(address memory);

class bson_error_t {
	unsigned domain;
	unsigned code;

	string message() {
		return string(pointer<byte>(&x2));
	}

	long x2;
	long x3;
	long x4;
	long x5;
	long x6;
	long x7;
	long x8;
	long x9;
	long x10;
	long x11;
	long x12;
	long x13;
	long x14;
	long x15;
	long x16;
	long x17;
	long x18;
	long x19;
	long x20;
	long x21;
	long x22;
	long x23;
	long x24;
	long x25;
	long x26;
	long x27;
	long x28;
	long x29;
	long x30;
	long x31;
	long x32;
	long x33;
	long x34;
	long x35;
	long x36;
	long x37;
	long x38;
	long x39;
	long x40;
	long x41;
	long x42;
	long x43;
	long x44;
	long x45;
	long x46;
	long x47;
	long x48;
	long x49;
	long x50;
	long x51;
	long x52;
	long x53;
	long x54;
	long x55;
	long x56;
	long x57;
	long x58;
	long x59;
	long x60;
	long x61;
	long x62;
	long x63;
	long x64;
}


class mongoc_client_pool_t { }
class mongoc_uri_t { }
class mongoc_client_t { }
class mongoc_database_t { }
class mongoc_collection_t { }
class mongoc_cursor_t { }
class mongoc_read_prefs_t { }

flags mongoc_query_flags_t {
   MONGOC_QUERY_TAILABLE_CURSOR,
   MONGOC_QUERY_SLAVE_OK,
   MONGOC_QUERY_OPLOG_REPLAY,
   MONGOC_QUERY_NO_CURSOR_TIMEOUT,
   MONGOC_QUERY_AWAIT_DATA,
   MONGOC_QUERY_EXHAUST,
   MONGOC_QUERY_PARTIAL,
}

class bson_t {
	unsigned `flags`;
	unsigned len;
	long pad2;
	long pad3;
	long pad4;
	long pad5;
	long pad6;
	long pad7;
	long pad8;
	long pad9;
	long pad10;
	long pad11;
	long pad12;
	long pad13;
	long pad14;
	long pad15;
	long pad16;
}

enum bcon_type_t {
   BCON_TYPE_UTF8,
   BCON_TYPE_DOUBLE,
   BCON_TYPE_DOCUMENT,
   BCON_TYPE_ARRAY,
   BCON_TYPE_BIN,
   BCON_TYPE_UNDEFINED,
   BCON_TYPE_OID,
   BCON_TYPE_BOOL,
   BCON_TYPE_DATE_TIME,
   BCON_TYPE_NULL,
   BCON_TYPE_REGEX,
   BCON_TYPE_DBPOINTER,
   BCON_TYPE_CODE,
   BCON_TYPE_SYMBOL,
   BCON_TYPE_CODEWSCOPE,
   BCON_TYPE_INT32,
   BCON_TYPE_TIMESTAMP,
   BCON_TYPE_INT64,
   BCON_TYPE_DECIMAL128,
   BCON_TYPE_MAXKEY,
   BCON_TYPE_MINKEY,
   BCON_TYPE_BCON,
   BCON_TYPE_ARRAY_START,
   BCON_TYPE_ARRAY_END,
   BCON_TYPE_DOC_START,
   BCON_TYPE_DOC_END,
   BCON_TYPE_END,
   BCON_TYPE_RAW,
   BCON_TYPE_SKIP,
   BCON_TYPE_ITER,
   BCON_TYPE_ERROR,
};

class mongoc_write_concern_t { }

public unsigned MONGOC_INSERT_NONE = 0;
public unsigned MONGOC_INSERT_CONTINUE_ON_ERROR = unsigned(1 << 0);
public unsigned MONGOC_INSERT_NO_VALIDATE = unsigned(1 << 31);

public int MONGOC_WRITE_CONCERN_W_UNACKNOWLEDGED = 0;
public int MONGOC_WRITE_CONCERN_W_ERRORS_IGNORED = -1; /* deprecated */
public int MONGOC_WRITE_CONCERN_W_DEFAULT = -2;
public int MONGOC_WRITE_CONCERN_W_MAJORITY = -3;
public int MONGOC_WRITE_CONCERN_W_TAG = -4;


