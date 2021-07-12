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
namespace mongodb.com:mongo;

import parasol:net;
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

public class Collection {
	private ref<mongoc_collection_t> _collection;

	Collection(ref<mongoc_collection_t> collection) {
		_collection = collection;
	}

	~Collection() {
		mongoc_collection_destroy(_collection);
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

class mongoc_client_pool_t {
}

class mongoc_uri_t {
}

class mongoc_client_t {
}

class mongoc_database_t {
}

class mongoc_collection_t {
}

class MsgHeader {
	int messageLength;
	int requestID;
	int responseTo;
	int opCode;
}

char DEFAULT_PORT = 27017;

int OP_REPLY = 1;			// Reply to a client request. responseTo is set.
int OP_UPDATE = 2001;		// Update document.
int OP_INSERT = 2002;		// Insert new document.
int RESERVED = 2003;		// Formerly used for OP_GET_BY_OID.
int OP_QUERY = 2004;		// Query a collection.
int OP_GET_MORE = 2005;		// Get more data from a query. See Cursors.
int OP_DELETE = 2006;		// Delete documents.
int OP_KILL_CURSORS = 2007;	// Notify database that the client has finished with the cursor.
int OP_COMPRESSED = 2012;	// Wraps other opcodes using compression
int OP_MSG = 2013;			// Send a message using the format introduced in MongoDB 3.6.
