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
namespace parasol:text;

import parasol:exception.IllegalArgumentException;

import native:linux;
/**
 * A Regular Expression compiled pattern.
 *
 * This implements the POSIX Extended Regular Expression syntax (using the
 * linux regex library).
 *
 * If you need to match multiple strings of text on separate threads,
 * you can instantiate a RegularExpression object, often as a static, public copy
 * and then construct {@link Matcher}'s that refer to it.
 * A Regular Expression object is constant for its lifetime.
 *
 * The usage pattern to match text with this and the {@link Matcher} class
 * is as follows:
 * <pre>
 * {@code
 *          import parasol:text;
 *
 *          text.RegularExpression re(pattern);
 *          for (<i>some number of text strings,</i> s) {
 *              text.Matcher m(&re);
 *              int start, end;
 *
 *              (start, end) = m.findIn(s);
 *              if (start == -1)
 *                  continue;                           // The search failed, try the next string
 *              wholeMatch := s.substr(start, end);     // Retrieve the whole matching portion
 *              subexpr1 := m.subexpression(1);         // Retrieve the 1st subexpression
 *          \}
 * }
 * </pre>
 */
public class RegularExpression {
	regex_t	_compiledPattern;
	int _compilationResult;

	public RegularExpression(string pattern) {
		_compilationResult = regcomp(&_compiledPattern, pattern.c_str(), REG_EXTENDED);
		/*
		if (_compilationResult == 0) {
			printf("buffer =    %p (%d)\n", _compiledPattern.buffer, &ref<regex_t>(null).buffer);
			printf("allocated = %d (%d)\n", _compiledPattern.allocated, &ref<regex_t>(null).allocated);
			printf("used =      %d (%d)\n", _compiledPattern.used, &ref<regex_t>(null).used);
			printf("syntax =    %x (%d)\n", _compiledPattern.syntax, &ref<regex_t>(null).syntax);
			printf("fastmap =   %p (%d)\n", _compiledPattern.fastmap, &ref<regex_t>(null).fastmap);
			printf("translate = %p (%d)\n", _compiledPattern.translate, &ref<regex_t>(null).translate);
			printf("re_nsub =   %d. (%d)\n", _compiledPattern.re_nsub, &ref<regex_t>(null).re_nsub);
			printf("__flags =   %x (%d)\n", _compiledPattern.__flag_bits, &ref<regex_t>(null).__flag_bits);
		}
		*/
	}
	/**
	 * The number of substring matches in the regular expression. Any text in those substrings
	 * that matches the regular expression will also be available from the
	 * {@link Matcher} object after {@link Matcher.findIn} returns.
	 *
	 * @return The number of parenthesized sub-expressions in the original pattern.
	 */
	public int substringMatches() {
		return int(_compiledPattern.re_nsub);
	}

	public boolean hasError() {
		return _compilationResult != 0;
	}

	public string errorMessage() {
		if (_compilationResult == 0)
			return null;
		sizeNeeded := regerror(_compilationResult, &_compiledPattern, null, 0);
		string s;
		s.resize(sizeNeeded - 1);		// The sizeNeeded includes the null terminator, but resizing a string adds a null byte.
		regerror(_compilationResult, &_compiledPattern, &s[0], sizeNeeded);
		return s;
	}
}
/**
 * A Regular Expression matcher.
 *
 * This implements the POSIX Extended Regular Expression syntax (using the
 * linux regex library).
 *
 * Most uses for regular expression pattern matching can be satisfied with the
 * Matcher class.
 * A Matcher object is created once to hold a compiled pattern.
 * Once created, any of several methods can then be used to either match text or customize
 * the matching algorithm.
 * 
 * Calls to the {@link matches} or {@link findIn} methods will produce, as a side-effect,
 * a set of zero or more sub-expression values.
 * Each parenthesized sub-expression in the original pattern specifies a value to be saved
 * on a successful match.
 * The value of those matched sub-expressions remains available until the next call to
 * either method.
 * Calls to any other method leaves the sub-expression values unchanged.
 *
 * Note that a sub-expression can be null after a successful match if that sub-expression
 * was not found.
 * <pre>
 * {@code
 *          text.Matcher m("(abc|def(.*))");    // Produces 2 sub-expressions
 *
 *          m.matches("ax");                    // Sub-expression values are undefined after a failed match
 *
 *          m.matches("abc");                   // Matched on the first alternative, didn't match the second
 *                  m.subexpression(1) -> "abc"
 *                  m.subexpression(2) -> null
 *
 *          m.matches("defghi");                // Matched on the second alternative, both populated
 *                  m.subexpression(1) -> "defghi"
 *                  m.subexpression(2) -> "ghi"
 * }
 * </pre>
 *
 * The usage pattern to match text with this and the Matcher class by itself
 * is as follows:
 * <pre>
 * {@code
 *          import parasol:text;
 *
 *          text.Matcher m(pattern);
 *          m.setAtEoL(false);                         // Do not match any $ sub-patterns
 *          for (<i>some number of text strings,</i> s) {
 *              int start, end;
 *
 *              (start, end) = m.findIn(s);
 *              if (start == -1)
 *                  continue;                           // The search failed, try the next string
 *              wholeMatch := s.substr(start, end);     // Retrieve the whole matching portion
 *              subexpr1 := m.subexpression(1);         // Retrieve the 1st subexpression
 *          \}
 * }
 * </pre>
 */
public class Matcher {
	ref<RegularExpression> _pattern;
	regmatch_t[] _matches;
	string[] _subexpressions;
	boolean _atBoL;
	boolean _atEoL;
	boolean _allocatedPattern;

	public Matcher(string pattern) {
		_pattern = new RegularExpression(pattern);
		init();
	}

	public Matcher(ref<RegularExpression> pattern) {
		_pattern = pattern;
		init();
	}

	private void init() {
		if (!_pattern.hasError()) {
			_matches.resize(int(_pattern._compiledPattern.re_nsub) + 1);
			_subexpressions.resize(int(_pattern._compiledPattern.re_nsub) + 1);
		}
		_atEoL = true;
		_atBoL = true;
	}

	public boolean hasError() {
		return _pattern.hasError();
	}

	~Matcher() {
		if (_allocatedPattern)
			delete _pattern;
	}

	public ref<Matcher> setAtBoL(boolean value) {
		_atBoL = value;
		return this;
	}

	public ref<Matcher> setAtEoL(boolean value) {
		_atEoL = value;
		return this;
	}
	/**
	 * Determine whether a string contains a given pattern.
	 *
	 * This is useful for a slightly faster test than {@link findIn}
	 * when the location of the match is not important.
	 *
	 * @param text The string of text to search.
	 *
	 * @return true if the regular expression matches some subset
	 * of the text.
	 */
	public boolean containedIn(substring text) {
		int eflags = REG_STARTEND;

		if (!_atBoL)
			eflags |= REG_NOTBOL;
		if (!_atEoL)
			eflags |= REG_NOTEOL;

		_matches[0].rm_so = 0;
		_matches[0].rm_eo = text.length();
		result := regexec(&_pattern._compiledPattern, text.c_str(), 0, &_matches[0], eflags);
		return result == 0;
	}
	/**
	 * Determine whether a string exactly matches a given pattern.
	 *
	 * If the method returns true, you may access the subexpressions using the {@link subexpression} method.
	 * @param text The string to compare.
	 *
	 * After a successful match, any matching sub-expressions are copied into this object,
	 * so the lifetime of the argument does not matter after the call.
	 * The subexpressions will be available until a subsequent call to this method or to {@link findIn}.
	 *
	 * @return true if the entire text of the argument matches the regular expression, false otherwise.
	 */
	public boolean matches(substring text) {
		int eflags = REG_STARTEND;

		if (!_atBoL)
			eflags |= REG_NOTBOL;
		if (!_atEoL)
			eflags |= REG_NOTEOL;

		_matches[0].rm_so = 0;
		_matches[0].rm_eo = text.length();
		result := regexec(&_pattern._compiledPattern, text.c_str(), _matches.length(), &_matches[0], eflags);
		if (result != 0)
			return false;
		populateSubexpressions(text.c_str());
		return _matches[0].rm_so == 0 && _matches[0].rm_eo == text.length();
	}
	/**
	 * Find the pattern in a string.
	 *
	 * Note that the text being searched can contain nul bytes.
	 *
	 * After a successful match, any matching sub-expressions are copied into this object,
	 * so the lifetime of the argument does not matter after the call.
	 * The subexpressions will be available until a subsequent call to this method or to {@link matches}.
	 *
	 * @param text The string of text to search.
	 *
	 * @return The index of the first matching character in the string, or -1 if no match was found.
	 * @return The index of the next character after the matching part of the searched string, or -1 if no match was found.
	 */
	public int, int findIn(substring text) {
		int eflags = REG_STARTEND;

		if (!_atBoL)
			eflags |= REG_NOTBOL;
		if (!_atEoL)
			eflags |= REG_NOTEOL;

		_matches[0].rm_so = 0;
		_matches[0].rm_eo = text.length();
		result := regexec(&_pattern._compiledPattern, text.c_str(), _matches.length(), &_matches[0], eflags);
		if (result == 0) {
			populateSubexpressions(text.c_str());
			return _matches[0].rm_so, _matches[0].rm_eo;
		} else
			return -1, -1;
	}
	/**
	 * Return the value of a sub-expression
	 * @exception IllegalArgumentException thrown when the argument is less than zero or greater 
	 * than the number of sub-expressions defined in the pattern.
	 */
	public string subexpression(int i) {
		if (i < 0 || i > _pattern._compiledPattern.re_nsub + 1)
			throw IllegalArgumentException("subexpression out of range " + i);
		if (_subexpressions[i] == null)
			return null;
		else
			return _subexpressions[i];
	}

	private void populateSubexpressions(pointer<byte> text) {
		for (i in _matches) {
			if (_matches[i].rm_so >= 0)
				_subexpressions[i] = string(text + _matches[i].rm_so, _matches[i].rm_eo - _matches[i].rm_so);
			else
				_subexpressions[i] = null;
		}
	}

}

@Linux("libc.so.6", "regcomp")
abstract int regcomp(ref<regex_t> preg, pointer<byte> pattern, int cflags);
@Linux("libc.so.6", "regerror")
abstract int regerror(int errorcode, ref<regex_t> preg, pointer<byte> errbuf, long errbuf_size);
@Linux("libc.so.6", "regexec")
abstract int regexec(ref<regex_t> preg, pointer<byte> data, long nmatch, pointer<regmatch_t> pmatch, int eflags);
@Linux("libc.so.6", "regfree")
abstract int regfree(ref<regex_t> preg);

class reg_syntax_t = unsigned;
class regoff_t = int;

class regex_t {
	pointer<byte> buffer;
	long allocated;
	long used;
	long syntax;
	pointer<byte> fastmap;
	pointer<byte> translate;
	long re_nsub;				// a C++ size_t, so should be Unsigned<64>
	byte __flag_bits;
}

class regmatch_t {
	regoff_t rm_so;
	regoff_t rm_eo;
}

@Constant
int REG_EXTENDED = 1;
@Constant
int REG_ICASE = REG_EXTENDED << 1;
@Constant
int REG_NEWLINE = REG_ICASE << 1;
@Constant
int REG_NOSUB = REG_NEWLINE << 1;

@Constant
int REG_NOTBOL = 1;
@Constant
int REG_NOTEOL = 1 << 1;
@Constant
int REG_STARTEND = 1 << 2;



