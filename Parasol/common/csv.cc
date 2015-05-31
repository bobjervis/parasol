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
#include "csv.h"

static const char* parseItem(const char* cp, string* output);

bool parseCsv(const string& data, vector<vector<string> >* output) {
	const char* cp = data.c_str();

	for (int i = 0; *cp; i++) {
		output->resize(i + 1);
		vector<string>* row = &(*output)[i];
		for (int j = 0; *cp; j++) {
			string item;

			cp = parseItem(cp, &item);
			if (cp == null)
				return false;

			row->push_back(item);
			if (*cp == ',')
				cp++;
			if (*cp == '\n')
				break;
		}
		if (*cp)
			cp++;
	}
	return true;
}

static const char* parseItem(const char* cp, string* output) {
	if (*cp == '"') {
		cp++;
		while (*cp) {
			if (*cp == '"') {
				if (cp[1] == '"') {
					output->push_back(*cp);
					cp += 2;
				} else {
					cp++;
					if (*cp == 0 || *cp == ',' || *cp == '\n')
						return cp;
					else
						return null;
				}
			} else {
				output->push_back(*cp);
				cp++;
			}
		}
	} else {
		while (*cp && *cp != ',' && *cp != '\n') {
			output->push_back(*cp);
			cp++;
		}
		return cp;
	}
	return null;
}
