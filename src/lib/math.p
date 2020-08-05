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
 * Provides facilities for calculating mathematical functions.
 */
namespace parasol:math;

import native:C;
/**
 * Calculate the absolute value of x.
 *
 * @return The value |x|.
 */
public int abs(int x) {
	if (x < 0)
		return -x;
	else
		return x;
}
/**
 * Calculate the absolute value of x.
 *
 * @return The value |x|.
 */
public long abs(long x) {
	if (x < 0)
		return -x;
	else
		return x;
}
/**
 * Calculate the absolute value of x.
 *
 * @return The value |x|.
 */
@Linux("libm.so.6", "fabsf")
public abstract float abs(float x);
/**
 * Calculate the absolute value of x.
 *
 * @return The value |x|.
 */
@Linux("libm.so.6", "fabs")
public abstract double abs(double x);

/**
 * Calculate the smaller of x and y.
 *
 * @return The value x if x < y, otherwise y.
 */
public int min(int x, int y) {
	if (x < y)
		return x;
	else
		return y;
}
/**
 * Calculate the smaller of x and y.
 *
 * @return The value x if x < y, otherwise y.
 */
public long min(long x, long y) {
	if (x < y)
		return x;
	else
		return y;
}
/**
 * Calculate the greater of x and y.
 *
 * @return The value x if x > y, otherwise y.
 */
public int max(int x, int y) {
	if (x < y)
		return y;
	else
		return x;
}
/**
 * Calculate the greater of x and y.
 *
 * @return The value x if x > y, otherwise y.
 */
public long max(long x, long y) {
	if (x < y)
		return y;
	else
		return x;
}
/**
 * Calculate the arc cosine of x.
 *
 * @return If x is in the range [-1, 1], the arc cosine of x in radians; otherwise NaN.
 */
@Linux("libm.so.6", "acosf")
public abstract float acos(float x);
/**
 * Calculate the arc sine of x.
 *
 * @return If x is in the range [-1, 1], the arc sine of x in radians; otherwise NaN.
 */
@Linux("libm.so.6", "asinf")
public abstract float asin(float x);
/**
 * Calculate the arc tangent of x.
 *
 * @return The arc tangent of x in radians.
 */
@Linux("libm.so.6", "atanf")
public abstract float atan(float x);
/**
 * Calculate the arc tangent of (x/y).
 *
 * @return The arc tangent of (x/y) in radians.
 */
@Linux("libm.so.6", "atan2f")
public abstract float atan2(float y, float x);
/**
 * Calculate the cosine of x.
 *
 * @return The cosine of x in radians.
 */
@Linux("libm.so.6", "cosf")
public abstract float cos(float x);

@Linux("libm.so.6", "sincosf")
abstract void sincos(float x, ref<float> sinx, ref<float> cosx);
/**
 * Calculate the sine and cosine of x.
 *
 * @return The sine of x in radians.
 * @return The cosine of x in radians.
 */
public float, float sincos(float x) {
	float sinx;
	float cosx;

	sincos(x, &sinx, &cosx);
	return sinx, cosx;
}
/**
 * Calculate the sine of x.
 *
 * @return The sine of x in radians.
 */
@Linux("libm.so.6", "sinf")
public abstract float sin(float x);
/**
 * Calculate the tangent of x.
 *
 * Note that since a floating point value can never be an exact fraction of pi,
 * the value of this function is never undefined.
 *
 * @return The tangent of x in radians.
 */
@Linux("libm.so.6", "tanf")
public abstract float tan(float x);
/**
 * Calculate the hyperbolic cosine of x.
 *
 * @return The hyperbolic cosine of x in radians.
 */
@Linux("libm.so.6", "coshf")
public abstract float cosh(float x);
/**
 * Calculate the hyperbolic sine of x.
 *
 * @return The hyperbolic sine of x in radians.
 */
@Linux("libm.so.6", "sinhf")
public abstract float sinh(float x);
/**
 * Calculate the hyperbolic tangent of x.
 *
 * @return The hyperbolic tangent of x in radians.
 */
@Linux("libm.so.6", "tanhf")
public abstract float tanh(float x);
/**
 * Calculate the hyperbolic arc cosine of x.
 *
 * @return The hyperbolic arc cosine of x in radians.
 */
@Linux("libm.so.6", "acoshf")
public abstract float acosh(float x);
/**
 * Calculate the hyperbolic arc sine of x.
 *
 * @return The hyperbolic arc sine of x in radians.
 */
@Linux("libm.so.6", "asinhf")
public abstract float asinh(float x);
/**
 * Calculate the hyperbolic arc tangent of x.
 *
 * @return The hyperbolic arc tangent of x in radians.
 */
@Linux("libm.so.6", "atanhf")
public abstract float atanh(float x);

@Linux("libm.so.6", "frexpf")
abstract float frexp(float x, ref<int> exp);
/**
 * Calculate the fraction and exponent of x.
 *
 * @return If x is 0, the function returns 0. otherwise the fraction, m, such
 * that m is in [0.5 - 1.0) and x = m * 2<sup>exp</sup>, for some integer exp.
 * @return if x is 0, the function returns 0, otherwise the exponent, exp,
 * necessary to satisfy the equation above.
 */
public float, int frexp(float x) {
	int exp;
	x = frexp(x, &exp);
	return x, exp;
}
/**
 * Calculate a value from a fraction x and exponent exp.
 *
 * @return The value x * 2<sup>exp</sup>.
 */
@Linux("libm.so.6", "ldexpf")
public abstract float ldexp(float x, int exp);
/**
 * Calculate the exponential raised to the x power.
 *
 * @return The value e<sup>x</sup>.
 */
@Linux("libm.so.6", "expf")
public abstract float exp(float x);
/**
 * Calculate 2 raised to the x power.
 *
 * @return The value 2<sup>x</sup>.
 */
@Linux("libm.so.6", "exp2f")
public abstract float exp2(float x);
/**
 * Calculate the natural logarithm of x.
 *
 * @return The natural logarithm ln(x).
 */
@Linux("libm.so.6", "logf")
public abstract float log(float x);
/**
 * Calculate the base 10 logarithm of x.
 *
 * @return The value log<sub>10</sub>(x).
 */
@Linux("libm.so.6", "log10f")
public abstract float log10(float x);
/**
 * Calculate the natural logarithm of (1 + x).
 *
 * @return The value ln(1 + x).
 */
@Linux("libm.so.6", "log1pf")
public abstract float log1p(float x);
/**
 * Calculate the machine base logarithm of x.
 *
 * @return The value log<sub>float.RADIX</sub>(x).
 */
@Linux("libm.so.6", "logbf")
public abstract float logb(float x);
/**
 * Calculate the base 2 logarithm of x.
 *
 * @return The value log<sub>2</sub>(x).
 */
@Linux("libm.so.6", "log2f")
public abstract float log2(float x);

@Linux("libm.so.6", "modff")
abstract float mod(float x, ref<float> p);
/**
 * Split the integral and fractional parts of x.
 *
 * Both return values have the same sign as x.
 *
 * @return The fractional part of x
 * @return The integral part of x
 */
public float, float mod(float x) {
	float y;
	x = mod(x, &y);
	return x, y;
}
/**
 * Calculate 10 raised to the x power.
 *
 * @return The value 10<sup>x</sup>.
 */
@Linux("libm.so.6", "exp10f")
public abstract float exp10(float x);
/**
 * Calculate the exponential raised to the x power minus 1.
 *
 * @return The value e<sup>x</sup>-1.
 */
@Linux("libm.so.6", "expm1f")
public abstract float expm1(float x);
/**
 * Calculate x raised to the y power.
 *
 * @return The value x<sup>y</sup>.
 */
@Linux("libm.so.6", "powf")
public abstract float pow(float x, float y);
/**
 * Calculate the hypoteneuse.
 *
 * @return The value sqrt(x<sup>2</sup>+y<sup>2</sup>).
 */
@Linux("libm.so.6", "hypotf")
public abstract float hypot(float x, float y);
/**
 * Calculate the square root of x.
 *
 * @return The square root of x if x is non-negative, NaN otherwise.
 */
@Linux("libm.so.6", "sqrtf")
public abstract float sqrt(float x);
/**
 * Calculate the cube root of x.
 *
 * @return The cube root of x.
 */
@Linux("libm.so.6", "cbrtf")
public abstract float cbrt(float x);
/**
 * Calculate the ceiling of x.
 *
 * @return The smallest integer equal to or greater than x.
 */
@Linux("libm.so.6", "ceilf")
public abstract float ceil(float x);
/**
 * Calculate the absolute value (magnitude) of x.
 *
 * @return The value |x|.
 */
@Linux("libm.so.6", "fabsf")
public abstract float abs(float x);
/**
 * Calculate the floor of x.
 *
 * @return The largest integer equal to or less than x.
 */
@Linux("libm.so.6", "floorf")
public abstract float floor(float x);
/**
 * Calculate the floating pointer remainder of x / y.
 *
 * @return The value x - n * y, where n = x/y truncated. The value has the same sign as
 * x and is less than or equal to y.
 */
@Linux("libm.so.6", "fmodf")
public abstract float fmod(float x, float y);
/**
 * Calculate the significand of x.
 *
 * @return The mantissa of x scaled to the range [1 - 2).
 */
@Linux("libm.so.6", "significandf")
public abstract float significand(float x);
/**
 * Copy the sign of y to the value of x.
 *
 * @return The magnitude x with the sign of y.
 */
@Linux("libm.so.6", "copysignf")
public abstract float copysign(float x, float y);
/**
 * Calculate a Bessel function of x.
 *
 * @return The Bessel function of the first kind, order 0 of x.
 */
@Linux("libm.so.6", "j0f")
public abstract float j0(float x);
/**
 * Calculate a Bessel function of x.
 *
 * @return The Bessel function of the first kind, order 1 of x.
 */
@Linux("libm.so.6", "j1f")
public abstract float j1(float x);
/**
 * Calculate a Bessel function of x.
 *
 * @return The Bessel function of the first kind, order n of x.
 */
@Linux("libm.so.6", "jnf")
public abstract float jn(float x, int n);
/**
 * Calculate a Bessel function of x.
 *
 * @return The Bessel function of the second kind, order 0 of x.
 */
@Linux("libm.so.6", "y0f")
public abstract float y0(float x);
/**
 * Calculate a Bessel function of x.
 *
 * @return The Bessel function of the second kind, order 1 of x.
 */
@Linux("libm.so.6", "y1f")
public abstract float y1(float x);
/**
 * Calculate a Bessel function of x.
 *
 * @return The the Bessel function of the second kind, order n of x.
 */
@Linux("libm.so.6", "ynf")
public abstract float yn(float x, int n);
/**
 * Calculate the <a href='https://en.wikipedia.org/wiki/Error_function'>Error Function</a> of x.
 *
 * @return The error function of x.
 */
@Linux("libm.so.6", "erff")
public abstract float erf(float x);
/**
 * Calculate the <a href='https://en.wikipedia.org/wiki/Error_function#Complementary_error_function'>Complementary error Function</a> of x.
 *
 * @return The complementary error function of x.
 */
@Linux("libm.so.6", "erfcf")
public abstract float erfc(float x);

@Linux("libm.so.6", "lgammaf_r")
abstract float lgamma_r(float x, ref<int> signgamp);
/**
 * Calculate the natural logarithm of the absolute value of the
 * <a href='https://en.wikipedia.org/wiki/Gamma_function'>Gamma Function</a> of x.
 *
 * @return The value ln(|gamma(x)|).
 */
public float, int lgamma(float x) {
	int signgam;

	x = lgamma_r(x, &signgam);
	return x, signgam;
}
/**
 * Calculate the <a href='https://en.wikipedia.org/wiki/Gamma_function'>Gamma Function</a> of x.
 *
 * @return The value gamma(x).
 */
@Linux("libm.so.6", "tgammaf")
public abstract float gamma(float x);
/**
 * Round to integer as a float.
 *
 * This differs from {@link nearbyint} in the handling of
 * inexact exceptions. This function will raise such an exception.

 * @return The nearest integer value to x.
 */
@Linux("libm.so.6", "rintf")
public abstract float rint(float x);
/**
 * Round to integer asn an int.
 *
 * @return The nearest integer value to x.
 */
@Linux("libm.so.6", "lrintf")
public abstract int irint(float x);
/**
 * Round to integer as a long.
 *
 * @return The nearest integer value to x.
 */
@Linux("libm.so.6", "llrintf")
public abstract long lrint(float x);
/**
 * Calculate the next floating point value after x in the direction of y.
 *
 * @return The next floating point value after x in the direction of y.
 */
@Linux("libm.so.6", "nextafterf")
public abstract float nextafter(float x, float y);
/**
 * Calculate the floating pointer remainder of x / y.
 *
 * @return The value x - n * y, where n = the nearest integer value to x/y. The value has the same sign as
 * x and is less than or equal to y. If n - |x/y| = 1/2 n is chosen to be even.
 */
@Linux("libm.so.6", "remainderf")
public abstract float remainder(float x);
/**
 * Scale x by the exponent n.
 *
 * @return The x * float.RADIX<sup>n</sup>.
 */
@Linux("libm.so.6", "scalbnf")
public abstract float scalbn(float x, int n);
/**
 * Scale x by the exponent y.
 *
 * @return The x * float.RADIX<sup>y</sup>.
 */
@Linux("libm.so.6", "scalbf")
public abstract float scalb(float x, float y);
/**
 * Calculate the integral exponent of x.
 *
 * @return The value log<sub>float.RADIX</sub>(|x|) truncated to int.
 */
@Linux("libm.so.6", "ilogbf")
public abstract int ilogb(float x);
/**
 * Round to integer as a float.
 *
 * This differs from {@link rint} in the handling of
 * inexact exceptions. This function will not raise such an exception.
 *
 * @return The nearest integer value to x.
 */
@Linux("libm.so.6", "nearbyintf")
public abstract float nearbyint(float x);
/**
 * Round to integer as a float.
 *
 * This rounds half-way values away from zero, regardless of the current 
 * rounding mode, which differs from {@link rint} which rounds to even
 * values.
 *
 * @return The nearest integer value to x.
 */
@Linux("libm.so.6", "roundf")
public abstract float round(float x);
/**
 * Round to integer as an int.
 *
 * This rounds half-way values away from zero, regardless of the current 
 * rounding mode, which differs from {@link irint} which rounds to even
 * values.
 *
 * @return The nearest integer value to x.
 */
@Linux("libm.so.6", "lroundf")
public abstract int iround(float x);
/**
 * Round to integer as a long.
 *
 * This rounds half-way values away from zero, regardless of the current 
 * rounding mode, which differs from {@link lrint} which rounds to even
 * values.
 *
 * @return The nearest integer value to x.
 */
@Linux("libm.so.6", "llroundf")
public abstract long lround(float x);
/**
 * Truncate to integer as a float.
 *
 * @return The nearest integer value to x not greater in absolute value.
 */
@Linux("libm.so.6", "truncf")
public abstract float trunc(float x);

@Linux("libm.so.6", "remquof")
abstract float remquo(float x, float y, ref<int> quo);
/**
 * Calculate the floating pointer remainder and quotient of x / y.
 *
 * @return The value x - n * y, where n = the nearest integer value to x/y. The value has the same sign as
 * x and is less than or equal to y. If n - |x/y| = 1/2 n is chosen to be even.
 * @return The low order bits of the nearest integer value to x/y. At least the low order 3 bits are returned
 */
public float, int remquo(float x, float y) {
	int quo;
	x = remquo(x, y, &quo);
	return x, quo;
}
/**
 * Calculate the positive difference between x and y.
 *
 * @return The value max(x - y, 0).
 */
@Linux("libm.so.6", "fdimf")
public abstract float fdim(float x, float y);
/**
 * Calculate the smaller of x and y.
 *
 * @return The value x if x <= y, or y if y < x, or Nan if neither is true.
 */
@Linux("libm.so.6", "fminf")
public abstract float min(float x, float y);
/**
 * Calculate the larger of x and y.
 *
 * @return The value x if x >= y, or y if y > x, or Nan if neither is true.
 */
@Linux("libm.so.6", "fmaxf")
public abstract float max(float x, float y);
/**
 * Calculate the x * y + z.
 *
 * @return The value x * y + z.
 */
@Linux("libm.so.6", "fmaf")
public abstract float fma(float x, float y, float z);
/**
 * Calculate the arc cosine of x.
 *
 * @return If x is in the range [-1, 1], the arc cosine of x in radians; otherwise NaN.
 */
@Linux("libm.so.6", "acos")
public abstract double acos(double x);
/**
 * Calculate the arc sine of x.
 *
 * @return If x is in the range [-1, 1], the arc sine of x in radians; otherwise NaN.
 */
@Linux("libm.so.6", "asin")
public abstract double asin(double x);
/**
 * Calculate the arc tangent of x.
 *
 * @return The arc tangent of x in radians.
 */
@Linux("libm.so.6", "atan")
public abstract double atan(double x);
/**
 * Calculate the arc tangent of (x/y).
 *
 * @return The arc tangent of (x/y) in radians.
 */
@Linux("libm.so.6", "atan2")
public abstract double atan2(double y, double x);
/**
 * Calculate the cosine of x.
 *
 * @return The cosine of x in radians.
 */
@Linux("libm.so.6", "cos")
public abstract double cos(double x);

@Linux("libm.so.6", "sincos")
abstract void sincos(double x, ref<double> sinx, ref<double> cosx);
/**
 * Calculate the sine and cosine of x.
 *
 * @return The sine of x in radians.
 * @return The cosine of x in radians.
 */
public double, double sincos(double x) {
	double sinx;
	double cosx;

	sincos(x, &sinx, &cosx);
	return sinx, cosx;
}
/**
 * Calculate the sine of x.
 *
 * @return The sine of x in radians.
 */
@Linux("libm.so.6", "sin")
public abstract double sin(double x);
/**
 * Calculate the tangent of x.
 *
 * Note that since a floating point value can never be an exact fraction of pi,
 * the value of this function is never undefined.
 *
 * @return The tangent of x in radians.
 */
@Linux("libm.so.6", "tan")
public abstract double tan(double x);
/**
 * Calculate the hyperbolic cosine of x.
 *
 * @return The hyperbolic cosine of x in radians.
 */
@Linux("libm.so.6", "cosh")
public abstract double cosh(double x);
/**
 * Calculate the hyperbolic sine of x.
 *
 * @return The hyperbolic sine of x in radians.
 */
@Linux("libm.so.6", "sinh")
public abstract double sinh(double x);
/**
 * Calculate the hyperbolic tangent of x.
 *
 * @return The hyperbolic tangent of x in radians.
 */
@Linux("libm.so.6", "tanh")
public abstract double tanh(double x);
/**
 * Calculate the hyperbolic arc cosine of x.
 *
 * @return The hyperbolic arc cosine of x in radians.
 */
@Linux("libm.so.6", "acosh")
public abstract double acosh(double x);
/**
 * Calculate the hyperbolic arc sine of x.
 *
 * @return The hyperbolic arc sine of x in radians.
 */
@Linux("libm.so.6", "asinh")
public abstract double asinh(double x);
/**
 * Calculate the hyperbolic arc tangent of x.
 *
 * @return The hyperbolic arc tangent of x in radians.
 */
@Linux("libm.so.6", "atanh")
public abstract double atanh(double x);

@Linux("libm.so.6", "frexp")
abstract double frexp(double x, ref<int> exp);
/**
 * Calculate the fraction and exponent of x.
 *
 * @return If x is 0, the function returns 0. otherwise the fraction, m, such
 * that m is in [0.5 - 1.0) and x = m * 2<sup>exp</sup>, for some integer exp.
 * @return if x is 0, the function returns 0, otherwise the exponent, exp,
 * necessary to satisfy the equation above.
 */
public double, int frexp(double x) {
	int exp;
	x = frexp(x, &exp);
	return x, exp;
}
/**
 * Calculate a value from a fraction x and exponent exp.
 *
 * @return The value x * 2<sup>exp</sup>.
 */
@Linux("libm.so.6", "ldexp")
public abstract double ldexp(double x, int exp);
/**
 * Calculate the exponential raised to the x power.
 *
 * @return The value e<sup>x</sup>.
 */
@Linux("libm.so.6", "exp")
public abstract double exp(double x);
/**
 * Calculate 2 raised to the x power.
 *
 * @return The value 2<sup>x</sup>.
 */
@Linux("libm.so.6", "exp2")
public abstract double exp2(double x);
/**
 * Calculate the natural logarithm of x.
 *
 * @return The natural logarithm ln(x).
 */
@Linux("libm.so.6", "log")
public abstract double log(double x);
/**
 * Calculate the base 10 logarithm of x.
 *
 * @return The value log<sub>10</sub>(x).
 */
@Linux("libm.so.6", "log10")
public abstract double log10(double x);
/**
 * Calculate the natural logarithm of (1 + x).
 *
 * @return The value ln(1 + x).
 */
@Linux("libm.so.6", "log1p")
public abstract double log1p(double x);
/**
 * Calculate the machine base logarithm of x.
 *
 * @return The value log<sub>double.RADIX</sub>(x).
 */
@Linux("libm.so.6", "logb")
public abstract double logb(double x);
/**
 * Calculate the base 2 logarithm of x.
 *
 * @return The value log<sub>2</sub>(x).
 */
@Linux("libm.so.6", "log2")
public abstract double log2(double x);

@Linux("libm.so.6", "modf")
abstract double mod(double x, ref<double> p);
/**
 * Split the integral and fractional parts of x.
 *
 * Both return values have the same sign as x.
 *
 * @return The fractional part of x
 * @return The integral part of x
 */
public double, double mod(double x) {
	double y;
	x = mod(x, &y);
	return x, y;
}
/**
 * Calculate 10 raised to the x power.
 *
 * @return The value 10<sup>x</sup>.
 */
@Linux("libm.so.6", "exp10")
public abstract double exp10(double x);
/**
 * Calculate the exponential raised to the x power minus 1.
 *
 * @return The value e<sup>x</sup>-1.
 */
@Linux("libm.so.6", "expm1")
public abstract double expm1(double x);
/**
 * Calculate x raised to the y power.
 *
 * @return The value x<sup>y</sup>.
 */
@Linux("libm.so.6", "pow")
public abstract double pow(double x, double y);
/**
 * Calculate the hypoteneuse.
 *
 * @return The value sqrt(x<sup>2</sup>+y<sup>2</sup>).
 */
@Linux("libm.so.6", "hypot")
public abstract double hypot(double x, double y);
/**
 * Calculate the square root of x.
 *
 * @return The square root of x if x is non-negative, NaN otherwise.
 */
@Linux("libm.so.6", "sqrt")
public abstract double sqrt(double x);
/**
 * Calculate the cube root of x.
 *
 * @return The cube root of x.
 */
@Linux("libm.so.6", "cbrt")
public abstract double cbrt(double x);
/**
 * Calculate the ceiling of x.
 *
 * @return The smallest integer equal to or greater than x.
 */
@Linux("libm.so.6", "ceil")
public abstract double ceil(double x);
/**
 * Calculate the absolute value (magnitude) of x.
 *
 * @return The value |x|.
 */
@Linux("libm.so.6", "fabs")
public abstract double abs(double x);
/**
 * Calculate the floor of x.
 *
 * @return The largest integer equal to or less than x.
 */
@Linux("libm.so.6", "floor")
public abstract double floor(double x);
/**
 * Calculate the floating pointer remainder of x / y.
 *
 * @return The value x - n * y, where n = x/y truncated. The value has the same sign as
 * x and is less than or equal to y.
 */
@Linux("libm.so.6", "fmod")
public abstract double fmod(double x, double y);
/**
 * Calculate the significand of x.
 *
 * @return The mantissa of x scaled to the range [1 - 2).
 */
@Linux("libm.so.6", "significand")
public abstract double significand(double x);
/**
 * Copy the sign of y to the value of x.
 *
 * @return The magnitude x with the sign of y.
 */
@Linux("libm.so.6", "copysign")
public abstract double copysign(double x, double y);
/**
 * Calculate a Bessel function of x.
 *
 * @return The Bessel function of the first kind, order 0 of x.
 */
@Linux("libm.so.6", "j0")
public abstract double j0(double x);
/**
 * Calculate a Bessel function of x.
 *
 * @return The Bessel function of the first kind, order 1 of x.
 */
@Linux("libm.so.6", "j1")
public abstract double j1(double x);
/**
 * Calculate a Bessel function of x.
 *
 * @return The Bessel function of the first kind, order n of x.
 */
@Linux("libm.so.6", "jn")
public abstract double jn(double x, int n);
/**
 * Calculate a Bessel function of x.
 *
 * @return The Bessel function of the second kind, order 0 of x.
 */
@Linux("libm.so.6", "y0")
public abstract double y0(double x);
/**
 * Calculate a Bessel function of x.
 *
 * @return The Bessel function of the second kind, order 1 of x.
 */
@Linux("libm.so.6", "y1")
public abstract double y1(double x);
/**
 * Calculate a Bessel function of x.
 *
 * @return The the Bessel function of the second kind, order n of x.
 */
@Linux("libm.so.6", "yn")
public abstract double yn(double x, int n);
/**
 * Calculate the <a href='https://en.wikipedia.org/wiki/Error_function'>Error Function</a> of x.
 *
 * @return The error function of x.
 */
@Linux("libm.so.6", "erf")
public abstract double erf(double x);
/**
 * Calculate the <a href='https://en.wikipedia.org/wiki/Error_function#Complementary_error_function'>Complementary error Function</a> of x.
 *
 * @return The complementary error function of x.
 */
@Linux("libm.so.6", "erfc")
public abstract double erfc(double x);

@Linux("libm.so.6", "lgammaf_r")
abstract double lgamma_r(double x, ref<int> signgamp);
/**
 * Calculate the natural logarithm of the absolute value of the
 * <a href='https://en.wikipedia.org/wiki/Gamma_function'>Gamma Function</a> of x.
 *
 * @return The value ln(|gamma(x)|).
 */
public double, int lgamma(double x) {
	int signgam;

	x = lgamma_r(x, &signgam);
	return x, signgam;
}
/**
 * Calculate the <a href='https://en.wikipedia.org/wiki/Gamma_function'>Gamma Function</a> of x.
 *
 * @return The value gamma(x).
 */
@Linux("libm.so.6", "tgamma")
public abstract double gamma(double x);
/**
 * Round to integer as a double.
 *
 * This differs from {@link nearbyint} in the handling of
 * inexact exceptions. This function will raise such an exception.

 * @return The nearest integer value to x.
 */
@Linux("libm.so.6", "rint")
public abstract double rint(double x);
/**
 * Round to integer asn an int.
 *
 * @return The nearest integer value to x.
 */
@Linux("libm.so.6", "lrint")
public abstract int irint(double x);
/**
 * Round to integer as a long.
 *
 * @return The nearest integer value to x.
 */
@Linux("libm.so.6", "llrint")
public abstract long lrint(double x);
/**
 * Calculate the next floating point value after x in the direction of y.
 *
 * @return The next floating point value after x in the direction of y.
 */
@Linux("libm.so.6", "nextafter")
public abstract double nextafter(double x, double y);
/**
 * Calculate the floating pointer remainder of x / y.
 *
 * @return The value x - n * y, where n = the nearest integer value to x/y. The value has the same sign as
 * x and is less than or equal to y. If n - |x/y| = 1/2 n is chosen to be even.
 */
@Linux("libm.so.6", "remainder")
public abstract double remainder(double x);
/**
 * Scale x by the exponent n.
 *
 * @return The x * double.RADIX<sup>n</sup>.
 */
@Linux("libm.so.6", "scalbn")
public abstract double scalbn(double x, int n);
/**
 * Scale x by the exponent y.
 *
 * @return The x * double.RADIX<sup>y</sup>.
 */
@Linux("libm.so.6", "scalb")
public abstract double scalb(double x, double y);
/**
 * Calculate the integral exponent of x.
 *
 * @return The value log<sub>double.RADIX</sub>(|x|) truncated to int.
 */
@Linux("libm.so.6", "ilogb")
public abstract int ilogb(double x);
/**
 * Round to integer as a double.
 *
 * This differs from {@link rint} in the handling of
 * inexact exceptions. This function will not raise such an exception.
 *
 * @return The nearest integer value to x.
 */
@Linux("libm.so.6", "nearbyint")
public abstract double nearbyint(double x);
/**
 * Round to integer as a double.
 *
 * This rounds half-way values away from zero, regardless of the current 
 * rounding mode, which differs from {@link rint} which rounds to even
 * values.
 *
 * @return The nearest integer value to x.
 */
@Linux("libm.so.6", "round")
public abstract double round(double x);
/**
 * Round to integer as an int.
 *
 * This rounds half-way values away from zero, regardless of the current 
 * rounding mode, which differs from {@link irint} which rounds to even
 * values.
 *
 * @return The nearest integer value to x.
 */
@Linux("libm.so.6", "lround")
public abstract int iround(double x);
/**
 * Round to integer as a long.
 *
 * This rounds half-way values away from zero, regardless of the current 
 * rounding mode, which differs from {@link lrint} which rounds to even
 * values.
 *
 * @return The nearest integer value to x.
 */
@Linux("libm.so.6", "llround")
public abstract long lround(double x);
/**
 * Truncate to integer as a double.
 *
 * @return The nearest integer value to x not greater in absolute value.
 */
@Linux("libm.so.6", "trunc")
public abstract double trunc(double x);

@Linux("libm.so.6", "remquo")
abstract double remquo(double x, double y, ref<int> quo);
/**
 * Calculate the floating pointer remainder and quotient of x / y.
 *
 * @return The value x - n * y, where n = the nearest integer value to x/y. The value has the same sign as
 * x and is less than or equal to y. If n - |x/y| = 1/2 n is chosen to be even.
 * @return The low order bits of the nearest integer value to x/y. At least the low order 3 bits are returned
 */
public double, int remquo(double x, double y) {
	int quo;
	x = remquo(x, y, &quo);
	return x, quo;
}
/**
 * Calculate the positive difference between x and y.
 *
 * @return The value max(x - y, 0).
 */
@Linux("libm.so.6", "fdim")
public abstract double fdim(double x, double y);
/**
 * Calculate the smaller of x and y.
 *
 * @return The value x if x <= y, or y if y < x, or Nan if neither is true.
 */
@Linux("libm.so.6", "fmin")
public abstract double min(double x, double y);
/**
 * Calculate the larger of x and y.
 *
 * @return The value x if x >= y, or y if y > x, or Nan if neither is true.
 */
@Linux("libm.so.6", "fmax")
public abstract double max(double x, double y);
/**
 * Calculate the x * y + z.
 *
 * @return The value x * y + z.
 */
@Linux("libm.so.6", "fma")
public abstract double fma(double x, double y, double z);
/**
 * Calculate the Pearson's Correlation Coefficient for two arrays of the same length.
 *
 * @param x The first array of values
 * @param y The second array of values
 * @return The correlation coefficient of the two arrays or NaN if the two arrays are
 * not of the same length. 
 */
public double correlate(double[] x, double[] y) {
	if (x.length() != y.length())
		return double.NaN;
	double xBar, yBar;

	for (i in x) {
		xBar += x[i];
		yBar += y[i];
	}
	xBar = xBar / x.length();
	yBar = yBar / y.length();

	double num, xSq, ySq;
	for (i in x) {
		double xDiff, yDiff;

		xDiff = x[i] - xBar;
		yDiff = y[i] - yBar;
		num += xDiff * yDiff;
		xSq += xDiff * xDiff;
		ySq += yDiff * yDiff;
	}

	return num / (sqrt(xSq) * sqrt(ySq));
}

