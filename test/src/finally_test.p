/*
   Copyright 2015 Rovert Jervis

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
import parasol:process;

boolean ranFinally = false;
boolean ranAfterFinally = false;
boolean ranCatch = false;

printf("Starting finally test!\n");
try {
	try {
		printf("About to throw!\n");
		throw Exception("Inner one!");
	} finally {
		printf("hit it!\n");
		ranFinally = true;
	}
	printf("Missed this!\n");
	ranAfterFinally = true;
} catch (Exception e) {
	printf("Caught exception!\n");
	e.printStackTrace();
	ranCatch = true;
}

assert(ranFinally);
assert(!ranAfterFinally);
assert(ranCatch);

boolean inCatch = false;
boolean inFinally = false;
boolean inFinallyAfterCatch = false;

void tryFunc(boolean doThrow) {
	try {
		printf("tryFunc(%s)\n", doThrow ? "true" : "false");
		if (doThrow)
			throw Exception("Hit it!");
	} catch (Exception e) {
		inCatch = true;
	} finally {
		if (inCatch && !inFinally)
			inFinallyAfterCatch = true;
		inFinally = true;
	}
}

tryFunc(false);

assert(inFinally);
assert(!inCatch);
assert(!inFinallyAfterCatch);

inCatch = false;
inFinally = false;
inFinallyAfterCatch = false;

tryFunc(true);

assert(inCatch);
assert(inFinally);
assert(inFinallyAfterCatch);
