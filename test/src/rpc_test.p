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
import parasol:process;
import parasol:rpc;
import parasol:runtime;
import parasol:thread;


private ref<log.Logger> logger = log.getLogger("parasol.rpc_test");

http.Server server;
char port;

server.disableHttps();
server.setHttpPort(port);		// if port == 0, a random port number will be assigned.

server.start(net.ServerScope.LOCALHOST);

port = server.httpPort();

HttpExchange httpExchange;
http.WebSocketService fullDuplex;
fullDuplex.webSocketProtocol("Test", new ServerWorkFactory());

server.httpService("/http", &httpExchange);
server.httpService("/ws", &fullDuplex);

interface Test {
	boolean simple(int argument);
}

interface WSUpstream {
	boolean upload(int x);
}

class ServerWorkFactory extends rpc.WebSocketFactory<WSUpstream, WSDownstream> {
	public boolean notifyCreation(ref<http.Request> request, ref<rpc.WebSocket<WSUpstream, WSDownstream>> socket) {
		ref<ServerWork> s = new ServerWork();
		socket.onDisconnect(ServerWork.disconnectWrapper, s);
		s.down = socket.configure(s);
		return true;
	}
}

boolean upstreamDisconnect;
boolean downstreamDisconnect;

class ServerWork implements WSUpstream {
	WSDownstream down;

	boolean upload(int x) {
		logger.debug("upload(%d)", x);
		down.download(x + 1);
		if (x > 10)
			return false;
		return true;
	}

	static void disconnectWrapper(address arg, boolean normalClose) {
		ref<ServerWork>(arg).disconnect(normalClose);
	}

	void disconnect(boolean normalClose) {
		logger.debug("upstream disconnect");
		upstreamDisconnect = true;
		delete this;
	}
}

interface WSDownstream {
	boolean download(int x);
}

class ClientWork implements WSDownstream {
	ref<rpc.Client<WSUpstream, WSDownstream>> _client;
	static int testMessageCount;
	static int[] values = [ 4, 1601, 1000001 ];

	ClientWork(ref<rpc.Client<WSUpstream, WSDownstream>> client) {
		_client = client;
	}

	boolean download(int x) {
		assert(x == values[testMessageCount]);
		testMessageCount++;
		return true;
	}

	static void disconnectWrapper(address arg, boolean normalClose) {
		ref<ClientWork>(arg).disconnect(normalClose);
	}

	void disconnect(boolean normalClose) {
		logger.debug("downstream disconnect\n");
		downstreamDisconnect = true;
	}
}

{							// Test 1: Simple HTTP request and response
	string url = "http://localhost:" + port + "/http";
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

{
	rpc.Client<WSUpstream, WSDownstream> client("ws://localhost:" + port + "/ws", "Test");
	ClientWork down(&client);

	assert(client.connect() == http.ConnectStatus.OK);
	ref<rpc.WebSocket<WSUpstream, WSDownstream>> socket = client.socket();
	socket.onDisconnect(ClientWork.disconnectWrapper, &down);
	WSUpstream up = socket.configure(down);

	logger.debug("Start calling up");
	assert(up.upload(3));
	assert(!up.upload(1600));
	assert(!up.upload(1000000));

	printf("message count %d\n", down.testMessageCount);
	assert(down.testMessageCount == 3);
	socket.shutDown(http.WebSocket.CLOSE_NORMAL, "");
	socket.waitForDisconnect();
}
assert(downstreamDisconnect);
server.stop();
assert(upstreamDisconnect);

class HttpExchange extends rpc.Service<Test> implements Test {
	HttpExchange() {
		super(this);
	}

	boolean simple(int argument) {
		logger.debug("In server simple");
		return argument < 10;
	}	
}

