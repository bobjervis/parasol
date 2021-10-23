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
import parasol:text;
import parasol:time;
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

flags F8 {
	 F1,  F2,  F3,  F4,  F5,  F6,  F7,  F8
}

flags F16 {
	 F1,  F2,  F3,  F4,  F5,  F6,  F7,  F8,
	 F9, F10, F11, F12, F13, F14, F15, F16
}

flags F32 {
	 F1,  F2,  F3,  F4,  F5,  F6,  F7,  F8,
	 F9, F10, F11, F12, F13, F14, F15, F16,
	F17, F18, F19, F20, F21, F22, F23, F24,
	F25, F26, F27, F28, F29, F30, F31, F32
}

flags F64 {
	 F1,  F2,  F3,  F4,  F5,  F6,  F7,  F8,
	 F9, F10, F11, F12, F13, F14, F15, F16,
	F17, F18, F19, F20, F21, F22, F23, F24,
	F25, F26, F27, F28, F29, F30, F31, F32,
	F33, F34, F35, F36, F37, F38, F39, F40,
	F41, F42, F43, F44, F45, F46, F47, F48,
	F49, F50, F51, F52, F53, F54, F55, F56,
	F57, F58, F59, F60, F61, F62, F63, F64
}

F8[] echoF8 = [ F8.F1, F8.F4|F8.F7, F8.F8, F8.F1|F8.F2|F8.F3|F8.F4|F8.F5|F8.F6|F8.F7|F8.F8 ];
F16[] echoF16 = [ F16.F1, F16.F4|F16.F7, F16.F8, F16.F1|F16.F2|F16.F3|F16.F4|F16.F5|F16.F6|F16.F7|F16.F8,
					F16.F16, F16.F1|F16.F2|F16.F3|F16.F4|F16.F5|F16.F6|F16.F7|F16.F8|F16.F9|F16.F10|F16.F11|F16.F12|F16.F13|F16.F14|F16.F15|F16.F16 ];
F32[] echoF32 = [ F32.F1, F32.F4|F32.F7, F32.F16, F32.F1|F32.F2|F32.F3|F32.F4|F32.F5|F32.F6|F32.F7|F32.F8,
					F32.F32, F32.F1|F32.F2|F32.F3|F32.F4|F32.F5|F32.F6|F32.F7|F32.F8|F32.F9|F32.F10|F32.F11|F32.F12|F32.F13|F32.F14|F32.F15|F32.F16,
					F32.F1|F32.F8|F32.F9|F32.F16|F32.F17|F32.F32 ];
F64[] echoF64 = [ F64.F1, F64.F4|F64.F7, F64.F16, F64.F1|F64.F2|F64.F3|F64.F4|F64.F5|F64.F6|F64.F7|F64.F8,
					F64.F32, F64.F1|F64.F2|F64.F3|F64.F4|F64.F5|F64.F6|F64.F7|F64.F8|F64.F9|F64.F10|F64.F11|F64.F12|F64.F13|F64.F14|F64.F15|F64.F16,
					F64.F1|F64.F8|F64.F9|F64.F16|F64.F17|F64.F32, F64.F64,
					F64.F1|F64.F8|F64.F8|F64.F16|F64.F17|F64.F32|F64.F33|F64.F40|F64.F41|F64.F48|F64.F49|F64.F64 ];

enum EchoEnum {
	E_FIRST,
	E_OTHER,
	E_LAST
}

EchoEnum[] echoEnum = [ EchoEnum.E_OTHER, EchoEnum.E_LAST, EchoEnum.E_FIRST ];

time.Duration[] echoDur = [ 4.minutes(), 2.seconds(), 1.year(), time.Duration(543, 143754987), 3.weeks() ];

printf("Starting test sequences\n");
{							// Test 1: Simple HTTP request and response
	string url = "http://localhost:" + port + "/http";
	rpc.Client<Test> client(url);

	// Manufacture the proxy object.

	Test t = client.proxy();

	for (i in echoBools) {
		printf("boolean echo(%d, %d)", echoBools[i], i);
		process.stdout.flush();
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
		process.stdout.flush();
		int value = t.echo(echoInts[i], i);
		assert(value == echoInts[i]);
		printf(" ok\n");
	}
	for (i in echoLongs) {
		printf("long echo(%d, %d)", echoLongs[i], i);
		process.stdout.flush();
		long value = t.echo(echoLongs[i], i);
		assert(value == echoLongs[i]);
		printf(" ok\n");
	}
	for (i in echoBytes) {
		printf("byte echo(%d, %d)", echoBytes[i], i);
		process.stdout.flush();
		byte value = t.echo(echoBytes[i], i);
		assert(value == echoBytes[i]);
		printf(" ok\n");
	}
	for (i in echoChars) {
		printf("char echo(%d, %d)", echoChars[i], i);
		process.stdout.flush();
		char value = t.echo(echoChars[i], i);
		assert(value == echoChars[i]);
		printf(" ok\n");
	}
	for (i in echoUns) {
		printf("unsigned echo(%d, %d)", echoUns[i], i);
		process.stdout.flush();
		long value = t.echo(echoUns[i], i);
		assert(value == echoUns[i]);
		printf(" ok\n");
	}
	for (i in echoStrings) {
		printf("string echo('%s', %d)", echoStrings[i], i);
		process.stdout.flush();
		string value = t.echo(echoStrings[i], i);
		assert(value == echoStrings[i]);
		printf(" ok\n");
	}
	string[string] a;
	a["a"] = "bcd";
	a["e"] = "fgh";
	a["i"] = "jkl";

	printf("string[string] echo(a)");
	process.stdout.flush();
	boolean b = t.echo(a);

	assert(b);
//	assert(b["a"] == "bcd");
//	assert(b["e"] == "fgh");
//	assert(b["i"] == "jkl");
	printf(" ok\n");

	for (i in echoF8) {
		printf("F8 echo(%x, %d)", long(echoF8[i]), i);
		process.stdout.flush();
		F8 value = t.echo(echoF8[i], i);
		assert(value == echoF8[i]);
		printf(" ok\n");
	}
	for (i in echoF16) {
		printf("F16 echo(%x, %d)", long(echoF16[i]), i);
		process.stdout.flush();
		F16 value = t.echo(echoF16[i], i);
		assert(value == echoF16[i]);
		printf(" ok\n");
	}
	for (i in echoF32) {
		printf("F32 echo(%x, %d)", long(echoF32[i]), i);
		process.stdout.flush();
		F32 value = t.echo(echoF32[i], i);
		assert(value == echoF32[i]);
		printf(" ok\n");
	}
	for (i in echoF64) {
		printf("F64 echo(%x, %d)", long(echoF64[i]), i);
		process.stdout.flush();
		F64 value = t.echo(echoF64[i], i);
		assert(value == echoF64[i]);
		printf(" ok\n");
	}
	for (i in echoEnum) {
		printf("EchoEnum echo(%s, %d)", string(echoEnum[i]), i);
		process.stdout.flush();
		EchoEnum value = t.echo(echoEnum[i], i);
		assert(value == echoEnum[i]);
		printf(" ok\n");
	}

	string[] vec = [ "abc", "def", "ghi" ];

	printf("string[] echo(vec)");
	process.stdout.flush();
	string[] vr = t.echo(vec);

	assert(vr.length() == 3);
	assert(vr[0] == "abc");
	assert(vr[1] == "def");
	assert(vr[2] == "ghi");

	printf(" ok\n");

	int[] vec2 = [ 12, 453675, 33645747, 132 ];

	printf("int[] echo(vec2)");
	process.stdout.flush();
	int[] vr2 = t.echo(vec2);

	assert(vr2.length() == 4);
	assert(vr2[0] == 12);
	assert(vr2[1] == 453675);
	assert(vr2[2] == 33645747);
	assert(vr2[3] == 132);

	printf(" ok\n");

	for (i in echoDur) {
		printf("time.Duration echo({%d:%9.9d}, %d)", echoDur[i].seconds(), echoDur[i].nanoseconds(), i);
		process.stdout.flush();
		time.Duration d = t.echo(echoDur[i], i);
		assert(d.seconds() == echoDur[i].seconds());
		assert(d.nanoseconds() == echoDur[i].nanoseconds());
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
	boolean echo(string[string] x);
	F8 echo(F8 x, int index);
	F16 echo(F16 x, int index);
	F32 echo(F32 x, int index);
	F64 echo(F64 x, int index);
	EchoEnum echo(EchoEnum x, int index);
	string[] echo(string[] x);
	int[] echo(int[] x);
	time.Duration echo(time.Duration x, int index);
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

	boolean echo(string[string] argument) {
		assert(argument.size() == 3);
		assert(argument["a"] == "bcd");
		assert(argument["e"] == "fgh");
		assert(argument["i"] == "jkl");
		return true;
	}

	F8 echo(F8 argument, int index) {
		assert(argument == echoF8[index]);
		return argument;
	}

	F16 echo(F16 argument, int index) {
		assert(argument == echoF16[index]);
		return argument;
	}

	F32 echo(F32 argument, int index) {
		assert(argument == echoF32[index]);
		return argument;
	}

	F64 echo(F64 argument, int index) {
		assert(argument == echoF64[index]);
		return argument;
	}

	EchoEnum echo(EchoEnum argument, int index) {
		assert(argument == echoEnum[index]);
		return argument;
	}

	string[] echo(string[] argument) {
		assert(argument.length() == 3);
		assert(argument[0] == "abc");
		assert(argument[1] == "def");
		assert(argument[2] == "ghi");
		return argument;
	}

	int[] echo(int[] argument) {
		assert(argument.length() == 4);
		assert(argument[0] == 12);
		assert(argument[1] == 453675);
		assert(argument[2] == 33645747);
		assert(argument[3] == 132);
		return argument;
	}

	time.Duration echo(time.Duration argument, int index) {
		assert(argument.seconds() == echoDur[index].seconds());
		assert(argument.nanoseconds() == echoDur[index].nanoseconds());
		return argument;
	}

}
