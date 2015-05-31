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
