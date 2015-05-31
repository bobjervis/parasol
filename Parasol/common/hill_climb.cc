#include "../common/platform.h"
#include "hill_climb.h"

#include <math.h>
#include <stdio.h>
#include "random.h"

namespace explore {

HillClimb::HillClimb() {
	_random = new random::Random();
	_privateRandom = true;
}

HillClimb::HillClimb(random::Random* r) {
	_random = r;
	_privateRandom = false;
}

HillClimb::~HillClimb() {
	if (_privateRandom)
		delete _random;
}

void HillClimb::randomize() {
	for (int i = 0; i < _variables.size(); i++) {
		_variables[i]->pickInitial(_random);
	}
}

int HillClimb::solve(int maxSteps) {
	int steps;

	steps = 0;
	_cancelled = false;
	double bestScore = computeScore();
	printf("    -- Baseline score %g\n", bestScore);
	for (;;) {
		if (maxSteps && maxSteps <= steps)
			break;
		if (_cancelled)
			break;
		int bestVariable = -1;
		double bestValue;
		for (int i = 0; i < _variables.size(); i++) {
			double v = _variables[i]->value();
			double incr = _variables[i]->incr();
			double x0 = v - incr;
			double x1 = v + incr;
			if (x0 >= _variables[i]->min()) {
				_variables[i]->set(x0);
				double n = computeScore();
				writeVariables(stdout);
				printf("    -- Score %g\n", n);
				if (_cancelled)
					break;
				if (n > bestScore) {
					bestVariable = i;
					bestValue = x0;
					bestScore = n;
				}
			}
			if (x1 <= _variables[i]->max()) {
				_variables[i]->set(x1);
				double n = computeScore();
				writeVariables(stdout);
				printf("    -- Score %g\n", n);
				if (_cancelled)
					break;
				if (n > bestScore) {
					bestVariable = i;
					bestValue = x1;
					bestScore = n;
				}
			}
			_variables[i]->set(v);
		}
		if (bestVariable < 0 || _cancelled)
			break;
		_variables[bestVariable]->set(bestValue);
		printf("    --> [%d] Best variable %s changed to %g\n", steps, _variables[bestVariable]->label(), _variables[bestVariable]->value());
		steps++;
	}
	return steps;
}

void HillClimb::writeVariables(FILE* out) {
	for (int i = 0; i < _variables.size(); i++)
		fprintf(out, "[%2d] %20s = %g\n", i, _variables[i]->label(), _variables[i]->value());
}

void HillClimb::defineVariable_(const char *label, int &variable, int min, int max, int incr) {
	Variable* v = new IntVariable(label, variable, min, max, incr);
	_variables.push_back(v);
}

void HillClimb::defineVariable_(const char *label, float &variable, float min, float max, float incr) {
	Variable* v = new FloatVariable(label, variable, min, max, incr);
	_variables.push_back(v);
}

void Variable::pickInitial(random::Random* r) {
	double minV, maxV, incrV;

	minV = min();
	maxV = max();
	incrV = incr();

	int dataPoints = (int)((maxV - minV) / incrV);

	int i = r->dieRoll(1, dataPoints);

	set(minV + i * incrV);
}

double IntVariable::min() const {
	return _min;
}

double IntVariable::max() const {
	return _max;
}

double IntVariable::incr() const {
	return _incr;
}

double IntVariable::value() const {
	return _variable;
}

void IntVariable::set(double value) {
	_variable = int(floor(value + 0.5));
}

double FloatVariable::min() const {
	return _min;
}

double FloatVariable::max() const {
	return _max;
}

double FloatVariable::incr() const {
	return _incr;
}

double FloatVariable::value() const {
	return _variable;
}

void FloatVariable::set(double value) {
	_variable = float(value);
}

}  // namespace explore
