#pragma once
#include "string.h"

namespace random {

class Random {
public:
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
	Random(const string& seed) {
		set(seed);
	}
	/*
	 *	This constructor supplies an unsigned integer value as the
	 *	seed data for the generator.  As above, if this is not enough
	 *	data to completely fill in the internal state of the generator,
	 *	the data is generated.
	 */
	Random(unsigned seed) {
		set(seed);
	}
	/*
	 *	This constructor initializes the state of the generator using
	 *	a cryptographically secure method native to the host operating
	 *	system (CryptGenRandom in Windows).  This constructor may require
	 *	operating system or even external device interactions, and so should
	 *	not be used for high-speed initialization of random number generators.
	 */
	Random() {
		set();
	}

	string save() const;

	void set(const string& seed);

	void set(unsigned seed);

	void set();
	/*
	 *	Returns a uniformly distributed 32-bit unsigned integer.
	 */
	unsigned next();
	/*
	 *	Returns a uniformly distributed integer in the range from
	 *  0 to 1.  Neither zero nor one can be returned.
	 */
	double uniform();
	/*
	 * normal
	 *
	 * This function returns a number with a normal
	 * distribution with a mean of 0 and standard
	 * deviation of 1.
	 */
	double normal();
	/*
	 * binomial
	 *
	 * This function returns a number between 0 and n according
	 * to a binomial distribution with n trials and probability of
	 * p at each trial
	 */
	int binomial(int n, double p);
	/*
	 * This function returns the sum on n random die rolls where
	 * sides is the number of sides on each die.  The assumption is
	 * that all sides are equally likely to appear and are numbered
	 * from 1 through sides in value.
	 */
	int dieRoll(int n, int sides);

private:
	class RandomState {
	public:
		unsigned	z;
		unsigned	w;
	};

	RandomState		_state;
};

}  // namespace random
