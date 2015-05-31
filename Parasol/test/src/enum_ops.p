enum a { 
	A, 
	B, 
	C 
}; 

a x = a.B;

a y;

y = a.C;

assert(y == a.C);

assert(byte(x) == 1);

switch (y) {
case	A:
	assert(false);
default:
	break;
}

switch(y) {
case A:
case B:
	assert(false);
default:
	break;
}

switch(y) {
case C:
	break;
default:
	assert(false);
}

y = null;

a func(a x) {
	x = a.B;
	return x;
}

assert(func(a.C) == a.B);
