namespace native:windows;

public class HANDLE extends address {
	HANDLE(address a) {
		*super = a;
	}
	
	boolean isValid() {
		return *super != INVALID_HANDLE_VALUE;
	}
}

public HANDLE INVALID_HANDLE_VALUE = HANDLE(address(-1));

class HMODULE extends address {}

public abstract int GetModuleFileName(address hModule, pointer<byte> filename, int filenameSize);
public abstract unsigned GetFullPathName(pointer<byte> filename, unsigned bufSz, pointer<byte> lpBuffer, ref<pointer<byte>> lpFilePart);

public abstract address FindFirstFile(pointer<byte> pattern, ref<WIN32_FIND_DATA> data);
public abstract int FindNextFile(address handle, ref<WIN32_FIND_DATA> data);
public abstract int FindClose(address handle);

public abstract int GetLastError();

public int sizeof_WIN32_FIND_DATA = 320;

public class WIN32_FIND_DATA {
	public unsigned dwFileAttributes;
    public FILETIME ftCreationTime;
    public FILETIME ftLastAccessTime;
    public FILETIME ftLastWriteTime;
    public unsigned nFileSizeHigh;
    public unsigned nFileSizeLow;
    public unsigned dwReserved0;
    public unsigned dwReserved1;
    private byte   cFileName;
    
    public string fileName() {
		string s(pointer<byte>(&cFileName));
		return s;
	}
}

public class FILETIME {
    public unsigned dwLowDateTime;
    public unsigned dwHighDateTime;
}

public unsigned MEM_COMMIT = 0x00001000;
public unsigned MEM_RESERVE = 0x00002000;

public unsigned PAGE_EXECUTE = 0x10;
public unsigned PAGE_EXECUTE_READ = 0x20;
public unsigned PAGE_EXECUTE_READWRITE = 0x40;
public unsigned PAGE_READWRITE = 0x04;

public abstract address VirtualAlloc(address lpAddress, long sz, unsigned flAllocationType, unsigned flProtect);
public abstract int VirtualProtect(address lpAddress, long sz, unsigned flNewProtect, ref<unsigned> lpflOldProtect);

public abstract pointer<byte> FormatMessage(unsigned ntstatus);
