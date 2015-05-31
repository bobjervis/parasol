string s = "abcdef";

assert(s.beginsWith("ab"));
assert(s.endsWith("def"));
assert(!s.beginsWith("abd"));
assert(!s.endsWith("gef"));
