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
namespace native:C;
/*
 * FILE type.  Mimics the C FILE type.  Used here just as an opaque type to ensure
 * type-safe handling.
 */
public class FILE {}

public class size_t = long;

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

@Windows("msvcrt.dll", "malloc")
@Linux("libc.s0.6", "malloc")
public abstract address malloc(unsigned size);

@Windows("msvcrt.dll", "memcpy")
@Linux("libc.so.6", "memcpy")
public abstract address memcpy(address destination, address source, int amount);

@Windows("msvcrt.dll", "memset")
@Linux("libc.so.6", "memset")
public abstract address memset(address destination, byte value, int amount);

@Windows("msvcrt.dll", "rename")
@Linux("libc.so.6", "rename")
public abstract int rename(pointer<byte> oldName, pointer<byte> newName);

@Windows("msvcrt.dll", "sqrt")
@Linux("libm.so.6", "sqrt")
public abstract double sqrt(double x);

@Windows("msvcrt.dll", "sleep")
@Linux("libc.so.6", "sleep")
public abstract int sleep(unsigned seconds);

@Windows("msvcrt.dll", "strchr")
@Linux("libc.so.6", "strchr")
public abstract pointer<byte> strchr(pointer<byte> s, int c);

@Windows("msvcrt.dll", "strcpy")
@Linux("libc.so.6", "strcpy")
public abstract pointer<byte> strcpy(pointer<byte> dest, pointer<byte> src);

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
@Linux("libc.so.6", "vsprintf")
public abstract int vsprintf(pointer<byte> buffer, pointer<byte> format, va_list ap);
