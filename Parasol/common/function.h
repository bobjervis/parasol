#pragma once
#include "vector.h"

class Function {
public:
	explicit Function(double leftSlope = 0, double rightSlope = 0) {
		_leftSlope = leftSlope;
		_rightSlope = rightSlope;
	}

	void value(double x, double y);

	int dataPoints() const { return _table.size(); }

	double operator () (double x);

private:
	class Pair {
	public:
		double x;
		double y;

		int compare(const Pair& p) const {
			if (x < p.x)
				return -1;
			else if (x > p.x)
				return 1;
			else
				return 0;
		}
	};

	vector<Pair>	_table;
	double			_leftSlope;
	double			_rightSlope;
};
