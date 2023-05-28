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
 * This is a cryptographic library used to generate various hash functions.
 *
 * This is the base library used by the {@link parasol:crypto} namespace. These bindings
 * are low-level and use exclusively the C argument and return types of the native functions.
 * Refer to {@link parasol:crypto} for more Parasol-friendly wrappers.
 *
 * Note: There are many more functions in libcrypto than currently appear in this binding. The
 * various hash functions supported by the library use a pattern of names and function like those
 * defined for MD5 or SHA256. The most difficult part is defining the xxx_CTX structures the libcrypto
 * library uses. These structures are not publicly documented and must be derived from the C header
 * files distributed with the library. While there are unlikely to be changes to these structures
 * (the implemented hash functions do not change their algorithms), one should consult the particular
 * release of the library being used and ensure that the classes match the underlying library..
 *
 * Please refer to the documentation at https://www.openssl.org/docs/ for information
 * on how to use this library. While this binding has been used and tested in the Parasol
 * runtime, not all methods and certainly not all combinations of methods and arguments have been
 * tested. The most likely source of such errors are mistakes in the function argument types or
 * return types.
 */
namespace openssl.org:crypto;
/**
 * hashData points to an array of 16 bytes that is the output of the algorithm.
 */
@Linux("libcrypto.so.10", "MD5")
public abstract pointer<byte> MD5(pointer<byte> data, long nBytes, pointer<byte> hashData);

@Linux("libcrypto.so.10", "MD5_Init")
public abstract pointer<byte> MD5_Init(ref<MD5_CTX> c);

@Linux("libcrypto.so.10", "MD5_Update")
public abstract pointer<byte> MD5_Update(ref<MD5_CTX> c, pointer<byte> data, long nBytes);

@Linux("libcrypto.so.10", "MD5_Final")
public abstract pointer<byte> MD5_Final(pointer<byte> hashData, ref<MD5_CTX> c);

public class MD5_CTX {
    unsigned A, B, C, D;
    unsigned Nl, Nh;
    unsigned data1, data2, data3, data4, data5, data6, data7, data8, data9, data10, data11, data12, data13, data14, data15, data16;
    unsigned num;
}
/**
 * The length of the hashData argument and return values of the MD5 functions.
 */
@Constant
public int MD5_DIGEST_LENGTH = 16;
/**
 * hashData points to an array of 32 bytes that is the output of the algorithm.
 */
@Linux("libcrypto.so.10", "SHA1")
public abstract pointer<byte> SHA1(pointer<byte> data, long nBytes, pointer<byte> hashData);

@Linux("libcrypto.so.10", "SHA256")
public abstract pointer<byte> SHA256(pointer<byte> data, long nBytes, pointer<byte> hashData);

@Linux("libcrypto.so.10", "SHA256_Init")
public abstract pointer<byte> SHA256_Init(ref<SHA256_CTX> c);

@Linux("libcrypto.so.10", "SHA256_Update")
public abstract pointer<byte> SHA256_Update(ref<SHA256_CTX> c, pointer<byte> data, long nBytes);

@Linux("libcrypto.so.10", "SHA256_Final")
public abstract pointer<byte> SHA256_Final(pointer<byte> hashData, ref<SHA256_CTX> c);

public class SHA256_CTX {
    unsigned h0, h1, h2, h3, h4, h5, h6, h7, h8;
    unsigned Nl, Nh;
    unsigned data1, data2, data3, data4, data5, data6, data7, data8, data9, data10, data11, data12, data13, data14, data15, data16;
    unsigned num, md_len;
}
/**
 * The length of the hashData argument and return values of the SHA256 functions.
 */
@Constant
public int SHA256_DIGEST_LENGTH = 32;

