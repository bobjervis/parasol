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

@Constant
public int MD5_DIGEST_LENGTH = 16;
/**
 * hashData points to an array of 20 bytes that is the output of the algorithm.
 */
@Linux("libcrypto.so.10", "SHA1")
public abstract pointer<byte> SHA1(pointer<byte> data, long nBytes, pointer<byte> hashData);
