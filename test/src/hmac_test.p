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
import parasol:crypto.SHA256;
import parasol:crypto.HMAC_SHA256;
string digest = SHA256("abcdef");
assert(digest == "\xbe\xf5\x7e\xc7\xf5\x3a\x6d\x40\xbe\xb6\x40\xa7\x80\xa6\x39\xc8\x3b\xc2\x9a\xc8\xa9\x81\x6f\x1f\xc6\xc5\xc6\xdc\xd9\x3c\x47\x21");
digest = HMAC_SHA256("", "");
printf("case 0 HMAC_SHA256 = ");
for (int i = 0; i < digest.length(); i++)
	printf("%2.2x", digest[i]);
printf("\n");
digest = HMAC_SHA256("ABCD", "xyz");
printf("case 1 HMAC_SHA256 = ");
for (int i = 0; i < digest.length(); i++)
	printf("%2.2x", digest[i]);
printf("\n");
assert(HMAC_SHA256("ABCD", "xyz") == 
			"\xbe\x2c\xee\xc2\xe3\xf1\xe5\x9b\xb9\x46\xd5\xe9\x22\xbf\x8a\x79" + 
			"\xc9\xdb\x25\xea\xd4\xf0\x58\x7e\xaf\x6f\xd5\xc4\x26\x78\xbb\x64");
assert(HMAC_SHA256("gwendolyn", 
						"Computes a Hash-based message authentication code (HMAC) using a secret key. " + 
							"A HMAC is a small set of data that helps authenticate the nature of messa" + 
							"ge; it protects the integrity and the authenticity of the message.") == 
			"\x65\x12\xdf\x6d\xee\xed\xf0\x3c\x62\x07\x04\x40\xf2\xd9\x57\x52" +
			"\x4d\x08\x36\x13\xed\xef\x8b\x28\x2b\x5d\x7f\x36\x9a\xf3\x85\xee");
assert(HMAC_SHA256("a123456789b123456789c123456789d123456789e123456789f123456789g123456789", "xyz") == 
			"\x03\x1b\xbe\xd6\xbf\x35\xae\x1c\xc4\xc8\x47\x9f\x33\x54\x3b\x96" +
			"\x7e\xa4\xf9\x9f\x9d\x4f\xca\x24\xad\x74\x35\x2c\xe5\x5c\x99\x01");

