import parasol:stream.UTF8Reader;
import parasol:stream.UTF8Writer;
import parasol:text.StringReader;
import parasol:text.StringWriter;

string s = "\xea\xa9\xba";

StringReader r(&s);
UTF8Reader ru(&r);

int c = ru.read();

printf("c = %x\n", c);

assert(c == 0xaa7a);

assert(ru.read() == -1);

string o;

StringWriter w(&o);
UTF8Writer wu(&w);

assert(wu.write(0xaa7a) == 3);

assert(o.length() == 3);
assert(o[0] == 0xea);
assert(o[1] == 0xa9);
assert(o[2] == 0xba);

