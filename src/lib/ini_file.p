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
/**
 * A Utility class to parse files that use the INI format.
 *
 * The file parser used here is intended to be permissive. It is also
 * intended solely for the purpose of parsing configuration files.
 */
public class IniFile {
	private string _path;
	private ref<Object>[string] _sections;

	public IniFile(string path) {
		_path = path;
	}

	~IniFile() {
		_sections.deleteAll();
	}

	public boolean load() {
		ref<Reader> reader = openTextFile(_path);
		ref<Object> currentSection;

		if (reader == null)
			return false;
		for (;;) {
			string line = reader.readLine();

			if (line == null)
				break;

			line = line.trim();

			// Allow blank lines.
			if (line.length() == 0)
				continue;

			// Recognize both semi-colon and hash mark comments, whole line only.
			if (line[0] == ';' || line[0] == '#')
				continue;

			if (line[0] == '[') {
				if (line.length() < 2 || line[line.length() - 1] != ']') {
					delete reader;
					return false;
				}
				string name = line.substring(1, line.length() - 1).trim();
				currentSection = _sections[name];
				if (currentSection == null) {
					currentSection = new Object();
					_sections[name] = currentSection;
				}
				continue;
			}

			if (currentSection == null) {
				delete reader;
				return false;
			}

			int eqPos = line.indexOf('=');
			if (eqPos < 0)
				currentSection.set(line, "");
			else
				currentSection.set(line.substring(0, eqPos).trim(), line.substring(eqPos + 1).trim());
		}
		delete reader;
		return true;
	}

	public ref<Object> section(string name) {
		return _sections[name];
	}
}
