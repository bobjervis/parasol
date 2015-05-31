int value;
boolean success;

(value, success) = int.parse("0");
assert(success);
assert(value == 0);

(value, success) = int.parse("-17");
assert(success);
assert(value == -17);

(value, success) = int.parse("x");
assert(!success);
assert(value == 0);

