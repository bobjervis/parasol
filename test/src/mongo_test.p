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
import mongodb.org:mongo;
import mongodb.org:mongo.Bson;

ref<mongo.MongoDB> db = mongo.MongoDB.connect("mongodb://localhost/?appname=mongo_test");

assert(db != null);

ref<mongo.Client> c = db.getClient();

assert(c != null);

ref<mongo.Database> d = c.getDatabase("alys-server");

assert(d != null);

delete d;

ref<mongo.Collection> coll = c.getCollection("alys-server", "state");

assert(coll != null);

ref<Bson> query = Bson.create();

query.append("_id", "master");

ref<Bson> fields = Bson.create();

fields.append("field1", true);

boolean result;
unsigned domain;
unsigned code;
string message;

ref<mongo.Cursor> cursor;
(cursor, domain, code, message) = coll.find(query, fields);

if (cursor == null) {
	ref<Bson> document = Bson.create();

	document.append("_id", "master");
	document.append("field1", "stuff");

	(result, domain, code, message) = coll.insert(document);

	assert(result);

	Bson.dispose(document);
} else
	delete cursor;

(result, domain, code, message) = coll.drop();
/*
if (!result)
	showError(domain, code, message);

assert(result);
 */
ref<Bson> document = Bson.create();

document.append("_id", "master");
document.append("field1", "stuff");

(result, domain, code, message) = coll.insert(document);

assert(result);

Bson.dispose(document);

delete coll;

delete c;

delete db;

void showError(unsigned domain, unsigned code, string message) {
	printf("Mongo error detected: domain %d code %d: %s\n", domain, code, message);
}

