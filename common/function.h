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
