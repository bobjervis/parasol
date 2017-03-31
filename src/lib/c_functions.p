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
namespace native:C;
/*
 * FILE type.  Mimics the C FILE type.  Used here just as an opaque type to ensure
 * type-safe handling.
 */
public class FILE {}

public int SEEK_SET = 0;
public int SEEK_CUR = 1;
public int SEEK_END = 2;

@Windows("msvcrt.dll", "calloc")
@Linux("libc.so", "calloc")
public abstract address calloc(unsigned count, unsigned size);

@Windows("msvcrt.dll", "_close")
@Linux("libc.so", "close")
public abstract int close(int fd);

@Windows("msvcrt.dll", "_ecvt")
@Linux("libc.so", "ecvt")
public abstract pointer<byte> ecvt(double number, int ndigits, ref<int> decpt, ref<int> sign);

@Windows("msvcrt.dll", "exit")
@Linux("libc.so", "exit")
public abstract void exit(int exitCode);

@Windows("msvcrt.dll", "fclose")
@Linux("libc.so", "fclose")
public abstract int fclose(ref<FILE> fp);

@Windows("msvcrt.dll", "_fcvt")
@Linux("libc.so", "fcvt")
public abstract pointer<byte> fcvt(double number, int ndigits, ref<int> decpt, ref<int> sign);

@Windows("msvcrt.dll", "ferror")
@Linux("libc.so", "ferror")
public abstract int ferror(ref<FILE> fp);

@Windows("msvcrt.dll", "fgetc")
@Linux("libc.so", "fgetc")
public abstract int fgetc(ref<FILE> fp);

@Windows("msvcrt.dll", "fopen")
@Linux("libc.so", "fopen")
public abstract ref<FILE> fopen(pointer<byte> filename, pointer<byte> mode);

@Windows("msvcrt.dll", "fread")
@Linux("libc.so", "fread")
public abstract unsigned fread(address cp, unsigned size, unsigned count, ref<FILE> fp);

@Windows("msvcrt.dll", "free")
@Linux("libc.so", "free")
public abstract void free(address data);

@Windows("msvcrt.dll", "fseek")
@Linux("libc.so", "fseek")
public abstract int fseek(ref<FILE> fp, int offset, int origin);

@Windows("msvcrt.dll", "ftell")
@Linux("libc.so", "ftell")
public abstract int ftell(ref<FILE> fp);

@Windows("msvcrt.dll", "fwrite")
@Linux("libc.so", "fwrite")
public abstract unsigned fwrite(address cp, unsigned size, unsigned count, ref<FILE> fp);

@Windows("msvcrt.dll", "_gcvt")
@Linux("libc.so", "gcvt")
public abstract pointer<byte> gcvt(double number, int ndigit, pointer<byte> buf);

@Windows("msvcrt.dll", "getenv")
@Linux("libc.so", "getenv")
public abstract pointer<byte> getenv(pointer<byte> variable);

@Windows("msvcrt.dll", "memcpy")
@Linux("libc.so", "memcpy")
public abstract address memcpy(address destination, address source, int amount);

@Windows("msvcrt.dll", "memset")
@Linux("libc.so", "memset")
public abstract address memset(address destination, byte value, int amount);

@Windows("msvcrt.dll", "strtod")
@Linux("libc.so", "strtod")
public abstract double strtod(pointer<byte> str, ref<pointer<byte>> endPtr);

@Windows("msvcrt.dll", "strlen")
@Linux("libc.so", "strlen")
public abstract int strlen(pointer<byte> cp);

@Windows("msvcrt.dll", "time")
@Linux("libc.so", "time")
public abstract int time(ref<int> t);


