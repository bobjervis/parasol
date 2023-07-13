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
import parasol:text;

interface I {
	void a();
}

boolean a_was_called;
boolean c_was_destroyed;

class C implements I {
	~C() {
		assert(!c_was_destroyed);
		if (this != &d)
			c_was_destroyed = true;
	}

	void a() {
		a_was_called = true;
	}
}

C c;

text.memDump(&c, c.bytes, long(&c));

I i = c;

i.a();

assert(a_was_called);

C d();

text.memDump(&d, d.bytes, long(&d));

I i2 = d;

a_was_called = false;
i2.a();

assert(a_was_called);

{
	C auto_c;
	I auto_i;

	text.memDump(&auto_c, auto_c.bytes, long(&auto_c));

	a_was_called = false;
	auto_i = auto_c;
	auto_i.a();

	assert(a_was_called);
	assert(!c_was_destroyed);
}

assert(c_was_destroyed);
c_was_destroyed = false;
{
	C auto_c();
	I auto_i;

	text.memDump(&auto_c, auto_c.bytes, long(&auto_c));

	a_was_called = false;
	auto_i = auto_c;
	auto_i.a();

	assert(a_was_called);
	assert(!c_was_destroyed);
}

assert(c_was_destroyed);
c_was_destroyed = false;

printf("SUCCESS\n");

