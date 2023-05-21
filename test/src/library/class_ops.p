/*
   Copyright 2015 Robert Jervis

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
class A extends B {
	A(int x) {
		super(x + 3);
	}
}

class B {
	B(int x) {
		assert(x == 5);
		didIt = true;
	}
}

boolean didIt = false;
A b(2);
A c(int x);
assert(didIt);

didIt = false;
ref<B> ap = new B(5);
assert(didIt);
delete ap;

ref<B> bp;

ref<A> axp = &b;

bp = axp;

assert(bp == &b);

assert(ranNoArgsConstructor);

boolean ranNoArgsConstructor = false;

class NoArgsConstructor {
	NoArgsConstructor() {
		ranNoArgsConstructor = true;
	}
}

NoArgsConstructor m;

assert(!ranNoArgsConstructor);


class Loc {
	int offset;
	
	Loc() {
	}
	
	Loc(int o) {
		offset = o;
	}
}

class Outer {
	private byte hidden;
	Loc x;
	
	Outer(Loc xx) {
		x = xx;
	}
}

int z() {
	Loc m(-2);
	Outer n(m);
	
	assert(n.x.offset == -2);
	return 6;
}

z();

enum Q {
	A, B, C
	}
	
class ContainsStatic {
	private static string[Q] x;
	
	ContainsStatic() {
		x.resize(Q.C);
	}
	
	public int f() {
		return int(x.length());
	}
}

ContainsStatic containsStatic;

assert(containsStatic.f() == 2);

boolean abstractCallHit;

class Abstracted {
	public abstract void f(int x, int y, byte... z);
}

class Concrete extends Abstracted {
	private int _local;
	
	public Concrete() {
		_local = 4;
	}
	
	public void f(int x, int y, byte... z) {
		if (_local == 4)
			abstractCallHit = true;
	}
	
}

Concrete concrete;		

func(&concrete);

assert(abstractCallHit);

void func(ref<Abstracted> a) {
	a.f(1, 2, 'a');
}

boolean baseConstructed;

class BaseC {
	BaseC(boolean v) {
		baseConstructed = v;
	}
}

class DerivedC extends BaseC {
	DerivedC() {
		super(true);
	}
}

DerivedC derivedObject;

assert(baseConstructed);

ref<Abstracted> indirect = new Concrete();

abstractCallHit = false;

indirect.f(1, 2, 'b');

assert(abstractCallHit);

class Simple {
	public int value;
}

Simple y;

y.value = 34;

Simple f() {
	return y;
}

void func(Simple x) {
	x = f();
	assert(x.value == 34);
}

func(y);

class Biggish {
	int a, b, c;
	
	void method1() {
		this.method2();
	}
	
	private void method2() {
	}
};

Biggish bigg;

bigg.b = 45;
bigg.a = 16;

Biggish bfunc() {
	return bigg;
}

void nf() {
	Biggish x;
	x = bfunc();
	printf("bfunc() = { a: %d b: %d c: %d }\n", x.a, x.b, x.c);
	
	assert(bfunc().b == 45);
	if (bfunc().a != 16) {
		bigg.c = 12;
		return;
	} else
		bigg.c = 14;
	
}

printf("bigg = { a: %d b: %d c: %d }\n", bigg.a, bigg.b, bigg.c);
nf();

Biggish thing1;
thing1.a = 23;
thing1.b = 94;
thing1.c = 117;

Biggish thing2 = thing1;
Biggish thing3;

thing3 = thing2;
printf("thing3 = { a: %d b: %d c: %d }\n", thing3.a, thing3.b, thing3.c);
assert(thing3.a == 23);
assert(thing3.b == 94);
assert(thing3.c == 117);

class Inline {
	pointer<byte>	_cp;
	int _len;
	
	Inline(pointer<byte> cp, int len) {
		_cp = cp;
		_len = len;
	}
}

string s = "abc";

void finline(Inline x) {
	assert(x._len == 4);
	x._len++;
	assert(x._len == 5);
	assert(x._cp == &s[0]);
}

finline(Inline(&s[0], 4));

class Foo {
	ref<Inline> _z;
	
	void bar() {
		_z._len = 2;
		_z._len++;
		assert(_z._len == 3);
	}
}

Foo foo;
foo._z = new Inline(&s[0], 4);

foo.bar();

class XX {
	int y;
}

ref<XX> xx = new XX();

assert(xx != null);
assert(xx.y == 0);


