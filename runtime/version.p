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
namespace parasol:context;

//import parasol:compiler;
//import parasol:exception.IllegalArgumentException;
//import parasol:exception.IllegalOperationException;
//import parasol:json;
//import parasol:process;
import parasol:storage;
//import parasol:time;
//import parasol:types.Set;
/**
 * This class encapsulates a {@doc-link version-string version string} and provides API's to
 * analyze and modify version strings.
 *
 */
public class Version {
	private string _version;
	/**
	 * Constructor
	 */
	public Version(string version) {
		_version = version;
	}
	/**
	 * Compare two version strings.
	 *
	 * This will compare two version strings.
	 * This function is very permissive. It assumes that 
	 * a version string is a set of digit sequences separated by period characters.
	 * 
	 * If a sequence of characters between any period characters contain non-decimal digits
	 * the value is undefined.
	 * If the value of any component is outside the range of the {@link unsigned} type,
	 * the value is undefined.
	 *
	 * One version number is greater than another according to the following algorithm:
	 *
	 *	<ol>
	 *		<li>Convert each digit sequence into an unsigned value, resulitng in two
	 *			unsigned arrays of values, one for the left operand and one for the right..
	 *			Thus, a version string of "12.5.67" would yield an array [ 12, 5, 67 ].
	 *		<li>For corresponding elements of the unsigned arrays, if any of them differ,
	 *			compare the first pair of unsigned values.
	 *			Since they differ, return a negative value if the left operand's value was
	 *			less and a positive value if it was greater than the right operand's value.
	 *		<li>If all corresponding unsigned values are equal, apply the following:
	 *			<ul>
	 *				<li>If the left operand has fewer digit sequences, return a negative value.
	 *				<li>If the two operands have the same number of unsigned values, return zero.
	 *				<li>Otherwise, the left operand has more digit sequences, return a positive number.
	 *			</ul>
	 *	</ol>
	 *			
	 * @param left The left side of the comparison.
	 *
	 * @param right The right side of the comparison.
	 *
	 * @return <ul>
	 * 			   <li>&lt;0 if the left operand is a lower version number than the right.
	 *			   <li>0 if the two version numbers were identical.
	 *			   <li>&gt;0 if the left operand is a greater version number than the right.
	 * 		   </ul>
	 */
	int compare(Version other) {
		unsigned[] leftComponents = components();
		unsigned[] rightComponents = other.components();
	
		if (leftComponents.length() >= rightComponents.length()) {
			for (i in rightComponents) {
				if (leftComponents[i] < rightComponents[i])
					return -1;
				else if (leftComponents[i] > rightComponents[i])
					return 1;
			}
			if (leftComponents.length() > rightComponents.length())
				return 1;
		} else {
			for (i in leftComponents) {
				if (leftComponents[i] < rightComponents[i])
					return -1;
				else if (leftComponents[i] > rightComponents[i])
					return 1;
			}
			return -1;
		}
		return 0;
	}

	public unsigned[] components() {
		unsigned[] output;

		if (_version == null)
			return output;
		s := _version.split('.');
		for (i in s) {
			component := unsigned.parse(s[i]);
			output.append(component);
		}
		return output;
	}
	/**
	 * Check whether a given string is a valid version string
	 *
	 * This predicate does not require constructing the object first.
	 *
	 * A string is a 'valid' version string, and will be well-behaved in
	 * comparing versions if the following holds true:
	 *
	 * <ul>
	 *	   <li>The string begins and ends in a decimal digit.
	 *	   <li>All characters in the string are either decimal digits or the
	 *		period character.
	 *	   <li>Each sub-sequence of digits begins with a zero digit only if it 
	 *		is the only character in the sequence.
	 *	   <li>The value of each digit sub-sequence can be prepresented by a
	 *		Parasol {@link long} object.
	 * </ul>
	 *
	 * @param candidate The string to be tested for whether it is a valid
	 * Parasol version string.
	 *
	 * @return true if the parameter string is a valid Parasol version string,
	 * false otherwise.
	 */
	public static boolean isValid(string candidate) {
		return isValidCore(candidate, false);
	}
	/**
	 * Check whether a given string is a valid version string template.
	 *
	 * A valid Parasol version string is also a valid template.
	 *
	 * In addition, a version template can include a 'D' character in the
	 * place of a digit sequence.
	 */
	public static boolean isValidTemplate(string template) {
		return isValidCore(template, true);
	}

	private static boolean isValidCore(string candidate, boolean isTemplate) {
		if (candidate == null)
			return false;
		boolean previousWasDigit;
		byte previousDigit = 'X';
		string digits;
		for (i in candidate) {
			c := candidate[i];
			if (c.isDigit()) {
				if (!previousWasDigit) {
					previousDigit = c;
				} else if (previousDigit == '0')
					return false;
				previousWasDigit = true;
				digits.append(c);
				continue;
			}
			if (!checkValue(digits))
				return false;
			digits = null;
			if (isTemplate && c == 'D') {
				if (i > 0) {
					if (candidate[i - 1] != '.')
						return false;
				}
				if (i < candidate.length() - 1) {
					if (candidate[i + 1] != '.')
						return false;
				}
				continue;
			}
			previousWasDigit = false;
			if (c != '.')
				return false;
			if (i == 0)
				return false;
			if (i == candidate.length() - 1)
				return false;
			if (candidate[i - 1] == '.')
				return false;
		}
		if (!checkValue(digits))
			return false;
		return true;

		boolean checkValue(string digits) {
			if (digits == null)				// If there are no digits to test, other validation should
											// take care of this case just fine.
				return true;
			boolean success;
			long value;
			(value, success) = long.parse(digits);
			return success;
		}
	}

	public string toString() {
		return _version;
	}
}

public int versionCompare(string left, string right) {
	return Version(left).compare(Version(right));
}

string highestVersion(string[] versionList) {
	Version highestVer(null);

	for (i in versionList) {
		if (!Version.isValid(versionList[i]))
			continue;
		Version v(versionList[i]);

		if (v.compare(highestVer) > 0) {
			highestVer = v;
//			printf("i = %d v = '%s' highestVer = '%s'\n", i, v.toString(), highestVer.toString());
		}
	}
	return highestVer.toString();
}

string[] versions(string packageDir) {
	storage.Directory d(packageDir);
	string[] results;

	if (d.first()) {
		do {
			name := d.filename();
			if (name[0] == 'v') {
				substring ss = name.substr(1);
				components := ss.split('.');
				boolean valid = true;
				for (j in components) {
					unsigned x;
					boolean success;
		
					(x, valid) = unsigned.parse(components[j]);
					if (!valid)
						break;
				}
				if (!valid)
					continue;
				results.append(ss);
			}
		} while (d.next());
	}
	return results;
}
