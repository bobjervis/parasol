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
 *
 * A process has a default locale inherited from the underlying operating system locale settings.
 * Most functions, such as printf, are sensitive to this locale. You don't have to do anything to get
 * formatting functions to use the correct decimal point, locale time formats and so on.
 *
 * Each thread also can have a locale specific to it by setting the locale member of the {@link Thread} object.
 * For example, to set the current threads locale to German, the following code can be used:
 *
 * <pre>{@code
 *	thread.currentThread().locale = getLocale("de-DE");
 *}</pre>
 *
 * You can restore a thread to the default process locale by settting the thread's locale member to null.
 *
 * You can obtain a new Locale object using the {@link getLocale} function. You can then obtain detailed
 * style information for that Locale if you wish to do your own formatting or you can use standard formatting
 * functions by either setting the current thread's locale as described above, or change the process's 
 * default locale using the {@link setDefaultLocale} function.
 */
namespace parasol:international;

import parasol:log;
import parasol:thread;
import parasol:runtime;
import native:linux;
import native:windows;
import native:C;

private ref<log.Logger> logger = log.getLogger("parasol.international");
/**
 * This function gets a Locale object for the named locale.
 *
 * Note that the special value "C" (or on Linux "POSIX") gets the C locale.
 * The special value "" gets the operating system's notion
 * of the locale of the program (the default process locale).
 *
 * If the string is any other, it is treated as a locale name with the following syntax:
 *
 *		language[-country][.codepage]
 *
 * Language is an ISO 639 language code. Country is an ISO-3166-1 country/region identifier.
 * Codepage identifies a code page that determines the mapping of 8-bit text data to Unicode.
 *
 * If the country is omitted, it is set to the value of the language.
 *
 * If the codepage is omitted it is treated as UTF-8.
 *
 * Note that operating system-specific transformations are then applied to the string to
 * the native form of a locale name. For example, on Linux the language and codepage are
 * converted to lower-case, the country to upper-case and the dash (if present) is changed to an underbar.
 */
public ref<Locale> getLocale(string locale) {
	if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
		string localeName;

		if (locale == "C" || locale == "POSIX" || locale == "")
			localeName = locale;
		else {
			localeName = locale.toLowerCase();

			int dashLoc = localeName.indexOf('-');
			int dotLoc;
			if (dashLoc >= 0) {
				localeName[dashLoc] = '_';
				dotLoc = localeName.indexOf('.', dashLoc);
				if (dotLoc < 0) {
					dotLoc = localeName.length();
					localeName += ".utf8";
				}
				for (int i = dashLoc + 1; i < dotLoc; i++) {
					localeName[i] = localeName[i].toUpperCase();
				}
			} else {
				dotLoc = localeName.indexOf('.');
				if (dotLoc < 0)
					localeName = localeName + "_" + localeName.toUpperCase() + ".utf8";
				else {
					string language = localeName.substr(0, dotLoc);
					localeName = language + "_" + language.toUpperCase() + localeName.substr(dotLoc);
				}
			}
		}
		lock (globalState) {
			if (localeMap.contains(localeName))
				return localeMap[localeName];
			linux.locale_t localeID = linux.newlocale(linux.LC_ALL_MASK, localeName.c_str(), null);
			if (localeID != null) {
				ref<Locale> locale = new LinuxLocale(localeID, localeName);
				remember(locale);
				return locale;
			} else {
				printf("newlocale of '%s' failed: %s\n", localeName, linux.strerror(linux.errno()));
			}
		}
	} else if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
		string localeName;

		if (locale == "C" || locale == "")
			localeName = locale;
		else
			localeName = locale.toLowerCase();

		int dashLoc = localeName.indexOf('-');
		int dotLoc;
		if (dashLoc >= 0) {
			dotLoc = localeName.indexOf('.', dashLoc);
			if (dotLoc < 0)
				dotLoc = localeName.length();
			for (int i = dashLoc + 1; i < dotLoc; i++)
				localeName[i] = localeName[i].toUpperCase();
		} else {
			dotLoc = locale.indexOf('.');
			if (dotLoc < 0)
				localeName += "-" + localeName.toUpperCase();
			else {
				string language = localeName.substr(0, dotLoc);
				localeName = language + "_" + language.toUpperCase() + localeName.substr(dotLoc);
				dotLoc += language.length() + 1;
			}
		}
		lock (globalState) {
			if (localeMap.contains(localeName))
				return localeMap[localeName];
			windows._locale_t localeID = windows._create_locale(C.LC_ALL, localeName.c_str());
			if (localeID != null) {
				ref<Locale> locale = new WindowsLocale(localeID, localeName);
				globalState.remember(locale);
				return locale;
				printf("newlocale of '%s' failed: %s\n", localeName, linux.strerror(linux.errno()));
			}
		}
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
 * @return The previous default locale.
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

monitor class GlobalState {
	ref<Locale> cLocaleMemory;
	ref<Locale> defaultLocaleMemory;
	private ref<Locale>[] _locales;
	ref<Locale>[string] localeMap;

	~GlobalState() {
		_locales.deleteAll();
	}

	void remember(ref<Locale> locale) {
		_locales.append(locale);
		localeMap[locale.name()] = locale;
	}
}

GlobalState globalState;


DecimalStyle defaultDecimalStyle = {
	decimalSeparator: ".",
	groupSeparator: ",",
	grouping: [ byte(3), byte(0) ],
	negativeSign: "-",
	positiveSign: "+",
	zeroDigit: '0',
};
/**
 * This describe the ISO A4 paper size.
 */
public PaperStyle A4Style = {
	width: 210,
	height: 297,
};
/**
 * This describes the US Letter size.
 */
public PaperStyle usLetterSize = {
	width: 216,
	height: 279
};
/**
 * This class describes a locale, with all its attendant data.
 */
public monitor class Locale {
	ref<DecimalStyle> _decimalStyle;
	ref<PaperStyle> _paperStyle;
	string _localeName;
	string _language;
	string _country;
	string _encoding;

	Locale(string localeName) {
		_localeName = localeName;
		int idx = _localeName.indexOf('_');
		if (idx < 0)
			_language = _localeName.toLowerCase();
		else {
			_language = _localeName.substr(0, idx).toLowerCase();
			int idx2 = _localeName.indexOf('.', idx + 1);
			if (idx2 < 0)
				_country = _localeName.substr(idx + 1).toLowerCase();
			else {
				_country = _localeName.substr(idx + 1, idx2).toLowerCase();
				_encoding = _localeName.substr(idx2 + 1).toLowerCase();
			}
		}
//		printf("lang = %s country = %s encoding = %s", _language, _country, _encoding);
	}

	~Locale() {
		delete _decimalStyle;
	}	

	/**
	 * Fetch the decimal style parameters for this locale.
	 *
	 * @return A {@link DecimalStyle} object describing this locale's decimal formatting. Do not modify this object.
	 */
	public ref<DecimalStyle> decimalStyle() {
		if (_decimalStyle == null)
			_decimalStyle = &defaultDecimalStyle;
		return _decimalStyle;
	}
	/**
	 * Fetch the paper style parameters for this locale.
	 *
	 * @return A {@link PaperStyle} object describing this locale's paper formatting. Do not modify this object.
	 */
	public ref<PaperStyle> paperStyle() {
		if (_paperStyle == null)
			_paperStyle = &A4Style;
		return _paperStyle;
	}

	public string name() {
		return _localeName;
	}
}
/**
 * Because of the wildly differing capabilites of underlying operating systems,
 * locale data has to be configured specifically to each system.
 */
class LinuxLocale extends Locale {
	private linux.locale_t _locale;

	LinuxLocale(linux.locale_t locale, string localeName) {
		super(localeName);
		_locale = locale;
	}

	public ref<DecimalStyle> decimalStyle() {
		lock (*this){
			if (_decimalStyle == null) {
				_decimalStyle = new DecimalStyle;
				_decimalStyle.decimalSeparator = string(linux.nl_langinfo_l(linux.DECIMAL_POINT, _locale));
				_decimalStyle.groupSeparator = string(linux.nl_langinfo_l(linux.THOUSANDS_SEP, _locale));
				pointer<byte> b = linux.nl_langinfo_l(linux.GROUPING, _locale);
				if (b != null) {
					for (;;) {
						if (*b == 0) {
							_decimalStyle.grouping.append(0);
							break;
						} else if (*b == 127 || *b == 255) {
							_decimalStyle.grouping.append(byte.MAX_VALUE);
							break;
						} else
							_decimalStyle.grouping.append(*b);
						b++;
					}
				}
				_decimalStyle.negativeSign = "-";
				_decimalStyle.positiveSign = "+";
				_decimalStyle.zeroDigit = '0';
			}
			return _decimalStyle;
		}
	}

	public ref<PaperStyle> paperStyle() {
		lock (*this) {
			if (_paperStyle == null) {
				switch (_country) {
				case "us":
				case "ca":
				case "ph":
					_paperStyle = &usLetterSize;
					break;

				default:
					_paperStyle = &A4Style;
				}
			}
			return _paperStyle;
		}
	}
}
/**
 * Because of the wildly differing capabilites of underlying operating systems,
 * locale data has to be configured specifically to each system.
 */
class WindowsLocale extends Locale {
	private windows._locale_t _locale;

	WindowsLocale(windows._locale_t locale, string localeName) {
		super(localeName);
		_locale = locale;
	}
}
/**
 * Specifies the manner in which decimal values should be formatted.
 */
public class DecimalStyle {
	/**
	 * A string representing a locale's decimal separator (commonly , or .).
	 */
	public string decimalSeparator;
	/**
	 * A string representing a locale's digit group separator (commonly , or .).
	 */
	public string groupSeparator;
	/**
	 * Each element is the number of digits in a group. Elements with higher
	 * indices are further left. An element with byte.MAX_VALUE means that
	 * no further grouping is done. An element with a zero value means that
	 * the previous element is used for all further left grouping.
	 */
	public byte[] grouping;
	/**
	 * A string representing a locale's negative sign.
	 */
	public string negativeSign;
	/**
	 * A string representing a locale's positive sign.
	 */
	public string positiveSign;
	/**
	 * A Unicode code point representing a locale's zero digit. Other digits
	 * are assumed to be consecutive code points. Thus, only a Unicode defined
	 * decimal digit character group can meaningfully be used here.
	 */
	public int zeroDigit;
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
