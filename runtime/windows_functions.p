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
/**
 * The Windows namespace provides facilities to access the Windows WIN64 C-language API.
 *
 * The emphasis has been to define the Windows functions needed to support the Parasol runtime.
 * Since the Linux port of Parasol has been the focus for the last year, the Windows upport is
 * well behind and a refresh of the Windows code is overdue.
 *
 * Only the ASCII versions of functions in the API are exposed, since Parasol encourages you to
 * use UTF-8, rather than UTF-16 in your programs (due to the more limited support for UTF-16
 * versions of Parasol runtime functions). In the future, both narrow and wide versions of Windows
 * function could easily be added. 
 */
namespace native:windows;

public class HANDLE = address;

public HANDLE INVALID_HANDLE_VALUE = HANDLE(address(-1));

public class HMODULE = address;
public class ATOM = char;
public class HICON = address;
public class HCURSOR = address;
public class HBRUSH = address;
public class HINSTANCE = address;
public class PVOID = address;
public class BOOL = int;
public class WINBOOL = int;
public class HLOCAL = address;
public class WORD = short;
public class DWORD = unsigned;
public class SIZE_T = address;
public class HTHREAD = address;
public class BCRYPT_ALG_HANDLE = address;
public class ULONG = unsigned;
public class NTSTATUS = int;

@Windows("kernel32.dll", "GetModuleFileNameA")
public abstract int GetModuleFileName(HMODULE hModule, pointer<byte> filename, int filenameSize);
@Windows("kernel32.dll", "GetModuleHandleA")
public abstract HMODULE GetModuleHandle(pointer<byte> filename);
@Windows("kernel32.dll", "GetProcAddress")
public abstract address GetProcAddress(HMODULE hModule, pointer<byte> procName);
@Windows("kernel32.dll", "GetFullPathNameA")
public abstract unsigned GetFullPathName(pointer<byte> filename, unsigned bufSz, pointer<byte> lpBuffer, ref<pointer<byte>> lpFilePart);

@Windows("kernel32.dll", "FindFirstFileA")
public abstract address FindFirstFile(pointer<byte> pattern, ref<WIN32_FIND_DATA> data);
@Windows("kernel32.dll", "FindNextFileA")
public abstract int FindNextFile(address handle, ref<WIN32_FIND_DATA> data);
@Windows("kernel32.dll", "FindClose")
public abstract int FindClose(address handle);

@Windows("kernel32.dll", "FlushFileBuffers")
public abstract BOOL FlushFileBuffers(HANDLE hFile);

@Windows("kernel32.dll", "GetFileAttributesA")
public abstract DWORD GetFileAttributes(pointer<byte> filename);

@Windows("kernel32.dll", "GetLastError")
public abstract int GetLastError();

@Windows("kernel32.dll", "LoadLibraryA")
public abstract HMODULE LoadLibrary(pointer<byte> lpLibFileName);
@Windows("kernel32.dll", "FreeLibrary")
public abstract BOOL FreeLibrary(HMODULE hModule);

@Windows("kernel32.dll", "LocalAlloc")
public abstract HLOCAL LocalAlloc(unsigned uFlags, unsigned uBytes);
@Windows("kernel32.dll", "LocalFree")
public abstract HLOCAL LocalFree(HLOCAL hMem);

@Windows("kernel32.dll", "GetSystemTime")
public abstract void GetSystemTime(ref<SYSTEMTIME> lpSystemTime);
@Windows("kernel32.dll", "SetSystemTime")
public abstract BOOL SetSystemTime(ref<SYSTEMTIME> lpSystemTime);
@Windows("kernel32.dll", "SystemTimeToFileTime")
public abstract WINBOOL SystemTimeToFileTime(ref<SYSTEMTIME> lpSystemTime, ref<FILETIME> lpFileTome);
@Windows("kernel32.dll", "FileTimeToSystemTime")
public abstract WINBOOL FileTimeToSystemTime(ref<FILETIME> lpFileTome, ref<SYSTEMTIME> lpSystemTime);

@Windows("kernel32.dll", "GetCurrentThreadId")
public abstract DWORD GetCurrentThreadId();
@Windows("kernel32.dll", "CreateThread")
public abstract HANDLE CreateThread(address lpThreadAttributes, SIZE_T dwStackSize, DWORD lpStartAddress(address p), address lpParameter, DWORD dwCreationFlags, ref<DWORD> lpThreadId);
@Windows("kernel32.dll", "Sleep")
public abstract void Sleep(DWORD dwMilliseconds);

@Windows("msvcrt.dll", "_beginthread")
public abstract address _beginthread(void startAddress(address p), unsigned stackSize, address args);
@Windows("msvcrt.dll", "_beginthreadex")
public abstract address _beginthreadex(address security, unsigned stackSize, unsigned startAddress(address p), address arglist, unsigned initflag, ref<unsigned> thrdaddr);

@Windows("kernel32.dll", "CloseHandle")
private abstract BOOL CloseHandle_internal(address hHandle);
// This is a hack to get around a parameter passing mismatch. Parasol wants to pass all class objects on the stack, but HANDLE is really passed in a register.
public BOOL CloseHandle(HANDLE hHandle) {
	return CloseHandle_internal(*ref<address>(&hHandle));
}

@Windows("kernel32.dll", "WaitForSingleObject")
private abstract DWORD WaitForSingleObject_internal(address hHandle, DWORD dwMilliseconds);
// This is a hack to get around a parameter passing mismatch. Parasol wants to pass all class objects on the stack, but HANDLE is really passed in a register.
public DWORD WaitForSingleObject(HANDLE hHandle, DWORD dwMilliseconds) {
	return WaitForSingleObject_internal(*ref<address>(&hHandle), dwMilliseconds);
}
@Windows("kernel32.dll", "CreateSemaphoreA")
public abstract address CreateSemaphore(address lpSemaphoreAttributes, int lInitialCount, int lMaximumCount, ref<byte> name);
@Windows("kernel32.dll", "ReleaseSemaphore")
private abstract BOOL ReleaseSemaphore_internal(address hHandle, int lReleaseCount, ref<int> lpPreviousCount);
//This is a hack to get around a parameter passing mismatch. Parasol wants to pass all class objects on the stack, but HANDLE is really passed in a register.
public BOOL ReleaseSemaphore(HANDLE hHandle, int lReleaseCount, ref<int> lpPreviousCount) {
	return ReleaseSemaphore_internal(*ref<address>(&hHandle), lReleaseCount, lpPreviousCount);
}

@Windows("kernel32.dll", "CreateDirectory")
public abstract BOOL CreateDirectory(pointer<byte> lpPathName, ref<SECURITY_ATTRIBUTES> lpSecurityAttributes);
@Windows("kernel32.dll", "RemoveDirectory")
public abstract BOOL RemoveDirectory(pointer<byte> lpPathName);
@Windows("kernel32.dll", "DeleteFile")
public abstract BOOL DeleteFile(pointer<byte> lpPathName);

@Windows("kernel32.dll", "MoveFile")
public abstract BOOL MoveFile(pointer<byte> lpExistingFilename, pointer<byte> lpNewFilename);

@Windows("kernel32.dll", "CreateMutexA")
public abstract address CreateMutex(address lpMutexAttributes, BOOL bInitialOwner, pointer<byte> lpName);
@Windows("kernel32.dll", "ReleaseMutex")
private abstract BOOL ReleaseMutex_internal(address hHandle);
//This is a hack to get around a parameter passing mismatch. Parasol wants to pass all class objects on the stack, but HANDLE is really passed in a register.
// TODO: Check that this is still necessary
public BOOL ReleaseMutex(HANDLE hHandle) {
	return ReleaseMutex_internal(*ref<address>(&hHandle));
}

@Windows("kernel32.dll", "AddVectoredExceptionHandler")
public abstract PVOID AddVectoredExceptionHandler(ULONG first, long (ref<EXCEPTION_POINTERS>) handler);
@Windows("kernel32.dll", "RemoveVectoredExceptionHandler")
public abstract ULONG RemoveVectoredExceptionHandler(PVOID handle);

@Windows("kernel32.dll", "CreateFile")
public abstract HANDLE CreateFile(pointer<byte> lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode, ref<SECURITY_ATTRIBUTES> lpSecurityAttributes, DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes, HANDLE hTemplateFile);

@Windows("kernel32.dll", "SetFilePointerEx")
public abstract BOOL SetFilePointerEx(HANDLE hFile, long lDistanceToMove, ref<long> lpDistanceToMoveHigh, DWORD dwMoveMethod);

@Windows("kernel32.dll", "ReadFile")
public abstract BOOL ReadFile(HANDLE hFile, address lpBuffer, DWORD nNumberOfBytesToRead, ref<DWORD> lpNumbersOfBytesRead, ref<OVERLAPPED> lpOverlapped);

@Windows("kernel32.dll", "WriteFile")
public abstract BOOL WriteFile(HANDLE hFile, address lpBuffer, DWORD nNumberOfBytesToWrite, ref<DWORD> lpNumbersOfBytesWritten, ref<OVERLAPPED> lpOverlapped);

@Windows("kernel32.dll", "BCryptGenRandom")
public abstract NTSTATUS BCryptGenRandom(BCRYPT_ALG_HANDLE hProv, pointer<byte> pbBuffer, ULONG cbBuffer, ULONG dwFlags);

public class OVERLAPPED {
	long Internal;
	long InternalHigh;
	long Offset;			// Possibly also a poiner, depending on the usage
	HANDLE hEvent;
}

public class EXCEPTION_POINTERS {
	ref<EXCEPTION_RECORD> ExceptionRecord;
	ref<CONTEXT>          ContextRecord;
}

public class EXCEPTION_RECORD {
	DWORD                    ExceptionCode;
	DWORD                    ExceptionFlags;
	ref<EXCEPTION_RECORD>    ExceptionRecord;
	PVOID                    ExceptionAddress;
	DWORD                    NumberParameters;
	address                  ExceptionInformation_0;
	address                  ExceptionInformation_1;
}

public class CONTEXT {
	long P1Home;
	long P2Home;
	long P3Home;
	long P4Home;
	long P5Home;
	long P6Home;
	DWORD   ContextFlags;
	DWORD   MxCsr;
	WORD    SegCs;
	WORD    SegDs;
	WORD    SegEs;
	WORD    SegFs;
	WORD    SegGs;
	WORD    SegSs;
	DWORD   EFlags;
	long Dr0;
	long Dr1;
	long Dr2;
	long Dr3;
	long Dr6;
	long Dr7;
	long Rax;
	long Rcx;
	long Rdx;
	long Rbx;
	long Rsp;
	long Rbp;
	long Rsi;
	long Rdi;
	long R8;
	long R9;
	long R10;
	long R11;
	long R12;
	long R13;
	long R14;
	long R15;
	long Rip;
/*
	These areas are not currently used, so ignore them for now.

  union {
    XMM_SAVE_AREA32 FltSave;
    NEON128         Q[16];
    ULONGLONG       D[32];
    struct {
      M128A Header[2];
      M128A Legacy[8];
      M128A Xmm0;
      M128A Xmm1;
      M128A Xmm2;
      M128A Xmm3;
      M128A Xmm4;
      M128A Xmm5;
      M128A Xmm6;
      M128A Xmm7;
      M128A Xmm8;
      M128A Xmm9;
      M128A Xmm10;
      M128A Xmm11;
      M128A Xmm12;
      M128A Xmm13;
      M128A Xmm14;
      M128A Xmm15;
    } DUMMYSTRUCTNAME;
    DWORD           S[32];
  } DUMMYUNIONNAME;
  M128A   VectorRegister[26];
	long VectorControl;
	long DebugControl;
	long LastBranchToRip;
	long LastBranchFromRip;
	long LastExceptionToRip;
	long LastExceptionFromRip;
 */
}

public DWORD GENERIC_READ = 	0x80000000;
public DWORD GENERIC_WRITE = 	0x40000000;
public DWORD GENERIC_EXECUTE = 	0x20000000;
public DWORD GENERIC_ALL = 		0x10000000;

public DWORD FILE_SHARE_READ = 		0x1;
public DWORD FILE_SHARE_WRITE =		0x2;
public DWORD FILE_SHARE_DELETE = 	0x4;

public DWORD CREATE_NEW = 1;
public DWORD CREATE_ALWAYS = 2;
public DWORD OPEN_EXISTING = 3;
public DWORD OPEN_ALWAYS = 4;
public DWORD TRUNCATE_EXISTING = 5;

public DWORD FILE_BEGIN = 0;
public DWORD FILE_CURRENT = 1;
public DWORD FILE_END = 2;

@Windows("kernel32.dll", "_get_osfhandle")
public abstract HANDLE _get_osfhandle(int fd);

public DWORD WAIT_FAILED = DWORD(~0);
public DWORD WAIT_ABANDONED = 0x80;
public DWORD WAIT_TIMEOUT = 0x102;
public DWORD WAIT_OBJECT_0 = 0;

public DWORD INFINITE = DWORD(~0);

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

public class SYSTEMTIME {
	public WORD wYear;
	public WORD wMonth;
	public WORD wDayOfWeek;
	public WORD wDay;
	public WORD wHour;
	public WORD wMinute;
	public WORD wSecond;
	public WORD wMilliseconds;
}

public class FILETIME {
    public unsigned dwLowDateTime;
    public unsigned dwHighDateTime;
}

public DWORD FILE_ATTRIBUTE_ARCHIVE = 0x20;
public DWORD FILE_ATTRIBUTE_COMPRESSED = 0x800;
public DWORD FILE_ATTRIBUTE_DEVICE = 0x40;
public DWORD FILE_ATTRIBUTE_DIRECTORY = 0x10;
public DWORD FILE_ATTRIBUTE_ENCRYPTED = 0x4000;
public DWORD FILE_ATTRIBUTE_HIDDEN = 0x2;
public DWORD FILE_ATTRIBUTE_INTEGRITY_STREAM = 0x8000;
public DWORD FILE_ATTRIBUTE_NORMAL = 0x80;
public DWORD FILE_ATTRIBUTE_NOT_CONTENT_INDEXED = 0x2000;
public DWORD FILE_ATTRIBUTE_NO_SCRUB_DATA = 0x20000;
public DWORD FILE_ATTRIBUTE_OFF_LINE = 0x1000;
public DWORD FILE_ATTRIBUTE_READONLY = 0x1;
public DWORD FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS = 0x400000;
public DWORD FILE_ATTRIBUTE_RECALL_ON_OPEN = 0x40000;
public DWORD FILE_ATTRIBUTE_REPARSE_POINT = 0x400;
public DWORD FILE_ATTRIBUTE_SPARSE_FILE = 0x200;
public DWORD FILE_ATTRIBUTE_SYSTEM = 0x4;
public DWORD FILE_ATTRIBUTE_TEMPORARY = 0x100;
public DWORD FILE_ATTRIBUTE_VIRTUAL = 0x10000;

public class SECURITY_ATTRIBUTES {
	public DWORD nLength;
	public address lpSecurityDescriptor;
	public BOOL bInheritHandle;
}

public unsigned MEM_COMMIT = 0x00001000;
public unsigned MEM_RESERVE = 0x00002000;
public unsigned MEM_DECOMMIT = 0x00004000;
public unsigned MEM_RELEASE = 0x00008000;

public unsigned PAGE_EXECUTE = 0x10;
public unsigned PAGE_EXECUTE_READ = 0x20;
public unsigned PAGE_EXECUTE_READWRITE = 0x40;
public unsigned PAGE_READWRITE = 0x04;

@Windows("kernel32.dll", "VirtualAlloc")
public abstract address VirtualAlloc(address lpAddress, long sz, unsigned flAllocationType, unsigned flProtect);
@Windows("kernel32.dll", "VirtualProtect")
public abstract int VirtualProtect(address lpAddress, long sz, unsigned flNewProtect, ref<unsigned> lpflOldProtect);
@Windows("kernel32.dll", "VirtualFree")
public abstract BOOL VirtualFree(address lpAddress, long sz, unsigned dwFreeType);

public class WNDCLASSEX {
	public unsigned cbSize;
	public unsigned style;
	public WNDPROC lpfnWndProc;
	public int cbClsExtra;
	public int cbWndExtra;
	public HINSTANCE hInstance;
	public HICON hIcon;
	public HCURSOR hCursor;
	public HBRUSH hbrBackground;
	public pointer<byte> lpszMenuName;
	public pointer<byte> lpszClassName;
	public HICON hIconSm;
}

class WNDPROC = address;

@Windows("user32.dll", "RegisterClassExA")
public abstract ATOM RegisterClassEx(ref<WNDCLASSEX> lpwcx);

public class _locale_t = ref<__locale_t>;
@Windows("msvcrt.dll", "_create_locale")
public abstract _locale_t _create_locale(int category, pointer<byte> locale);

class __locale_t {
}

@Constant
public ULONG BCRYPT_USE_SYSTEM_PREFERRED_RNG = 2;

@Constant
public NTSTATUS STATUS_SUCCESS = 0;

