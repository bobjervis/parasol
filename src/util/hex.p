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
import parasol:text;

int main(string[] args) {
	for (int i = 0; i < args.length(); i++) {
		string filename = args[i];
		ref<Reader> f = storage.openBinaryFile(filename);
		string content;
		content = f.readAll();
		delete f;
		if (content != null) {
			printf("%s:\n", filename);
			text.memDump(&content[0], content.length(), 0);
		} else
			printf("Could not read %s\n", filename);
	}
	return 0;
}

