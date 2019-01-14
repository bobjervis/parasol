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

import parasol:log;
import parasol:process;
import parasol:storage.File;
import parasol:storage.openBinaryFile;
import parasol:storage.Seek;
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

private ref<log.Logger> logger = log.getLogger("parasol.http.server");

/*
 * This class implements an HTTP server. It implements HTTP version 1.1 for an Origin Server only. Hooks are defined to allow for
 * future expansion.
 * 
 *  This class is under construction and as such has numerous places where configurability will need to be expanded in the
 *  future.
 */
public class HttpServer {
	public string cipherList;
	public string certificatesFile;
	public string privateKeyFile;
	public string dhParamsFile;
	boolean _publicServiceEnabled;
	boolean _secureServiceEnabled;
	char _httpPort;									// actual port used, if not zero
	char _httpsPort;								// actual port used, if not zero
	ref<Socket> _publicSocket;
	ref<Socket> _secureSocket;
	private string _hostname;
	private ref<ThreadPool<int>> _requestThreads;
	private PathHandler[] _handlers;
	private ref<Thread> _httpsThread;
	private ref<Thread> _httpThread;
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
		_publicServiceEnabled = true;
		_httpPort = 80;
		_secureServiceEnabled = true;
		_httpsPort = 443;
		_hostname = "";
		_requestThreads = new ThreadPool<int>(4);
	}

	~HttpServer() {
		wait();
		delete _publicSocket;
		delete _secureSocket;
	}

	public boolean enableHttp() {
		boolean priorState = _publicServiceEnabled;
		_publicServiceEnabled = true;
		return priorState;
	}

	public boolean disableHttp() {
		boolean priorState = _publicServiceEnabled;
		_publicServiceEnabled = false;
		return priorState;
	}

	public boolean setHttpActivation(boolean newState) {
		boolean priorState = _publicServiceEnabled;
		_publicServiceEnabled = newState;
		return priorState;
	}

	public boolean enableHttps() {
		boolean priorState = _secureServiceEnabled;
		_secureServiceEnabled = true;
		return priorState;
	}

	public boolean disableHttps() {
		boolean priorState = _secureServiceEnabled;
		_secureServiceEnabled = false;
		return priorState;
	}

	public boolean setHttpsActivation(boolean newState) {
		boolean priorState = _secureServiceEnabled;
		_secureServiceEnabled = newState;
		return priorState;
	}

	public char httpPort() {
		return _httpPort;
	}

	public char httpsPort() {
		return _httpsPort;
	}

	public void setHttpPort(char port) {
		_httpPort = port;
	}

	public void setHttpsPort(char sslPort) {
		_httpsPort = sslPort;
	}

	/*
	 * Binds the absPath in any incoming URL to the local file-system
	 * file or directory name filename.
	 */
	public void staticContent(string absPath, string filename) {
		ref<HttpService> handler = new StaticContentService(filename);
		post(PathHandler(absPath, handler, ServiceClass.ANY_SECURITY_LEVEL));
	}
	
	public void httpsStaticContent(string absPath, string filename) {
		ref<HttpService> handler = new StaticContentService(filename);
		post(PathHandler(absPath, handler, ServiceClass.SECURED_ONLY));
	}
	
	public void httpStaticContent(string absPath, string filename) {
		ref<HttpService> handler = new StaticContentService(filename);
		post(PathHandler(absPath, handler, ServiceClass.UNSECURED_ONLY));
	}
	
	public void service(string absPath, ref<HttpService> handler) {
		post(PathHandler(absPath, handler, ServiceClass.ANY_SECURITY_LEVEL));
	}
	
	public void httpsService(string absPath, ref<HttpService> handler) {
		post(PathHandler(absPath, handler, ServiceClass.SECURED_ONLY));
	}
	
	public void httpService(string absPath, ref<HttpService> handler) {
		post(PathHandler(absPath, handler, ServiceClass.UNSECURED_ONLY));
	}

	private void post(PathHandler ph) {
		for (i in _handlers) {
			if (ph.absPath.length() > _handlers[i].absPath.length()) {
				_handlers.insert(i, ph);
				return;
			}
		}
		_handlers.append(ph);
	}

	public void start() {
		start(ServerScope.INTERNET);
	}

	public boolean start(ServerScope scope) {
		if (_publicServiceEnabled) {
			_publicSocket = bindSocket(scope, _httpPort, Encryption.NONE);
			if (_publicSocket == null)
				return false;
			if (_httpPort == 0)
				_httpPort = _publicSocket.port();
			_httpThread = new Thread();
			_httpThread.start(startHttpEntry, this);
		}
		if (_secureServiceEnabled) {
			_secureSocket = bindSocket(scope, _httpsPort, Encryption.SSLv23);
			if (_secureSocket == null)
				return false;
			if (_httpsPort == 0)
				_httpsPort = _secureSocket.port();
			_httpsThread = new Thread();
			_httpsThread.start(startHttpsEntry, this);
		}
		return true;
	}

	private ref<Socket> bindSocket(ServerScope scope, char port, Encryption encryption) {
		ref<Socket> socket = Socket.create(encryption, cipherList, certificatesFile, privateKeyFile, dhParamsFile);
		if (socket.bind(port, scope)) {
			if (!socket.listen()) {
				printf("listen failed\n");
				delete socket;
				return null;
			}
		} else {
			printf("bind failed\n");
			delete socket;
			return null;
		}
		return socket;
	}

	private static void startHttpEntry(address param) {
		ref<HttpServer> server = ref<HttpServer>(param);
//		printf("Starting http on port %d\n", server._httpPort);
			server.acceptLoop(server._publicSocket);
	}

	private static void startHttpsEntry(address param) {
		ref<HttpServer> server = ref<HttpServer>(param);
//		printf("Starting https on port %d\n", server._httpsPort);
		server.acceptLoop(server._secureSocket);
	}

	public void wait() {
		if (_httpThread != null)
			_httpThread.join();
		if (_httpsThread != null)
			_httpsThread.join();
	}

	void acceptLoop(ref<Socket> socket) {
		while (!socket.closed()) {
			ref<net.Connection> connection = socket.accept();
			if (connection != null) {
				ref<HttpContext> context = new HttpContext(this, connection);
//				logger.format(log.DEBUG, "about to execute 'processHttpRequest' threads %d", _requestThreads.idleThreads());
				_requestThreads.execute(processHttpRequest, context);
			}
		}
	}

	boolean dispatch(ref<HttpRequest> request, ref<HttpResponse> response, boolean secured) {
		for (int i = 0; i < _handlers.length(); i++) {
			if (_handlers[i].absPath == "/") {
				request.serviceResource = request.url.substring(1);
//				printf("hit handler %d absPath = %s\n", i, _handlers[i].absPath);
				return _handlers[i].handler.processRequest(request, response);
			} else if (request.url.startsWith(_handlers[i].absPath)) {
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
		logger.format(log.ERROR, "Failed request for %s from %s", request.serviceResource, request.connection().sourceIPv4());
//		printf("miss!\n");
		response.error(404);
//		printf("done.\n");
		return false;
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
	if (!context.connection.acceptSecurityHandshake()) {
		return;
	}
	HttpRequest request(context.connection);
	HttpParser parser(context.connection);
	HttpResponse response(context.connection);
	if (parser.parseRequest(&request)) {
		if (request.method == HttpRequest.Method.NO_CONTENTS)
			response.error(400);
		else if (context.server.dispatch(&request, &response, context.connection.secured())) {
			delete context;
			return;				// if dispatch returns true, we want to keep the connection open (for at least a while).
		}
	} else {
		logger.format(log.DEBUG, "Could not parse request from %s", net.dottedIP(context.connection.sourceIPv4()));
//		request.print();
		response.error(400);
	}
	response.close();
	delete context;
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
		NO_CONTENTS,							// Not actually part of HTTP. Indicates empty HTTP payload.
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
				substring ss(&query[nextParam], ampersand - nextParam);
				int equals = ss.indexOf('=');
				if (equals == -1) {
					string param(ss);
					_parameters[param] = "";
				} else {
					string param(ss.c_str(), equals);
					int v = equals + 1;
					string value(ss.c_str() + v, ss.length() - v);
					// TODO: decode URI component to unescape character sequences.
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

	public void print() {
		unsigned ip = sourceIP();
		printf("Source family %d %s:%d\n", sourceFamily(), net.dottedIP(ip), sourcePort());
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
/**
 * This class is used to store the parsed fields of an HTTP response in an HTTP client.
 */
public class HttpParsedResponse {
	/**
	 * The value of the HTTP version string passed in the response.
	 */
	public string httpVersion;
	/**
	 * The HTTP code returned from the server. For example, a 'page not fund' error
	 * would have a code of "404".
	 */
	public string code;
	/**
	 * The text of the 'reason' string supplied following the code.
	 */
	public string reason;
	/**
	 * A map of all headers, keyed by the header name.
	 *
	 * Header names are converted to lower-case in the map, since they are case-insensitive.
	 * Note that the values of the headers are case sensitive.
	 *
	 * If a header occurs more than once in a response, all the supplied values are concatenated,
	 * separated by commas, as a single string.
	 */
	public string[string] headers;
	/**
	 * This function is supplied as a debugging aid.
	 */
	public void print() {
		process.printf("HttpResponse\n");
		process.printf("  HTTP Version     %s\n", httpVersion);
		process.printf("  Code             %s\n", code);
		process.printf("  Reason           %s\n", reason);
		if (headers.size() > 0)
			process.printf("  Headers:\n");
		for (string[string].iterator i = headers.begin(); i.hasNext(); i.next()) {
			process.printf("    %-20s %s\n", i.key(), i.get());
		}
	}
}
/**
 * This class is used to generate the response to an HTTP request inside an
 * HTTP server.
 *
 * It is important to understand that an HTTPResponse object is quite stateful.
 * An HTTPResponse object goes through three phases corresponding to the three
 * segments of an HTTP response message. This is done to minimize the amount of
 * information that must be held in memory at once. 
 *
 * The initial phase generates the status line, the first line of the HTTP response
 * message. The class will always respond with HTTP 1.1 as the protocol version. You
 * can specify both the status code and the reason phrase by calling {@link statusLine}.
 * That will compose and write the status line to the connection. Once called, the
 * HTTPResponse object transitions to the second phase and the only options are completing the
 * message or aborting it and severing the connection.
 *
 * Several convenience functions are provided that devolve to a call to {@link statusLine}:
 * <ul>
 *     <li>{@link ok} - This function composes a status line with a code of 200 and a
 *                      reason of ok.
 *     <li>{@link error} - This function takes an error code and supplies the standard
 *                      reason for that code. Currently, the implementation only supports
 *                      a few of the codes, so check the source code.
 *     <li>{@link redirect} - This function take a URL and responds with the necessary
 *						headers to signal a redirection to the URL.
 * </ul>
 * The second phase involves the generation of headers.
 */
public class HttpResponse {
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
	
	public void error(int statusCode) {
		string reasonPhrase;
		switch (statusCode) {
		case	400:	reasonPhrase = "Bad Request";			break;
		case	401:	reasonPhrase = "Unauthorized";			break;
		case	404:	reasonPhrase = "Not Found";				break;
		case	405:	reasonPhrase = "Method Not Allowed";	break;
		case	410:	reasonPhrase = "Gone";					break;
		case	500:	reasonPhrase = "Internal Server Error";	break;
		case	501:	reasonPhrase = "Not Implemented";		break;
		default:		reasonPhrase = "Unknown";				break;
		}
		statusLine(statusCode, reasonPhrase);
	}
	/**
	 * Respond with a redirect to a given uri.
	 *
	 * The recommendation is to follow this call by writing a short
	 * web page that contains a link the user can click on to get to 
	 * the intended destination.
	 *
	 * @param uri The redirect URI. The intention is that the browser
	 * should re-issue the request to the new location.
	 */
	public void redirect(string uri) {
		statusLine(302, "Found");
		header("Location", uri);
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

	ref<net.Connection> connection() {
		return _connection;
	}
	
	public void respond() {
		_connection.flush();
	}
}
/**
 * This class is used to convert between a string and a parsed URI.
 *
 * This implements the syntax described in RFC 3986.
 */
public class Uri {
	public string scheme;
	public string userinfo;
	public string host;
	public string path;
	public string query;
	public string fragment;
	public char port;				// optional (default will be filled in from scheme)
	public boolean portDefaulted;
	public boolean parsed;
	/**
	 * Parses a URI applying the precise rules of RFC 2986.
	 *
	 * On a successful parse, the public members of the structure will be initialized with
	 * the values of the various fields in the URI.
	 *
	 * @param uri A string containing a URI
	 *
	 * @return true if the string contains a valid RFC3986 URI, false otherwise.
	 */
	public boolean parseRFC3986(string uri) {
		return parse(uri, true);
	}
	/**
	 * Parses a URI with a few rules relaxed to permit additional strings to be parsed
	 *
	 * @param uri A string containing a URI
	 *
	 * @return true if the string contains a valid URI using relaxed rules from RFC3986, false otherwise.
	 */
	public boolean parse(string uri) {
		return parse(uri, false);
	}
	/**
	 * Parse a URI.
	 *
	 * @param uri A string containing a URI
	 * @param strict true if the URI should be parsed as if calling {@link parseRFC3986}, or false
	 * if the URI should be parsed as if callid {@link parse}.
	 *
	 * @return true if the string contains a valid URI using the rules selected by {@link strict}, false otherwise.
	 */
	public boolean parse(string uri, boolean strict) {
		reset();
		int colonIdx = uri.indexOf(':');
		if (colonIdx < 0) {
			if (strict)
				return false;
		} else if (colonIdx == 0) {
			if (strict)
				return false;
			scheme = "";
		} else
			scheme = uri.substring(0, colonIdx);

		if (colonIdx + 1 >= uri.length()) {
			path = "";
			return parsed = true;			// This is scheme:
		}

		int slashIdx = uri.indexOf('/', colonIdx + 1);

		int pathIdx;
		if (slashIdx > 0) {
			if (slashIdx == colonIdx + 1) {
				if (slashIdx + 1 >= uri.length()) {
					// This is: scheme:/
					path = "/";
					return parsed = true;
				}
				if (uri[slashIdx + 1] == '/') {
					int authIdx = slashIdx + 2;
					// This is: scheme://something
					pathIdx = uri.indexOf('/', authIdx);
					if (pathIdx < 0)
						pathIdx = uri.length();
					// This is: scheme:://authority path
					int atIdx = uri.indexOf('@', authIdx);
					if (atIdx > 0) {
						userinfo = uri.substring(authIdx, atIdx);
						authIdx = atIdx + 1;
					}
					int portIdx = uri.indexOf(':', authIdx);
					if (portIdx > 0) {
						boolean success;
						(port, success) = char.parse(uri.substring(portIdx + 1, pathIdx));
						if (!success)
							// This will leave the URI unparsed
							return false;				
						portDefaulted = false;
					} else {
						port = defaultPort[scheme];
						if (port == 0)
							// This will leave the URI unparsed
							return false;
						portIdx = pathIdx;
					}
					host = uri.substring(authIdx, portIdx);
				}
			} else {
				// This is scheme:something-containing-a-slash
				pathIdx = colonIdx + 1;
				if (strict) {
					if (pathIdx < uri.length())
						return false;
				}
			}
		} else {
			// This is scheme:something-not-containing-a-slash
			pathIdx = colonIdx + 1;
			if (strict) {
				if (pathIdx < uri.length())
					return false;
			}
		}

		int fragIdx = uri.indexOf('#', pathIdx);
		if (fragIdx > 0)
			fragment = uri.substring(fragIdx + 1);
		else
			fragIdx = uri.length();

		int quesIdx = uri.indexOf('?', pathIdx);
		if (quesIdx > 0)
			query = uri.substring(quesIdx + 1, fragIdx);
		else
			quesIdx = fragIdx;

		path = uri.substring(pathIdx, quesIdx);
		return parsed = true;
	}

	public void reset() {
		scheme = null;
		userinfo = null;
		host = null;
		port = 0;
		path = null;
		portDefaulted = true;
		query = null;
		fragment = null;
		parsed = false;
	}

	public string toString() {
		string result;

		result = scheme + "://";
		if (userinfo != null)
			result += userinfo + "@";
		result += host;
		if (!portDefaulted)
			result += string(port);
		result += path;
		if (query != null)
			result += "?" + query;
		if (fragment != null)
			result += "#" + fragment;
		return result;
	}
}

private char[string] defaultPort = [
	"http": 80,
	"https": 443,
	"ws": 80,
	"wss": 443
];

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
		if (t == HttpToken.END_OF_MESSAGE)
			return true;
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
			name = name.toLowerCase();
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

	public boolean parseResponse(ref<HttpParsedResponse> response) {
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
			name = name.toLowerCase();
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
				if (_tokenValue == null) {
//					logger.debug("token END_OF_MESSAGE");
					return separator(HttpToken.END_OF_MESSAGE);
				}
			}
			if (ch <= 31 || ch >= 127) {
				if (_tokenValue == null) {
					// we have no token, so this is the first character we saw, some special case processing
					if (ch == '\r') {
						ch = _connection.read();
						if (ch != '\n') {
							_connection.ungetc();
							
//							logger.debug("token CR");
							return _previousToken = HttpToken.CR;
						}
						// We have a CR/LF
						
						// Consecutive CRLF tokens means end-of-headers, so don't read ahead - that might hang a get or other
						// message that has no body.
						
						if (_previousToken == HttpToken.CRLF) {
//							logger.debug("token CRLF");
							return HttpToken.CRLF;
						}
						ch = _connection.read();
						if (ch == ' ' || ch == '\t') {
							// Yup, it's a line escape
							skipWhiteSpace();
//							logger.debug("token SP");
							return _previousToken = HttpToken.SP;
						} else {
							_connection.ungetc();
//							logger.debug("token CRLF");
							return _previousToken = HttpToken.CRLF;
						}
					}
					_tokenValue.append(byte(ch));
//					logger.format(log.DEBUG, "CTL '%s'", _tokenValue);
					return _previousToken = HttpToken.CTL;
				}
				_connection.ungetc();
//				logger.format(log.DEBUG, "TOKEN %s", _tokenValue);
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
//					logger.format(log.DEBUG, "TOKEN %s", _tokenValue);
					return _previousToken = HttpToken.TOKEN;
				}
				skipWhiteSpace();
//				logger.debug("token SP");
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
				if (pendingWhiteSpace){
					_tokenValue.append(' ');
					pendingWhiteSpace = false;
				}
				_tokenValue.append(byte(ch));
			}
		}
	}
	
	private HttpToken separator(HttpToken sep) {
		if (_tokenValue == null) {
//			logger.format(log.DEBUG, "separator(%s)", string(sep));
			return _previousToken = sep;
		} else {
//			logger.format(log.DEBUG, "TOKEN '%s' -> %s", _tokenValue, string(sep));
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
//		logger.format(log.DEBUG, "Static Content! fetching %s / %s", _filename, request.serviceResource);
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
			File f;
			if (f.open(filename)) {
				response.ok();
				f.seek(0, Seek.END);
				long size = f.tell(); 
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

public boolean isValidDnsLabel(string label) {
	if (label.length() ==  0)
		return false;
	if (label.length() > 63)
		return false;
	if (!label[0].isAlphanumeric())
		return false;
	if (!label[label.length() - 1].isAlphanumeric())
		return false;
	for (int i = 1; i < label.length() - 2; i++) {
		byte c = label[i];
		if (c != '-' && !c.isAlphanumeric())
			return false;
	}
	return true;
}

public boolean isValidHost(string host) {
	string[] labels = host.split('.');
	if (labels.length() == 0)
		return false;
	// return &/isValidDnsLabel(labels); - needs reductions and vectorized function calls.
	for (i in labels)
		if (!isValidDnsLabel(labels[i]))
			return false;
	return true;
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

