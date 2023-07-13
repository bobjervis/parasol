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
import parasol:exception.IOException;
import parasol:http;
import parasol:log;
import parasol:net;
import parasol:process;
import parasol:rpc;
import parasol:runtime;
import parasol:thread;
import parasol:time;

private ref<log.Logger> logger = log.getLogger("parasol.rpc_test");

time.Formatter formatter("yyyy/MM/dd HH:mm:ss.SSS");

class TestLogHandler extends log.LogHandler {
	public void processEvent(ref<log.LogEvent> logEvent) {
		time.Date d(logEvent.when, &time.UTC);
		string logTime = formatter.format(&d);				// Note: if the format includes locale-specific stuff,
															// like a named time zone or month, we would have to add
															// some arguments to the format call.
		printf("%s %s %s\n", logTime, label(logEvent.level), logEvent.msg);
		process.stdout.flush();
	}
}

TestLogHandler tlh;
log.getLogger("http.client").configure(log.INFO, &tlh, false);

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
	boolean hang();				// intentionally pauses indefinitely.
}

class ServerWorkFactory extends rpc.WebSocketFactory<WSUpstream, WSDownstream> {
	public boolean notifyCreation(ref<http.Request> request, 
								  ref<rpc.WebSocket<WSUpstream, WSDownstream>> socket) {
		ref<ServerWork> s = new ServerWork(socket);
		socket.setObject(s);
		socket.onDisconnect(s);
		return true;
	}
}

boolean upstreamDisconnect;
boolean downstreamDisconnect;

class ServerWork implements WSUpstream, http.DisconnectListener {
	ref<rpc.WebSocket<WSUpstream, WSDownstream>> socket;

	ServerWork(ref<rpc.WebSocket<WSUpstream, WSDownstream>> socket) {
		this.socket = socket;
	}

	boolean upload(int x) {
		logger.debug("upload(%d)", x);
		socket.proxy().download(x + 1);
		thread.sleep(1);
		if (x > 10)
			return false;
		return true;
	}

	boolean hang() {
		Monitor m;

		// Start a socket shutdown, then wait for nothing.
		socket.shutDown(555, "just because");
		m.wait();
		return true;
	}

	void disconnect(boolean normalClose) {
		logger.debug("upstream disconnect, normal close? %s", string(normalClose));
		upstreamDisconnect = true;
	}
}

interface WSDownstream {
	boolean download(int x);
}

class ClientWork implements WSDownstream, http.DisconnectListener {
	static int testMessageCount;
	static int[] values = [ 4, 1601, 1000001 ];

	boolean download(int x) {
		logger.debug("download(%d)", x);
		assert(x == values[testMessageCount]);
		testMessageCount++;
		logger.debug("Download returning");
		return true;
	}

	void disconnect(boolean normalClose) {
		logger.debug("downstream disconnect");
		downstreamDisconnect = true;
	}
}

{							// Test 1: Simple HTTP request and response
	string url = "http://localhost:" + port + "/http";
	rpc.Client<Test> client(url);
	client.logTo("http.client");

	// Manufacture the proxy object.

	Test t = client.proxy();

	boolean result = t.simple(6);
	assert(result);
	result = t.simple(12);
	assert(!result);

	// When done, delete the proxy.

	delete t;
}

{	// first, a 'correct' session, with completed messages and a graceful shutdown.
	ClientWork down();
	rpc.Client<WSUpstream, WSDownstream> client("ws://localhost:" + port + "/ws", "Test", down);
	client.onDisconnect(down);
	assert(client.connect() == http.ConnectStatus.OK);
	WSUpstream up = client.proxy();

	logger.debug("Start calling up");
	assert(up.upload(3));
	assert(!up.upload(1600));
	assert(!up.upload(1000000));

	logger.debug("message count %d", down.testMessageCount);
	assert(down.testMessageCount == 3);

	// The normal shutdown sequence

	client.shutdown();
}
assert(downstreamDisconnect);
server.stop();
assert(upstreamDisconnect);
logger.debug("First web socket test complete");
server.start(net.ServerScope.LOCALHOST);

port = server.httpPort();

{	// now, a session where the client issues a 'long duration' call.
	ClientWork down();
	rpc.Client<WSUpstream, WSDownstream> client("ws://localhost:" + port + "/ws", "Test", down);
	client.onDisconnect(down);
	http.ConnectStatus status = client.connect();
	logger.debug("status = %s", string(status));
	assert(status == http.ConnectStatus.OK);
	WSUpstream up = client.proxy();

	try {
		up.hang();
		printf("Hang returned? Not supposed to be possible.\n");
		assert(false);
	} catch (IOException e) {
		assert(e.message() == "Connection closed before reply");
	}
	printf("PASS: Dropped connection caused RPC caller to receive an Exception.\n");
}

server.stop();
logger.debug("Second web  socket test complete");

class HttpExchange extends rpc.Service<Test> implements Test {
	HttpExchange() {
		super(this);
	}

	boolean simple(int argument) {
		logger.debug("In server simple");
		return argument < 10;
	}	
}

logger.debug("SUCCESS!!!");
