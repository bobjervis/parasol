/*
   Copyright 2015 Rovert Jervis

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

import native:windows.GetFullPathName;

public int FILENAME_MAX = 260;

public class FileSystem {
}

string absolutePath(string filename) {
	string buffer;
	buffer.resize(256);
	unsigned len = GetFullPathName(filename.c_str(), unsigned(buffer.length()), buffer.c_str(), null);
	if (len == 0)
		return string();
	if (len >= unsigned(buffer.length())) {
		buffer.resize(int(len));
		GetFullPathName(filename.c_str(), unsigned(len + 1), buffer.c_str(), null);
	} else
		buffer.resize(int(len));
	return buffer.toLower();
}

public string basename(string filename) {
	for (int x = filename.length() - 1; x >= 0; x--)
		if (filename[x] == '\\' || filename[x] == '/')
			return filename.substring(x + 1);
	return filename;
}

public string constructPath(string directory, string baseName, string extension) {
	string base;
	if (directory.length() > 0) {
		byte c = directory[directory.length() - 1];
		if (c == ':' || c == '\\' || c == '/')
			base = directory + baseName;
		else
			base = directory + "/" + baseName;
	} else
		base = baseName;
	if (extension.length() > 0) {
		string b = basename(base);
		int i = b.lastIndexOf('.');
		if (i != -1) {
			int extSize = b.length() - i;
			base.resize(base.length() - extSize);
		}
		if (extension[0] != '.')
			base = base + ".";
		base = base + extension;
	}
	return base;
}

public string directory(string filename) {
	for (int x = filename.length() - 1; x >= 0; x--) {
		if (filename[x] == '\\' || filename[x] == '/') {
			if (x == 0)
				return "/";
			else
				return filename.substring(0, x);
		}
	}
	return ".";
}


