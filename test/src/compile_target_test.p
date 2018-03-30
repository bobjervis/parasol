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

import parasol:runtime.compileTarget;
import parasol:runtime;

@Linux("libc.so.6", "getpgid")
abstract int getpgid(int pid);

@Windows("kernel32.dll", "GetExitCodeProcess")
abstract int GetExitCodeProcess(int handle, ref<int> pid);

if (compileTarget == runtime.Target.X86_64_WIN) {
	int exitCode;
	
	int status = GetExitCodeProcess(-1, &exitCode);
	if (status == 0) {
		printf("Expecting GetExitCodeProcess to fail: it did\n");
	} else {
		printf("Expecting GetExitCodeProcess to fail: it succeeded! exitCode = %d\n", exitCode);
		assert(false);
	}
}

if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
	int x = getpgid(-3);
	if (x < 0) {
		printf("Expecting getpgid to fail: it did\n");
	} else {
		printf("getpgid somehow succeeded!");
		assert(false);
	}
}