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
import parasol:net.Connection;
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
	private string _cipherList;
	private ref<ThreadPool<int>> _requestThreads;
	private PathHandler[] _handlers;
	private ref<Thread> _httpsThread;
	private ref<Thread> _httpThread;
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
		_handlers.append(PathHandler(absPath, handler, ServiceClass.ANY_SECURITY_LEVEL));
	}
	
	public void secureStaticContent(string absPath, string filename) {
		ref<HttpService> handler = new StaticContentService(filename);
		_handlers.append(PathHandler(absPath, handler, ServiceClass.SECURED_ONLY));
	}
	
	public void unsecureStaticContent(string absPath, string filename) {
		ref<HttpService> handler = new StaticContentService(filename);
		_handlers.append(PathHandler(absPath, handler, ServiceClass.UNSECURED_ONLY));
	}
	
	public void service(string absPath, ref<HttpService> handler) {
		_handlers.append(PathHandler(absPath, handler, ServiceClass.ANY_SECURITY_LEVEL));
	}
	
	public void secureService(string absPath, ref<HttpService> handler) {
		_handlers.append(PathHandler(absPath, handler, ServiceClass.SECURED_ONLY));
	}
	
	public void unsecureService(string absPath, ref<HttpService> handler) {
		_handlers.append(PathHandler(absPath, handler, ServiceClass.UNSECURED_ONLY));
	}
	
	public void setPort(char newPort) {
		_port = newPort;
	}

	public void setSslPort(char newPort) {
		_sslPort = newPort;
	}

	public void setCipherList(string cipherList) {
		_cipherList = cipherList;
	}

	public void start() {
		start(ServerScope.INTERNET);
	}

	public void start(ServerScope scope) {
		_serverScope = scope;
		if (_port > 0) {
			_httpThread = new Thread();
			_httpThread.start(startHttpEntry, this);
		}
		if (_sslPort > 0) {
			_httpsThread = new Thread();
			_httpsThread.start(startHttpsEntry, this);
		}
	}
	
	public void wait() {
		if (_httpThread != null)
			_httpThread.join();
		if (_httpsThread != null)
			_httpsThread.join();
	}

	private static void startHttpEntry(address param) {
		ref<HttpServer> server = ref<HttpServer>(param);
//		printf("Starting http on port %d\n", server._port);
		server.startHttp(server._serverScope, server._port, Encryption.NONE);
	}

	private static void startHttpsEntry(address param) {
		ref<HttpServer> server = ref<HttpServer>(param);
//		printf("Starting https on port %d\n", server._sslPort);
		server.startHttp(server._serverScope, server._sslPort, Encryption.SSLv23);
	}

	private void startHttp(ServerScope scope, char port, Encryption encryption) {
		ref<Socket> socket = Socket.create(encryption, _cipherList);
		if (socket.bind(port, scope)) {
			if (!socket.listen()) {
				printf("listen failed\n");
				return;
			}
			while (!socket.closed()) {
				ref<net.Connection> connection = socket.accept();
				if (connection != null) {
					ref<HttpContext> context = new HttpContext(this, connection);
					_requestThreads.execute(processHttpRequest, context);
				}
			}
		} else
			printf("bind failed\n");
	}

	boolean dispatch(ref<HttpRequest> request, ref<HttpResponse> response, boolean secured) {
//		printf("dispatch %s %s\n", string(request.method), request.url);
		for (int i = 0; i < _handlers.length(); i++) {
			if (request.url.startsWith(_handlers[i].absPath)) {
				switch (_handlers[i].serviceClass) {
				case SECURED_ONLY:
					if (!secured)
						continue;
					break;

				case UNSECURED_ONLY:
					if (secured)
						continue;
					break;
				}
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

private enum ServiceClass {
	UNSECURED_ONLY,
	SECURED_ONLY,
	ANY_SECURITY_LEVEL,
}

private class PathHandler {
	string absPath;
	ref<HttpService> handler;
	ServiceClass serviceClass;

	PathHandler() {}
	
	PathHandler(string absPath, ref<HttpService> handler, ServiceClass serviceClass) {
		this.absPath = absPath;
		this.handler = handler;
		this.serviceClass = serviceClass;
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
//	printf("accept security handshake... ");
	if (!context.connection.acceptSecurityHandshake()) {
//		printf("security handshake rejected\n");
		return;
	}
//	printf("security handshake accepted.\n");
	HttpRequest request(context.connection);
	HttpParser parser(context.connection);
	HttpResponse response(context.connection);
	if (parser.parseRequest(&request)) {
//		request.print();
		if (context.server.dispatch(&request, &response, context.connection.secured())) {
			delete context;
			return;				// if dispatch returns true, we want to keep the connection open (for at least a while).
		}
	} else {
		request.print();
		response.error(400);
	}
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
	public string query;
	public string fragment;
	public string httpVersion;
	public string[string] headers;

	public string serviceResource;
	
	private string[string] _parameters;			// These will be the parsed query parameters.
	private ref<net.Connection> _connection;
	
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
	}

	public int sourceFamily() {
		return _connection.sourceAddress().sin_family;
	}

	public int sourcePort() {
		return _connection.sourceAddress().sin_port;
	}

	public unsigned sourceIP() {
		return _connection.sourceAddress().sin_addr.s_addr;
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
	
	public string queryParameter(string name) {
		if (query == null)
			return null;
		if (_parameters.size() == 0) {
			int nextParam = 0;
			while (nextParam < query.length()) {
				int ampersand = query.indexOf('&', nextParam);
				if (ampersand == -1)
					ampersand = query.length();
				text.substring ss(&query[nextParam], ampersand - nextParam);
				int equals = ss.indexOf('=');
				if (equals == -1) {
					string param(ss);
					_parameters[param] = "";
				} else {
					string param(ss.c_str(), equals);
					int v = equals + 1;
					string value(ss.c_str() + v, ss.length() - v);
					_parameters[param] = value;
				}
				nextParam = ampersand + 1;
			}
		}
		return _parameters[name];
	}

	public ref<net.Connection> connection() {
		return _connection;
	}

	void print() {
		unsigned ip = sourceIP();
		printf("Source family %d %d.%d.%d.%d:%d\n", sourceFamily(), ip & 0xff, (ip >> 8) & 0xff, (ip >> 16) & 0xff, ip >> 24, sourcePort());
		printf("Method           %s(%s)\n", string(method), methodString);
		printf("Url              %s\n", url);
		if (query != null)
			printf("query            %s\n", query);
		if (fragment != null)
			printf("fragment         %s\n", fragment);
		printf("HTTP Version     %s\n", httpVersion);
		if (headers.size() > 0)
			printf("Headers:\n");
		for (string[string].iterator i = headers.begin(); i.hasNext(); i.next()) {
			printf("  %-20s %s\n", i.key(), i.get());
		}
		printf("body size: %d\n", contentLength());
	}
}

public class HttpResponse {
	public string httpVersion;
	public string code;
	public string reason;
	public string[string] headers;

	@Constant
	private static int BUFFER_SIZE = 2048;
	
	private ref<net.Connection> _connection;
	private boolean _headersEnded;
	
	HttpResponse() {
		_connection = null;
	}
	
	HttpResponse(ref<net.Connection> connection) {
		_connection = connection;
	}
	
	void close() {
		if (!_headersEnded)
			endOfHeaders();
		_connection.flush();
		_connection.close();
	}
	
	void printf(string format, var... parameters) {
		_connection.printf(format, parameters);
	}

	void write(string s) {
		_connection.write(s);
	}

	void write(pointer<byte> data, int length) {
		for (int i = 0; i < length; i++)
			_connection.putc(data[i]);
	}

	void putc(byte c) {
		_connection.putc(c);
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
	
	public void ok() {
		statusLine(200, "OK");
	}
	
	public void statusLine(int statusCode, string reasonPhrase) {
		_connection.printf("HTTP/1.1 %d %s\r\n", statusCode, reasonPhrase);
	}
	
	public void header(string label, string value) {
		_connection.printf("%s: %s\r\n", label, value);
	}
	
	public void endOfHeaders() {
		_headersEnded = true;
		_connection.write("\r\n");
		_connection.flush();
	}
	
	/**
	 * Only make this visible to internal users, such as WebSocket.
	 */
	public ref<net.Connection> connection() {
		return _connection;
	}
	
	public void respond() {
		_connection.flush();
	}
	
	public void print() {
		text.printf("HttpResponse\n");
		text.printf("  HTTP Version     %s\n", httpVersion);
		text.printf("  Code             %s\n", code);
		text.printf("  Reason           %s\n", reason);
		if (headers.size() > 0)
			text.printf("  Headers:\n");
		for (string[string].iterator i = headers.begin(); i.hasNext(); i.next()) {
			text.printf("    %-20s %s\n", i.key(), i.get());
		}
	}
}

public class Url {
}

public class HttpParser {
	HttpToken _previousToken;
	string _tokenValue;
	ref<Connection> _connection;
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

	HttpParser(ref<Connection> connection) {
		_connection = connection;
	}
	
	boolean parseRequest(ref<HttpRequest> request) {
		_request = request;
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
			int ch = _connection.read();
			if (ch == -1)
				return _tokenValue != null;
			switch (urlClass[ch]) {
			case UNRESERVED:
			case GEN_DELIM:
			case SUB_DELIM:
			case PCHAR:
			case SLASH:
				_tokenValue.append(byte(ch));
				break;
				
			case QUERY_DELIM:
				for (;;) {
					ch = _connection.read();
					if (ch == -1)
						return _tokenValue != null;
					switch (urlClass[ch]) {
					case UNRESERVED:
					case GEN_DELIM:
					case SUB_DELIM:
					case SLASH:
					case PCHAR:
					case QUERY_DELIM:
						_request.query.append(byte(ch));
						break;
	
					case FRAGMENT_DELIM:
						return collectFragment();

					default:
						_connection.ungetc();
						return _tokenValue != null;
					}
				}

			case FRAGMENT_DELIM:
				return collectFragment();

			default:
				_connection.ungetc();
				return _tokenValue != null;
			}
		}
	}

	private boolean collectFragment() {
		for (;;) {
			int ch = _connection.read();
			if (ch == -1)
				return _tokenValue != null;
			switch (urlClass[ch]) {
			case UNRESERVED:
			case SUB_DELIM:
			case PCHAR:
			case SLASH:
			case QUERY_DELIM:
				_request.fragment.append(byte(ch));
				break;
				
			default:
				_connection.ungetc();
				return _tokenValue != null;
			}
		}
	}

	public boolean parseResponse(ref<HttpResponse> response) {
		HttpToken t = token();
		while (t == HttpToken.CRLF)
			t = token();
		if (t != HttpToken.TOKEN)
			return false;
		if (_tokenValue != "HTTP")
			return false;
		if (token() != HttpToken.SL)
			return false;
		if (token() != HttpToken.TOKEN)
			return false;
		response.httpVersion = _tokenValue;
		if (token() != HttpToken.SP)
			return false;
		if (token() != HttpToken.TOKEN)
			return false;
		response.code = _tokenValue;
		if (token() != HttpToken.SP)
			return false;
		response.reason = readToEOL();
				
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
			if (response.headers.contains(name)) {
				string s = response.headers[name];
				s.append(',');
				s.append(_tokenValue);
				response.headers[name] = s;
			} else
				response.headers[name] = _tokenValue;
		}
//		_request.print();
		return true;
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
			int ch = _connection.read();
			if (ch == -1) {
				if (_tokenValue == null)
					return separator(HttpToken.END_OF_MESSAGE);
			}
			if (ch <= 31 || ch >= 127) {
				if (_tokenValue == null) {
					// we have no token, so this is the first character we saw, some special case processing
					if (ch == '\r') {
						ch = _connection.read();
						if (ch != '\n') {
							_connection.ungetc();
							
							return _previousToken = HttpToken.CR;
						}
						// We have a CR/LF
						
						// Consecutvie CRLF tokens means end-of-headers, so don't read ahead - that might hang a get or other
						// message that has no body.
						
						if (_previousToken == HttpToken.CRLF)
							return HttpToken.CRLF;
						ch = _connection.read();
						if (ch == ' ' || ch == '\t') {
							// Yup, it's a line escape
							skipWhiteSpace();
							return _previousToken = HttpToken.SP;
						} else {
							_connection.ungetc();
							return _previousToken = HttpToken.CRLF;
						}
					}
					_tokenValue.append(byte(ch));
					return _previousToken = HttpToken.CTL;
				}
				_connection.ungetc();
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
					_connection.ungetc();
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
			int ch = _connection.read();
			switch (ch) {
			case '\r':
				_connection.ungetc();
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
				if (pendingWhiteSpace){
					_tokenValue.append(' ');
					pendingWhiteSpace = false;
				}
				_tokenValue.append(byte(ch));
			}
		}
	}
	
	private HttpToken separator(HttpToken sep) {
		if (_tokenValue == null)
			return _previousToken = sep;
		else {
			_connection.ungetc();
			return _previousToken = HttpToken.TOKEN;
		}
	}
	
	private void skipWhiteSpace() {
		int ch;
		do {
			ch = _connection.read();
		} while (ch == ' ' || ch == '\t');
		_connection.ungetc();
	}

	private string readToEOL() {
		string text;
		int ch;
		for (;;) {
			ch = _connection.read();
			if (ch < 0)
				return text;
			if (ch == '\r') {
				ch = _connection.read();
				if (ch < 0)
					return text;
				if (ch == '\n')
					return text;
				_connection.ungetc();
				continue;
			}
			text.append(byte(ch));
		}
	}
}

public class StaticContentService extends HttpService {
	private string _filename;
	
	StaticContentService(string filename) {
		_filename = filename;
	}

	public boolean processRequest(ref<HttpRequest> request, ref<HttpResponse> response) {
		printf("Static Content! fetching %s / %s\n", _filename, request.serviceResource);
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
					int n = f.read(&buffer);
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

private enum UrlClass {
	DISALLOWED,
	UNRESERVED,
	GEN_DELIM,
	SUB_DELIM,
	QUERY_DELIM,
	FRAGMENT_DELIM,
	PCHAR,
	SLASH,
}

private UrlClass[] urlClass = [
	'a':	UrlClass.UNRESERVED,
	'b':	UrlClass.UNRESERVED,
	'c':	UrlClass.UNRESERVED,
	'd':	UrlClass.UNRESERVED,
	'e':	UrlClass.UNRESERVED,
	'f':	UrlClass.UNRESERVED,
	'g':	UrlClass.UNRESERVED,
	'h':	UrlClass.UNRESERVED,
	'i':	UrlClass.UNRESERVED,
	'j':	UrlClass.UNRESERVED,
	'k':	UrlClass.UNRESERVED,
	'l':	UrlClass.UNRESERVED,
	'm':	UrlClass.UNRESERVED,
	'n':	UrlClass.UNRESERVED,
	'o':	UrlClass.UNRESERVED,
	'p':	UrlClass.UNRESERVED,
	'q':	UrlClass.UNRESERVED,
	'r':	UrlClass.UNRESERVED,
	's':	UrlClass.UNRESERVED,
	't':	UrlClass.UNRESERVED,
	'u':	UrlClass.UNRESERVED,
	'v':	UrlClass.UNRESERVED,
	'w':	UrlClass.UNRESERVED,
	'x':	UrlClass.UNRESERVED,
	'y':	UrlClass.UNRESERVED,
	'z':	UrlClass.UNRESERVED,
	'A':	UrlClass.UNRESERVED,
	'B':	UrlClass.UNRESERVED,
	'C':	UrlClass.UNRESERVED,
	'D':	UrlClass.UNRESERVED,
	'E':	UrlClass.UNRESERVED,
	'F':	UrlClass.UNRESERVED,
	'G':	UrlClass.UNRESERVED,
	'H':	UrlClass.UNRESERVED,
	'I':	UrlClass.UNRESERVED,
	'J':	UrlClass.UNRESERVED,
	'K':	UrlClass.UNRESERVED,
	'L':	UrlClass.UNRESERVED,
	'M':	UrlClass.UNRESERVED,
	'N':	UrlClass.UNRESERVED,
	'O':	UrlClass.UNRESERVED,
	'P':	UrlClass.UNRESERVED,
	'Q':	UrlClass.UNRESERVED,
	'R':	UrlClass.UNRESERVED,
	'S':	UrlClass.UNRESERVED,
	'T':	UrlClass.UNRESERVED,
	'U':	UrlClass.UNRESERVED,
	'V':	UrlClass.UNRESERVED,
	'W':	UrlClass.UNRESERVED,
	'X':	UrlClass.UNRESERVED,
	'Y':	UrlClass.UNRESERVED,
	'Z':	UrlClass.UNRESERVED,
	'0':	UrlClass.UNRESERVED,
	'1':	UrlClass.UNRESERVED,
	'2':	UrlClass.UNRESERVED,
	'3':	UrlClass.UNRESERVED,
	'4':	UrlClass.UNRESERVED,
	'5':	UrlClass.UNRESERVED,
	'6':	UrlClass.UNRESERVED,
	'7':	UrlClass.UNRESERVED,
	'8':	UrlClass.UNRESERVED,
	'9':	UrlClass.UNRESERVED,
	'-':	UrlClass.UNRESERVED,
	'.':	UrlClass.UNRESERVED,
	'_':	UrlClass.UNRESERVED,
	'~':	UrlClass.UNRESERVED,
	'%':	UrlClass.UNRESERVED,
	'/':	UrlClass.SLASH,
	':':	UrlClass.PCHAR,
	'[':	UrlClass.GEN_DELIM,
	']':	UrlClass.GEN_DELIM,
	'@':	UrlClass.PCHAR,
	'!':	UrlClass.SUB_DELIM,
	'$':	UrlClass.SUB_DELIM,
	'&':	UrlClass.SUB_DELIM,
	'\'':	UrlClass.SUB_DELIM,
	'(':	UrlClass.SUB_DELIM,
	')':	UrlClass.SUB_DELIM,
	'*':	UrlClass.SUB_DELIM,
	'+':	UrlClass.SUB_DELIM,
	',':	UrlClass.SUB_DELIM,
	';':	UrlClass.SUB_DELIM,
	'=':	UrlClass.SUB_DELIM,
	'?':	UrlClass.QUERY_DELIM,
	'#':	UrlClass.FRAGMENT_DELIM,
	255:	UrlClass.DISALLOWED,
];

