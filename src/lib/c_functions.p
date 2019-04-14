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
 * Provides access to portably defined C functions.
 *
 * Currently, many standard C function are provided here. Parasol has no syntax to describe a C variadic
 * function like <b>printf</b> or <b>scanf</b>, so there is no way to add these to this namespace, nor are most of the
 * variants that take a va_list object, which is highly specific to the C compiler used. Properly navigating the
 * compiler internals is quite complicated and not recommended for the faint of heart.
 *
 * As much as possible, the C funcions are exposed using some conventions for describing data types that are not
 * directly equivalent. Simple types like int or double are the same in both Parasol and C. The Parasol long type is
 * equivalent to a Java long, and to a C long long type. Since Parasol currently has no support for unsigned long long, 
 * the rare C methods that use this type (no portable functions in this namespace happen to), will use the Parasol
 * long type, even though it is signed and there is some risk of confusion for values with the high-order bit set.
 */
namespace native:C;

import parasol:runtime;
/*
 * FILE type.  Mimics the C FILE type.  Used here just as an opaque type to ensure
 * type-safe handling.
 */
public class FILE {}

public class size_t = long;
public class time_t = long;

public class va_list = address;
/**
 * This is the GNU CC __builtin_va_list structure used internally by GNU CC runtime to implemant va_list.
 * 
 * Do not venture into this without understanding...
 */
public class __x86_64_va_list {
	unsigned gp_offset;
	unsigned fp_offset;
	ref<address> overflow_arg_area;
	ref<address> reg_save_area;
}

@Constant
public int SEEK_SET = 0;
@Constant
public int SEEK_CUR = 1;
@Constant
public int SEEK_END = 2;

@Windows("msvcrt.dll", "atexit")
private abstract int __atexit(void() exitHandler);

@Linux("libc.so.6", "__cxa_atexit")
private abstract int __cxa_atexit(void() exitHandler, address arg, address dso_handle);
/**
 * Register an atexit handler with the C runtime.
 *
 * The Linux C runtime does a little dance to get atexit appropriately defined (atexit is statically bound). As
 * a result, we can't dynamically link directly to it. We have to use the 'binary standard' atexit handler which
 * is __cxa_atexit.
 *
 * In order to mask this wrinkle, Parasol defines an 'atexit' entry point in Parasol, but maps it appropriately
 * depending on the operating system.
 */
public int atexit(void() exitHandler) {
	if (runtime.compileTarget == runtime.Target.X86_64_LNX)
		return __cxa_atexit(exitHandler, null, null);
	else
		return __atexit(exitHandler);
}

@Windows("msvcrt.dll", "atof")
@Linux("libc.so.6", "atof")
public abstract double atof(pointer<byte> text);

@Windows("msvcrt.dll", "atoi")
@Linux("libc.so.6", "atoi")
public abstract int atoi(pointer<byte> text);

@Windows("msvcrt.dll", "calloc")
@Linux("libc.so.6", "calloc")
public abstract address calloc(long count, long size);

@Windows("msvcrt.dll", "_ecvt")
@Linux("libc.so.6", "ecvt")
public abstract pointer<byte> ecvt(double number, int ndigits, ref<int> decpt, ref<int> sign);

@Windows("msvcrt.dll", "exit")
@Linux("libc.so.6", "exit")
public abstract void exit(int exitCode);

@Windows("msvcrt.dll", "fclose")
@Linux("libc.so.6", "fclose")
public abstract int fclose(ref<FILE> fp);

@Windows("msvcrt.dll", "_fcvt")
@Linux("libc.so.6", "fcvt")
public abstract pointer<byte> fcvt(double number, int ndigits, ref<int> decpt, ref<int> sign);

@Windows("msvcrt.dll", "fdopen")
@Linux("libc.so.6", "fdopen")
public abstract ref<FILE> fdopen(int fd, pointer<byte> mode);

@Windows("msvcrt.dll", "ferror")
@Linux("libc.so.6", "ferror")
public abstract int ferror(ref<FILE> fp);

@Windows("msvcrt.dll", "fflush")
@Linux("libc.so.6", "fflush")
public abstract int fflush(ref<FILE> fp);

@Windows("msvcrt.dll", "fgetc")
@Linux("libc.so.6", "fgetc")
public abstract int fgetc(ref<FILE> fp);

@Windows("msvcrt.dll", "_fileno")
@Linux("libc.so.6", "fileno")
public abstract int fileno(ref<FILE> fp);

@Windows("msvcrt.dll", "fopen")
@Linux("libc.so.6", "fopen")
public abstract ref<FILE> fopen(pointer<byte> filename, pointer<byte> mode);

@Windows("msvcrt.dll", "fputc")
@Linux("libc.so.6", "fputc")
public abstract int fputc(int character, ref<FILE> fp);

@Windows("msvcrt.dll", "fread")
@Linux("libc.so.6", "fread")
public abstract unsigned fread(address cp, unsigned size, unsigned count, ref<FILE> fp);

@Windows("msvcrt.dll", "free")
@Linux("libc.so.6", "free")
public abstract void free(address data);

@Windows("msvcrt.dll", "fseek")
@Linux("libc.so.6", "fseek")
public abstract int fseek(ref<FILE> fp, long offset, int origin);

@Windows("msvcrt.dll", "ftell")
@Linux("libc.so.6", "ftell")
public abstract int ftell(ref<FILE> fp);

@Windows("msvcrt.dll", "fwrite")
@Linux("libc.so.6", "fwrite")
public abstract unsigned fwrite(address cp, unsigned size, unsigned count, ref<FILE> fp);

@Windows("msvcrt.dll", "_gcvt")
@Linux("libc.so.6", "gcvt")
public abstract pointer<byte> gcvt(double number, int ndigit, pointer<byte> buf);

@Windows("msvcrt.dll", "getenv")
@Linux("libc.so.6", "getenv")
public abstract pointer<byte> getenv(pointer<byte> variable);

@Linux("libc.so.6", "gmtime")
public abstract ref<tm> gmtime(ref<time_t> time);

@Windows("msvcrt.dll", "_gmtime64_s")
@Linux("libc.so.6", "gmtime_r")
public abstract ref<tm> gmtime_s(ref<time_t> time, ref<tm> result);

@Linux("libc.so.6", "localtime")
public abstract ref<tm> localtime(ref<time_t> time);

@Windows("msvcrt.dll", "_localtime64_s")
@Linux("libc.so.6", "localtime_r")
public abstract ref<tm> localtime_s(ref<time_t> time, ref<tm> result);

@Windows("msvcrt.dll", "malloc")
@Linux("libc.s0.6", "malloc")
public abstract address malloc(unsigned size);

@Windows("msvcrt.dll", "memcpy")
@Linux("libc.so.6", "memcpy")
public abstract address memcpy(address destination, address source, int amount);

@Windows("msvcrt.dll", "memset")
@Linux("libc.so.6", "memset")
public abstract address memset(address destination, byte value, int amount);

@Linux("libc.so.6", "mktime")
public abstract time_t mktime(ref<tm> time);

@Windows("msvcrt.dll", "rename")
@Linux("libc.so.6", "rename")
public abstract int rename(pointer<byte> oldName, pointer<byte> newName);

@Windows("msvcrt.dll", "sleep")
@Linux("libc.so.6", "sleep")
public abstract int sleep(unsigned seconds);

@Windows("msvcrt.dll", "strchr")
@Linux("libc.so.6", "strchr")
public abstract pointer<byte> strchr(pointer<byte> s, int c);

@Windows("msvcrt.dll", "strcpy")
@Linux("libc.so.6", "strcpy")
public abstract pointer<byte> strcpy(pointer<byte> dest, pointer<byte> src);

@Windows("msvcrt.dll", "strftime")
@Linux("libc.so.6", "strftime")
public abstract size_t strftime(pointer<byte> s, size_t max, pointer<byte> format,
                       ref<tm> tmData);

@Windows("msvcrt.dll", "strncmp")
@Linux("libc.so.6", "strncmp")
public abstract int strncmp(pointer<byte> s1, pointer<byte> s2, size_t n);

@Windows("msvcrt.dll", "strstr")
@Linux("libc.so.6", "strstr")
public abstract pointer<byte> strstr(pointer<byte> s1, pointer<byte> s2);

@Windows("msvcrt.dll", "strtod")
@Linux("libc.so.6", "strtod")
public abstract double strtod(pointer<byte> str, ref<pointer<byte>> endPtr);

@Windows("msvcrt.dll", "strtof")
@Linux("libc.so.6", "strtof")
public abstract float strtof(pointer<byte> str, ref<pointer<byte>> endPtr);

@Windows("msvcrt.dll", "strlen")
@Linux("libc.so.6", "strlen")
public abstract int strlen(pointer<byte> cp);

@Windows("msvcrt.dll", "time")
@Linux("libc.so.6", "time")
public abstract long time(ref<long> t);

//@Windows("msvcrt.dll", "vsprintf") - not yet implemented on Windows, Linux is pretty hacky, so beware
@Linux("libc.so.6", "vsnprintf")
public abstract int vsnprintf(pointer<byte> buffer, size_t size, pointer<byte> format, va_list ap);

//@Windows("msvcrt.dll", "vsprintf") - not yet implemented on Windows, Linux is pretty hacky, so beware
@Linux("libc.so.6", "vsprintf")
public abstract int vsprintf(pointer<byte> buffer, pointer<byte> format, va_list ap);

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
public int LC_ALL                = 6;

public class tm {
  int tm_sec;                   /* Seconds.     [0-60] (1 leap second) */
  int tm_min;                   /* Minutes.     [0-59] */
  int tm_hour;                  /* Hours.       [0-23] */
  int tm_mday;                  /* Day.         [1-31] */
  int tm_mon;                   /* Month.       [0-11] */
  int tm_year;                  /* Year - 1900.  */
  int tm_wday;                  /* Day of week. [0-6] */
  int tm_yday;                  /* Days in year.[0-365] */
  int tm_isdst;                 /* DST.         [-1/0/1]*/

  long tm_gmtoff;           	/* Seconds east of UTC.  */
  pointer<byte> tm_zone;		/* Timezone abbreviation.  */
}
