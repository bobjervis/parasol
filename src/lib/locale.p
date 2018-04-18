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
namespace parasol:international;

import parasol:runtime;
import native:linux;
/**
 * This locale gives you the settings that the "C" locale uses.
 */
public ref<Locale> cLocale() {					// By using the default settings on everything, we get the C Locale.
	return null;
}

ref<Locale> cLocaleMemory;
/*
if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
	//LinuxLocale linuxCLocale("C");
} else if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
}
 */
DecimalStyle defaultDecimalStyle; /* = {
	decimalSeparator: ".",
	groupSeparator: ",",
	//grouping: [ 3, 0 ],
	negativeSign: "-",
	positiveSign: "+",
	zeroDigit: '0',
};*/
/**
 * Use the ISO A4 paper size as the default.
 */
PaperStyle A4Style = {
	width: 210,
	height: 297,
};

public PaperStyle usLetterSize = {
	width: 210,
	height: 279
};
/**
 * This is the default locale used by any locale-dependent functions. 
 */
public ref<Locale> defaultLocale() {
	return null;
}

public monitor class Locale {
	protected ref<DecimalStyle> _decimalStyle;
	protected ref<PaperStyle> _paperStyle;

	public ref<DecimalStyle> decimalStyle() {
		if (_decimalStyle == null)
			_decimalStyle = &defaultDecimalStyle;
		return _decimalStyle;
	}

	public ref<PaperStyle> paperStyle() {
		if (_paperStyle == null)
			_paperStyle = &A4Style;
		return _paperStyle;
	}
}
/**
 * Because of the wildly differing capabilites of sunderlying operating systems,
 * locale data has to be 
 */
public class LinuxLocale extends Locale {
	private linux.locale_t _locale;

	LinuxLocale(string locale) {
	}

	~LinuxLocale() {
		lock (*this) {
			delete _decimalStyle;
			delete _paperStyle;
		}
	}	

	public ref<DecimalStyle> decimalStyle() {
		return null;
	}

	public ref<PaperStyle> paperStyle() {
		lock (*this) {
			if (_paperStyle == null) {
				_paperStyle = new PaperStyle;
			
			}
			return _paperStyle;
		}
	}
}
/**
 *
 */
public class WindowsLocale {
}

public class DecimalStyle {
	public string decimalSeparator;		// A string representing a locale's decimal separator (commonly , or .).
	public string groupSeparator;		// A string representing a locale's digit group separator.
	public byte[] grouping;				// Each element is the number of digits in a group. Elements with higher
										// indices are further left. An element with byte.MAX_VALUE means that
										// no further grouping is done. An element with a zero value means that
										// the previous element is used for all further left grouping.
	public string negativeSign;			// A string representing a locale's negative sign.
	public string positiveSign;			// A string representing a locale's positive sign.
	public int zeroDigit;				// A Unicode code point representing a locale's zero digit. Other digits
										// are assumed to be consecutive code points. Thus, only a Unicode defined
										// decimal digit character group can meaningfully be used here.
}
/**
 * Reserved for future expansion.
 */
public class MonetaryStyle {
}
/**
 * Reserved for future expansion.
 */
public class AddressStyle {
}
/**
 * Reserved for future expansion.
 */
public class CollationStyle {
}
/**
 * Reserved for future expansion.
 */
public class CharacterClassificationStyle {
}
/**
 * Reserved for future expansion.
 */
public class MeasurementsStyle {
}
/**
 * Reserved for future expansion.
 */
public class NameStyle {
	
}
/**
 * Specifies the expected paper dimensions in the given locale.
 */
public class PaperStyle {
	public int width;					// In millimeters
	public int height;					// In millimeters
}
/**
 * Reserved for future expansion.
 */
public class TelephoneStyle {
}
/**
 * Reserved for future expansion.
 */
public class TimeStyle {
	string[] abbreviatedDay;			// An array of 7 abbreviated day-of-week names.
	string[] day;						// An array of 7 full day of week names.
	/**

	public ref<string[]> abbreviatedMonth(ref<time.Calendar> calendar) {
	}
*/
}

