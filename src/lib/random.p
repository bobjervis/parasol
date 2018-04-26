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
namespace parasol:random;

import native:C;
import parasol:runtime;

public class Random {
	private class RandomState {
		public unsigned	z;
		public unsigned	w;
	}

	private RandomState		_state;
	/*
	 *	This constructor allows an arbitrary quantity of random data.
	 *	Typically, this might be used to clone the internal state
	 *	of the random number generator or restore the state from
	 *	external storage (by using the output of Random::save).
	 *
	 *	If the supplied data is more than is needed by the algorithm,
	 *	the excess is ignored.  If less, then the additional data is
	 *	generated using what is supplied.  
	 */
	public Random(string seed) {
		set(seed);
	}
	/*
	 *	This constructor supplies an integer value as the
	 *	seed data for the generator.  As above, if this is not enough
	 *	data to completely fill in the internal state of the generator,
	 *	the data is generated.
	 */
	public Random(int seed) {
		set(seed);
	}
	/*
	 *	This constructor initializes the state of the generator using
	 *	a cryptographically secure method native to the host operating
	 *	system (CryptGenRandom in Windows).  This constructor may require
	 *	operating system or even external device interactions, and so should
	 *	not be used for high-speed initialization of random number generators.
	 */
	public Random() {
		set();
	}

	public string save() {
		return string(pointer<byte>(&_state), _state.bytes);
	}

	public void set(string seed) {
		int i = seed.length();
		if (i < _state.bytes) {
			unsigned jcong = 0;

			if (i > jcong.bytes)
				i = jcong.bytes;
			C.memcpy(&jcong, seed.c_str(), i);
			
			jcong = nextCongruential(jcong);
			_state.z = jcong;
			jcong = nextCongruential(jcong);
			_state.w = jcong;
		} else
			C.memcpy(&_state, seed.c_str(), _state.bytes);
	}

	private unsigned nextCongruential(unsigned jcong) {
		return 69069 * jcong + 1234567;
	}

	void set(long seed) {
		string s(pointer<byte>(&seed), seed.bytes);
		set(s);
	}

	void set() {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			/*
				HCRYPTPROV handle;
		
				if (CryptAcquireContext(&handle, null, null, PROV_RSA_FULL, CRYPT_VERIFYCONTEXT|CRYPT_SILENT)) {
					CryptGenRandom(handle, _state.bytes, pointer<byte>(&_state));
					CryptReleaseContext(handle, 0);
				} else {
				}
			*/
			set(C.time(null));
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			ref<C.FILE> f = C.fopen("/dev/urandom".c_str(), "rb".c_str());
			if (f == null)
				set(C.time(null));
			else {
				long x;
				C.fread(&x, 1, unsigned(x.bytes), f);
				C.fclose(f);
				set(x);
			}
		} else
			set(C.time(null));
	}

	byte[] getBytes(int length) {
		byte[] b;

		b.resize(length);
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			/*
				HCRYPTPROV handle;
		
				if (CryptAcquireContext(&handle, null, null, PROV_RSA_FULL, CRYPT_VERIFYCONTEXT|CRYPT_SILENT)) {
					CryptGenRandom(handle, _state.bytes, pointer<byte>(&_state));
					CryptReleaseContext(handle, 0);
				} else {
				}
			*/
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			ref<C.FILE> f = C.fopen("/dev/urandom".c_str(), "rb".c_str());
			if (f != null) {
				C.fread(&b[0], 1, unsigned(length), f);
				C.fclose(f);
				return b;
			}
		}
		for (int i = 0; i < length; i++)
			b[i] = byte(uniform(256));
		return b;
	}
	/*
	 *	Returns a uniformly distributed 32-bit unsigned integer.
	 */
	unsigned next() {
		_state.z = 36969 * (_state.z & 0xffff) + (_state.z >> 16);
		_state.w = 18000 * (_state.w & 0xffff) + (_state.w >> 16);
		return (_state.z << 16) + (_state.w & 0xffff);
	}
	/*
	 *	Returns a uniformly distributed number in the range from
	 *  0 to 1.  Neither zero nor one can be returned.
	 */
	double uniform() {
		return next() / double(0x100000000);
	}
	/*
	 * Returns a uniformly distributed integer in the range from 0 - range-1, inclusive.
	 */
	int uniform(int range) {
		return int(range * uniform());
	}
	/*
	 * normal
	 *
	 * This function returns a number with a normal
	 * distribution with a mean of 0 and standard
	 * deviation of 1.
	 */
	/*
	double normal()  {
		double x1, x2, r;

		do {
			x1 = 2 * uniform() - 1;
			x2 = 2 * uniform() - 1;
			r = x1 * x1 + x2 * x2;
		} while (r >= 1);
		double fac = sqrt(-2 * log(r) / r);
		return x2 * fac;
	}
	*/
	/*
	 * binomial
	 *
	 * This function returns a number between 0 and n according
	 * to a binomial distribution with n trials and probability of
	 * p at each trial
	 */
	/*
	int binomial(int n, double p) {
		double mean = n * p;
		double sdev = mean * (1 - p);
		int x = int(normal() * sdev + mean);
		if (x < 0)
			x = 0;
		else if (x > n)
			x = n;
		return x;
	}
	*/
	/*
	 * This function returns the sum on n random die rolls where
	 * sides is the number of sides on each die.  The assumption is
	 * that all sides are equally likely to appear and are numbered
	 * from 1 through sides in value.
	 */
	int dieRoll(int n, int sides) {
		int sum = 0;
		while (n > 0) {
			sum += int(sides * uniform()) + 1;
			n--;
		}
		return sum;
	}
}

