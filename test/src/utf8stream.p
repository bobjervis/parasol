import parasol:stream.Utf8Reader;
import parasol:stream.Utf8Writer;
import parasol:stream.StringReader;
import parasol:stream.StringWriter;

string s = "\xea\xa9\xba";

StringReader r(&s);
Utf8Reader ru(&r);

int c = ru.read();

printf("c = %x\n", c);

assert(c == 0xaa7a);

assert(ru.read() == -1);

string o;

StringWriter w(&o);
Utf8Writer wu(&w);

wu.write(0xaa7a);

assert(o.length() == 3);
assert(o[0] == 0xea);
assert(o[1] == 0xa9);
assert(o[2] == 0xba);

