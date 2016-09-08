/*
   Copyright 2015 Rovert Jervis

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
namespace parasol:http;

import parasol:thread.ThreadPool;
import native:C.close;
import native:net.accept;
import native:net.AF_INET;
import native:net.bind;
import native:net.gethostbyname;
import native:net.hostent;
import native:net.htons;
import native:net.inet_addr;
import native:net.inet_ntoa;
import native:net.listen;
import native:net.SOCK_STREAM;
import native:net.sockaddr_in;
import native:net.socket;
import native:net.SOMAXCONN;
import native:net.WSADATA;
import native:net.WSAGetLastError;
import native:net.WSAStartup;
import native:windows.WORD;

public class HttpServer {
	private string _hostname;
	private char _port;
	private ref<ThreadPool<int>> _requestThreads;
	
	public HttpServer() {
		_hostname = "";
		_port = 80;
		_requestThreads = new ThreadPool<int>(4);
	}
	
	public boolean start() {
		WSADATA data;
		WORD version = 0x202;
		
		int result = WSAStartup(version, &data);
		if (result != 0) {
			// TODO: Make up an exception class for this error.
			printf("WSAStartup returned %d\n", result);
			assert(result == 0);
		}
		int socketfd = socket(AF_INET, SOCK_STREAM, 0);
		if (socketfd < 0) {
			printf("socket returned %d\n", socketfd);
			return false;
		}
		sockaddr_in s;
		
		ref<hostent> localHost = gethostbyname(&_hostname[0]);
		if (localHost == null) {
			printf("gethostbyname failed for '%s'\n", _hostname);
			return false;
		}
		pointer<byte> ip = inet_ntoa (*ref<unsigned>(*localHost.h_addr_list));
		string x(ip);
		string n(localHost.h_name);
//		printf("hostent name = '%s' ip = '%s'\n", n, x);
		s.sin_family = AF_INET;
		s.sin_addr.s_addr = inet_addr(ip);
		s.sin_port = htons(_port);
//		printf("s = { %d, %x, %x }\n", s.sin_family, s.sin_addr.s_addr, s.sin_port);
		if (bind(socketfd, &s, s.bytes) != 0) {
			printf("Binding failed!\n");
			close(socketfd);
			return false;
		}
		for (;;) {
			if (listen(socketfd, SOMAXCONN) != 0) {
				close(socketfd);
				return false;
			}
			sockaddr_in a;
			int addrlen = a.bytes;
			
//			printf("&a = %p a.bytes = %d\n", &a, a.bytes);
			// TODO: Develop a test fraemwork that allows us to test this scenario.
//			int acceptfd = accept(socketfd, &a, &addrlen);
//			printf("acceptfd = %d\n", acceptfd);
//			if (acceptfd < 0) {
//				close(socketfd);
//				return false;
//			}
			break;
		}
		
		return true;
	}
}
