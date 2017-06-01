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
import parasol:http.HttpRequest;
import parasol:http.HttpResponse;
import parasol:http.HttpServer;
import parasol:http.HttpService;

HttpServer server;

TestService service;

server.staticContent("/sim", "c:/SetsInMotion-Alpha-4/help");
server.service("/service", &service);

assert(server.start(ServerScope.LOCALHOST));

class TestService extends HttpService {
	
	public boolean processRequest(ref<HttpRequest> request, ref<HttpResponse> response) {
		printf("Test Service! fetching %s\n", request.serviceResource);
		if (request.method != HttpRequest.Method.POST) {
			response.error(405);
			return true;
		}
		long messageBodySize = request.contentLength();
		printf("Reading %d bytes more\n", messageBodySize);
		byte[] buffer;
		buffer.resize(int(messageBodySize));
		for (int i = 0; i < buffer.length(); i++) {
			buffer[i] = byte(request.getc());
		}
		text.memDump(&buffer[0], messageBodySize, 0);
		return false;
	}
}
