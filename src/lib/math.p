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
namespace parasol:math;

import native:C;

public int abs(int x) {
	if (x < 0)
		return -x;
	else
		return x;
}

public long abs(long x) {
	if (x < 0)
		return -x;
	else
		return x;
}

public float abs(float x) {
	if (x < 0)
		return -x;
	else
		return x;
}

public double abs(double x) {
	if (x < 0)
		return -x;
	else
		return x;
}

public int min(int x, int y) {
	if (x < y)
		return x;
	else
		return y;
}

public long min(long x, long y) {
	if (x < y)
		return x;
	else
		return y;
}

public int max(int x, int y) {
	if (x < y)
		return y;
	else
		return x;
}

public long max(long x, long y) {
	if (x < y)
		return y;
	else
		return x;
}

public float sqrt(float x) {
	return float(sqrt(double(x)));
}

@Windows("msvcrt.dll", "log")
@Linux("libm.so.6", "log")
public abstract double log(double x);

@Windows("msvcrt.dll", "sqrt")
@Linux("libm.so.6", "sqrt")
public abstract double sqrt(double x);
