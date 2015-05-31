namespace native:POSIX;

public abstract int open(pointer<byte> filename, int flags);

public abstract int openCreat(pointer<byte> filename, int flags, int mode);

public abstract int close(int fd);


