/*
   Copyright 2015 Rovert Jervis

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
class Container {
	abstract int f();
	
}

class Bucket extends Container {
	int f() {
		return 1;
	}
}

class Envelope extends Container {
	Envelope() {
		envelopeConstructorCalled = true;
	}
	
	int f() {
		return 2;
	}
	
	int g() {
		return 3;
	}
}

class LegalEnvelope extends Envelope {
	int f() {
		return 44;
	}
}

boolean envelopeCalled;
boolean bucketCalled;

LegalEnvelope le;				// has an implicit constructor, to the base class of this guy (which has none).

assert(envelopeConstructorCalled);

ref<Envelope> ep = new Envelope();

boolean envelopeConstructorCalled;

int x = ep.f();

void ff(ref<Container> c) {
	int x = c.f();
	if (c.class == Envelope) {
		ref<Envelope> e = ref<Envelope>(c);
		envelopeCalled = true;
		assert(e.g() == 3);
	} else {
		bucketCalled = true;
		assert(c.f() == 1);
	}
}

Bucket b;
Envelope e;

assert(!bucketCalled);
assert(!envelopeCalled);
ff(&b);
assert(bucketCalled);
assert(!envelopeCalled);
bucketCalled = false;
ff(&e);
assert(!bucketCalled);
assert(envelopeCalled);

assert(e.class == Envelope);
