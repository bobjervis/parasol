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

public abstract ref<FILE> fopen(pointer<byte> filename, pointer<byte> mode);

public abstract int fclose(ref<FILE> fp);

public abstract int ftell(ref<FILE> fp);

public abstract int fseek(ref<FILE> fp, int offset, int origin);

public abstract int fgetc(ref<FILE> fp);

public abstract unsigned fread(address cp, unsigned size, unsigned count, ref<FILE> fp);

public abstract unsigned fwrite(address cp, unsigned size, unsigned count, ref<FILE> fp);

public abstract int ferror(ref<FILE> fp);

public abstract void exit(int exitCode);

public abstract pointer<byte> getenv(pointer<byte> variable);
