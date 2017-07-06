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
namespace parasol:http;

import parasol:file.File;
import parasol:file.openBinaryFile;
import parasol:file.Seek;
import parasol:storage.constructPath;
import parasol:storage.exists;
import parasol:thread.Thread;
import parasol:thread.ThreadPool;
import parasol:thread.currentThread;
import parasol:net.Socket;
import parasol:net.Encryption;
import parasol:net.ServerScope;
import native:linux;
import parasol:net;

/*
 * This class implements an HTTP server. It implements HTTP version 1.1 for an Origin Server only. Hooks are defined to allow for
 * future expansion.
 * 
 *  This class is under construction and as such has numerous places where configurability will need to be expanded in the
 *  future.
 */
public class HttpServer {
	private string _hostname;
	private char _port;								// default to 80
	private char _sslPort;								// default to 443
	private ref<ThreadPool<int>> _requestThreads;
	private PathHandler[] _handlers;
	private ref<Thread> _httpsThread;
	private ServerScope _serverScope;
	/*
	 * The various roles a server can play determine how messages should be interpreted. 
	 */
	enum Type {
		ORIGIN,			
		PROXY,
		GATEWAY,
		TUNNEL
	}
	
	public HttpServer() {
		_hostname = "";
		_port = 80;
		_sslPort = 443;
		_requestThreads = new ThreadPool<int>(4);
	}
	/*
	 * Binds the absPath in any incoming URL to the local file-system
	 * file or directory name filename.
	 */
	public void staticContent(string absPath, string filename) {
		ref<HttpService> handler = new StaticContentService(filename);
		_handlers.append(PathHandler(absPath, handler));
	}
	
	public void service(string absPath, ref<HttpService> handler) {
		_handlers.append(PathHandler(absPath, handler));
	}
	
	public void setPort(char newPort) {
		_port = newPort;
	}

	public void setSslPort(char newPort) {
		_sslPort = newPort;
	}
	
	public boolean start(ServerScope scope) {
		_serverScope = scope;
		_httpsThread = new Thread();
		_httpsThread.start(startHttpsEntry, this);
		ref<Socket> socket = Socket.create(Encryption.NONE);
		if (socket.bind(_port, scope))
			listenLoop(socket);
		printf("http listen loop broken\n");
		return true;
	}
	
	private static void startHttpsEntry(address param) {
		printf("%s https param = %p\n", currentThread().name(), param);
		ref<HttpServer> server = ref<HttpServer>(param);
		server.startHttps(server._serverScope);
	}

	private void startHttps(ServerScope scope) {
		ref<Socket> socket = Socket.create(Encryption.SSLv23);
		if (socket.bind(_sslPort, scope))
			listenLoop(socket);
		printf("https listen loop broken\n");
	}

	private void listenLoop(ref<Socket> socket) {
		if (!socket.listen())
			return;
		for (;;) {
			ref<net.Connection> connection = socket.accept();
			if (connection == null)
				return;			
//			printf("Dispatching");
			ref<HttpContext> context = new HttpContext(this, connection);
//			printf("Calling execute\n");
			_requestThreads.execute(processHttpRequest, context);
		}
	}

	boolean dispatch(ref<HttpRequest> request, ref<HttpResponse> response) {
//		printf("dispatch %s %s\n", string(request.method), request.url);
		for (int i = 0; i < _handlers.length(); i++) {
			if (request.url.startsWith(_handlers[i].absPath)) {
				if (request.url.length() > _handlers[i].absPath.length()) {
					if (request.url[_handlers[i].absPath.length()] != '/')
						continue;			// a false alarm, e.g. absPath = /foo url = /food
					request.serviceResource = request.url.substring(_handlers[i].absPath.length() + 1);
				} else
					request.serviceResource = null;
//				printf("hit handler %d absPath = %s\n", i, _handlers[i].absPath);
				return _handlers[i].handler.processRequest(request, response);
			}
		}
//		printf("miss!\n");
		response.error(404);
//		printf("done.\n");
		return false;
	}
	
	public char port() {
		return _port;
	}
}

private class PathHandler {
	string absPath;
	ref<HttpService> handler;
	
	PathHandler() {}
	
	PathHandler(string absPath, ref<HttpService> handler) {
		this.absPath = absPath;
		this.handler = handler;
	}
}

private class HttpContext {
	public ref<HttpServer> server;
	public ref<net.Connection> connection;
//	public int requestFd;
//	public sockaddr_in sourceAddress;
//	public int addressLength;

	public HttpContext(ref<HttpServer> server, ref<net.Connection> connection) {
		this.server = server;
		this.connection = connection;
//		this.requestFd = requestFd;
//		this.sourceAddress = sourceAddress;
//		this.addressLength = addressLength;
	}
}

private void processHttpRequest(address ctx) {
	ref<HttpContext> context = ref<HttpContext>(ctx);
	if (!context.connection.acceptSecurityHandshake())
		return;
	HttpRequest request(context.connection);
	HttpParser parser(&request);
	HttpResponse response(context.connection);
	if (parser.parse()) {
		if (context.server.dispatch(&request, &response)) {
			delete context;
			return;				// if dispatch returns true, we want to keep the connection open (for at least a while).
		}
	} else
		response.error(400);
//	printf("About to close socket %d %d\n", context.connection.requestFd(), currentThread().id());
	response.close();
	delete context;
}

public class Http {
	public static HttpResponse get(string url) {
		HttpResponse response();
		// TODO: Add some code to issue a request.
		return response;
	}
}

public class HttpService {
	public abstract boolean processRequest(ref<HttpRequest> request, ref<HttpResponse> response);
}

public class HttpRequest {
	public Method method;
	public string methodString;	// Only set for method == CUSTOM
	public string url;
	public string httpVersion;
	public string[string] headers;
	
	public string serviceResource;
	
	private ref<net.Connection> _connection;
	private byte[] _buffer;
	private int _bufferEnd;
	private int _cursor;
	
	enum Method {
		OPTIONS,
		GET,
		HEAD,
		POST,
		PUT,
		DELETE,
		TRACE,
		CONNECT,
		CUSTOM
	}
	
	public HttpRequest(ref<net.Connection> connection) {
		_connection = connection;
		_buffer.resize(65536);
	}
	
	public long contentLength() {
		string s = headers["content-length"];
		if (s == null)
			return 0;
		boolean success;
		long value;
		
		(value, success) = long.parse(s);
		if (!success)
			return 0;
		else
			return value;
	}
	
	void ungetc() {
		if (_bufferEnd >= 0)
			_cursor--;
//		printf("after ungetc _cursor = %x\n", _cursor);
	}
	
	int getc() {
		// Refill the buffer until we get an empty read.
		if (_cursor >= _bufferEnd) {
			if (_bufferEnd < 0)
				return -1;
			_bufferEnd = _connection.read(&_buffer[0], _buffer.length());
			if (_bufferEnd <= 0) {
				_bufferEnd = -1;
				return -1;
			}
//			text.memDump(&_buffer[0], _bufferEnd, 0);
			_cursor = 0;
		}
//		printf("after getc _cursor = %x\n", _cursor);
		return _buffer[_cursor++];		
	}

	void print() {
		printf("Method %s(%s)\n", string(method), methodString);
		printf("Url %s\n", url);
		printf("HTTP Version %s\n", httpVersion);
		if (headers.size() > 0)
			printf("Headers:\n");
		for (string[string].iterator i = headers.begin(); i.hasNext(); i.next()) {
			printf("  %-20s %s\n", i.key(), i.get());
		}
		printf("body size: %d\n", contentLength());
	}
}

public class HttpResponse {
	@Constant
	private static int BUFFER_SIZE = 2048;
	
	private ref<net.Connection> _connection;
	private byte[] _buffer;
	private int _fill;
	
	HttpResponse() {
		_connection = null;
		_buffer.resize(BUFFER_SIZE);
	}
	
	HttpResponse(ref<net.Connection> connection) {
		_connection = connection;
		_buffer.resize(BUFFER_SIZE);
	}
	
	void close() {
		flush();
		_connection.close();
	}
	
	private void flush() {
		if (_fill > 0) {
			int x = _connection.write(&_buffer[0], _fill);
			if (x < 0) {
				printf("flush failed\n");
				linux.perror(null);
			}
//			printf("sent %d bytes\n", _fill);
//			text.memDump(&_buffer[0], _fill, 0);
			_fill = 0;
		}
	}
	
	void putc(byte c) {
		_buffer[_fill++] = c;
		if (_fill >= BUFFER_SIZE)
			flush();
	}
	
	void error(int statusCode) {
		string reasonPhrase;
		switch (statusCode) {
		case	400:	reasonPhrase = "Bad Request";			break;
		case	404:	reasonPhrase = "Not Found";				break;
		case	405:	reasonPhrase = "Method Not Allowed";	break;
		case	500:	reasonPhrase = "Internal Server Error";	break;
		case	501:	reasonPhrase = "Not Implemented";		break;
		default:		reasonPhrase = "Unknown";				break;
		}
		statusLine(statusCode, reasonPhrase);
		// emit headers?
	}
	
	void ok() {
		statusLine(200, "OK");
	}
	
	void statusLine(int statusCode, string reasonPhrase) {
		string s;
		
		s.printf("HTTP/1.1 %d %s\r\n", statusCode, reasonPhrase);
		write(s);
	}
	
	void header(string label, string value) {
		write(label);
		write(": ");
		write(value);
		write("\r\n");
	}
	
	void endOfHeaders() {
		write("\r\n");
		flush();
	}
	
	public void write(string s) {
		for (int i = 0; i < s.length(); i++)
			putc(s[i]);
	}
	
	public void write(pointer<byte> buffer, int len) {
		for (int i = i; i < len; i++)
			putc(buffer[i]);
	}
	/**
	 * Only make this visible to internal users, such as WebSocket.
	 */
	ref<net.Connection> connection() {
		return _connection;
	}
	
	void respond() {
		flush();
	}
	
	void print() {
		text.memDump(&_buffer[0], _fill, 0);
	}
}

public class Url {
}

private class HttpParser {
	HttpToken _previousToken;
	string _tokenValue;
	ref<HttpRequest> _request;
	
	enum HttpToken {
		END_OF_MESSAGE,
		CR,
		CRLF,
		SP,
		TOKEN,
		CTL,
		LP,
		RP,
		LT,
		GT,
		AT,
		CM,
		SM,
		CO,
		BSLASH,
		QUOTED,
		SL,
		LB,
		RB,
		QUES,
		EQ,
		LC,
		RC
	}

	HttpParser(ref<HttpRequest> request) {
		_request = request;
	}
	
	boolean parse() {
		HttpToken t = token();
		while (t == HttpToken.CRLF)
			t = token();
		if (t != HttpToken.TOKEN)
			return false;
		_request.methodString = _tokenValue;
		if (_tokenValue == "OPTIONS")
			_request.method = HttpRequest.Method.OPTIONS;
		else if (_tokenValue == "GET")
			_request.method = HttpRequest.Method.GET;
		else if (_tokenValue == "HEAD")
			_request.method = HttpRequest.Method.HEAD;
		else if (_tokenValue == "POST")
			_request.method = HttpRequest.Method.POST;
		else if (_tokenValue == "PUT")
			_request.method = HttpRequest.Method.PUT;
		else if (_tokenValue == "DELETE")
			_request.method = HttpRequest.Method.DELETE;
		else if (_tokenValue == "TRACE")
			_request.method = HttpRequest.Method.TRACE;
		else if (_tokenValue == "CONNECT")
			_request.method = HttpRequest.Method.CONNECT;
		else
			_request.method = HttpRequest.Method.CUSTOM;
		if (token() != HttpToken.SP)
			return false;
		if (!collectUrl())
			return false;
		_request.url = _tokenValue;
		if (token() != HttpToken.SP)
			return false;
		// Now comes the HTTP version
		if (token() != HttpToken.TOKEN)
			return false;
		if (_tokenValue != "HTTP")
			return false;
		if (token() != HttpToken.SL)
			return false;
		if (token() != HttpToken.TOKEN)
			return false;
		_request.httpVersion = _tokenValue;
		if (token() != HttpToken.CRLF)
			return false;
		
		for (;;) {
			t = token();
			if (t == HttpToken.CRLF)
				break;
			if (t != HttpToken.TOKEN)
				return false;
			string name = _tokenValue;
			if (token() != HttpToken.CO)
				return false;
			skipWhiteSpace();
			if (!fieldValue())
				return false;
			// header names are case-insensitive
			name = name.toLower();
			// The fieldValue() method consumed the CRLF, so we are ready to start parsing the next header
			if (_request.headers.contains(name)) {
				string s = _request.headers[name];
				s.append(',');
				s.append(_tokenValue);
				_request.headers[name] = s;
			} else
				_request.headers[name] = _tokenValue;
		}
//		_request.print();
		return true;
	}
	/*
	 * Based on RFC 3986: URI general syntax. This may include strings that are not well-formed URL's, but is
	 * intended to accept all valid URL's. Later parsing will segment the URL components.
	 */
	private boolean collectUrl() {
		_tokenValue = null;
		for (;;) {
			int ch = _request.getc();
			switch (ch) {
			case 'a':
			case 'b':
			case 'c':
			case 'd':
			case 'e':
			case 'f':
			case 'g':
			case 'h':
			case 'i':
			case 'j':
			case 'k':
			case 'l':
			case 'm':
			case 'n':
			case 'o':
			case 'p':
			case 'q':
			case 'r':
			case 's':
			case 't':
			case 'u':
			case 'v':
			case 'w':
			case 'x':
			case 'y':
			case 'z':
			case 'A':
			case 'B':
			case 'C':
			case 'D':
			case 'E':
			case 'F':
			case 'G':
			case 'H':
			case 'I':
			case 'J':
			case 'K':
			case 'L':
			case 'M':
			case 'N':
			case 'O':
			case 'P':
			case 'Q':
			case 'R':
			case 'S':
			case 'T':
			case 'U':
			case 'V':
			case 'W':
			case 'X':
			case 'Y':
			case 'Z':
			case '0':
			case '1':
			case '2':
			case '3':
			case '4':
			case '5':
			case '6':
			case '7':
			case '8':
			case '9':
			case '/':
			case ':':
			case '?':
			case '#':
			case '[':
			case ']':
			case '@':
			case '!':
			case '$':
			case '&':
			case '\'':
			case '(':
			case ')':
			case '*':
			case '+':
			case ',':
			case ';':
			case '=':
			case '-':
			case '.':
			case '_':
			case '~':
				_tokenValue.append(byte(ch));
				break;
				
			case -1:
				return _tokenValue != null;

			default:
				_request.ungetc();
				return _tokenValue != null;
			}
		}
	}
	/*
	 * Token values, always a string:
	 *   - just a carriage return = just a carriage return in the input.
	 *   - just a newline = saw a CR/LF followed by not a space (so not a line wrap).
	 *   - 
	 */
	private HttpToken token() {
		_tokenValue = null;
		
		for (;;) {
			int ch = _request.getc();
			if (ch == -1) {
				if (_tokenValue == null)
					return separator(HttpToken.END_OF_MESSAGE);
			}
			if (ch <= 31 || ch >= 127) {
				if (_tokenValue == null) {
					// we have no token, so this is the first character we saw, some special case processing
					if (ch == '\r') {
						ch = _request.getc();
						if (ch != '\n') {
							_request.ungetc();
							
							return _previousToken = HttpToken.CR;
						}
						// We have a CR/LF
						
						// Consecutvie CRLF tokens means end-of-headers, so don't read ahead - that might hang a get or other
						// message that has no body.
						
						if (_previousToken == HttpToken.CRLF)
							return HttpToken.CRLF;
						ch = _request.getc();
						if (ch == ' ' || ch == '\t') {
							// Yup, it's a line escape
							skipWhiteSpace();
							return _previousToken = HttpToken.SP;
						} else {
							_request.ungetc();
							return _previousToken = HttpToken.CRLF;
						}
					}
					_tokenValue.append(byte(ch));
					return _previousToken = HttpToken.CTL;
				}
				_request.ungetc();
				return _previousToken = HttpToken.TOKEN;
			}
			switch (ch) {
			case '(':	return separator(HttpToken.LP);
			case ')':	return separator(HttpToken.RP);
			case '<':	return separator(HttpToken.LT);
			case '>':	return separator(HttpToken.GT);
			case '@':	return separator(HttpToken.AT);
			case ',':	return separator(HttpToken.CM);
			case ';':	return separator(HttpToken.SM);
			case ':':	return separator(HttpToken.CO);
			case '\\':	return separator(HttpToken.BSLASH);
			case '"':	return separator(HttpToken.QUOTED);
			case '/':	return separator(HttpToken.SL);
			case '[':	return separator(HttpToken.LB);
			case ']':	return separator(HttpToken.RB);
			case '?':	return separator(HttpToken.QUES);
			case '=':	return separator(HttpToken.EQ);
			case '{':	return separator(HttpToken.LC);
			case '}':	return separator(HttpToken.RC);
				
			case ' ':
			case '\t':
				if (_tokenValue != null) {
					_request.ungetc();
					return _previousToken = HttpToken.TOKEN;
				}
				skipWhiteSpace();
				return _previousToken = HttpToken.SP;
				
			default:
				_tokenValue.append(byte(ch));
			}
		}
	}
	
	private boolean fieldValue() {
		_tokenValue = null;
		boolean pendingWhiteSpace = false;
		for (;;) {
			int ch = _request.getc();
			switch (ch) {
			case '\r':
				_request.ungetc();
				string saveArea = _tokenValue;
				HttpToken t = token();
				_tokenValue = saveArea;
				switch (t) {
				case CRLF:
					return true;
					
				case SP:
					pendingWhiteSpace = true;
					break;
					
				default:
					return false;
				}
				break;
				
			case ' ':
			case '\t':
				pendingWhiteSpace = true;
				break;
				
			default:
				if (pendingWhiteSpace)
					_tokenValue.append(' ');
				_tokenValue.append(byte(ch));
			}
		}
	}
	
	private HttpToken separator(HttpToken sep) {
		if (_tokenValue == null)
			return _previousToken = sep;
		else {
			_request.ungetc();
			return _previousToken = HttpToken.TOKEN;
		}
	}
	
	private void skipWhiteSpace() {
		int ch;
		do {
			ch = _request.getc();
		} while (ch == ' ' || ch == '\t');
		_request.ungetc();
	}
}

private class StaticContentService extends HttpService {
	private string _filename;
	
	StaticContentService(string filename) {
		_filename = filename;
	}

	public boolean processRequest(ref<HttpRequest> request, ref<HttpResponse> response) {
//		printf("Static Content! fetching %s / %s\n", _filename, request.serviceResource);
		if (request.method != HttpRequest.Method.GET) {
			response.error(501);
			return false;
		}
		string filename;
		if (request.serviceResource != null)
			filename = constructPath(_filename, request.serviceResource, null);
		else
			filename = _filename;
		if (exists(filename)) {
			File f = openBinaryFile(filename);
			if (f.opened()) {
				response.ok();
				f.seek(0, Seek.END);
				int size = f.tell(); 
				f.seek(0, Seek.START);
				string s;
				s.printf("%d", size);
				response.header("Content-Length", s);
				response.endOfHeaders();
//				printf("Reading %d bytes from file %s\n", size, filename);
				byte[] buffer;
				buffer.resize(8192);
				for (;;) {
					int n = f.read(buffer);
					if (n <= 0)
						break;
//					printf("Read %d bytes\n", n);
					response.write(&buffer[0], n);
//					printf("Wrote a response\n");
				}
				f.close();
			} else
				response.error(500);
		} else
			response.error(404);
		
		return false;
	}
}
