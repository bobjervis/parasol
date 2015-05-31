#include "../common/platform.h"
#include "function.h"

#include "atom.h"
#include "parser.h"
#include "hill_climb.h"
#include "random.h"

class FunctionObject : script::Object {
public:
	static script::Object* factory() {
		return new FunctionObject();
	}

	FunctionObject() {}

	virtual bool isRunnable() const { return true; }

	virtual bool run() {
		double leftSlope = 0, rightSlope = 0;
		Atom* a = get("leftSlope");
		if (a)
			leftSlope = a->toString().toDouble();
		a = get("rightSlope");
		if (a)
			rightSlope = a->toString().toDouble();

		_function = new Function(leftSlope, rightSlope);
		return runAnyContent();
	}

	Function* function() const { return _function; }
private:
	Function*		_function;
};

class FunctionValueObject : script::Object {
public:
	static script::Object* factory() {
		return new FunctionValueObject();
	}

	FunctionValueObject() {}

	virtual bool isRunnable() const { return true; }

	virtual bool run() {
		FunctionObject* fo;

		if (containedBy(&fo)) {
			double x, y;

			Atom* a = get("x");
			if (a)
				x = a->toString().toDouble();
			else {
				printf("Missing x\n");
				return false;
			}
			a = get("y");
			if (a)
				y = a->toString().toDouble();
			else {
				printf("Missing y\n");
				return false;
			}

			fo->function()->value(x, y);
		} else {
			printf("Not contained by a function object.\n");
			return false;
		}
		return true;
	}

};

class FunctionCheckObject : script::Object {
public:
	static script::Object* factory() {
		return new FunctionCheckObject();
	}

	FunctionCheckObject() {}

	virtual bool isRunnable() const { return true; }

	virtual bool run() {
		FunctionObject* fo;

		if (containedBy(&fo)) {
			double x, expect;

			Atom* a = get("x");
			if (a)
				x = a->toString().toDouble();
			else {
				printf("Missing x\n");
				return false;
			}
			a = get("expect");
			if (a)
				expect = a->toString().toDouble();
			else {
				printf("Missing expect\n");
				return false;
			}
			static double interval = 1.0e-6;
			double actual = (*fo->function())(x);
			if (actual < expect - interval || actual > expect + interval) {
				printf("Actual value in range of expected value.\n");
				printf("Expected: %g\n", expect);
				printf("Actual: %g\n", actual);
				return false;
			}
		} else {
			printf("Not contained by a function object.\n");
			return false;
		}
		return true;
	}

};

class RandomObject : script::Object {
public:
	static script::Object* factory() {
		return new RandomObject();
	}

	RandomObject() {}

	virtual bool isRunnable() const { return true; }

	virtual bool run() {
		Atom* a = get("seed");
		if (a) {
			string s = a->toString();
			unsigned u = s.toInt();

			if (u)
				_random = new random::Random(u);
			else
				_random = new random::Random(s);
		} else
			_random = new random::Random();
		string state = _random->save();
		printf("State vector is %d bytes long\n", state.size());
		int iterations = 1;
		a = get("iterations");
		if (a)
			iterations = a->toString().toInt();
		a = get("method");
		if (a) {
			string s = a->toString();

			for (int i = 0; i < iterations; i++) {
				string state = _random->save();
				double n, n2;
				if (!iteration(s, &n))
					return false;
				_random->set(state);
				if (!iteration(s, &n2))
					return false;
				if (n != n2) {
					printf("Resetting state did not produce identical results: had %g got %g\n", n, n2);
					return false;
				}
			}
		}

		return true;
	}

	bool iteration(const string& method, double* out) {
		double x;
		if (method == "uniform") {
			x = _random->uniform();
			if (x <= 0 || x >= 1) {
				printf("uniform(): Result out of range for uniform method: %g\n", x);
				return false;
			}
		} else if (method == "next") {
			x = _random->next();
			if (x == 0) {
				printf("next(): Result is zero\n");
				return false;
			}
		} else if (method == "normal") {
			x = _random->normal();
		} else if (method == "binomial") {
			int n = 0;
			double p = 0;
			Atom* a = get("n");
			if (a)
				n = a->toString().toInt();
			a = get("p");
			if (a)
				p = a->toString().toDouble();
			x = _random->binomial(n, p);
			if (x < 0 || x > n) {
				printf("binomial(): Result out of range (%d): %g\n", n, x);
				return false;
			}
		} else if (method == "dieRoll") {
			int n = 0;
			int sides = 0;
			Atom* a = get("n");
			if (a)
				n = a->toString().toInt();
			a = get("sides");
			if (a)
				sides = a->toString().toInt();
			x = _random->dieRoll(n, sides);
			if (x < n || x > n * sides) {
				printf("dieRoll(): Result out of range (with %d dice, each having %d sides): %g\n", n, sides, x);
				return false;
			}
		} else {
			printf("Unknown method: %s\n", method.c_str());
			return false;
		}
		*out = x;
		return true;
	}

private:
	random::Random*	_random;
};

class VectorObject : script::Object {
public:
	static script::Object* factory() {
		return new VectorObject();
	}

	VectorObject() {}

	virtual bool isRunnable() const { return true; }

	virtual bool run() {
		bool ascending = true;
		Atom* a = get("direction");
		if (a) {
			if (a->toString() == "ascending")
				ascending = true;
			else if (a->toString() == "descending")
				ascending = false;
		}
		if (!runAnyContent())
			return false;
		_values.sort(ascending);
		if (_values.size() != _unsorted.size()) {
			printf("Sort changed the size of the vector:\n    was %d\n    is %d\n", _unsorted.size(), _values.size());
			return false;
		}
		vector<bool> present;
		for (int i = 0; i < _values.size(); i++)
			present.push_back(false);
		printf("Sorted %s:\n", a ? a->toString().c_str() : "by default ascending");
		for (int i = 0; i < _values.size(); i++) {
			if (_values[i] == null)
				printf("    <null>\n");
			else
				printf("    [%4d] was [%4d] %d\n", i, _values[i]->_index, _values[i]->_value);
		}
		for (int i = 0; i < _values.size(); i++) {
			if (_values[i] == null) {
				printf("Null entry %d\n", i);
				return false;
			} else {
				if (_values[i]->_index < 0 ||
					_values[i]->_index >= _unsorted.size()) {
					printf("Original index out of range in entry %d\n", i);
					return false;
				}
				if (present[_values[i]->_index]) {
					printf("Original index duplicated in entry %d\n", i);
					return false;
				}
				present[_values[i]->_index] = true;
				if (_values[i] != _unsorted[_values[i]->_index]) {
					printf("Not the correct value object in entry %d\n", i);
					return false;
				}
			}
		}
		for (int i = 0; i < present.size(); i++) {
			if (!present[i]) {
				printf("Original item at index %d missing in results\n", i);
				return false;
			}
		}
		// We now know that all of the original entries are present in the results.
		// now check the ordering constraint.
		for (int i = 1; i < _values.size(); i++) {
			int relation = _values[i - 1]->compare(_values[i]);
			if (ascending) {
				if (relation > 0) {
					printf("Out of sequence entry at %d\n", i);
					return false;
				}
			} else {
				if (relation < 0) {
					printf("Out of sequence entry at %d\n", i);
					return false;
				}
			}
		}
		return true;
	}

	void value(int x) {
		IntValue* iv = new IntValue(x, _values.size());
		_values.push_back(iv);
		_unsorted.push_back(iv);
	}

private:
	class IntValue {
	public:
		IntValue(int x, int index) {
			_value = x;
			_index = index;
		}

		int compare(IntValue* iv) {
			if (_value < iv->_value)
				return -1;
			else if (_value > iv->_value)
				return 1;
			else
				return 0;
		}

		int			_value;
		int			_index;
	};

	vector<IntValue*>		_values;
	vector<IntValue*>		_unsorted;
};

class VectorValueObject : script::Object {
public:
	static script::Object* factory() {
		return new VectorValueObject();
	}

	VectorValueObject() {}

	virtual bool isRunnable() const { return true; }

	virtual bool run() {
		Atom* a = get("x");
		if (a == null)
			a = get("content");
		if (a == null) {
			printf("No x property\n");
			return false;
		}
		int x = a->toString().toInt();
		VectorObject* vo;
		if (containedBy(&vo)) {
			vo->value(x);
		}
		return runAnyContent();
	}
};

class HillClimbObject : script::Object {
public:
	static script::Object* factory() {
		return new HillClimbObject();
	}

	HillClimbObject() {}

	virtual bool isRunnable() const { return true; }

	virtual bool run() {
		int x = 10;
		float y = 10;
		explore::HillClimb* hc = new TestHillClimb(&x, &y);

		hc->defineVariable(x, -10, 10, 1);
		hc->defineVariable(y, -10, 10, 0.1f);
		hc->randomize();

		printf("Initial x = %d y = %g\n", x, y);
		int steps = hc->solve();
		printf("Final x = %d y = %g after %d steps\n", x, y, steps);
		return runAnyContent();
	}

	class TestHillClimb : public explore::HillClimb {
	public:
		TestHillClimb(const int* x, const float* y) {
			_x = x;
			_y = y;
		}

		virtual double computeScore() {
			printf("computeScore() x = %d y = %g\n", *_x, *_y);
			return 1 - (*_x * *_x + *_y * *_y);
		}

	private:
		const int*		_x;
		const float*	_y;
	};
};

void initCommonTestObjects() {
	script::objectFactory("function", FunctionObject::factory);
	script::objectFactory("functionValue", FunctionValueObject::factory);
	script::objectFactory("functionCheck", FunctionCheckObject::factory);
	script::objectFactory("random", RandomObject::factory);
	script::objectFactory("vector", VectorObject::factory);
	script::objectFactory("vectorValue", VectorValueObject::factory);
	script::objectFactory("hillClimb", HillClimbObject::factory);
}
