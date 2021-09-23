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
import parasol:thread;

private ref<log.Logger> logger = log.getLogger("parasol.marshaller_test");

http.Server server;
char port;

server.disableHttps();
server.setHttpPort(port);		// if port == 0, a random port number will be assigned.

server.start(net.ServerScope.LOCALHOST);

port = server.httpPort();

HttpExchange httpExchange;

server.httpService("/http", &httpExchange);

boolean[] echoBools = [ false, true ];
short[] echoShorts = [ 0, 44, 903, short.MAX_VALUE, short.MIN_VALUE, short(-44), short(-903) ];
int[] echoInts = [ 0, 23, 457, 345621, int.MAX_VALUE, int.MIN_VALUE, -23, -457, -345621 ];
long[] echoLongs = [ 0, 27, 652, 712064, int.MAX_VALUE, long.MAX_VALUE, long.MIN_VALUE, int.MIN_VALUE, -712064, -652, -27 ];
byte[] echoBytes = [ 0, 15, 255 ];
char[] echoChars = [ 0, 19, 601, char.MAX_VALUE ];
unsigned[] echoUns = [ 0, 31, 801, 1546002994, unsigned.MAX_VALUE ];

string[] echoStrings = [ null, "", "abc", "usdggbafgao[gpoasg[poi5420q0 abop eopw	f kopk opwkckqw pwopkfkopqwe " ];

{							// Test 1: Simple HTTP request and response
	string url = "http://localhost:" + port + "/http";
	rpc.Client<Test> client(url);

	// Manufacture the proxy object.

	Test t = client.proxy();

	for (i in echoBools) {
		printf("boolean echo(%d, %d)", echoBools[i], i);
		boolean value = t.echo(echoBools[i], i);
		assert(value == echoBools[i]);
		printf(" ok\n");
	}
	for (i in echoShorts) {
		printf("short echo(%d, %d)", echoShorts[i], i);
		process.stdout.flush();
		short value = t.echo(echoShorts[i], i);
		assert(value == echoShorts[i]);
		printf(" ok\n");
	}
	for (i in echoInts) {
		printf("int echo(%d, %d)", echoInts[i], i);
		int value = t.echo(echoInts[i], i);
		assert(value == echoInts[i]);
		printf(" ok\n");
	}
	for (i in echoLongs) {
		printf("long echo(%d, %d)", echoLongs[i], i);
		long value = t.echo(echoLongs[i], i);
		assert(value == echoLongs[i]);
		printf(" ok\n");
	}
	for (i in echoBytes) {
		printf("byte echo(%d, %d)", echoBytes[i], i);
		byte value = t.echo(echoBytes[i], i);
		assert(value == echoBytes[i]);
		printf(" ok\n");
	}
	for (i in echoChars) {
		printf("char echo(%d, %d)", echoChars[i], i);
		char value = t.echo(echoChars[i], i);
		assert(value == echoChars[i]);
		printf(" ok\n");
	}
	for (i in echoUns) {
		printf("unsigned echo(%d, %d)", echoUns[i], i);
		long value = t.echo(echoUns[i], i);
		assert(value == echoUns[i]);
		printf(" ok\n");
	}
	for (i in echoStrings) {
		printf("string echo('%s', %d)", echoStrings[i], i);
		string value = t.echo(echoStrings[i], i);
		assert(value == echoStrings[i]);
		printf(" ok\n");
	}



	// When done, delete the proxy.

	delete t;
}

interface Test {
	boolean echo(boolean x, int index);
	short echo(short x, int index);
	int echo(int x, int index);
	long echo(long x, int index);
	byte echo(byte x, int index);
	char echo(char x, int index);
	unsigned echo(unsigned x, int index);
	string echo(string x, int index);
}

server.stop();

class HttpExchange extends rpc.Service<Test> implements Test {
	HttpExchange() {
		super(this);
	}

	boolean echo(boolean argument, int index) {
		assert(argument == echoBools[index]);
		return argument;
	}

	short echo(short argument, int index) {
//		logger.debug("in echo(%d, %d) testing against %d", argument, index, echoShorts[index]);
		assert(argument == echoShorts[index]);
		return argument;
	}

	int echo(int argument, int index) {
		assert(argument == echoInts[index]);
		return argument;
	}

	long echo(long argument, int index) {
		assert(argument == echoLongs[index]);
		return argument;
	}

	byte echo(byte argument, int index) {
		assert(argument == echoBytes[index]);
		return argument;
	}

	char echo(char argument, int index) {
		assert(argument == echoChars[index]);
		return argument;
	}

	unsigned echo(unsigned argument, int index) {
		assert(argument == echoUns[index]);
		return argument;
	}

	string echo(string argument, int index) {
		assert(argument == echoStrings[index]);
		return argument;
	}
}
