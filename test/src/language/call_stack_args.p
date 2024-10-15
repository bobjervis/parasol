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
import parasol:text
import parasol:time
/*
 * This contained a code-gen error. Because the variable arguments are a multiple of 16 bytes, adding an 8 byte stack argument (now())
 * requires some careful stack adjustment to ensure that the stack generally stays a multiple of 16.
 *
 * The generated code produced an extra 'sub rsp,8' instruction in the middle of the sequence. That meant that one of the arguments was
 * generated into the wrong stack address, 
 */
f(time.Time.now(), "%d %s %d", 15124, "hello world", 9)

void f(time.Time t, string format, var... arguments) {
	text.memDump(&arguments[0], 48);
	string s
	s.printf(format, arguments)
	assert(s == "15124 hello world 9")
}


