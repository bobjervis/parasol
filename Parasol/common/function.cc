#include "../common/platform.h"
#include "function.h"

void Function::value(double x, double y) {
	Pair p = { x, y };

	for (int i = 0; i < _table.size(); i++) {
		if (x < _table[i].x) {
			_table.insert(i, p);
			return;
		}
	}
	_table.push_back(p);
}

double Function::operator ()(double x) {
	Pair p = { x };
	int i = binarySearchClosestGreater(_table, p);
	if (i == -1) {
		double y = 0;
		return y / y;
	}
	if (i == _table.size()) {
		const Pair& p = _table[_table.size() - 1];

		return p.y + (x - p.x) * _rightSlope;
	} else if (i == 0) {
		const Pair& p = _table[0];

		return p.y + (x - p.x) * _leftSlope;
	} else {
		const Pair& left = _table[i - 1];
		const Pair& right = _table[i];

		return left.y + (x - left.x) * (right.y - left.y) / (right.x - left.x);
	}
}
