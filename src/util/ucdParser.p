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
import parasol:storage;
import parasol:process;

/*
 * Date and Copyright holder of this code base.
 */
string COPYRIGHT_STRING = "2015 Robert Jervis";
/*
 *	Parasol Unicode Classifier Generator:
 *
 *		This code parses a UnicodeData.txt file and generates Parasol code
 *		to classify incoming UTF-8 code sequences.
 *		
 */
class UCDParserCommand extends process.Command {
	public UCDParserCommand() {
		finalArguments(2, 2, "<UnicodeData.txt file> <classifier-filename>");
		description("The first given filename is parsed as a UnicodeData.txt file. " +
					"\n" +
					"This program will interpret the information in that file and generate " +
					"a set of classifier function (in Parasol) that must then be checked into " +
					"the Parasol compiler source code to complete the compiler." +
					"\n" +
					"Copyright (c) " + COPYRIGHT_STRING
					);
		verboseOption = booleanOption('v', null,
					"Enables verbose output.");
		helpOption('?', "help",
					"Displays this help.");
	}

	ref<process.Option<boolean>> verboseOption;
}

private UCDParserCommand ucdParserCommand;
private string[] finalArguments;

enum Treatment {
	DECIMAL_0,
	DECIMAL_1,
	DECIMAL_2,
	DECIMAL_3,
	DECIMAL_4,
	DECIMAL_5,
	DECIMAL_6,
	DECIMAL_7,
	DECIMAL_8,
	DECIMAL_9,
	LETTER,
	WHITE_SPACE
}

class Interval {
	public int first;
	public int last;
	public Treatment treatment;
}

Interval[] intervals;

int main(string[] args) {
	int result = 1;
	
	if (!ucdParserCommand.parse(args))
		ucdParserCommand.help();
	finalArguments = ucdParserCommand.finalArguments();
	if (finalArguments.length() != 2)
		ucdParserCommand.help();
	printf("Creating classifiers in %s\n", finalArguments[1]);

	string unicodeData_txt = finalArguments[0];
	
	ref<Reader> ucd = storage.openTextFile(unicodeData_txt);
	if (ucd == null) {
		printf("Could not read file %s\n", unicodeData_txt);
		return 1;
	}
	int lineNumber = 1;
	int lastCodePoint = -1;
	boolean needsSort = false;
	
	Interval[] letters;
	Interval[] whiteSpace;
	int[][] digits;
	digits.resize(10);
	
	for (;; lineNumber++) {
		string line;
		
		line = ucd.readLine();
		if (line == null) {
			delete ucd;
			break;
		}
		string[] fields = line.split(';');
		
		if (fields.length() != 15) {
			printf("Unexpected text in %s: %s at line %d\n", unicodeData_txt, line, lineNumber);
			return 1;
		}
		int codePoint;
		boolean status;
		(codePoint, status) = int.parse(fields[0], 16);
		if (!status) {
			printf("Invalid code point: %s\n", fields[0]);
			return 1;
		}
		if (codePoint < lastCodePoint)
			needsSort = true;
		Interval x;
		x.first = codePoint;
		x.last = codePoint;
		if (fields[2][0] == 'L') {
			x.treatment = Treatment.LETTER;
			recordCodePoint(fields[1], codePoint, &x);
		} else if (fields[2] == "Nd") {
			int value = int.parse(fields[8]);
			x.treatment = Treatment(value);
			recordCodePoint(fields[1], codePoint, &x);
		} else if (fields[2] == "Zs") {
			x.treatment = Treatment.WHITE_SPACE;
			recordCodePoint(fields[1], codePoint, &x);
		}
	}
	if (needsSort) {
		printf("Code points are not in ascending order.\n");
		return 1;
	}
	if (ucdParserCommand.verboseOption.value) {
		for (int i = 0; i < intervals.length(); i++)
			printf("%8x-%x %s\n", intervals[i].first, intervals[i].last, string(intervals[i].treatment));
	}
	int totalLetters = 0;
	int totalWhiteSpace = 0;
	int totalDecimals = 0;
	for (int i = 0; i < intervals.length(); i++) {
		int span = 1 + intervals[i].last - intervals[i].first;
		switch (intervals[i].treatment) {
		case	LETTER:
			totalLetters += span;
			break;
			
		case	WHITE_SPACE:
			totalWhiteSpace += span;
			break;
			
		default:
			totalDecimals += span;
		}
	}

	printf("Total Intervals - %d Total Letters %d Total White Space %d Total Decimals %d\n", intervals.length(),
			totalLetters, totalWhiteSpace, totalDecimals);
	ref<Writer> classifier = storage.createTextFile(finalArguments[1]);
	if (classifier == null) {
		printf("Could not create file %s\n", finalArguments[1]);
		return 1;
	}
	classifier.write("/*\n");
	classifier.write(" * Generated file - DO NOT MODIFY\n");
	classifier.write(" */\n");
	if (!writeClassifier(classifier)) {
		delete classifier;
		printf("Failed to write classifier %s\n", finalArguments[1]);
		return 1;
	} else {
		delete classifier;
		return 0;
	}
}

void recordCodePoint(string generalCategory, int codePoint, ref<Interval> x) {
	if (generalCategory[0] == '<') {
		if (generalCategory.endsWith(" First>")) {
			intervals.append(*x);
			return;
		} else if (generalCategory.endsWith(" Last>")) {
			ref<Interval> ip = &intervals[intervals.length() - 1];
			if (ip.treatment != x.treatment) {
				printf("First and Last not properly paired at %x\n", codePoint);
				process.exit(1);
			}
			ip.last = codePoint;
			return;
		}	
	}
	if (intervals.length() == 0)
		intervals.append(*x);
	else {
		ref<Interval> ip = &intervals[intervals.length() - 1];
		if (codePoint == ip.last + 1 && ip.treatment == x.treatment)
			ip.last = codePoint;
		else
			intervals.append(*x);
	}
}

boolean writeClassifier(ref<Writer> classifier) {
	classifier.write("namespace parasol:unicode;\n\n");
	classifier.write("// 0-9 = digit value, 254 = white space, 255 = letter, -1 = unclassified\n");
	classifier.write("@Constant\n");
	classifier.write("public int CPC_ERROR = -1;\n");
	classifier.write("@Constant\n");
	classifier.write("public int CPC_WHITE_SPACE = 254;\n");
	classifier.write("@Constant\n");
	classifier.write("public int CPC_LETTER = 255;\n");
	classifier.write("@Constant\n");
	classifier.write("public int CPC_DIGIT_0 = 0;\n");
	classifier.write("@Constant\n");
	classifier.write("public int CPC_DIGIT_1 = 1;\n");
	classifier.write("@Constant\n");
	classifier.write("public int CPC_DIGIT_2 = 2;\n");
	classifier.write("@Constant\n");
	classifier.write("public int CPC_DIGIT_3 = 3;\n");
	classifier.write("@Constant\n");
	classifier.write("public int CPC_DIGIT_4 = 4;\n");
	classifier.write("@Constant\n");
	classifier.write("public int CPC_DIGIT_5 = 5;\n");
	classifier.write("@Constant\n");
	classifier.write("public int CPC_DIGIT_6 = 6;\n");
	classifier.write("@Constant\n");
	classifier.write("public int CPC_DIGIT_7 = 7;\n");
	classifier.write("@Constant\n");
	classifier.write("public int CPC_DIGIT_8 = 8;\n");
	classifier.write("@Constant\n");
	classifier.write("public int CPC_DIGIT_9 = 9;\n");
	classifier.write("public int codePointClass(int codePoint) {\n");
	classifier.write("    int match = intervalLast.binarySearchClosestGreater(codePoint);\n");
	classifier.write("    if (match >= 0 && match < intervalLast.length() && codePoint >= intervalFirst[match])\n");
	classifier.write("        return intervalClass[match];\n");
	classifier.write("    return CPC_ERROR;\n");
	classifier.write("}\n");
	classifier.write("private int[] intervalFirst, intervalLast;\n");
	classifier.write("private byte[] intervalClass;\n");
	for (int i = 0; i < intervals.length(); i++) {
		classifier.printf("intervalFirst.append(%d);\n", intervals[i].first);
		classifier.printf("intervalLast.append(%d);\n", intervals[i].last + 1);
		classifier.write("intervalClass.append(");
		switch (intervals[i].treatment) {
		case	LETTER:
			classifier.printf("255");
			break;
			
		case	WHITE_SPACE:
			classifier.printf("254");
			break;
			
		default:
			classifier.printf("%d", int(intervals[i].treatment));
		}
		classifier.write(");\n");
	}
	return true;
}
