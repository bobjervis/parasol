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
