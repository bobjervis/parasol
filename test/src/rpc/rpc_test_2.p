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
/*
 * The purpose of these tests is to verify that string text can be passed
 * as parameters and returned as well, even for strings that are several kilobytes long.
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
	string simple(string argument);
}

interface WSUpstream {
	string get(string query);
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

	string get(string query) {
		return "I got: " + query;
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
	boolean download(int x) {
		return x < 7;
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

	string result = t.simple("What do yyou wish?");
	assert(result == "I wish I could fly");

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
	assert(up.get("hiccups") == "I got: hiccups");
	string s;
	for (int i = 0; i < 1000; i++)
		s += "More goo ";
	assert(up.get(s) == "I got: " + s);

	delete up;
}
assert(downstreamDisconnect);
server.stop();
assert(upstreamDisconnect);

class HttpExchange extends rpc.Service<Test> implements Test {
	HttpExchange() {
		super(this);
	}

	string simple(string s) {
		return "I wish I could fly";
	}
}

logger.debug("SUCCESS!!!");

