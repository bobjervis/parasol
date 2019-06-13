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
 * Provides facilities for creating an internationalized Parasol application. 
 */
namespace parasol:international;

import parasol:thread;
import parasol:runtime;
import native:linux;
import native:windows;
import native:C;

/**
 * This function gets a Locale object for the named locale. Note that the 
 * special value "C" (or on Linux "POSIX") gets the C locale. Note also that the special
 * value "" gets the operating system's notion of the locale of the program.
 *
 * If the string is any other, it is treated as a locale name with the following syntax:
 *
 *		language[-country][.codepage]
 *
 * Language is an ISO 639 language code. Country is an ISO-3166-1 country/region identifier.
 * Codepage identifies a code page that determines the mapping of 8-bit text data to Unicode.
 *
 * Note that operating system-specific transformations are then applied to the string to
 * the native form of a locale name. For example, on Linux the language, country and codepage are
 * converted to lower-case and the dash (if present) is changed to an underbar.
 */
public ref<Locale> getLocale(string locale) {
	if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		string localeName;

		if (locale == "C" || locale == "POSIX")
			localeName = locale;
		else
			localeName = locale.toLowerCase();

		int dashLoc = locale.indexOf('-');
		if (dashLoc >= 0)
			localeName[dashLoc] = '_';
		linux.locale_t localeID = linux.newlocale(linux.LC_ALL_MASK, localeName.c_str(), null);
		if (localeID != null)
			return new LinuxLocale(localeID);
	} else if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		string localeName;

		if (locale == "C")
			localeName = locale;
		else
			localeName = locale.toLowerCase();

		int dashLoc = locale.indexOf('-');
		int dotLoc;
		if (dashLoc >= 0) {
			dotLoc = locale.indexOf('.', dashLoc);
			if (dotLoc < 0)
				dotLoc = locale.length();
			for (int i = dashLoc + 1; i < dotLoc; i++)
				localeName[i] = localeName[i].toUpperCase();
		} else
			dotLoc = locale.indexOf('.');
		if (dotLoc >= 0) {
			string codepage = locale.substring(dotLoc + 1);
//			if (codepage == "utf8") {
//				localeName = localeName.substring(0, dotLoc + 1) + "utf-8";
//			}
		}
		windows._locale_t localeID = windows._create_locale(C.LC_ALL, localeName.c_str());
		if (localeID != null)
			return new WindowsLocale(localeID);
	}
	return null;
}

/**
 * This locale gives you the settings that the "C" locale uses.
 */
public ref<Locale> cLocale() {					// By using the default settings on everything, we get the C Locale.
	lock (globalState) {
		if (cLocaleMemory == null)
			cLocaleMemory = getLocale("C");
		return cLocaleMemory;
	}
}
/**
 * This is the default locale of the underlying operating system. 
 *
 * @return The default process locale.
 */
public ref<Locale> defaultLocale() {
	lock (globalState) {
		if (defaultLocaleMemory == null)
			defaultLocaleMemory = getLocale("");
		return defaultLocaleMemory;
	}
}
/**
 * This sets the default locale of the process.
 *
 * @param locale The new locale to set.
 * @return The previous defualt locale.
 */
public ref<Locale> setDefaultLocale(ref<Locale> locale) {
	ref<Locale> prior;
	lock (globalState) {
		prior = defaultLocale();
		if (locale != null && prior != locale)
			defaultLocaleMemory = locale;
	}
	return prior;
}
/**
 * Gets the current thread locale.
 *
 * @return The thread locale, if one is defined, otherwise the process locale.
 */
public ref<Locale> myLocale() {
	ref<thread.Thread> th = thread.currentThread();

	if (th.locale != null)
		return th.locale;
	else
		return defaultLocale();
}

Monitor globalState;

ref<Locale> cLocaleMemory;
ref<Locale> defaultLocaleMemory;

DecimalStyle defaultDecimalStyle; /* = {
	decimalSeparator: ".",
	groupSeparator: ",",
	grouping: [ byte(3), byte(0) ],
	negativeSign: "-",
	positiveSign: "+",
	zeroDigit: '0',
}; */
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
 * Because of the wildly differing capabilites of underlying operating systems,
 * locale data has to be configured specifically to each system.
 */
public class LinuxLocale extends Locale {
	private linux.locale_t _locale;

	LinuxLocale(linux.locale_t locale) {
		_locale = locale;
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
 * Because of the wildly differing capabilites of underlying operating systems,
 * locale data has to be configured specifically to each system.
 */
public class WindowsLocale extends Locale {
	private windows._locale_t _locale;

	WindowsLocale(windows._locale_t locale) {
		_locale = locale;
	}
}
/**
 * Specifies the manner in which decimal values should be formatted.
 */
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
	/**
	 * width in  millimeters
	 */
	public int width;
	/**
	 * height in millimeters
	 */
	public int height;
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
/*
	public ref<string[]> abbreviatedMonth(ref<time.Calendar> calendar) {
	}
*/
}

