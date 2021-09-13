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

import native:linux;
import parasol:http;
import parasol:log;
import parasol:net;
import parasol:process;
import parasol:rpc;
import parasol:thread;

linux.pid_t childProcessID;
http.Server server;
char port;

server.httpService("/http", &httpExchange);
//server.httpService("/ws", &fullDuplex);
server.disableHttps();
server.setHttpPort(port);		// if port == 0, a random port number will be assigned.

server.start();

port = server.httpPort();

HttpExchange httpExchange;

interface Test {
	boolean simple(int argument);
}

{							// Test 1: Simple HTTP request and response
	string url = "http://192.168.1.2:" + port + "/http";
	rpc.Client<Test> client(url);

	// Manufacture the proxy object.

	Test t = client.proxy();

	boolean result = t.simple(6);
	assert(result);
	result = t.simple(12);
	assert(!result);

	// When done, delete the proxy.

	delete t;
}
/*
{
	http.Client client("http://localhost:" + port + "/ws");
	assert(client.get() == http.ConnectStatus.OK);
	ref<http.WebSocket> webSocket = client.webSocket();
	assert(webSocket != null);
	rpc.Reader<WSUpstream, WSDownstream> reader(webSocket);
}
 */
server.stop();

class HttpExchange extends rpc.Service<Test> implements Test {
	HttpExchange() {
		super(this);
	}

	boolean simple(int argument) {
		printf("In server simple\n");
		return argument < 10;
	}	
}

