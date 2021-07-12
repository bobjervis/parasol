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
import mongodb.com:mongo;

ref<mongo.MongoDB> db = mongo.MongoDB.connect("mongodb://localhost/?appname=mongo_test");

assert(db != null);

ref<mongo.Client> c = db.getClient();

assert(c != null);

ref<mongo.Database> d = c.getDatabase("alys-server");

assert(d != null);

delete d;

ref<mongo.Collection> coll = c.getCollection("alys-server", "coll");

assert(coll != null);

delete coll;

delete c;

delete db;

