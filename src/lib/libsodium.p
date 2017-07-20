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
namespace libsodium.org:crypto;

// Scrypt interface

/**
 * This function returns a verification string in the out buffer, which must be crypto_pwhash_scryptsalsa208sha256_STRBYTES long.
 */
@Linux("libsodium.so", "crypto_pwhash_scryptsalsa208sha256_str")
public abstract int crypto_pwhash_scryptsalsa208sha256_str(pointer<byte> out, 
					pointer<byte> passwd, long passwdlen, long opslimit, long memlimit);

@Linux("libsodium.so", "crypto_pwhash_scryptsalsa208sha256_str_verify")
public abstract int crypto_pwhash_scryptsalsa208sha256_str_verify(pointer<byte> str, 
					pointer<byte> passwd, long passwdlen);

@Constant
public long crypto_pwhash_scryptsalsa208sha256_OPSLIMIT_MIN = 32768;
@Constant
public long crypto_pwhash_scryptsalsa208sha256_OPSLIMIT_MAX = 4294967295;
@Constant
public long crypto_pwhash_scryptsalsa208sha256_OPSLIMIT_INTERACTIVE = 524288;
@Constant
public long crypto_pwhash_scryptsalsa208sha256_OPSLIMIT_SENSITIVE = 33554432;

@Constant
public long crypto_pwhash_scryptsalsa208sha256_MEMLIMIT_MIN = 16777216;
@Constant
public long crypto_pwhash_scryptsalsa208sha256_MEMLIMIT_MAX = 68719476736;		// too big for any 32 bit system
@Constant
public long crypto_pwhash_scryptsalsa208sha256_MEMLIMIT_INTERACTIVE = 16777216;
@Constant
public long crypto_pwhash_scryptsalsa208sha256_MEMLIMIT_SENSITIVE = 1073741824;

@Constant
public unsigned crypto_pwhash_scryptsalsa208sha256_STRBYTES = 102;

// Argon2 interface

/**
 * This function returns a verification string in the out buffer, which must be crypto_pwhash_STRBYTES long.
 */
@Linux("libsodium.so", "crypto_pwhash_str")
public abstract int crypto_pwhash_str(pointer<byte> out, pointer<byte> passwd, long passwdlen, long opslimit, long memlimit);

@Linux("libsodium.so", "crypto_pwhash_verify")
public abstract int crypto_pwhash_verify(pointer<byte> str, pointer<byte> passwd, long passwdlen);

@Linux("libsodium.so", "sodium_init")
public abstract int sodium_init();

@Constant
public long crypto_pwhash_OPSLIMIT_MIN = 3;
@Constant
public long crypto_pwhash_OPSLIMIT_MAX = 4294967295;
@Constant
public long crypto_pwhash_OPSLIMIT_INTERACTIVE = 4;
@Constant
public long crypto_pwhash_OPSLIMIT_MODERATE = 6;
@Constant
public long crypto_pwhash_OPSLIMIT_SENSITIVE = 8;

@Constant
public long crypto_pwhash_MEMLIMIT_MIN = 1;
@Constant
public long crypto_pwhash_MEMLIMIT_MAX = 4398046510080;		// too big for any 32 bit system
@Constant
public long crypto_pwhash_MEMLIMIT_INTERACTIVE = 33554432;
@Constant
public long crypto_pwhash_MEMLIMIT_MODERATE = 134217728;
@Constant
public long crypto_pwhash_MEMLIMIT_SENSITIVE = 536870912;

@Constant
public unsigned crypto_pwhash_STRBYTES = 128;
