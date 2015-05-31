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
