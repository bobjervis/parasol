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

address[string] m;

m["create-cell:0"] = &m;

m.remove("create-cell:0");

m["dataset-create:1"] = &m;

m.remove("dataset-create:1");

m["link:2"] = &m;

m.remove("link:2");

m["define-job:3"] = &m;

m.remove("define-job:3");

m["change-root:4"] = &m;

// This was asserting because of a bug in deleted entries handling.

assert(m["change-root:4"] != null);

