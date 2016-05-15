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
namespace parasol:process;

import parasol:storage;
import parasol:time;
import native:windows;
import native:C;

public string binaryFilename() {
	byte[] filename;
	filename.resize(storage.FILENAME_MAX + 1);
	
	int length = windows.GetModuleFileName(null, &filename[0], filename.length());
	filename.resize(length);
	string s(filename);
	return s;
}

public enum exception_t {
	NO_EXCEPTION,
	ABORT,
	BREAKPOINT,
	TIMEOUT,							// debugSpawn exceeded specified timeout
	TOO_MANY_EXCEPTIONS,				// too many exceptions raised by child process
	ACCESS_VIOLATION,					// hardware memory access violation
	UNKNOWN_EXCEPTION					// A system or application exception not known to the
										// runtime
}

private class SpawnPayload {
	public pointer<byte> output;
	public int outputLength;
	public int outcome;
}

public int debugSpawn(string command, ref<string> output, ref<exception_t> outcome, time.Time timeout) {
	SpawnPayload payload;
	
	int result = debugSpawnImpl(&command[0], &payload, timeout);
	if (output != null)
		*output = string(payload.output, payload.outputLength);
	if (outcome != null) 
		*outcome = exception_t(payload.outcome);
	disposeOfPayload(&payload);
	return result;
}

private abstract int debugSpawnImpl(pointer<byte> command, ref<SpawnPayload> output, time.Time timeout);

private abstract void disposeOfPayload(ref<SpawnPayload> output);

public void exit(int code) {
	C.exit(code);
}
