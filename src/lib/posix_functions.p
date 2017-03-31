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
namespace native:posix;

public abstract int open(pointer<byte> filename, int ioFlags);

public abstract int openCreat(pointer<byte> filename, int ioFlags, int mode);

public abstract int close(int fd);

@Linux("libc.so", "readlink")
public abstract int readlink(pointer<byte> filename, pointer<byte> buffer, int buf_len);

@Linux("libc.so", "opendir")
public abstract ref<DIR> opendir(pointer<byte> name);

@Linux("libc.so", "closedir")
public abstract int closedir(ref<DIR> dirp);

@Linux("libc.so", "clock_gettime")
public abstract int clock_gettime(int clock_id, ref<timespec> tp);

public class DIR {
	private int dummy;			// Don't expose anything about this structure
}

public class dirent {
	public byte d_name;
}

public class timespec {
	public int tv_sec;
	public int tv_nsec;
}

@Constant
public int CLOCK_REALTIME = 0;