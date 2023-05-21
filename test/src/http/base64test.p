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
import parasol:net.base64encode;
import parasol:net.base64decode;

byte[] example1 = [ 0xb3, 0x7a, 0x4f, 0x2c, 0xc0, 0x62, 0x4f, 0x16, 0x90, 0xf6, 0x46, 0x06, 0xcf, 0x38, 0x59, 0x45, 0xb2, 0xbe, 0xc4, 0xea ];

printf("Calling\n");
string encoded = base64encode(example1);

printf("encoded = '%s'\n", encoded);
assert(encoded == "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=");

byte[] decoded = base64decode(encoded);

assert(example1.length() == decoded.length());

for (int i = 0; i < decoded.length(); i++) {
	printf("[%d] 0x%02x : 0x%02x\n", i, example1[i], decoded[i]);
	assert(example1[i] == decoded[i]);
}

