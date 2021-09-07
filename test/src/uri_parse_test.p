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
