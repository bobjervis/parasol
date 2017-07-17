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
public abstract int crypto_pwhash_scryptsalsa208sha256_str(pointer<byte> out, pointer<byte> passwd, long passwdlen, long opslimit, long memlimit);

@Linux("libsodium.so", "crypto_pwhash_scryptsalsa208sha256_str_verify")
public abstract int crypto_pwhash_scryptsalsa208sha256_str_verify(pointer<byte> str, pointer<byte> passwd, long passwdlen);

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
public unsigned crypto_pwhash_STRBYTES = 128;
@Constant
public unsigned crypto_pwhash_scryptsalsa208sha256_STRBYTES = 102;
