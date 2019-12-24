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
namespace parasol:types;

import native:C;
/**
 * An IEEE single-precision floating point value.
 */
public class float {
	private static unsigned SIGN_MASK = 0x80000000;
	private static unsigned ONE = 		0x3f800000;
	private static unsigned ZERO = 		0x00000000;
	/**
	 * Not a number.
	 *
	 * This value will compare false for all relations
	 * with any other float value.
	 */
//	@Constant
	public static float NaN = 0.0f / 0.0f;
	/**
	 * The floating point radix.
	 *
	 * The value defined here, 2, is correct for Intel processors, as well as all IEEE standard floating point hardware.
	 */	
	@Constant
	public static int RADIX = 2;

	public float() {
	}
	/**
	 * Parse a floating point number
	 *
	 * Valid contents of the string can be:
	 * <ul>
	 *   <li> An optional sequence of leading white space.
	 *   <li> An optional plus (+) or minus (-) sign.
	 *   <li> One of the following:
	 *	   <ul>
	 *       <li> A decimal number
	 *       <li> a hexadecimal number
	 *       <li> an infinity
	 *       <li> a Nan (not a number)
	 *     </ul>
	 * </ul>
	 * 
	 * <b>Decimal Number</b>
	 *
	 * Consists of a sequence of decimal digits, possibly including one radix character (dependant on
	 * locale) followed by an optional decimal exponent. A decimal exponent consists of an 'E' or 'e'
	 * followed by an optional  plus (+) or minus (-) sign followed by a sequence of one or more decimal digits
	 * that denote multiplication by a power of ten.
	 *
	 * <b>Hexadecimal Number</b>
	 *
	 * Consists of a sequence of hexadecimal digits, possibly including one radix character and followed
	 * by an optiona binary exponent. A binary exponent consists of 'P' or 'p' followed  by an optional
	 * plus (+) or minus (-) sign followed by one or more decimal digits that denote multiplication by a power
	 * of two. At least a radix character or binary exponent must be present.
	 *
	 * <b>Infinity</b>
	 *
	 * The string 'inf' or 'infinity' either in lower- or upper-case.
	 *
	 * <b>NaN (Not a Number)</b>
	 *
	 * The letters 'nan' either in lower- or upper-case, optionally followed by a parenthesized
	 * sequence of alphanumeric characters that designate the type of NaN. If the alphanumeric string 
	 * begins with 0x or 0X and a string of hexadecimal digits, the value of those digits will fill the 
	 * fractional part of the floating point number, except that the high order fraction bit is always set.
	 * Without a leading 0x, the string is interpreted as a decimal string to fill all but the high order
	 * fraction bit.
	 *
	 * @param text The string to parse
	 *
	 * @return On success, the converted value, on failure, undefined
	 * @return true on success, false on failure.
	 */
	public static float, boolean parse(string text) {
		pointer<byte> endptr;
		
		float x = C.strtof(&text[0], &endptr);
		return x, endptr != &text[0] && endptr == &text[text.length()];
	}
	/**
	 * Test whether a value is positive or negative infinity
	 *
	 * @return +1 if the value is +infinity, -1 if the value is -infinity or 0 otherwise.
	 */
	public int infinite() {
		return isinf(*this);
	}
	/**
	 * Test whether a value is finite
	 *
	 * @return true if the vlaue is finite, false otherwise
	 */
	public boolean finite() {
		return finite(*this) != 0;
	}
	/**
	 * Base of the natural logarithm
	 */
//	@Constant
	public static float E =           2.7182818284590452354f;   /* e */
	/**
	 * Base 2 logarithm of e
	 */
//	@Constant
	public static float LOG2E =       1.4426950408889634074f;   /* log_2 e */
	/**
	 * Base 10 logarithm of e
	 */
//	@Constant
	public static float LOG10E =      0.43429448190325182765f;  /* log_10 e */
	/**
	 * Natural logarithm of 2
	 */
//	@Constant
	public static float LN2 =         0.69314718055994530942f;  /* log_e 2 */
	/**
	 * Natural logarithm of 10
	 */
//	@Constant
	public static float LN10 =        2.30258509299404568402f;  /* log_e 10 */
	/**
	 * Pi
	 */
//	@Constant
	public static float PI =          3.14159265358979323846f;  /* pi */
	/**
	 * Pi / 2
	 */
//	@Constant
	public static float PI_2 =        1.57079632679489661923f;  /* pi/2 */
	/**
	 * Pi / 4
	 */
//	@Constant
	public static float PI_4 =        0.78539816339744830962f;  /* pi/4 */
	/**
	 * 1 / Pi
	 */
//	@Constant
	public static float ONE_PI =      0.31830988618379067154f;  /* 1/pi */
	/**
	 * 2 / Pi
	 */
//	@Constant
	public static float TWO_PI =      0.63661977236758134308f;  /* 2/pi */
//	@Constant
	/**
	 * 2 / sqrt(Pi)
	 */
	public static float TWO_SQRTPI =  1.12837916709551257390f;  /* 2/sqrt(pi) */
	/**
	 * Square root of 2
	 */
//	@Constant
	public static float SQRT2 =       1.41421356237309504880f;  /* sqrt(2) */
	/**
	 * 1 / sqrt(2)
	 */
//	@Constant
	public static float ONE_SQRT2 =   0.70710678118654752440f;  /* 1/sqrt(2) */
}

@Linux("libm.so.6", "isinff")
abstract int isinf(float x);

@Linux("libm.so.6", "finitef")
abstract int finite(float x);
/**
 * An IEEE double precision floating point value.
 */
public class double {
	private static long SIGN_MASK = 0x8000000000000000;
	private static long ONE =       0x3ff0000000000000;
	private static long ZERO =      0x0000000000000000;
	/**
	 * Not a number.
	 *
	 * This value will compare false for all relations
	 * with any other double value.
	 */
//	@Constant
	public static double NaN = 0.0 / 0.0;
	/**
	 * The floating point radix.
	 *
	 * The value defined here, 2, is correct for Intel processors, as well as all IEEE standard floating point hardware.
	 */	
	@Constant
	public static int RADIX = 2;

	public double() {
	}
	/**
	 * Parse a floating point number
	 *
	 * Valid contents of the string can be:
	 * <ul>
	 *   <li> An optional sequence of leading white space.
	 *   <li> An optional plus (+) or minus (-) sign.
	 *   <li> One of the following:
	 *	   <ul>
	 *       <li> A decimal number
	 *       <li> a hexadecimal number
	 *       <li> an infinity
	 *       <li> a Nan (not a number)
	 *     </ul>
	 * </ul>
	 * 
	 * <b>Decimal Number</b>
	 *
	 * Consists of a sequence of decimal digits, possibly including one radix character (dependant on
	 * locale) followed by an optional decimal exponent. A decimal exponent consists of an 'E' or 'e'
	 * followed by an optional  plus (+) or minus (-) sign followed by a sequence of one or more decimal digits
	 * that denote multiplication by a power of ten.
	 *
	 * <b>Hexadecimal Number</b>
	 *
	 * Consists of a sequence of hexadecimal digits, possibly including one radix character and followed
	 * by an optiona binary exponent. A binary exponent consists of 'P' or 'p' followed  by an optional
	 * plus (+) or minus (-) sign followed by one or more decimal digits that denote multiplication by a power
	 * of two. At least a radix character or binary exponent must be present.
	 *
	 * <b>Infinity</b>
	 *
	 * The string 'inf' or 'infinity' either in lower- or upper-case.
	 *
	 * <b>NaN (Not a Number)</b>
	 *
	 * The letters 'nan' either in lower- or upper-case, optionally followed by a parenthesized
	 * sequence of alphanumeric characters that designate the type of NaN. If the alphanumeric string 
	 * begins with 0x or 0X and a string of hexadecimal digits, the value of those digits will fill the 
	 * fractional part of the floating point number, except that the high order fraction bit is always set.
	 * Without a leading 0x, the string is interpreted as a decimal string to fill all but the high order
	 * fraction bit.
	 *
	 * @param text The string to parse
	 *
	 * @return On success, the converted value, on failure, undefined
	 * @return true on success, false on failure.
	 */
	public static double, boolean parse(string text) {
		pointer<byte> endptr;
		
		double x = C.strtod(&text[0], &endptr);
		return x, endptr != &text[0] && endptr == &text[text.length()];
	}
	/**
	 * Test whether a value is positive or negative infinity
	 *
	 * @return +1 if the value is +infinity, -1 if the value is -infinity or 0 otherwise.
	 */
	public int infinite() {
		return isinf(*this);
	}
	/**
	 * Test whether a value is finite
	 *
	 * @return true if the vlaue is finite, false otherwise
	 */
	public boolean finite() {
		return finite(*this) != 0;
	}
	/**
	 * Base of the natural logarithm
	 */
//	@Constant
	public static double E =           2.7182818284590452354;   /* e */
	/**
	 * Base 2 logarithm of e
	 */
//	@Constant
	public static double LOG2E =       1.4426950408889634074;   /* log_2 e */
	/**
	 * Base 10 logarithm of e
	 */
//	@Constant
	public static double LOG10E =      0.43429448190325182765;  /* log_10 e */
	/**
	 * Natural logarithm of 2
	 */
//	@Constant
	public static double LN2 =         0.69314718055994530942;  /* log_e 2 */
	/**
	 * Natural logarithm of 10
	 */
//	@Constant
	public static double LN10 =        2.30258509299404568402;  /* log_e 10 */
	/**
	 * Pi
	 */
//	@Constant
	public static double PI =          3.14159265358979323846;  /* pi */
	/**
	 * Pi / 2
	 */
//	@Constant
	public static double PI_2 =        1.57079632679489661923;  /* pi/2 */
	/**
	 * Pi / 4
	 */
//	@Constant
	public static double PI_4 =        0.78539816339744830962;  /* pi/4 */
	/**
	 * 1 / Pi
	 */
//	@Constant
	public static double ONE_PI =      0.31830988618379067154;  /* 1/pi */
	/**
	 * 2 / Pi
	 */
//	@Constant
	public static double TWO_PI =      0.63661977236758134308;  /* 2/pi */
	/**
	 * 2 / sqrt(Pi)
	 */
//	@Constant
	public static double TWO_SQRTPI =  1.12837916709551257390;  /* 2/sqrt(pi) */
	/**
	 * Square root of 2
	 */
//	@Constant
	public static double SQRT2 =       1.41421356237309504880;  /* sqrt(2) */
	/**
	 * 1 / sqrt(2)
	 */
//	@Constant
	public static double ONE_SQRT2 =   0.70710678118654752440;  /* 1/sqrt(2) */
}

@Linux("libm.so.6", "isinf")
abstract int isinf(double x);

@Linux("libm.so.6", "finite")
abstract int finite(double x);



