#include "../common/platform.h"
#include "random.h"

#include <math.h>
#include <stdlib.h>
#include <windows.h>
#include <wincrypt.h>

namespace random {
/*
 *	Implementation Note:
 *
 *		Based on http://www.bobwheeler.com/statistics/Password/MarsagliaPost.txt
 *
 *	Referred to in Wikipedia article on random number generators.  The current
 *	implementation uses the MWC algorithm documented there.
 *
 *	When less than 2 unsigned integers worth of data are supplied as seeds,
 *	CONG is used with what is supplied to generate the initial bytes of the
 *	RandomState object.
 */
string Random::save() const {
	string n;

	memcpy(n.buffer_(sizeof _state), &_state, sizeof _state);
	return n;
}

void Random::set(const string& seed) {
	int i = seed.size();
	if (i < sizeof _state) {
		unsigned jcong = 0;

		#define CONG  (jcong=69069*jcong+1234567)

		if (i > sizeof jcong)
			i = sizeof jcong;
		memcpy(&jcong, seed.c_str(), i);

		_state.z = CONG;
		_state.w = CONG;

		#undef CONG

	} else
		memcpy(&_state, seed.c_str(), sizeof _state);
}

void Random::set(unsigned seed) {
	string s;

	memcpy(s.buffer_(sizeof seed), &seed, sizeof seed);
	set(s);
}

void Random::set() {
	HCRYPTPROV handle;

	if (CryptAcquireContext(&handle, NULL, NULL, PROV_RSA_FULL, CRYPT_VERIFYCONTEXT|CRYPT_SILENT)) {
		CryptGenRandom(handle, sizeof _state, (BYTE*)&_state);
		CryptReleaseContext(handle, 0);
	} else {
	}
}

unsigned Random::next() {
	_state.z = 36969 * (_state.z & 0xffff) + (_state.z >> 16);
	_state.w = 18000 * (_state.w & 0xffff) + (_state.w >> 16);
	return (_state.z << 16) + (_state.w & 0xffff);
}

double Random::uniform() {
	return next() * (1 / 4294967296.0);
}

double Random::normal() {
	double x1, x2, r;

	do {
		x1 = 2 * uniform() - 1;
		x2 = 2 * uniform() - 1;
		r = x1 * x1 + x2 * x2;
	} while (r >= 1);
	double fac = sqrt(-2 * log(r) / r);
	return x2 * fac;
}

int Random::binomial(int n, double p) {
	double mean = n * p;
	double sdev = mean * (1 - p);
	int x = int(normal() * sdev + mean);
	if (x < 0)
		x = 0;
	else if (x > n)
		x = n;
	return x;
}

int Random::dieRoll(int n, int sides) {
	int sum = 0;
	while (n > 0) {
		sum += int(sides * uniform()) + 1;
		n--;
	}
	return sum;
}

}  // namespace random
