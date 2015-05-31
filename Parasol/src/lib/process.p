namespace parasol:process;

import parasol:storage;
import parasol:time;
import native:windows;

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

public string[exception_t] exceptionNames;

exceptionNames.append("NO_EXCEPTION");
exceptionNames.append("ABORT");
exceptionNames.append("BREAKPOINT");
exceptionNames.append("TIMEOUT");
exceptionNames.append("TOO_MANY_EXCEPTIONS");
exceptionNames.append("ACCESS_VIOLATION");
exceptionNames.append("UNKNOWN_EXCEPTION");

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

public abstract void exit(int code);
