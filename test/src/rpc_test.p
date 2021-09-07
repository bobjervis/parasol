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
import parasol:net;
import parasol:process;
import parasol:rpc;

linux.pid_t childProcessID;
http.Server server;
char port;

server.httpService("/http", &httpExchange);
//server.httpService("/ws", &fullDuplex);
server.disableHttps();
server.setHttpPort(port);		// if port == 0, a random port number will be assigned.

server.start(net.ServerScope.LOCALHOST);

port = server.httpPort();

interface Test {
	boolean simple(int argument);
}

int main(string[] args) {
	childProcessID = linux.fork();
	int result;

	if (childProcessID == 0) {		// This is the child process.
		server.stop();
		{							// Test 1: Simple HTTP request and response
			rpc.Client<Test> client("http://localhost:" + port + "/http");

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
		process.exit(0);
	} else {						// This is the parent process.
	
		int exitStatus;
	
		linux.waitpid(childProcessID, &exitStatus, 0);
	
		if (exitStatus != 0) {
			printf("Child process ended with exit code %d\n", exitStatus);
			result = 1;
		}
	}
	server.stop();
	if (result != 0)
		printf("*** FAIL ***\n");
	return result;
}

class HttpExchange extends rpc.Service<Test> implements Test {
	HttpExchange() {
		super(this);
	}

	boolean simple(int argument) {
		return argument < 10;
	}	
}

HttpExchange httpExchange;

