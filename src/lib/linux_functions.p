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
namespace native:linux;

@Linux("libc.so.6", "aligned_alloc")
public abstract address aligned_alloc(long alignment, long length);

@Linux("libc.so.6", "clock_gettime")
public abstract int clock_gettime(int clock_id, ref<timespec> tp);

@Windows("msvcrt.dll", "_close")
@Linux("libc.so", "close")
public abstract int close(int fd);

@Linux("libc.so.6", "closedir")
public abstract int closedir(ref<DIR> dirp);

@Linux("libdl.so.2", "dlclose")
public abstract int dlclose(address handle);

@Linux("libdl.so.2", "dlerror")
public abstract pointer<byte> dlerror();

@Linux("libdl.so.2", "dlopen")
public abstract address dlopen(pointer<byte> file, int mode);

@Linux("libdl.so.2", "dlsym")
public abstract address dlsym(address handle, pointer<byte> name);

@Linux("libc.so.6", "mprotect")
public abstract int mprotect(address addr, long length, int prot);

@Linux("libc.so.6", "opendir")
public abstract ref<DIR> opendir(pointer<byte> name);

@Linux("libc.so.6", "pathconf")
public abstract int pathconf(pointer<byte> path, int selector);

@Linux("libc.so.6", "readdir_r")
public abstract int readdir_r(ref<DIR> dir, ref<dirent> entry, ref<ref<dirent>> result);

@Linux("libc.so.6", "readlink")
public abstract int readlink(pointer<byte> filename, pointer<byte> buffer, int buf_len);

@Linux("libc.so.6", "realpath")
public abstract pointer<byte> realpath(pointer<byte> filename, pointer<byte> resolved_path);

@Linux("libc.so.6", "sysconf")
public abstract int sysconf(int parameter_index);

public abstract int open(pointer<byte> filename, int ioFlags);

public abstract int openCreat(pointer<byte> filename, int ioFlags, int mode);

public class DIR {
	private int dummy;			// Don't expose anything about this structure
}

@Constant
public int _PC_NAME_MAX = 4;

@Constant
public int PROT_READ = 0x01;
@Constant
public int PROT_WRITE = 0x02;
@Constant
public int PROT_EXEC = 0x04;
@Constant
public int PROT_NONE = 0x08;
@Constant
public int PROT_GROWSDOWN = 0x01000000;
@Constant
public int PROT_GROWSUP = 0x02000000;

@Constant
public int RTLD_LAZY = 0x00001;
@Constant
public int RTLD_NOW = 0x00002;
@Constant
public int RTLD_BINDING_MASK = 0x3;
@Constant
public int RTLD_NOLOAD = 0x00004;
@Constant
public int RTLD_DEEPBIND = 0x00008;

public class dirent {
    public long d_ino;
    public long d_off;
    public char d_reclen;
    public byte d_type;
	public byte d_name;
}

public class timespec {
	public int tv_sec;
	public int tv_nsec;
}

@Constant
public int CLOCK_REALTIME = 0;

enum SysConf {
	_SC_ARG_MAX,
	_SC_CHILD_MAX,
	_SC_CLK_TCK,
	_SC_NGROUPS_MAX,
	_SC_OPEN_MAX,
	_SC_STREAM_MAX,
	_SC_TZNAME_MAX,
	_SC_JOB_CONTROL,
	_SC_SAVED_IDS,
	_SC_REALIME_SIGNALS,
	_SC_PRIORITY_SCHEDULING,
	_SC_TIMERS,
	_SC_ASYNCHRONOUS_IO,
	_SC_PRIORITIZED_IO,
	_SC_SYNCHRONIZED_IO,
	_SC_FSYNC,
	_SC_MAPPED_FILES,
	_SC_MEMLOCK,
	_SC_MEMLOCK_RANGE,
	_SC_MEMORY_PROTECTION,
	_SC_MESSAGE_PASSING,
	_SC_SEMAPHORES,
	_SC_SHARED_MEMORY_OBJECTS,
	_SC_AIO_LISTIO_MAX,
	_SC_AIO_MAX,
	_SC_AIO_PRIO_DELTA_MAX,
	_SC_DELAYTIMER_MAX,
	_SC_MQ_OPEN_MAX,
	_SC_MQ_PRIO_MAX,
	_SC_VERSION,
	_SC_PAGESIZE,
	_SC_RTSIG_MAX,
	_SC_SEM_NSEMS_MAX,
	_SC_SEM_VALUE_MAX,
	_SC_SIGQUEUE_MAX,
	_SC_TIMER_MAX,
	_SC_BC_BASE_MAX,
	_SC_BC_DIM_MAX,
	_SC_BC_SCALE_MAX,
	_SC_BC_STRING_MAX,
	_SC_COLL_WEIGHTS_MAX,
	_SC_EQUIV_CLASS_MAX,
	_SC_EXPR_NEXT_MAX,
	_SC_LINE_MAX,
	_SC_RE_DUP_MAX,
	_SC_CHARCLASS_NAME_MAX,
	_SC_2_VERSION,
	_SC_2_C_BIND,
	_SC_2_C_DEV,
	_SC_2_FORT_DEV,
	_SC_2_FORT_RUN,
	_SC_2_SW_DEV,
	_SC_2_LOCALDEF,
	_SC_PII,
	_SC_PII_XTI,
	_SC_PII_SOCKET,
	_SC_PII_INTERNET,
	_SC_PII_OSI,
	// ... plus a lot more than I have the energy to enter today.
}