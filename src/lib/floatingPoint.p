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

public class float {
	private static unsigned SIGN_MASK = 0x80000000;
	private static unsigned ONE = 0x3f800000;
	
	public static float NaN = 0.0f / 0.0f;
	
	public float() {
	}
	
//	public float(float value) {
		
//	}
	public static float, boolean parse(string text) {
		pointer<byte> endptr;
		
		float x = C.strtof(&text[0], &endptr);
		return x, endptr != &text[0] && endptr == &text[text.length()];
	}
}

public class double {
	private static long SIGN_MASK = 0x8000000000000000;
	private static long ONE =       0x3ff0000000000000;

	public static double NaN = 0.0 / 0.0;

	public double() {
	}
	
//	public double(double value) {
		
//	}
	
	public static double, boolean parse(string text) {
		pointer<byte> endptr;
		
		double x = C.strtod(&text[0], &endptr);
		return x, endptr != &text[0] && endptr == &text[text.length()];
	}
}


