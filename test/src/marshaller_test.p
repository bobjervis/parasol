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
import parasol:http;
import parasol:log;
import parasol:net;
//import parasol:process;
import parasol:rpc;
//import parasol:thread;

private ref<log.Logger> logger = log.getLogger("parasol.marshaller_test");

http.Server server;
char port;

server.disableHttps();
server.setHttpPort(port);		// if port == 0, a random port number will be assigned.

server.start(net.ServerScope.LOCALHOST);

port = server.httpPort();

HttpExchange httpExchange;

server.httpService("/http", &httpExchange);

int[] echoInts = [ 0, 23, 457, 345621, int.MAX_VALUE, int.MIN_VALUE, -23, -457, -345621 ];

{							// Test 1: Simple HTTP request and response
	string url = "http://localhost:" + port + "/http";
	rpc.Client<Test> client(url);

	// Manufacture the proxy object.

	Test t = client.proxy();

	for (i in echoInts) {
		printf("About to call echo(%d, %d)\n", echoInts[i], i);
		int value = t.echo(echoInts[i], i);
		assert(value == echoInts[i]);
		printf(" ok\n");
	}

	// When done, delete the proxy.

	delete t;
}

interface Test {
	int echo(int x, int index);
}

server.stop();

class HttpExchange extends rpc.Service<Test> implements Test {
	HttpExchange() {
		super(this);
	}

	int echo(int argument, int index) {
		printf("In echo(%d, %d) ", argument, index);
		assert(argument == echoInts[index]);
		return argument;
	}
}
