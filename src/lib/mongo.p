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

import parasol:exception.IllegalOperationException;
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
	/**
	 * @param newDB The new database name for this collection.
	 * @param newName The new name for this collection.
	 * @param dropTargetBeforeRename true if you want any existing collection
	 * with the new name to be overwritten by the rename, false if you want the
	 * rename to fail..
	 * @return true if the operation succeeded, false otherwise.
	 * @return the failing domain if the operation failed.
	 * @return the failure code if the operation failed.
	 * @return a text message describing the error if the operation failed.
	 */
	public boolean, unsigned, unsigned, string rename(string newDb, string newName, boolean dropTargetBeforeRename) {
		bson_error_t error;

		boolean result = mongoc_collection_rename(_collection, newDb.c_str(), newName.c_str(), dropTargetBeforeRename, &error);
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
	 * Convert the Bson document to an Object.
	 *
	 * Note that a Mongo database can include field types that are not recognized
	 * by an Object as JSON.
	 *
	 * @return An Object containing the same JSON data as the source.
	 *
	 * @exception IllegalOperationException is thrown if a field type is not
	 * a valid JSON data type.
	 */
	public ref<Object> asObject() {
		iterator iter(this);
		ref<Object> o = new Object();

		while (iter.next())
			o.set(iter.key(), iter.getField());
		return o;
	}
	/**
	 * Convert the Bson document to an Array.
	 *
	 * Note that a Mongo database can include field types that are not recognized
	 * by an Object as JSON.
	 *
	 * This code assumes that the field keys are a compact set of integers.
	 *
	 * @return An Array containing the same JSON data as the source.
	 *
	 * @exception IllegalOperationException is thrown if a field type is not
	 * a valid JSON data type, or if any key is not a valid integer.
	 */
	public ref<Array> asArray() {
		iterator iter(this);
		ref<Array> a = new Array();

		while (iter.next()) {
			int key;
			boolean success;

			(key, success) = int.parse(iter.key());
			if (!success)
				throw IllegalOperationException("Key not integral");
			a.setExpand(key, iter.getField());
		}
		return a;
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
	/**
	 * Iterates over a Bson document. Permits decoding and validation of contents
	 */
	public class iterator {
		bson_iter_t _iter;
		/**
		 * Initialize the iterator to work on the given Bson object.
		 *
		 * @param bson A reference to a Bson object returned by mongo.
		 */
		public iterator(ref<Bson> bson) {
			bson_iter_init(&_iter, bson);
		}
		/** Initialize a sub-iterator over the current ARRAY or DOCUMENT
		 * field of the parent iterator.
		 *
		 * @param parent An existing iterator currently positioned at an ARRAY or DOCUMENT
		 * field.
		 */
		public iterator(ref<iterator> parent) {
			bson_iter_recurse(&parent._iter, &_iter);
		}
		/**
		 * Scans the Bson for a field with the given key.
		 *
		 * On success, the field with that key becomes the current field.
		 *
		 * @param key A string identifying the field to locate.
		 *
		 * @return true if the field with the identified key is present in the
		 * document, false if not. 
		 */
		public boolean find(string key) {
			return bson_iter_find(&_iter, key.c_str());
		}
		/**
		 * Advances to the next field in the document.
		 *
		 * On success, the next field in the document becomes the current field.
		 *
		 * @return true if there is another field in the document,
		 * false otherwise.
		 */
		public boolean next() {
			return bson_iter_next(&_iter);
		}
		/**
		 * @return The key for the current field in the iterator.
		 */
		public string key() {
			return string(bson_iter_key(&_iter));
		}
		/**
		 * If the current field has numeric type, the value is converted to long
		 * and returned.
		 *
		 * @exception IllegalOperationException is thrown if the field type is not
		 * numeric.
		 *
		 * @return The long value of the field.
		 */
		public long getLong() {
			switch (bson_iter_type(&_iter)) {
			case DOUBLE:
				return long(bson_iter_double(&_iter));

			case INT32:
				return bson_iter_int32(&_iter);

			case INT64:
				return bson_iter_int64(&_iter);
			}
			throw IllegalOperationException("getLong found " + string(bson_iter_type(&_iter)));
		}
		/**
		 * If the current field has numeric type, the value is converted to double
		 * and returned.
		 *
		 * @exception IllegalOperationException is thrown if the field type is not
		 * numeric.
		 *
		 * @return The double value of the field.
		 */
		public double getDouble() {
			switch (bson_iter_type(&_iter)) {
			case DOUBLE:
				return bson_iter_double(&_iter);

			case INT32:
				return bson_iter_int32(&_iter);

			case INT64:
				return bson_iter_int64(&_iter);
			}
			throw IllegalOperationException("getDouble found " + string(bson_iter_type(&_iter)));
		}
		/**
		 * If the current field has UTF8 type, the value is converted to string
		 * and returned.
		 *
		 * @exception IllegalOperationException is thrown if the field type is not
		 * UTF8.
		 *
		 * @return The string value of the field.
		 */
		public string getString() {
			if (bson_iter_type(&_iter) == BsonType.UTF8) {
				pointer<byte> str;
				unsigned length;

				str = bson_iter_utf8(&_iter, &length);
				return string(str, int(length));
			}
			throw IllegalOperationException("getString found " + string(bson_iter_type(&_iter)));
		}
		/**
		 * If the current field has DATE_TIME type, the value is converted to Time
		 * and returned.
		 *
		 * @exception IllegalOperationException is thrown if the field type is not
		 * DATE_TIME.
		 *
		 * @return The Time value of the field.
		 */
		public time.Time getTime() {
			if (bson_iter_type(&_iter) == BsonType.DATE_TIME)
				return time.Time(bson_iter_date_time(&_iter));
			throw IllegalOperationException("getTime found " + string(bson_iter_type(&_iter)));
		}
		/**
		 * If the current field has DOCUMENT type, the value is converted to Bson
		 * and returned.
		 *
		 * @exception IllegalOperationException is thrown if the field type is not
		 * DOCUMENT.
		 *
		 * @return The Time value of the field.
		 */
		public ref<Bson> getDocument() {
			if (bson_iter_type(&_iter) == BsonType.DOCUMENT) {
				unsigned length;
				pointer<byte> docp;

				bson_iter_document(&_iter, &length, &docp);
				return bson_new_from_data(docp, length);
			}
			throw IllegalOperationException("getDocument found " + string(bson_iter_type(&_iter)));
		}
		/**
		 * If the current field has ARRAY type, the value is converted to Bson
		 * and returned.
		 *
		 * @exception IllegalOperationException is thrown if the field type is not
		 * ARRAY.
		 *
		 * @return The Time value of the field.
		 */
		public ref<Bson> getArray() {
			if (bson_iter_type(&_iter) == BsonType.ARRAY) {
				unsigned length;
				pointer<byte> docp;

				bson_iter_array(&_iter, &length, &docp);
				return bson_new_from_data(docp, length);
			}
			throw IllegalOperationException("getDocument found " + string(bson_iter_type(&_iter)));
		}

		var getField() {
			var x;

			switch (type()) {
			case DOUBLE:
				x = getDouble();
				break;

			case INT32:
			case INT64:
				x = getLong();
				break;

			case UTF8:
				x = getString();
				break;

			case DATE_TIME:
				x = getTime();
				break;

			case DOCUMENT:
				ref<Object> o = new Object();
				{
					iterator sub(this);
	
					while (sub.next())
						o.set(sub.key(), sub.getField());
				}
				x = o;
				break;

			case ARRAY:
				ref<Array> a = new Array();
				{
					iterator sub(this);
	
					while (sub.next()) {
						int key;
						boolean success;
			
						(key, success) = int.parse(sub.key());
						if (!success)
							throw IllegalOperationException("Key not integral");
						a.setExpand(key, sub.getField());
					}
				}
				x = a;
				break;

			default:
				throw IllegalOperationException("Type: " + string(type()));
			}
			return x;
		}

		BsonType type() {
			return bson_iter_type(&_iter);
		}
		
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
@Linux("libmongoc-1.0.so.0", "mongoc_collection_rename")
abstract boolean mongoc_collection_rename(ref<mongoc_collection_t> collection, pointer<byte> newDB, pointer<byte> newName, boolean dropTargetBeforeRename, ref<bson_error_t> error);

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
@Linux("libmongoc-1.0.so.0", "bson_new_from_data")
abstract ref<Bson> bson_new_from_data(pointer<byte> data, C.size_t length);
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
@Linux("libmongoc-1.0.so.0", "bson_iter_init")
abstract void bson_iter_init(ref<bson_iter_t> iter, ref<Bson> bson);
@Linux("libmongoc-1.0.so.0", "bson_iter_find")
abstract boolean bson_iter_find(ref<bson_iter_t> iter, pointer<byte> key);
@Linux("libmongoc-1.0.so.0", "bson_iter_next")
abstract boolean bson_iter_next(ref<bson_iter_t> iter);
@Linux("libmongoc-1.0.so.0", "bson_iter_key")
abstract pointer<byte> bson_iter_key(ref<bson_iter_t> iter);
@Linux("libmongoc-1.0.so.0", "bson_iter_type")
abstract BsonType bson_iter_type(ref<bson_iter_t> iter);
@Linux("libmongoc-1.0.so.0", "bson_iter_double")
abstract long bson_iter_double(ref<bson_iter_t> iter);
@Linux("libmongoc-1.0.so.0", "bson_iter_int32")
abstract long bson_iter_int32(ref<bson_iter_t> iter);
@Linux("libmongoc-1.0.so.0", "bson_iter_int64")
abstract long bson_iter_int64(ref<bson_iter_t> iter);
@Linux("libmongoc-1.0.so.0", "bson_iter_utf8")
abstract pointer<byte> bson_iter_utf8(ref<bson_iter_t> iter, ref<unsigned> length);
@Linux("libmongoc-1.0.so.0", "bson_iter_date_time")
abstract long bson_iter_date_time(ref<bson_iter_t> iter);
@Linux("libmongoc-1.0.so.0", "bson_iter_document")
abstract void bson_iter_document(ref<bson_iter_t> iter, ref<unsigned> length, ref<pointer<byte>> documentp);
@Linux("libmongoc-1.0.so.0", "bson_iter_array")
abstract void bson_iter_array(ref<bson_iter_t> iter, ref<unsigned> length, ref<pointer<byte>> arrayp);
@Linux("libmongoc-1.0.so.0", "bson_iter_recurse")
abstract boolean bson_iter_recurse(ref<bson_iter_t> iter, ref<bson_iter_t> child);

class bson_value_t {
	BsonType value_type;
	int pad;
	long value_1;
	long value_2;
	long value_3;
}

class bson_iter_t {
   pointer<byte> raw; /* The raw buffer being iterated. */
   unsigned len;       /* The length of raw. */
   unsigned off;       /* The offset within the buffer. */
   unsigned type;      /* The offset of the type byte. */
   unsigned key;       /* The offset of the key byte. */
   unsigned d1;        /* The offset of the first data byte. */
   unsigned d2;        /* The offset of the second data byte. */
   unsigned d3;        /* The offset of the third data byte. */
   unsigned d4;        /* The offset of the fourth data byte. */
   unsigned next_off;  /* The offset of the next field. */
   unsigned err_off;   /* The offset of the error. */
   bson_value_t value; /* Internal value for various state. */
}

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

public enum BsonType {
   EOD,
   DOUBLE,
   UTF8,
   DOCUMENT,
   ARRAY,
   BINARY,
   UNDEFINED,
   OID,
   BOOL,
   DATE_TIME,
   NULL,
   REGEX,
   DBPOINTER,
   CODE,
   SYMBOL,
   CODEWSCOPE,
   INT32,
   TIMESTAMP,
   INT64,
   DECIMAL128
}

class mongoc_write_concern_t { }

public unsigned MONGOC_INSERT_NONE = 0;
public unsigned MONGOC_INSERT_CONTINUE_ON_ERROR = unsigned(1 << 0);
public unsigned MONGOC_INSERT_NO_VALIDATE = unsigned(1 << 31);

public int MONGOC_WRITE_CONCERN_W_UNACKNOWLEDGED = 0;
public int MONGOC_WRITE_CONCERN_W_ERRORS_IGNORED = -1; /* deprecated */
public int MONGOC_WRITE_CONCERN_W_DEFAULT = -2;
public int MONGOC_WRITE_CONCERN_W_MAJORITY = -3;
public int MONGOC_WRITE_CONCERN_W_TAG = -4;


