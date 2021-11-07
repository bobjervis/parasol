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

import parasol:http;

http.Uri uri;

assert(uri.parseURI("abc:"));
assert(uri.parsed);
assert(uri.scheme == "abc");
assert(uri.userinfo == null);
assert(uri.host == null);
assert(uri.portDefaulted);
assert(uri.port == 0);
assert(uri.query == null);
assert(uri.fragment == null);
assert(uri.path == "");

uri.userinfo = "def";
uri.host = "ghi";
uri.portDefaulted = false;
uri.port = 1234;
uri.query = "jkl";
uri.fragment = "mno";
uri.path = "pqr";

uri.reset();
assert(!uri.parsed);
assert(uri.scheme == null);
assert(uri.userinfo == null);
assert(uri.host == null);
assert(uri.portDefaulted);
assert(uri.port == 0);
assert(uri.query == null);
assert(uri.fragment == null);
assert(uri.path == null);

assert(uri.parseURI("abc:"));
assert(uri.parsed);
assert(uri.scheme == "abc");
assert(uri.userinfo == null);
assert(uri.host == null);
assert(uri.portDefaulted);
assert(uri.port == 0);
assert(uri.query == null);
assert(uri.fragment == null);
assert(uri.path == "");

assert(uri.parseURI("abc://1.2.3.4:1235/"));
assert(uri.parsed);
assert(uri.scheme == "abc");
assert(uri.userinfo == null);
assert(uri.host == "1.2.3.4");
assert(!uri.portDefaulted);
assert(uri.port == 1235);
assert(uri.query == null);
assert(uri.fragment == null);
assert(uri.path == "/");

assert(uri.parseURI("https://192.168.1.2:5013/secure/src_server_ready?A=p8ROxQ9jims/XYq8SMmahQNBKN0w5HdWtGlkdznixZ9tpHRiR5ZSaA=="));
assert(uri.parsed);
assert(uri.scheme == "https");
assert(uri.userinfo == null);
assert(uri.host == "192.168.1.2");
assert(!uri.portDefaulted);
assert(uri.port == 5013);
assert(uri.query == "A=p8ROxQ9jims/XYq8SMmahQNBKN0w5HdWtGlkdznixZ9tpHRiR5ZSaA==");
assert(uri.fragment == null);
assert(uri.path == "/secure/src_server_ready");
assert(uri.toString() == "https://192.168.1.2:5013/secure/src_server_ready?A=p8ROxQ9jims/XYq8SMmahQNBKN0w5HdWtGlkdznixZ9tpHRiR5ZSaA==");

assert(uri.parseRelativeReference("abc"));
assert(uri.parsed);
assert(uri.scheme == null);
assert(uri.userinfo == null);
assert(uri.host == null);
assert(uri.portDefaulted);
assert(uri.port == 0);
assert(uri.query == null);
assert(uri.fragment == null);
assert(uri.path == "abc");

assert(!uri.parseURI("abc"));
assert(!uri.parsed);

assert(!uri.parseURI(":"));
assert(!uri.parsed);
