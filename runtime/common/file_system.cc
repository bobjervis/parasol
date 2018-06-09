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
#include "../common/platform.h"
#include "file_system.h"

#ifdef MSVC
#include <typeinfo.h>
#else
#include <typeinfo>
#endif
#if defined(__WIN64)
#include <io.h>
#elif __linux__
#include <stddef.h>
#include <stdlib.h>
#include <limits.h>
#include <unistd.h>
#include <sys/stat.h>
#endif
#include "machine.h"

namespace fileSystem {

FILE* openBinaryFile(const string& filename) {
	return fopen(filename.c_str(), "rb");
}

string directory(const string& filename) {
	for (int x = filename.size() - 1; x >= 0; x--) {
		if (filename[x] == '\\' || filename[x] == '/') {
			if (x == 0)
				return "/";
			else
				return filename.substr(0, x);
		}
	}
	return ".";
}

string basename(const string& filename) {
	for (int x = filename.size() - 1; x >= 0; x--)
		if (filename[x] == '\\' || filename[x] == '/')
			return filename.substr(x + 1);
	return filename;
}

string constructPath(const string& directory, const string& baseName, const string& extension) {
	string base;
	if (directory.size()) {
		char c = directory[directory.size() - 1];
		if (c == ':' || c == '\\' || c == '/')
			base = directory + baseName;
		else
			base = directory + "/" + baseName;
	} else
		base = baseName;
	if (extension.size()) {
		string b = basename(base);
		int i = b.rfind('.');
		if (i != string::npos) {
			int extSize = b.size() - i;
			base.resize(base.size() - extSize);
		}
		if (extension[0] != '.')
			base = base + ".";
		base = base + extension;
	}
	return base;
}

}
