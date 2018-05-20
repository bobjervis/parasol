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
import parasol:text.string16;
import parasol:storage;

int main(string[] args) {
	if (args.length() != 1) {
		printf("Use is: string16_test_1 <filename>\n");
		return 1;
	}
	string s;

	ref<Reader> r = storage.openBinaryFile(args[0]);
	s = r.readAll();
	delete r;

	string16 s2(s);
	string s3(s2);

	printf("s has %d octets s2 has %d char's and s3 has %d octets\n", s.length(), s2.length(), s3.length());
	assert(s == s3);
	return 0;
}
