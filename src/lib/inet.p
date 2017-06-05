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
namespace parasol:net;
/**
 * Based on RFC 4648, performa a base-64 encoding of the byte array
 */
public string base64encode(byte[] data) {
	return base64encode(&data[0], data.length());
}

public string base64encode(pointer<byte> data, long length) {
	string result;
	
	while (length > 0) {
		printf("result='%s'\n", result);
		int triplet;
		int digits;
		switch (length) {
		default:
			triplet = (data[0] << 16) + (data[1] << 8) + data[2];
			digits = 4;
			break;
			
		case 2:
			triplet = (data[0] << 16) + (data[1] << 8);
			digits = 3;
			break;
			
		case 1:
			triplet = data[0] << 16;
			digits = 2;
			break;
		}
		result.append(encoding[triplet >> 18]);
		result.append(encoding[(triplet >> 12) & 0x3f]);
		if (digits > 2) {
			result.append(encoding[(triplet >> 6) & 0x3f]);
			if (digits > 3)
				result.append(encoding[triplet & 0x3f]);
			else
				result.append("=");
		} else
			result.append("==");
		length -= 3;
		data += 3;
	}
	return result;
}

private string encoding = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
