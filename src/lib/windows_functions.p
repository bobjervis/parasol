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
namespace native:windows;

public class HANDLE extends address {
	HANDLE() {
	}
	
	HANDLE(address a) {
		*super = a;
	}
	
	boolean isValid() {
		return *super != INVALID_HANDLE_VALUE;
	}
}

public HANDLE INVALID_HANDLE_VALUE = HANDLE(address(-1));

public class HMODULE = address;
public class ATOM = char;
public class HICON = address;
public class HCURSOR = address;
public class HBRUSH = address;
public class HINSTANCE = address;

public abstract int GetModuleFileName(HMODULE hModule, pointer<byte> filename, int filenameSize);
public abstract HMODULE GetModuleHandle(pointer<byte> filename);
public abstract address GetProcAddress(HMODULE hModule, pointer<byte> procName);
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

@Windows("user32.dll", "RegisterCLassExA")
public abstract ATOM RegisterClassEx(ref<WNDCLASSEX> lpwcx);
//public ATOM RegisterClassEx(ref<WNDCLASSEX> lpwcx) { return 0; }
