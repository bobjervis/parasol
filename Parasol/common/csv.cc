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
