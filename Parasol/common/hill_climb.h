#pragma once
#include <stdio.h>
#include "vector.h"

namespace random {

class Random;

}  // namespace random

namespace explore {

#define defineVariable(x, min, max, incr) defineVariable_(#x, x, min, max, incr)

class Variable;

class HillClimb {
public:
	HillClimb();

	HillClimb(random::Random* r);

	~HillClimb();

	void randomize();
	/*
	 *	solve
	 *
	 *	This method solves the hill-climb from the current state until either the
	 *	maxSteps number of iterations have completed, or a local maximum has been
	 *	reached.  The number of actual steps used is returned.  Note that a maxSteps
	 *	value of zero means to run until a maximum is reached, regardless of how many
	 *	steps are needed.
	 */
	int solve(int maxSteps = 0);
	/*
	 *	cancel
	 *
	 *	Called recursively from within computeScore() to break out of the solve()
	 *	method.
	 */
	void cancel() {
		_cancelled = true;
	}

	void writeVariables(FILE* out);

	virtual double computeScore() = 0;

	void defineVariable_(const char* label, int& variable, int min, int max, int incr);

	void defineVariable_(const char* label, float& variable, float min, float max, float incr);

private:
	vector<Variable*>		_variables;
	random::Random*			_random;
	bool					_cancelled;
	bool					_privateRandom;
};

class Variable {
public:
	Variable(const char* label) {
		_label = label;
	}

	virtual double min() const = 0;

	virtual double max() const = 0;

	virtual double incr() const = 0;

	virtual double value() const = 0;

	virtual void set(double value) = 0;

	void pickInitial(random::Random* r);

	const char* label() const { return _label; }

private:
	const char*			_label;
};

class IntVariable : public Variable {
public:
	IntVariable(const char* label, int& variable, int min, int max, int incr) 
		: Variable(label),
		  _variable(variable) {
		_min = min;
		_max = max;
		_incr = incr;
	}

	virtual double min() const;

	virtual double max() const;

	virtual double incr() const;

	virtual double value() const;

	virtual void set(double value);

private:
	int&			_variable;
	int				_min;
	int				_max;
	int				_incr;
};

class FloatVariable : public Variable {
public:
	FloatVariable(const char* label, float& variable, float min, float max, float incr) 
		: Variable(label),
		  _variable(variable) {
		_min = min;
		_max = max;
		_incr = incr;
	}

	virtual double min() const;

	virtual double max() const;

	virtual double incr() const;

	virtual double value() const;

	virtual void set(double value);

private:
	float&			_variable;
	float			_min;
	float			_max;
	float			_incr;
};

}  // namespace explore



