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
public abstract address calloc(unsigned count, unsigned size);

@Windows("msvcrt.dll", "_ecvt")
public abstract pointer<byte> ecvt(double number, int ndigits, ref<int> decpt, ref<int> sign);

@Windows("msvcrt.dll", "exit")
public abstract void exit(int exitCode);

@Windows("msvcrt.dll", "fclose")
public abstract int fclose(ref<FILE> fp);

@Windows("msvcrt.dll", "_fcvt")
public abstract pointer<byte> fcvt(double number, int ndigits, ref<int> decpt, ref<int> sign);

@Windows("msvcrt.dll", "ferror")
public abstract int ferror(ref<FILE> fp);

@Windows("msvcrt.dll", "fgetc")
public abstract int fgetc(ref<FILE> fp);

@Windows("msvcrt.dll", "fopen")
public abstract ref<FILE> fopen(pointer<byte> filename, pointer<byte> mode);

@Windows("msvcrt.dll", "fread")
public abstract unsigned fread(address cp, unsigned size, unsigned count, ref<FILE> fp);

@Windows("msvcrt.dll", "free")
public abstract void free(address data);

@Windows("msvcrt.dll", "fseek")
public abstract int fseek(ref<FILE> fp, int offset, int origin);

@Windows("msvcrt.dll", "ftell")
public abstract int ftell(ref<FILE> fp);

@Windows("msvcrt.dll", "fwrite")
public abstract unsigned fwrite(address cp, unsigned size, unsigned count, ref<FILE> fp);

@Windows("msvcrt.dll", "_gcvt")
public abstract pointer<byte> gcvt(double number, int ndigit, pointer<byte> buf);

@Windows("msvcrt.dll", "getenv")
public abstract pointer<byte> getenv(pointer<byte> variable);

@Windows("msvcrt.dll", "memcpy")
public abstract address memcpy(address destination, address source, int amount);

@Windows("msvcrt.dll", "memset")
public abstract address memset(address destination, byte value, int amount);

@Windows("msvcrt.dll", "strtod")
public abstract double strtod(pointer<byte> str, ref<pointer<byte>> endPtr);

@Windows("msvcrt.dll", "strlen")
public abstract int strlen(pointer<byte> cp);

@Windows("msvcrt.dll", "time")
public abstract int time(ref<int> t);


