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
 * This namespace provides access to the linux C-language library and system calls.
 *
 * Most of the functions and types defined here should be familiar to anyone who has programmed 
 * Linux in C.
 *
 * One notable difference is the {@link native:linux.stat} call, which fills in a C stat structure.
 * Since Parasol does not allow a function and a class in the same scope to have the same name, for
 * Parasol, the class is called {@link native:linux.statStruct}.
 */
namespace native:linux;

import native:net.sockaddr;
import native:C.size_t;
import native:C.time_t;
import native:C.tm;

public class pid_t = int;
public class pthread_t = address;
public class uid_t = unsigned;
public class gid_t = unsigned;
public class useconds_t = unsigned;
public class mode_t = unsigned;
public class fsblkcnt_t = long;
public class fsfilcnt_t = long;
public class off_t = long;

public class locale_t = ref<__locale_t>;

class __locale_t {
}

@Linux("libc.so.6", "aligned_alloc")
public abstract address aligned_alloc(long alignment, long length);

@Linux("libc.so.6", "chdir")
public abstract int chdir(pointer<byte> path);

@Linux("libc.so.6", "chmod")
public abstract int chmod(pointer<byte> path, mode_t mode);

@Linux("libc.so.6", "clock_gettime")
public abstract int clock_gettime(int clock_id, ref<timespec> tp);

@Windows("msvcrt.dll", "_close")
@Linux("libc.so.6", "close")
public abstract int close(int fd);

@Linux("libc.so.6", "closedir")
public abstract int closedir(ref<DIR> dirp);

@Linux("libc.so.6", "creat")
public abstract int creat(pointer<byte> pathname, mode_t mode);

@Linux("libdl.so.2", "dladdr")
public abstract int dladdr(address addr, ref<Dl_info> info);

@Linux("libdl.so.2", "dlclose")
public abstract int dlclose(address handle);

@Linux("libdl.so.2", "dlerror")
public abstract pointer<byte> dlerror();

@Linux("libdl.so.2", "dlopen")
public abstract address dlopen(pointer<byte> file, int mode);

@Linux("libdl.so.2", "dlsym")
public abstract address dlsym(address handle, pointer<byte> name);

@Linux("libc.so.6", "dup2")
public abstract int dup2(int oldfd, int newfd);

@Linux("libc.so.6", "__errno_location")
private abstract ref<int> __errno_location();

@Linux("libc.so.6", "_exit")
public abstract void _exit(int status);

@Linux("libc.so.6", "execv")
public abstract int execv(pointer<byte> path, pointer<pointer<byte>> argv);

@Linux("libc.so.6", "fcntl")
public abstract int fcntl(int fd, int cmd, int arg0);

@Linux("libc.so.6", "fdatasync")
public abstract int fdatasync(int fd);

@Linux("libc.so.6", "fork")
public abstract pid_t fork();

@Linux("libc.so.6", "getcwd")
public abstract pointer<byte> getcwd(pointer<byte> buf, long len);

@Linux("libc.so.6", "geteuid")
public abstract uid_t geteuid();

@Linux("libc.so.6", "getgrouplist")
public abstract uid_t getgrouplist(pointer<byte> user, gid_t group, pointer<gid_t> groups, ref<int> ngroups);

@Linux("libc.so.6", "gethostname")
public abstract int gethostname(pointer<byte> name, size_t len);

@Linux("libc.so.6", "getifaddrs")
public abstract int getifaddrs(ref<ref<ifaddrs>> ifap);

@Linux("libc.so.6", "getpid")
public abstract pid_t getpid();

@Linux("libc.so.6", "getppid")
public abstract pid_t getppid();

@Linux("libc.so.6", "getpwnam_r")
public abstract int getpwnam_r(pointer<byte> name, ref<passwd> pwd, address buffer, size_t buflen, ref<ref<passwd>> result);

@Linux("libc.so.6", "getrlimit")
public abstract int getrlimit(int resource, ref<rlimit> rlim);

@Linux("libc.so.6", "getuid")
public abstract uid_t getuid();

@Linux("libc.so.6", "glob")
public abstract int glob(pointer<byte> pattern, int _flags, int(pointer<byte>, int) errfunc, ref<glob_t> pglob);

@Linux("libc.so.6", "globfree")
public abstract int globfree(ref<glob_t> pglob);

@Linux("libc.so.6", "grantpt")
public abstract int grantpt(int fd);

@Linux("libc.so.6", "isatty")
public abstract int isatty(int fd);

@Linux("libc.so.6", "kill")
public abstract int kill(pid_t pid, int sig);

@Linux("libc.so.6", "link")
public abstract int link(pointer<byte> oldpath, pointer<byte> newpath);

@Linux("libc.so.6", "lseek")
public abstract off_t lseek(int fd, off_t offset, int whence);

@Linux("libc.so.6", "mkdir")
public abstract int mkdir(pointer<byte> path, mode_t mode);

@Linux("libc.so.6", "mprotect")
public abstract int mprotect(address addr, long length, int prot);

@Linux("libc.so.6", "nanosleep")
public abstract int nanosleep(ref<timespec> req, ref<timespec> rem);

@Linux("libc.so.6", "newlocale")
public abstract locale_t newlocale(int categoryMask, pointer<byte> locale, locale_t base);

@Linux("libc.so.6", "open")
public abstract int open(pointer<byte> pathname, int openFlags);

@Linux("libc.so.6", "open")
public abstract int open(pointer<byte> pathname, int openFlags, mode_t mode);

@Linux("libc.so.6", "opendir")
public abstract ref<DIR> opendir(pointer<byte> name);

@Linux("libc.so.6", "pathconf")
public abstract int pathconf(pointer<byte> path, int selector);

@Linux("libc.so.6", "perror")
public abstract void perror(pointer<byte> message);

@Linux("libc.so.6", "pipe")
public abstract int pipe(pointer<int> pipefd);

@Linux("libc.so.6", "posix_openpt")
public abstract int posix_openpt(int openFlags);

@Linux("libpthread.so.0", "pthread_cond_destroy")
public abstract pthread_t pthread_cond_destroy(ref<pthread_cond_t> conditionVariable);

@Linux("libpthread.so.0", "pthread_cond_init")
public abstract pthread_t pthread_cond_init(ref<pthread_cond_t> conditionVariable, ref<pthread_condattr_t> attr);

@Linux("libpthread.so.0", "pthread_cond_signal")
public abstract pthread_t pthread_cond_signal(ref<pthread_cond_t> conditionVariable);

@Linux("libpthread.so.0", "pthread_cond_timedwait")
public abstract int pthread_cond_timedwait(ref<pthread_cond_t> conditionVariable, ref<pthread_mutex_t> mutex, ref<timespec> termination);

@Linux("libpthread.so.0", "pthread_create")
public abstract int pthread_create(ref<pthread_t> thread, ref<pthread_attr_t> attr, address start_routine(address arg), address arg);

@Linux("libpthread.so.0", "pthread_exit")
public abstract void pthread_exit(address retval);

@Linux("libpthread.so.0", "pthread_join")
public abstract int pthread_join(pthread_t thread, ref<address> retval);

@Linux("libpthread.so.0", "pthread_mutex_destroy")
public abstract int pthread_mutex_destroy(ref<pthread_mutex_t> mutex);

@Linux("libpthread.so.0", "pthread_mutex_init")
public abstract int pthread_mutex_init(ref<pthread_mutex_t> mutex, ref<pthread_mutexattr_t> attr);

@Linux("libpthread.so.0", "pthread_mutex_lock")
public abstract int pthread_mutex_lock(ref<pthread_mutex_t> mutex);

@Linux("libpthread.so.0", "pthread_mutex_trylock")
public abstract int pthread_mutex_trylock(ref<pthread_mutex_t> mutex);

@Linux("libpthread.so.0", "pthread_mutex_unlock")
public abstract int pthread_mutex_unlock(ref<pthread_mutex_t> mutex);

@Linux("libpthread.so.0", "pthread_mutexattr_settype")
public abstract int pthread_mutexattr_settype(ref<pthread_mutexattr_t> attr, int type);

@Linux("libpthread.so.0", "pthread_self")
public abstract pthread_t pthread_self();

@Linux("libpthread.so.0", "pthread_sigmask")
public abstract pthread_t pthread_sigmask(int how, ref<sigset_t> set, ref<sigset_t> oldset);

@Linux("libc.so.6", "ptsname_r")
public abstract int ptsname_r(int fd, pointer<byte> buf, size_t buflen);

@Linux("libc.so.6", "read")
public abstract int read(int fd, address buffer, long bufferSize);

@Linux("libc.so.6", "readdir_r")
public abstract int readdir_r(ref<DIR> dir, ref<dirent> entry, ref<ref<dirent>> result);

@Linux("libc.so.6", "readlink")
public abstract int readlink(pointer<byte> filename, pointer<byte> buffer, int buf_len);

@Linux("libc.so.6", "realpath")
public abstract pointer<byte> realpath(pointer<byte> filename, pointer<byte> resolved_path);

@Linux("libc.so.6", "rmdir")
public abstract int rmdir(pointer<byte> path);

@Linux("libpthread.so.0", "sem_destroy")
public abstract int sem_destroy(ref<sem_t> sem);

@Linux("libpthread.so.0", "sem_init")
public abstract int sem_init(ref<sem_t> sem, int pshared, unsigned value);

@Linux("libpthread.so.0", "sem_post")
public abstract int sem_post(ref<sem_t> sem);

@Linux("libpthread.so.0", "sem_timedwait")
public abstract int sem_timedwait(ref<sem_t> sem, ref<timespec> abs_timeout);

@Linux("libpthread.so.0", "sem_wait")
public abstract int sem_wait(ref<sem_t> sem);

@Linux("libc.so.6", "setenv")
public abstract int setenv(pointer<byte> name, pointer<byte> value, int overwrite);

@Linux("libc.so.6", "seteuid")
public abstract int seteuid(uid_t uid);

@Linux("libc.so.6", "setfsuid")
public abstract int setfsuid(uid_t uid);

@Linux("libc.so.6", "setpgrp")
public abstract int setpgrp();

@Linux("libc.so.6", "setreuid")
public abstract int setreuid(uid_t ruid, uid_t euid);

@Linux("libc.so.6", "setrlimit")
public abstract int setrlimit(int resource, ref<rlimit> rlim);

@Linux("libc.so.6", "setuid")
public abstract int setuid(uid_t uid);

@Linux("libc.so.6", "sigaction")
public abstract int sigaction(int signum, ref<struct_sigaction> act, ref<struct_sigaction> oldact);

@Linux("libc.so.6", "sigaddset")
public abstract int sigaddset(ref<sigset_t> set, int signum);

@Linux("libc.so.6", "sigandset")
public abstract int sigandset(ref<sigset_t> dest, ref<sigset_t> left, ref<sigset_t> right);

@Linux("libc.so.6", "sigdelset")
public abstract int sigdelset(ref<sigset_t> set, int signum);

@Linux("libc.so.6", "sigemptyset")
public abstract int sigemptyset(ref<sigset_t> set);

@Linux("libc.so.6", "sigfillset")
public abstract int sigfillset(ref<sigset_t> set);

@Linux("libc.so.6", "sigisemptyset")
public abstract int sigisemptyset(ref<sigset_t> set);

@Linux("libc.so.6", "sigismember")
public abstract int sigismember(ref<sigset_t> set, int signum);

@Linux("libc.so.6", "sigorset")
public abstract int sigorset(ref<sigset_t> dest, ref<sigset_t> left, ref<sigset_t> right);

@Linux("libc.so.6", "sigwaitinfo")
public abstract int sigwaitinfo(ref<sigset_t> set, ref<siginfo_t> info);

@Linux("libc.so.6", "symlink")
public abstract int symlink(pointer<byte> oldpath, pointer<byte> newpath);

@Linux("libc.so.6", "syscall")
public abstract long syscall(long callId);

@Linux("libc.so.6", "syscall")
public abstract long syscall(long callId, long p1);

@Linux("libc.so.6", "syscall")
public abstract long syscall(long callId, long p1, long p2);

@Linux("libc.so.6", "syscall")
public abstract long syscall(long callId, long p1, long p2, long p3);

@Linux("libc.so.6", "statvfs")
public abstract int statvfs(pointer<byte> path, ref<statvfsStruct> buf);

@Linux("libc.so.6", "sysconf")
public abstract int sysconf(int parameter_index);

@Linux("libc.so.6", "tcgetattr")
public abstract int tcgetattr(int fd, ref<termios> termios_p);

@Linux("libc.so.6", "tcsetattr")
public abstract int tcsetattr(int fd, int optional_actions, ref<termios> termios_p);

@Linux("libc.so.6", "timegm")
public abstract time_t timegm(ref<tm> time);

@Linux("libc.so.6", "unlink")
public abstract int unlink(pointer<byte> path);

@Linux("libc.so.6", "unlockpt")
public abstract int unlockpt(int fd);

@Linux("libc.so.6", "unsetenv")
public abstract int unsetenv(pointer<byte> name);

@Linux("libc.so.6", "usleep")
public abstract int usleep(useconds_t usec);

@Linux("libc.so.6", "utime")
public abstract int utime(pointer<byte> filename, ref<utimbuf> times);

@Linux("libc.so.6", "utimes")
public abstract int utimes(pointer<byte> filename, ref<timevalPair> times);

@Linux("libc.so.6", "vfork")
public abstract pid_t vfork();

@Linux("libc.so.6", "wait")
public abstract pid_t wait(ref<int> exitStatus);

//@Linux("libc.so.6", "waitid")
//public abstract int waitid()

@Linux("libc.so.6", "waitpid")
public abstract pid_t waitpid(pid_t pid, ref<int> exitStatus, int options);

@Linux("libc.so.6", "write")
public abstract int write(int fd, address buffer, long bufferSize);

@Linux("libc.so.6", "__fxstat")
public abstract int __fxstat(int statVersion, int fd, ref<statStruct> buf);

@Linux("libc.so.6", "__lxstat")
public abstract int __lxstat(int statVersion, pointer<byte> path, ref<statStruct> buf);

@Linux("libc.so.6", "__xstat")
public abstract int __xstat(int statVersion, pointer<byte> path, ref<statStruct> buf);

/*
 * Hack to get the tid - gettid is not in the Linux library, so we have to resort to this...
 */
public pid_t gettid() {
	return pid_t(syscall(186));
}
/*
 * POSIX requires that seteuid set all thread's permissions in the process, but this call side-steps
 * the POSIX requirements and switches just the calling thread's permissions. This should be used with caution
 * (duh!)
 */
public int thread_seteuid(uid_t uid) {
	return int(syscall(117, -1, uid, -1));
}

public int lstat(pointer<byte> path, ref<statStruct> buf) {
	return __lxstat(1, path, buf);
}

public int stat(pointer<byte> path, ref<statStruct> buf) {
	return __xstat(1, path, buf);
}

public int fstat(int fd, ref<statStruct> buf) {
	return __fxstat(1, fd, buf);
}

public int tgkill(int tgid, int tid, int sig) {
	return int(syscall(234, tgid, tid, sig));
}
/**
 * Note that errno() in Parasol is a call to a function, rather than a simple variable.
 */
public int errno() {
	return *__errno_location();
}

public class cc_t = byte;
public class tcflag_t = unsigned;
public class speed_t = unsigned;

public class termios {
    public tcflag_t c_iflag;           /* input mode flags */
    public tcflag_t c_oflag;           /* output mode flags */
    public tcflag_t c_cflag;           /* control mode flags */
    public tcflag_t c_lflag;           /* local mode flags */
    public cc_t c_line;                /* line discipline */
	// The C struct defines an array of 32 control characters.
    public cc_t c_cc1;	               /* control characters */
    public cc_t c_cc2;	               /* control characters */
    public cc_t c_cc3;	               /* control characters */
    public cc_t c_cc4;	               /* control characters */
    public cc_t c_cc5;	               /* control characters */
    public cc_t c_cc6;	               /* control characters */
    public cc_t c_cc7;	               /* control characters */
    public long c_cc08_15;             /* control characters */
    public long c_cc16_23;             /* control characters */
    public long c_cc24_31;             /* control characters */
	public cc_t c_cc32;                /* control characters */
    public speed_t c_ispeed;           /* input speed */
    public speed_t c_ospeed;           /* output speed */

	// Use these accessors to manipulate the cc elements.
	public void set_cc(int i, byte value) {
		pointer<byte> p = pointer<byte>(&c_cc1);
		p[i] = value;
	}

	public byte get_cc(int i) {
		pointer<byte> p = pointer<byte>(&c_cc1);
		return p[i];
	}
}

/* c_oflag bits */
/*
#define OPOST   0000001
#define OLCUC   0000002
#define ONLCR   0000004
#define OCRNL   0000010
#define ONOCR   0000020
*/
@constant
public unsigned ONLRET = 0000040;
/*
#define OFILL   0000100
#define OFDEL   0000200
#if defined __USE_MISC || defined __USE_XOPEN
# define NLDLY  0000400
# define   NL0  0000000
# define   NL1  0000400
# define CRDLY  0003000
# define   CR0  0000000
# define   CR1  0001000
# define   CR2  0002000
# define   CR3  0003000
# define TABDLY 0014000
# define   TAB0 0000000
# define   TAB1 0004000
# define   TAB2 0010000
# define   TAB3 0014000
# define BSDLY  0020000
# define   BS0  0000000
# define   BS1  0020000
# define FFDLY  0100000
# define   FF0  0000000
# define   FF1  0100000
#endif

#define VTDLY   0040000
#define   VT0   0000000
#define   VT1   0040000

#ifdef __USE_MISC
# define XTABS  0014000
#endif
*/

public class DIR {
	private int dummy;			// Don't expose anything about this structure
}

public class Dl_info {
	public pointer<byte> dli_fname;        /* File name of defining object.  */
  	public address       dli_fbase;        /* Load address of that object.  */
	public pointer<byte> dli_sname;        /* Name of nearest symbol.  */
	public address		 dli_saddr;        /* Exact value of nearest symbol.  */
}
/**
 * The Parasol equivalent of the C stat structure.
 */
public class statStruct {
    long st_dev;		/* Device.  */
    long st_ino;		/* File serial number.	*/
    long st_nlink;		/* Link count.  */
    unsigned st_mode;		/* File mode.  */
    unsigned st_uid;		/* User ID of the file's owner.	*/
    unsigned st_gid;		/* Group ID of the file's group.*/
    int __pad0;
    long st_rdev;		/* Device number, if device.  */
    long st_size;			/* Size of file, in bytes.  */
    long st_blksize;	/* Optimal block size for I/O.  */
    long st_blocks;		/* Number 512-byte blocks allocated. */
    /* Nanosecond resolution timestamps are stored in a format
       equivalent to 'struct timespec'.  This is the type used
       whenever possible but the Unix namespace rules do not allow the
       identifier 'timespec' to appear in the <sys/stat.h> header.
       Therefore we have to handle the use of this header in strictly
       standard-compliant sources special.  */
    timespec st_atim;		/* Time of last access.  */
    timespec st_mtim;		/* Time of last modification.  */
    timespec st_ctim;		/* Time of last status change.  */
    long __glibc_reserved0;
    long __glibc_reserved1;
    long __glibc_reserved2;
}

public class ifaddrs {
	  public ref<ifaddrs> ifa_next;		/* Pointer to the next structure.  */

	  public pointer<byte> ifa_name;	/* Name of this network interface.  */
	  public unsigned ifa_flags;		/* Flags as from SIOCGIFFLAGS ioctl.  */

	  public ref<sockaddr> ifa_addr;	/* Network address of this interface.  */
	  public ref<sockaddr> ifa_netmask; /* Netmask of this interface.  */
	  public ref<sockaddr> ifa_dstaddr; /* Point-to-point destination address */
	  
	  public ref<sockaddr> ifa_broadaddr() {
		  return ifa_dstaddr;
	  }

	  public address ifa_data;			/* Address-specific data (may be unused).  */
}

public class statvfsStruct {
	long f_bsize;
	long f_frsize;
	fsblkcnt_t f_blocks;
	fsblkcnt_t f_bfree;
	fsblkcnt_t f_bavail;
	fsfilcnt_t f_files;
	fsfilcnt_t f_ffree;
	fsfilcnt_t f_favail;
	long f_fsid;
	long f_flag;
	long f_namemax;
	int f_spare0;
	int f_spare1;
	int f_spare2;
	int f_spare3;
	int f_spare4;
	int f_spare5;
}

public class utimbuf {
	time_t actime;					/* access time */
	time_t modtime;					/* modification time */
}

public class timeval {
	long tv_sec;					/* seconds */
	long tv_usec;					/* microseconds */
}

public class timevalPair {
	public timeval accessTime;
	public timeval modificationTime;
}
	
public class glob_t {
	public size_t gl_pathc;       				/* Count of paths matched by the pattern.  */
    public pointer<pointer<byte>> gl_pathv;     /* List of matched pathnames.  */
    public size_t gl_offs;           /* Slots to reserve in `gl_pathv'.  */
    public int gl_flags;               /* Set to FLAGS, maybe | GLOB_MAGCHAR.  */

    /* If the GLOB_ALTDIRFUNC flag is set, the following functions
       are used instead of the normal file access functions.  */
    public void(address) gl_closedir;
    public address(address) gl_readdir;
	public address(pointer<byte>) gl_opendir;
    public int(pointer<byte>, address) gl_lstat;
    public int(pointer<byte>, address) gl_stat;
}

@Constant
public int PATH_MAX = 4096;

/* Error returns from `glob'.  */
public int GLOB_NOSPACE =    1;       /* Ran out of memory.  */
public int GLOB_ABORTED =    2;       /* Read error.  */
public int GLOB_NOMATCH =    3;       /* No matches found.  */
public int GLOB_NOSYS =      4;       /* Not implemented.  */

@Constant
public int LC_CTYPE              = 0;
@Constant
public int LC_NUMERIC            = 1;
@Constant
public int LC_TIME               = 2;
@Constant
public int LC_COLLATE            = 3;
@Constant
public int LC_MONETARY           = 4;
@Constant
public int LC_MESSAGES           = 5;
@Constant
public int LC_ALL                = 6;
@Constant
public int LC_PAPER              = 7;
@Constant
public int LC_NAME               = 8;
@Constant
public int LC_ADDRESS            = 9;
@Constant
public int LC_TELEPHONE          = 10;
@Constant
public int LC_MEASUREMENT        = 11;
@Constant
public int LC_IDENTIFICATION     = 12;

/* These are the bits that can be set in the CATEGORY_MASK argument to
   `newlocale'.  In the GNU implementation, LC_FOO_MASK has the value
   of (1 << LC_FOO), but this is not a part of the interface that
   callers can assume will be true.  */
//@Constant
public int LC_CTYPE_MASK          = (1 << LC_CTYPE);
public int LC_NUMERIC_MASK        = (1 << LC_NUMERIC);
public int LC_TIME_MASK           = (1 << LC_TIME);
public int LC_COLLATE_MASK        = (1 << LC_COLLATE);
public int LC_MONETARY_MASK       = (1 << LC_MONETARY);
public int LC_MESSAGES_MASK       = (1 << LC_MESSAGES);
public int LC_PAPER_MASK          = (1 << LC_PAPER);
public int LC_NAME_MASK           = (1 << LC_NAME);
public int LC_ADDRESS_MASK        = (1 << LC_ADDRESS);
public int LC_TELEPHONE_MASK      = (1 << LC_TELEPHONE);
public int LC_MEASUREMENT_MASK    = (1 << LC_MEASUREMENT);
public int LC_IDENTIFICATION_MASK = (1 << LC_IDENTIFICATION);
public int LC_ALL_MASK            = (LC_CTYPE_MASK
                                 | LC_NUMERIC_MASK
                                 | LC_TIME_MASK
                                 | LC_COLLATE_MASK
                                 | LC_MONETARY_MASK
                                 | LC_MESSAGES_MASK
                                 | LC_PAPER_MASK
                                 | LC_NAME_MASK
                                 | LC_ADDRESS_MASK
                                 | LC_TELEPHONE_MASK
                                 | LC_MEASUREMENT_MASK
                                 | LC_IDENTIFICATION_MASK
                                 );

@Constant
public int HOST_NAME_MAX = 64;

@Constant
public int O_ACCMODE =   00000003;
@Constant
public int O_RDONLY =    00000000;
@Constant
public int O_WRONLY =    00000001;
@Constant
public int O_RDWR =      00000002;
@Constant
public int O_CREATE =    00000100;
@Constant
public int O_EXCL =      00000200;
@Constant
public int O_NOCTTY =    00000400;
@Constant
public int O_TRUNC =     00001000;
@Constant
public int O_APPEND =    00002000;
@Constant
public int O_NONBLOCK =  00004000;
@Constant
public int O_DSYNC =     00010000;
@Constant
public int FASYNC =      00020000;
@Constant
public int O_DIRECT =    00040000;
@Constant
public int O_LARGEFILE = 00100000;
@Constant
public int O_DIRECTORY = 00200000;
@Constant
public int O_NOFOLLOW =  00400000;
@Constant
public int O_NOATIME =   01000000;
@Constant
public int O_CLOEXEC =   02000000;

@Constant
public int _PC_NAME_MAX = 4;@Constant


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

@Constant
public int SIGHUP = 1;		/* Hangup (POSIX).  */
@Constant
public int SIGINT = 2;		/* interrupt (ANSI).  */
@Constant
public int SIGQUIT = 3;		/* Quit (POSIX).  */
@Constant
public int SIGILL = 4;		/* Illegal instruction (ANSI).  */
@Constant
public int SIGTRAP = 5;		/* Trace trap (POSIX).  */
@Constant
public int SIGABRT = 6;		/* Abort (ANSI).  */
@Constant
public int SIGIOT = 6;		/* IOT trap (4.2 BSD).  */
@Constant
public int SIGBUS = 7;		/* BUS error (4.2 BSD).  */
@Constant
public int SIGFPE = 8;		/* Floating-point exception (ANSI).  */
@Constant
public int SIGKILL = 9;		/* Kill, unblockable (POSIX).  */
@Constant
public int SIGUSR1 = 10;	/* User-defined signal 1 (POSIX).  */
@Constant
public int SIGSEGV = 11;	/* Segmentation violation (ANSI).  */
@Constant
public int SIGUSR2 = 12;	/* User-defined signal 2 (POSIX).  */
@Constant
public int SIGPIPE = 13;	/* Broken pipe (POSIX).  */
@Constant
public int SIGALRM = 14;	/* Alarm clock (POSIX).  */
@Constant
public int SIGTERM = 15;	/* Termination (ANSI).  */
@Constant
public int SIGSTKFLT = 16;	/* Stack fault.  */
@Constant
public int SIGCLD = 17;		/* Same as SIGCHLD (System V).  */
@Constant
public int SIGCHLD = 17;	/* Child status has changed (POSIX).  */
@Constant
public int SIGCONT = 18;	/* Continue (POSIX).  */
@Constant
public int SIGSTOP = 19;	/* Stop, unblockable (POSIX).  */
@Constant
public int SIGTSTP = 20;	/* Keyboard stop (POSIX).  */
@Constant
public int SIGTTIN = 21;	/* Background read from tty (POSIX).  */
@Constant
public int SIGTTOU = 22;	/* Background write to tty (POSIX).  */
@Constant
public int SIGURG = 23;		/* Urgent condition on socket (4.2 BSD).  */
@Constant
public int SIGXCPU = 24;	/* CPU limit exceeded (4.2 BSD).  */
@Constant
public int SIGXFSZ = 25;	/* File size limit exceeded (4.2 BSD).  */
@Constant
public int SIGVTALRM = 26;	/* Virtual alarm clock (4.2 BSD).  */
@Constant
public int SIGPROF = 27;	/* Profiling alarm clock (4.2 BSD).  */
@Constant
public int SIGWINCH = 28;	/* Window size change (4.3 BSD, Sun).  */
@Constant
public int SIGPOLL = 29;	/* Pollable event occurred (System V).  */
@Constant
public int SIGIO = 29;		/* I/O now possible (4.2 BSD).  */
@Constant
public int SIGPWR = 30;		/* Power failure restart (System V).  */
@Constant
public int SIGSYS = 31;		/* Bad system call.  */
@Constant
public int SIGUNUSED = 31;

/* 'How' parameter to sigprocmask or pthread_sigmask */

@Constant
public int SIG_BLOCK = 0;

@Constant
public int SIG_UNBLOCK = 1;

@Constant
public int SIG_SETMASK = 2;

/* Bits in `sa_flags'.  */
@Constant
public int SA_NOCLDSTOP = 1;		 /* Don't send SIGCHLD when children stop.  */
@Constant
public int SA_NOCLDWAIT = 2;		 /* Don't create zombie on child death.  */
@Constant
public int SA_SIGINFO = 4;			 /* Invoke signal-catching function with
				    					three arguments instead of one.  */
@Constant
public int SA_ONSTACK = 0x08000000;	 /* Use signal stack by using `sa_restorer'. */
@Constant
public int SA_RESTART = 0x10000000;  /* Restart syscall on signal return.  */
@Constant
public int SA_NODEFER = 0x40000000;  /* Don't automatically block the signal when
				    					its handler is being executed.  */
public int SA_RESETHAND = int(0x80000000); /* Reset to SIG_DFL on entry to handler.  */

/* Some aliases for the SA_ constants.  */
public int SA_NOMASK = SA_NODEFER;
public int SA_ONESHOT = SA_RESETHAND;
public int SA_STACK = SA_ONSTACK;

@Constant
public int	CLD_EXITED = 1;               /* Child has exited.  */
@Constant
public int	CLD_KILLED = 2;               /* Child was killed.  */
@Constant
public int	CLD_DUMPED = 3;               /* Child terminated abnormally.  */
@Constant
public int	CLD_TRAPPED = 4;              /* Traced child has trapped.  */
@Constant
public int	CLD_STOPPED = 5;              /* Child has stopped.  */
@Constant
public int	CLD_CONTINUED = 6;            /* Stopped child has continued.  */


@Constant
public int _NSIG = 65;	/* Biggest signal number + 1 */
/*
#define	EPERM		 1	/* Operation not permitted */
#define	ENOENT		 2	/* No such file or directory */
#define	ESRCH		 3	/* No such process */
 */
@Constant
public int EINTR = 4;	/* Interrupted system call */
@Constant
public int EIO = 5;		/* I/O error */
/*
#define	ENXIO		 6	/* No such device or address */
#define	E2BIG		 7	/* Argument list too long */
#define	ENOEXEC		 8	/* Exec format error */
#define	EBADF		 9	/* Bad file number */
#define	ECHILD		10	/* No child processes */
#define	EAGAIN		11	/* Try again */
#define	ENOMEM		12	/* Out of memory */
#define	EACCES		13	/* Permission denied */
#define	EFAULT		14	/* Bad address */
#define	ENOTBLK		15	/* Block device required */
*/
@Constant
public int EBUSY = 16;	/* Device or resource busy */
/*
#define	EEXIST		17	/* File exists */
#define	EXDEV		18	/* Cross-device link */
#define	ENODEV		19	/* No such device */
#define	ENOTDIR		20	/* Not a directory */
#define	EISDIR		21	/* Is a directory */
#define	EINVAL		22	/* Invalid argument */
#define	ENFILE		23	/* File table overflow */
#define	EMFILE		24	/* Too many open files */
#define	ENOTTY		25	/* Not a typewriter */
#define	ETXTBSY		26	/* Text file busy */
#define	EFBIG		27	/* File too large */
#define	ENOSPC		28	/* No space left on device */
#define	ESPIPE		29	/* Illegal seek */
#define	EROFS		30	/* Read-only file system */
#define	EMLINK		31	/* Too many links */
#define	EPIPE		32	/* Broken pipe */
#define	EDOM		33	/* Math argument out of domain of func */
#define	ERANGE		34	/* Math result not representable */

#define	EDEADLK		35	/* Resource deadlock would occur */
#define	ENAMETOOLONG	36	/* File name too long */
#define	ENOLCK		37	/* No record locks available */

/*
 * This error code is special: arch syscall entry code will return
 * -ENOSYS if users try to call a syscall that doesn't exist.  To keep
 * failures of syscalls that really do exist distinguishable from
 * failures due to attempts to use a nonexistent syscall, syscall
 * implementations should refrain from returning -ENOSYS.
 */
#define	ENOSYS		38	/* Invalid system call number */

#define	ENOTEMPTY	39	/* Directory not empty */
#define	ELOOP		40	/* Too many symbolic links encountered */
#define	EWOULDBLOCK	EAGAIN	/* Operation would block */
#define	ENOMSG		42	/* No message of desired type */
#define	EIDRM		43	/* Identifier removed */
#define	ECHRNG		44	/* Channel number out of range */
#define	EL2NSYNC	45	/* Level 2 not synchronized */
#define	EL3HLT		46	/* Level 3 halted */
#define	EL3RST		47	/* Level 3 reset */
#define	ELNRNG		48	/* Link number out of range */
#define	EUNATCH		49	/* Protocol driver not attached */
#define	ENOCSI		50	/* No CSI structure available */
#define	EL2HLT		51	/* Level 2 halted */
#define	EBADE		52	/* Invalid exchange */
#define	EBADR		53	/* Invalid request descriptor */
#define	EXFULL		54	/* Exchange full */
#define	ENOANO		55	/* No anode */
#define	EBADRQC		56	/* Invalid request code */
#define	EBADSLT		57	/* Invalid slot */

#define	EDEADLOCK	EDEADLK

#define	EBFONT		59	/* Bad font file format */
#define	ENOSTR		60	/* Device not a stream */
#define	ENODATA		61	/* No data available */
#define	ETIME		62	/* Timer expired */
#define	ENOSR		63	/* Out of streams resources */
#define	ENONET		64	/* Machine is not on the network */
#define	ENOPKG		65	/* Package not installed */
#define	EREMOTE		66	/* Object is remote */
#define	ENOLINK		67	/* Link has been severed */
#define	EADV		68	/* Advertise error */
#define	ESRMNT		69	/* Srmount error */
#define	ECOMM		70	/* Communication error on send */
#define	EPROTO		71	/* Protocol error */
#define	EMULTIHOP	72	/* Multihop attempted */
#define	EDOTDOT		73	/* RFS specific error */
#define	EBADMSG		74	/* Not a data message */
#define	EOVERFLOW	75	/* Value too large for defined data type */
#define	ENOTUNIQ	76	/* Name not unique on network */
#define	EBADFD		77	/* File descriptor in bad state */
#define	EREMCHG		78	/* Remote address changed */
#define	ELIBACC		79	/* Can not access a needed shared library */
#define	ELIBBAD		80	/* Accessing a corrupted shared library */
#define	ELIBSCN		81	/* .lib section in a.out corrupted */
#define	ELIBMAX		82	/* Attempting to link in too many shared libraries */
#define	ELIBEXEC	83	/* Cannot exec a shared library directly */
#define	EILSEQ		84	/* Illegal byte sequence */
#define	ERESTART	85	/* Interrupted system call should be restarted */
#define	ESTRPIPE	86	/* Streams pipe error */
#define	EUSERS		87	/* Too many users */
#define	ENOTSOCK	88	/* Socket operation on non-socket */
#define	EDESTADDRREQ	89	/* Destination address required */
#define	EMSGSIZE	90	/* Message too long */
#define	EPROTOTYPE	91	/* Protocol wrong type for socket */
#define	ENOPROTOOPT	92	/* Protocol not available */
#define	EPROTONOSUPPORT	93	/* Protocol not supported */
#define	ESOCKTNOSUPPORT	94	/* Socket type not supported */
#define	EOPNOTSUPP	95	/* Operation not supported on transport endpoint */
#define	EPFNOSUPPORT	96	/* Protocol family not supported */
#define	EAFNOSUPPORT	97	/* Address family not supported by protocol */
#define	EADDRINUSE	98	/* Address already in use */
#define	EADDRNOTAVAIL	99	/* Cannot assign requested address */
#define	ENETDOWN	100	/* Network is down */
#define	ENETUNREACH	101	/* Network is unreachable */
#define	ENETRESET	102	/* Network dropped connection because of reset */
#define	ECONNABORTED	103	/* Software caused connection abort */
#define	ECONNRESET	104	/* Connection reset by peer */
#define	ENOBUFS		105	/* No buffer space available */
#define	EISCONN		106	/* Transport endpoint is already connected */
#define	ENOTCONN	107	/* Transport endpoint is not connected */
#define	ESHUTDOWN	108	/* Cannot send after transport endpoint shutdown */
#define	ETOOMANYREFS	109	/* Too many references: cannot splice */
*/
@Constant
public int ETIMEDOUT = 110;	/* Connection timed out */
/*
#define	ECONNREFUSED	111	/* Connection refused */
#define	EHOSTDOWN	112	/* Host is down */
#define	EHOSTUNREACH	113	/* No route to host */
#define	EALREADY	114	/* Operation already in progress */
#define	EINPROGRESS	115	/* Operation now in progress */
#define	ESTALE		116	/* Stale file handle */
#define	EUCLEAN		117	/* Structure needs cleaning */
#define	ENOTNAM		118	/* Not a XENIX named type file */
#define	ENAVAIL		119	/* No XENIX semaphores available */
#define	EISNAM		120	/* Is a named type file */
#define	EREMOTEIO	121	/* Remote I/O error */
#define	EDQUOT		122	/* Quota exceeded */

#define	ENOMEDIUM	123	/* No medium found */
#define	EMEDIUMTYPE	124	/* Wrong medium type */
#define	ECANCELED	125	/* Operation Canceled */
#define	ENOKEY		126	/* Required key not available */
#define	EKEYEXPIRED	127	/* Key has expired */
#define	EKEYREVOKED	128	/* Key has been revoked */
#define	EKEYREJECTED	129	/* Key was rejected by service */

/* for robust mutexes */
#define	EOWNERDEAD	130	/* Owner died */
#define	ENOTRECOVERABLE	131	/* State not recoverable */

#define ERFKILL		132	/* Operation not possible due to RF-kill */

#define EHWPOISON	133	/* Memory page has hardware error */
*/


/* If WIFEXITED(STATUS), the low-order 8 bits of the status.  */
public int WEXITSTATUS(int status) {
	return (status & 0xff00) >> 8;
}

/* If WIFSIGNALED(STATUS), the terminating signal.  */
public int WTERMSIG(int status) {
	return status & 0x7f;
}

/* If WIFSTOPPED(STATUS), the signal that stopped the child.  */
public int WSTOPSIG(int status) {
	return WEXITSTATUS(status);
}

/* Nonzero if STATUS indicates normal termination.  */
public boolean WIFEXITED(int status) {
	return WTERMSIG(status) == 0;
}

/* Nonzero if STATUS indicates termination by a signal.  */
public boolean WIFSIGNALED(int status) {
  return (((status & 0x7f) + 1) << 24 >> 25) > 0;
}

/* Nonzero if STATUS indicates the child is stopped.  */
public boolean WIFSTOPPED(int status) {
	return (status & 0xff) == 0x7f;
}

/* Nonzero if STATUS indicates the child continued after a stop.  We only
   define this if <bits/waitflags.h> provides the WCONTINUED flag bit.  */
public boolean WIFCONTINUED(int status) {
	return status == __W_CONTINUED;
}

public boolean WCOREDUMP(int status) {
	return (status & __WCOREFLAG) != 0;
}

/* Nonzero if STATUS indicates the child dumped core.  */
//#define	__WCOREDUMP(status)	((status) & __WCOREFLAG)

/* Macros for constructing status values.  */
//#define	__W_EXITCODE(ret, sig)	((ret) << 8 | (sig))
//#define	__W_STOPCODE(sig)	((sig) << 8 | 0x7f)
@Constant
private int __W_CONTINUED = 0xffff;
@Constant
private int __WCOREFLAG = 0x80;

@Constant
public int PTHREAD_MUTEX_NORMAL = 0;
@Constant
public int PTHREAD_MUTEX_RECURSIVE = 1;
@Constant
public int PTHREAD_MUTEX_ERRORCHECK = 2;
@Constant
public int PTHREAD_MUTEX_DEFAULT = 0;

public class dirent {
    public long d_ino;
    public long d_off;
    public char d_reclen;
    public byte d_type;
	public byte d_name;
}

public class timespec {
	public long tv_sec;
	public long tv_nsec;
}

public class pthread_attr_t {
	public int align;
	private int _filler1;
	private long _filler2;
	private long _filler3;
	private long _filler4;
	private long _filler5;
	private long _filler6;
	private long _filler7;
}

public class pthread_mutex_t {
	private long _filler0;
	private long _filler1;
	private long _filler2;
	private long _filler3;
	private long _filler4;
}

public class pthread_mutexattr_t {
	private unsigned _filler0;
}

public class pthread_cond_t {
	private long _filler0;
	private long _filler1;
	private long _filler2;
	private long _filler3;
	private long _filler4;
	private long _filler5;
}

public class pthread_condattr_t {
	private unsigned _filler0;
}

public class sem_t {
	private long _filler0;
	private long _filler1;
	private long _filler2;
	private long _filler3;
}
/**
 * 1024 bits in a bit map.
 */
public class sigset_t {
	private long _word0; 
	private long _word1; 
	private long _word2; 
	private long _word3; 
	private long _word4; 
	private long _word5; 
	private long _word6; 
	private long _word7; 
	private long _word8; 
	private long _word9; 
	private long _word10; 
	private long _word11; 
	private long _word12; 
	private long _word13; 
	private long _word14; 
	private long _word15; 
}

public class struct_sigaction {
	private address _handler;
	public sigset_t sa_mask;
	public int sa_flags;
	public void() sa_restorer;
	
	public void(int) sa_handler() {
		return void(int)(_handler);
	}
	
	public void(int, ref<siginfo_t>, address) sa_sigaction() {
		return void(int, ref<siginfo_t>, address)(_handler); 
	}

	public void set_sa_handler(void handler(int x)) {
		_handler = address(handler);
	}
	
	public void set_sa_sigaction(void handler(int x, ref<siginfo_t> info, address arg)) {
		_handler = address(handler);
	}
}
/** 
 * This is defined in C as a union. The Parasol binding implements this as a class hierarchy.
 * 
 */
public class siginfo_t {
    public int si_signo;		/* Signal number.  */
    public int si_errno;		/* If non-zero, an errno value associated with
						   		   this signal, as defined in <errno.h>.  */
    public int si_code;			/* Signal code.  */
	public int si_trapno;		/* Trap number. */
}

public class siginfo_t_kill extends siginfo_t {
    public pid_t si_pid;		/* Sending process ID.  */
    public uid_t si_uid;		/* Real user ID of sending process.  */
}

public class siginfo_t_timer extends siginfo_t {
    public int si_tid;			/* Timer ID.  */
    public int si_overrun;		/* Overrun count.  */
    public sigval_t si_sigval;	/* Signal value.  */
}

public class siginfo_t_rt extends siginfo_t {
    public pid_t si_pid;		/* Sending process ID.  */
    public uid_t si_uid;		/* Real user ID of sending process.  */
    public sigval_t si_sigval;	/* Signal value.  */
}

public class siginfo_t_sigchld extends siginfo_t {
    public pid_t si_pid;		/* Which child.  */
    public uid_t si_uid;		/* Real user ID of sending process.  */
    public int si_status;		/* Exit value or signal.  */
    public clock_t si_utime;
    public clock_t si_stime;
}

public class siginfo_t_sigfault extends siginfo_t {
    public address si_addr;		/* Faulting insn/memory ref.  */
    public short si_addr_lsb;	/* Valid LSB of the reported address.  */
    public address si_addr_bnd_lower;
    public address si_addr_bnd_upper;
}

public class siginfo_t_sigpoll extends siginfo_t {
    public int si_band;			/* Band event for SIGPOLL.  */
    public int si_fd;
}

public class siginfo_t_sigsys extends siginfo_t {
    public address _call_addr;	/* Calling user insn.  */
    public int _syscall;		/* Triggering system call number.  */
    public unsigned _arch;		/* AUDIT_ARCH_* of syscall.  */
}

public class sigval_t = address;		// in C actually a union
public class clock_t = int;

/* Encoding of the file mode.  */

@Constant
public unsigned S_IXOTH =   0000001;
@Constant
public unsigned S_IWOTH =   0000002;
@Constant
public unsigned S_IROTH =   0000004;
@Constant
public unsigned S_IRWXO =   0000007;
@Constant
public unsigned S_IXGRP =   0000010;
@Constant
public unsigned S_IWGRP =   0000020;
@Constant
public unsigned S_IRGRP =   0000040;
@Constant
public unsigned S_IRWXG =   0000070;
@Constant
public unsigned S_IXUSR =   0000100;
@Constant
public unsigned S_IWUSR =   0000200;
@Constant
public unsigned S_IRUSR =   0000400;
@Constant
public unsigned S_IRWXU =   0000700;
@Constant
public unsigned S_ISVTX =   0001000;
@Constant
public unsigned S_ISGID =   0002000;
@Constant
public unsigned S_ISUID =   0004000;

@Constant
public unsigned S_IFMT	=   0170000;	/* These bits determine file type.  */

/* File types.  */
@Constant
public unsigned S_IFDIR	=	0040000;	/* Directory.  */
@Constant
public unsigned S_IFCHR	=	0020000;	/* Character device.  */
@Constant
public unsigned S_IFBLK	=	0060000;	/* Block device.  */
@Constant
public unsigned S_IFREG	=	0100000;	/* Regular file.  */
@Constant
public unsigned S_IFIFO	=	0010000;	/* FIFO.  */
@Constant
public unsigned S_IFLNK	=	0120000;	/* Symbolic link.  */
@Constant
public unsigned S_IFSOCK =	0140000;	/* Socket.  */

public boolean S_ISDIR(unsigned mode) {
	return (mode & S_IFMT) == S_IFDIR;
}

public boolean S_ISCHR(unsigned mode) {
	return (mode & S_IFMT) == S_IFCHR;
}

public boolean S_ISBLK(unsigned mode) {
	return (mode & S_IFMT) == S_IFBLK;
}

public boolean S_ISREG(unsigned mode) {
	return (mode & S_IFMT) == S_IFREG;
}

public boolean S_ISFIFO(unsigned mode) {
	return (mode & S_IFMT) == S_IFIFO;
}

public boolean S_ISLNK(unsigned mode) {
	return (mode & S_IFMT) == S_IFLNK;
}

public boolean S_ISSOCK(unsigned mode) {
	return (mode & S_IFMT) == S_IFSOCK;
}

public class passwd {
	pointer<byte> pw_name;
	pointer<byte> pw_passwd;
	uid_t pw_uid;
	gid_t pw_gid;
	pointer<byte> pw_gecos;
	pointer<byte> pw_dir;
	pointer<byte> pw_shell;
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
	_SC_POLL,
	_SC_SELECT,
	_SC_UID_MAXIOV,
	_SC_PII_INTERNET_STREAM,
	_SC_PII_INTERNET_DGRAM,
	_SC_PII_OSI_COTS,
	_SC_PII_OSI_CLTS,
	_SC_PII_OSI_M,
	_SC_T_IOV_MAX,
	_SC_THREADS,
	_SC_THREAD_SAFE_FUNCTIONS,
	_SC_GETGR_R_SIZE_MAX,
	_SC_GETPW_R_SIZE_MAX,
	// ... plus a lot more than I have the energy to enter today.
}

@Constant
public int F_DUPFD =       0;       /* dup */
@Constant
public int F_GETFD =       1;       /* get close_on_exec */
@Constant
public int F_SETFD =       2;       /* set/clear close_on_exec */
@Constant
public int F_GETFL =       3;       /* get file->f_flags */
@Constant
public int F_SETFL =       4;       /* set file->f_flags */
@Constant
public int F_GETLK =       5;
@Constant
public int F_SETLK =       6;
@Constant
public int F_SETLKW =      7;
@Constant
public int F_SETOWN =      8;       /* for sockets. */
@Constant
public int F_GETOWN =      9;       /* for sockets. */
@Constant
public int F_SETSIG =      10;      /* for sockets. */
@Constant
public int F_GETSIG =      11;      /* for sockets. */
@Constant
public int F_GETLK64 =     12;      /*  using 'struct flock64' */
@Constant
public int F_SETLK64 =     13;
@Constant
public int F_SETLKW64 =    14;
@Constant
public int F_SETOWN_EX =   15;
@Constant
public int F_GETOWN_EX =   16;
@Constant
public int F_GETOWNER_UIDS = 17;

@Constant
public int FD_CLOEXEC =     1;      /* actually anything with low bit set goes */

public class rlim_t = long;			// actually Unsigned<64>

@Constant
public rlim_t RLIM_INFINITY = -1;

public class rlimit {
	public rlim_t rlim_cur;
	public rlim_t rlim_max;
}

  /* Per-process CPU limit, in seconds.  */
@Constant
public int RLIMIT_CPU = 0;

  /* Largest file that can be created, in bytes.  */
@Constant
public int RLIMIT_FSIZE = 1;

  /* Maximum size of data segment, in bytes.  */
@Constant
public int RLIMIT_DATA = 2;

  /* Maximum size of stack segment, in bytes.  */
@Constant
public int RLIMIT_STACK = 3;

  /* Largest core file that can be created, in bytes.  */
@Constant
public int RLIMIT_CORE = 4;

  /* Largest resident set size, in bytes.
     This affects swapping; processes that are exceeding their
     resident set size will be more likely to have physical memory
     taken from them.  */
@Constant
public int RLIMIT_RSS = 5;

  /* Number of open files.  */
@Constant
public int RLIMIT_NOFILE = 7;
@Constant
public int RLIMIT_OFILE = RLIMIT_NOFILE; /* BSD name for same.  */

  /* Address space limit.  */
@Constant
public int RLIMIT_AS = 9;

  /* Number of processes.  */
@Constant
public int RLIMIT_NPROC = 6;

  /* Locked-in-memory address space.  */
@Constant
public int RLIMIT_MEMLOCK = 8;

  /* Maximum number of file locks.  */
@Constant
public int RLIMIT_LOCKS = 10;

  /* Maximum number of pending signals.  */
@Constant
public int RLIMIT_SIGPENDING = 11;

  /* Maximum bytes in POSIX message queues.  */
@Constant
public int RLIMIT_MSGQUEUE = 12;

  /* Maximum nice priority allowed to raise to.
     Nice levels 19 .. -20 correspond to 0 .. 39
     values of this resource limit.  */
@Constant
public int RLIMIT_NICE = 13;

  /* Maximum realtime priority allowed for non-priviledged
     processes.  */
@Constant
public int RLIMIT_RTPRIO = 14;
// TODO: THere be dragons below this point in the file. Need to fix srcServer issue #21.
  /* Maximum CPU time in µs that a process scheduled under a real-time
     scheduling policy may consume without making a blocking system
     call before being forcibly descheduled.  */
@Constant
public int RLIMIT_RTTIME = 15;
@Constant
public int RLIMIT_NLIMITS = 16;
@Constant
public int RLIM_NLIMITS = RLIMIT_NLIMITS;

