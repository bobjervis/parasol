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
import native:C.gcvt;

interface I {
	void a();
}

ref<B> b;

class C {
	long filler;
}

class B extends C implements I {
	long g;
	long h;
	long x;

	~B() {
		printf("this in ~B %p\n", this);
		assert(b == this);
		assert(x == 7);
		byte[] buffer;

		buffer.resize(80);
		gcvt(0.0, 6, &buffer[0]);
	}

	void a() {
		printf("this = %p\n", this);
		b = this;
		x = 7;
	}
}

ref<B> n = new B;

I ip = n;

n.a();

printf("n = %p ip = %p\n", n, ip);

delete ip;



