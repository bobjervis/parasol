int offset = 2000;

class E {
	int loc;
	int handler;
}

class H {
	int loc;
	int segmentOffset;
}

E[] _exceptionTable;
H[] _exceptionHandlers;

E e;

e.loc = 123;
e.handler = 456;

H h;

h.loc = 122;
h.segmentOffset = 319;

_exceptionTable.append(e);
_exceptionHandlers.append(h);

int i = 0;

_exceptionTable[i].handler = offset + _exceptionHandlers[i].segmentOffset;

printf("handler = %d\n", _exceptionTable[i].handler);
assert(_exceptionTable[i].handler == 2319);
