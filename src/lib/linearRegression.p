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
namespace parasol:math.regression;

public class LinearRegression<class T> {
	private T[] _y;
	private T[] _x;
	private T _beta;
	private T _alpha;
	private T[] _error;
	
	public LinearRegression() {
		
	}
	
	public void dependent(T[] y) {
		_y = y;
	}
	
	public void independent(T[] x) {
		_x = x;
	}
	
	public void ordinaryLeastSquares() {
		int n = _y.length();
		T xSum = +=_x;
		T ySum = +=_y;
		T xySum = +=(_x * _y);
		T xSumYSum = xSum * ySum;
		T x2Sum = +=(_x * _x);
		T xBar = xSum / n;
		T yBar = ySum / n;
		T xyBar = xSumYSum / n;
		T x2Bar = x2Sum / n;
		T num = xyBar - xBar * yBar;
		T denom = x2Bar - xBar * xBar;
		_beta = num / denom;
		_alpha = yBar - _beta * xBar;
		_error = _y - _alpha - _beta * _x;
	}
	
	public T alpha() {
		return _alpha;
	}
	
	public T beta() {
		return _beta;
	}
	
	public T[] error() {
		return _error;
	}
}