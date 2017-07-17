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
namespace openssl.org:crypto;
/**
 * hashData points to an array of 16 bytes that is the output of the algorithm.
 */
@Linux("libcrypto.so.1.0.0", "MD5")
public abstract pointer<byte> MD5(pointer<byte> data, long nBytes, pointer<byte> hashData);
/**
 * hashData points to an array of 20 bytes that is the output of the algorithm.
 */
@Linux("libcrypto.so.1.0.0", "SHA1")
public abstract pointer<byte> SHA1(pointer<byte> data, long nBytes, pointer<byte> hashData);
