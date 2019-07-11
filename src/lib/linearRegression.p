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
/**
 * Provides facilities for calculating regressions.
 */
namespace parasol:math.regression;
/**
 * This template class can calculate ordinary least squares metrics
 * for arrays of type T.
 *
 * The value of T is either float or double, depending on your needs.
 */
public class LinearRegression<class T> {
	private T[] _y;
	private T[] _x;
	private T _beta;
	private T _alpha;
	private T[] _error;
	
	public LinearRegression() {
		
	}
	/**
	 * Set the depenndent variable vector
	 *
	 * @param y The array of dependent variables.
	 */
	public void dependent(T[] y) {
		_y = y;
	}
	/**
	 * Set the indepenndent variable vector
	 *
	 * @param y The array of independent variables.
	 */
	public void independent(T[] x) {
		_x = x;
	}
	/**
	 * Calculate the ordinary least squares.
	 *
	 * The results can be inspected by calling the {@link alpha},
	 * {@link beta} and {@link error} methods.
	 */
	public void ordinaryLeastSquares() {
		int n = _y.length();
		T xSum = +=_x;
		T ySum = +=_y;
		T xySum = +=(_x * _y);
		T x2Sum = +=(_x * _x);
		T num = xySum - (xSum * ySum) / n;
		T denom = x2Sum - (xSum * xSum) / n;
		_beta = num / denom;
		_alpha = (ySum - _beta * xSum) / n;
		_error = _y - (_alpha + _beta * _x);
	}
	/**
	 * Get the alpha value for the last computed least squares
	 *
	 * @return The last computed alpha value.
	 */
	public T alpha() {
		return _alpha;
	}
	/**
	 * Get the beta value for the last computed least squares
	 *
	 * @return The last computed beta value.
	 */
	public T beta() {
		return _beta;
	}
	/**
	 * Get the error values for the last computed least squares
	 *
	 * @return The last computed error values.
	 */
	public T[] error() {
		return _error;
	}
}