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
namespace parasol:storage;

import parasol:compiler;					// TODO: Move Unicode code point class logic into it's own
											// namespace.
import parasol:exception.BoundsException;
import parasol:exception.IllegalOperationException;
import parasol:text;
/**
 * A Utility class to parse files that use the CSV format.
 *
 * The file parser used here is intended to be permissive. The CSV 'format'
 * encompasses a family of related formats that encode data in text files as
 * Comma Separated Values. Each line of the file corresponds to a row of data.
 * That data consists on 1 or more discrete values, each separated by a comma.
 *
 * Where CSV formats vary is in how characters are escaped or quoted.
 */
public class CsvFile {
	private string[] _header;
	private string[][] _records;
	private int[string] _headerMap;
	/**
	 * If not null, specifies the separator sequence that separates fields. If
	 * null, the parse behaves as if this field contained a comma character.
	 *
	 * Defaults to null.
	 */
	public string separator;
	/**
	 * If not null, specifiees the quoting string that must precede or follow any
	 * quoted string value. If null, the parse behaves as if this field were the double-
	 * quote character.
	 *
	 * Defaults to null.
	 */
	public string quote;
	/**
	 * If true, the first line of the file is parsed as a header record and is not included
	 * in the data.
	 *
	 * Including a header allows using the {@link fetch} method that uses a string field name
	 * variation of the method.
	 *
	 * Defaults to false.
	 */
	public boolean includesHeader;
	/**
	 * If true, quoted fields can contain line separators.
	 *
	 * Defaults to true.
	 */
	public boolean quotesLineSeparators;
	/**
	 * If true, white space around fields are removed. THis also allows
	 * white space around the outside of quoted fields.
	 *
	 * Defaults to true.
	 */
	public boolean trimFields;
	/**
	 * Creates a .csv file reader from the file at the given path.
	 *
	 * @param path The local filesystem path of the .csv file.
	 */
	public CsvFile() {
		quotesLineSeparators = true;
		trimFields = true;
	}
	/**
	 * reads and parses the file into records.
	 *
	 * @return true if the file could be read, false
	 * if the file did not exist or otherwise could not be read, or if it
	 * could be read, but contained malformed data. 
	 *
	 * If a file has {@link includesHeader} set, but there are no lines of text
	 * in the file, this function return false.
	 */
	public boolean load(string path) {
		ref<Reader> reader = openTextFile(path);

		if (reader == null)
			return false;
		boolean result;
		ref<text.Decoder> decoder = new text.UTF8Decoder(reader);
		result = load(decoder);
		delete decoder;
		delete reader;
		return result;
	}
		
	private int[] _separator;
	private int[] _quote;

	public boolean load(ref<text.Decoder> decoder) {
		if (separator != null) {
			text.UTF8Decoder d(&separator[0], separator.length());

			for (;;) {
				int c = d.decodeNext();

				if (c < 0)
					break;
				_separator.append(c);
			}
		} else
			_separator.append(',');
//		printf("separator '%s' %d tokens\n", separator, _separator.length());
		if (quote != null) {
			text.UTF8Decoder d(&quote[0], quote.length());

			for (;;) {
				int c = d.decodeNext();

				if (c < 0)
					break;
				_quote.append(c);
			}
		} else
			_quote.append('"');
//		printf("quote '%s' %d tokens\n", quote, _quote.length());
		if (includesHeader) {
			if (!parseLine(-1, decoder, &_header))
				return false;

			if (_header.length() == 0)
				return false;
			for (i in _header)
				if (!_headerMap.contains(_header[i]))
					_headerMap[_header[i]] = i;
		}
//		printf("header map %d items\n", _headerMap.size());
		int record = 0;
		for (;;) {
			_records.resize(record + 1);
			if (!parseLine(record, decoder, &_records[record])) {
				_records.resize(record);
				break;
			}
			if (_records[record].length() > 0)
				record++;
		}
		return true;
	}

	private boolean parseLine(int record, ref<text.Decoder> decoder, ref<string[]> parsed) {
		enum ParseState {
			START_OF_FIELD,
			IN_FIELD,
			IN_QUOTES,
			AFTER_QUOTES,
		}

		int field = 0;
		int sepIdx = 0;
		int quoIdx = 0;
		int quoStart;
		int sepStart;
		ParseState state;
		string value = "";
		for (;;) {
			int c = decoder.decodeNext();
/*
			printf("field = %d c = %d", field, c);
			if (c >= 0)
				printf(" (%c)", c);
			printf("\n");
 */
			if (c < 0) {
				switch (state) {
				case START_OF_FIELD:
					if (field == 0)
						return false;
					break;

				default:
					if (trimFields)
						value = value.trim();
					parsed.append(value);
				}
				return true;
			}
			if (c == '\n') {
				switch (state) {
				case IN_QUOTES:
					if (quotesLineSeparators)
						value.append(c);
					else {
						if (record < 0)
							throw IllegalOperationException("header field " + field);
						else
							throw IllegalOperationException("record " + record + " field " + field);
					}
					break;

				default:
					if (trimFields)
						value = value.trim();
					parsed.append(value);
					return true;
				}
				continue;
			}
			int cpc = compiler.codePointClass(c);
			switch (state) {
			case START_OF_FIELD:
				if (trimFields && cpc == compiler.CPC_WHITE_SPACE)
					break;

			default:
				int lastLength = value.length();
				value.append(c);
				for (;;) {
					if (_quote[quoIdx] == c) {
						if (quoIdx == 0)
							quoStart = lastLength;
						quoIdx++;
						if (quoIdx >= _quote.length()) {		// we have a match on the _quote string.
							value.resize(quoStart);
							sepIdx = 0;
							switch (state) {
							case START_OF_FIELD:
								state = ParseState.IN_QUOTES;
								break;

							case IN_QUOTES:
								state = ParseState.AFTER_QUOTES;
								break;

							default:
								throw IllegalOperationException("record " + record + " field " + field);
							}
							quoIdx = 0;
							break;
						}
					} else {
						// We have a miss. Now resync and prepare to try again
						if (quoIdx > 0) {
							int newQuoIdx = -1;
							for (int k = 1; k < quoIdx; k++) {
								boolean success = true;
								for (int i = 0; i < quoIdx - k; i++)
									if (_quote[i] != _quote[i + k]) {
										success = false;
										break;
									}
								if (success) {
									newQuoIdx = quoIdx - k;
									break;
								}
							}
							if (newQuoIdx > 0)
								quoIdx = newQuoIdx;
							else
								quoIdx = 0;
						} else
							break;
					}
				}
				if (state != ParseState.IN_QUOTES) {
					for (;;) {
						if (_separator[sepIdx] == c) {
							if (sepIdx == 0)
								sepStart = lastLength;
							sepIdx++;
							if (sepIdx >= _separator.length()) {	// we have a match on the _separator string.
								value.resize(sepStart);
								if (trimFields)
									value = value.trim();
								parsed.append(value);
								value = "";
								sepIdx = 0;
								quoIdx = 0;
								field++;
								state = ParseState.START_OF_FIELD;
								break;
							}
						} else {
							// We have a miss. Now resync and prepare to try again
							if (sepIdx > 0) {
								int newSepIdx = -1;
								for (int k = 1; k < sepIdx; k++) {
									boolean success = true;
									for (int i = 0; i < sepIdx - k; i++)
										if (_separator[i] != _separator[i + k]) {
											success = false;
											break;
										}
									if (success) {
										newSepIdx = sepIdx - k;
										break;
									}
								}
								if (newSepIdx > 0)
									sepIdx = newSepIdx;
								else
									sepIdx = 0;
							} else
								break;
						}
					}
				}
			}
		}
		return true;
	}

	public double, boolean fetchDouble(int record, int field) {
		string s = fetch(record, field);
		return double.parse(s);
	}

	public double, boolean fetchDouble(int record, string field) {
		string s = fetch(record, field);
		return double.parse(s);
	}

	public long, boolean fetchLong(int record, int field) {
		string s = fetch(record, field);
		return long.parse(s);
	}

	public long, boolean fetchLong(int record, string field) {
		string s = fetch(record, field);
		return long.parse(s);
	}

	/**
	 * Fetch a field from the CSV file.
	 *
	 * @param record The 0-based index of the record to be retrieved.
	 * @param field The 0-based index of the field to be retrieved.
	 *
	 * @return The field value, or null if the record or field does not exist.
	 */
	public string fetch(int record, int field) {
		if (record < 0 || record >= _records.length())
			return null;
		if (field < 0 || field >= _records[record].length())
			return null;
		return _records[record][field];
	}
	/**
	 * Fetch a field from the CSV file.
	 *
	 * The field name must be one of the header field values.
	 * 
	 * @param record The 0-based index of the record to be retrieved.
	 * @param field The name of the field to be retrieved.
	 *
	 * @return The field value, or null if the record or field value does not exist.
	 *
	 * @exception BoundsException Thrown if the field name 
	 * is not in the header.(or there was no header).
	 */
	public string fetch(int record, string field) {
		if (record < 0 || record >= _records.length())
			return null;
		if (!_headerMap.contains(field))
			throw BoundsException("record " + record + " field " + field);
		int index = _headerMap[field];
		if (index >= _records[record].length())
			return null;
		return _records[record][index];
	}
	/**
	 * Fetch the number of records in the file.
	 *
	 * @return The number of parsed records.
	 */
	public int recordCount() {
		return _records.length();
	}
	/**
	 * Fetch the field count of the indicated record.
	 */
	public int fieldCount(int record) {
		if (record < 0 || record >= _records.length())
			throw BoundsException("record " + record);
		return _records[record].length();
	}
	/**
	 * Check whether a record contains a named field
	 */
	public boolean contains(int record, string field) {
		if (record < 0 || record >= _records.length())
			throw BoundsException("record " + record);
		if (!_headerMap.contains(field))
			throw BoundsException("record " + record + " field " + field);
		int index = _headerMap[field];
		return index < _records[record].length();
	}
}
