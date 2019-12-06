import parasol:text.UTF8Decoder;
import parasol:text.UTF8Encoder;
import parasol:text.StringReader;
import parasol:text.StringWriter;

string s = "\xea\xa9\xba";

StringReader r(&s);
UTF8Decoder ru(&r);

int c = ru.decodeNext();

printf("c = %x\n", c);

assert(c == 0xaa7a);

assert(ru.decodeNext() == -1);

string o;

StringWriter w(&o);
UTF8Encoder wu(&w);

assert(wu.encode(0xaa7a) == 3);

assert(o.length() == 3);
assert(o[0] == 0xea);
assert(o[1] == 0xa9);
assert(o[2] == 0xba);

