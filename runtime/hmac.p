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
/**
 * A collection of convenience functions that allow for easy computation of cryptographic
 * functions.
 *
 * Currently, only SHA256 is defined.
 *
 * The openssl.org libcrypto library is used as the actual implementation of the cryptogrpahic
 * functions.
 */
namespace parasol:crypto;

import parasol:text;
import openssl.org:crypto;
/**
 * A simple SHA256 hash. This maps an input string to a (binary) SHA256 digest.
 *
 * @param input The input string to be hashed. This string may be binary data, ASCII or UTF-8.
 * @return the SHA256 hash of the input string.
 */
public string SHA256(string input) {
	string hash;
	hash.resize(crypto.SHA256_DIGEST_LENGTH);
	crypto.SHA256(&input[0], input.length(), &hash[0]);
	return hash;
}
/**
 * A SHA256 hash computed from a reader. This maps an input stream to a (binary) SHA256 digest.
 *
 * The stream is positioned at the end-of-stream on conclusion of this function.
 *
 * @param input The input Reader to be hashed. This Reader may return binary data, ASCII or UTF-8.
 * @return the SHA256 hash of the input stream.
 */
public string SHA256(ref<Reader> input) {
	crypto.SHA256_CTX ctx;
	byte[] buffer;
	buffer.resize(8192);

	crypto.SHA256_Init(&ctx);
	for (;;) {
		int actual = input.read(&buffer);
		if (actual <= 0)
			break;
		crypto.SHA256_Update(&ctx, &buffer[0], actual);
	}
	string hash;
	hash.resize(crypto.SHA256_DIGEST_LENGTH);
	crypto.SHA256_Final(&hash[0], &ctx);
	return hash;
}
/**
 * Calculate an HMAC-SHA256 signature given a string-to-sign and a key.
 *
 * @param stringToSign The text to be included in the signature.
 * @param key The key string to use to create the signature.
 * @return The 32-byte signature.
 */
public string HMAC_SHA256(string key, string stringToSign) {
	string ipad;

	// If the key is longer than 64 bytes
	if (key.length() > 64)
		ipad = SHA256(key);
	else
		ipad = key;
	ipad.resize(64);

	string opad = ipad;

	for (int i = 0; i < 64; i++) {
		ipad[i] ^= 0x36;
		opad[i] ^= 0x5c;
//		printf("%2d i %2.2x o %2.2x\n", i, ipad[i], opad[i]);
	}
	return SHA256(opad + SHA256(ipad + stringToSign));
}

