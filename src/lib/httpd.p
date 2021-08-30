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
/**
 * Provides facilities to implement an HTTP 1.1 server or client request.
 *
 * This is a work in progress.
 * The server and client are missing a number of HTTP 1.1 functions, such as client side redirection,
 * server side support for '100 Continue' messaging, etc.
 *
 * The server and client do support Web sockets, https and wss protocols.
 */
namespace parasol:http;

import parasol:exception.IllegalOperationException;
import parasol:log;
import parasol:process;
import parasol:storage.File;
import parasol:storage.openBinaryFile;
import parasol:storage.Seek;
import parasol:storage.constructPath;
import parasol:storage.exists;
import parasol:storage.isDirectory;
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
private monitor class HttpServerVolatileData {
	protected boolean _publicSocketStopped;
	protected boolean _secureSocketStopped;

	void stopListening() {
		_publicSocketStopped = true;
		_secureSocketStopped = true;
	}

	void startListening() {
		_publicSocketStopped = false;
		_secureSocketStopped = false;
	}

	boolean publicSocketStopped() {
		return _publicSocketStopped;
	}

	boolean secureSocketStopped() {
		return _secureSocketStopped;
	}
}
 */
/**
 * This class implements an HTTP server. It implements HTTP version 1.1 for an Origin Server only. Hooks are defined to allow for
 * future expansion.
 * 
 *  This class is under construction and as such has numerous places where configurability will need to be expanded in the
 *  future.
 *
 * <b>Handling URL's</b>
 *
 * The HttpServer allows a user to describe the space of acceptable URL's and map them onto either static content
 * located in the local file system, or to dynamic services that will process URL's in code.
 *
 * Before starting the server, the initialization code will need to make one call for each distinct subset of
 * URL's to one of the folloiwng methods:
 *
 * <ul>
 *		<li>{@link staticContent}. For static content available on http or https protocols.
 *		<li>{@link httpStaticContent}. For static content available only on http protocol requests.
 *		<li>{@link httpsStaticContent}. For static content available only on https protocol requests.
 *		<li>{@link service}. For service responses available on http or https protocols.
 *		<li>{@link httpService}. For service responses available only on http protocol requests.
 *		<li>{@link httpsService}. For service responses available only on https protocol requests.
 * </ul> 
 *
 * You must supply an absPath for each such call. All incoming URL's whose absPath begins with the same components
 * as one of the above calls will be routed to that call's service or static content, assuming the protocols
 * match.
 *
 * As a special case, the absPath value of "/" in one of these calls matches all incoming URL's.
 *
 * Note that when processing an incoming URL, the set of absPath parameters to the above calls are checked.
 * The incoming URL will be directed to the service or static conetnt whose absPath matches and is the longest
 * absPath to match the incoming URL. Thus you should not have to take extreme care in ordering your calls.
 * If, for example, you want a custom response to all URL's, you can define a service with an absPath of "/" and
 * then define other services and static content for other paths. An incoming URL will only match the
 * "/" service if no other path does match.
 *
 * @threading
 * Most calls are not thread safe, so calling any of these methods on a server that has been started will
 * produce unpredictable results.
 *
 * The exceptios are {@link stop} and {@link wait} that can be called while the server is running. Note that
 * calling {@link start} on a different thread from {@link stop} or {@link wait} could result in unpredictable
 * behavior. 
 */
public class HttpServer {
	/**
	 * The List of ciphers to use in https protocol handshakes.
	 *
	 * This value has no effect if https is disabled. Unencrypted Http requests do not use a cipher list.
	 */
	public string cipherList;
	/**
	 * The certificates file to use in https protocol handshakes.
	 *
	 * This value has no effect if https is disabled. Unencrypted Http requests do not use a certificates file.
	 */
	public string certificatesFile;
	/**
	 * The private key file to use in https protocol handshakes.
	 *
	 * This value has no effect if https is disabled. Unencrypted Http requests do not use a private key file.
	 */
	public string privateKeyFile;
	/**
	 * The dh parameters file to use in https protocols.
	 *
	 * This value has no effect if https is disabled. Unencrypted Http requests do not use a DH parameters file.
	 */
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
	/**
	 * The various roles a server can play determine how messages should be interpreted. 
	 */
	enum Type {
		ORIGIN,			
		PROXY,
		GATEWAY,
		TUNNEL
	}
	/**
	 * Create an HTTP Origin server. By default, both the http (port 80) and https (port 443)
	 * services are enabled.
	 */
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
	/**
	 * Enables requests on the http protocol.
	 *
	 * This takes effect the next time the server is started.
	 *
	 * @return the prior http status, true if it was enabled, false if not.
	 */
	public boolean enableHttp() {
		boolean priorState = _publicServiceEnabled;
		_publicServiceEnabled = true;
		return priorState;
	}
	/**
	 * Disables requests on the http protocol.
	 *
	 * This takes effect the next time the server is started.
	 *
	 * @return the prior http status, true if it was enabled, false if not.
	 */
	public boolean disableHttp() {
		boolean priorState = _publicServiceEnabled;
		_publicServiceEnabled = false;
		return priorState;
	}
	/**
	 * Sets the enabled status for requests on the http protocol.
	 *
	 * This takes effect the next time the server is started.
	 *
	 * @param newState true to enable http, false to disable.
	 *
	 * @return the prior http status, true if it was enabled, false if not.
	 */
	public boolean setHttpActivation(boolean newState) {
		boolean priorState = _publicServiceEnabled;
		_publicServiceEnabled = newState;
		return priorState;
	}
	/**
	 * Enables requests on the https protocol.
	 *
	 * This takes effect the next time the server is started.
	 *
	 * @return the prior https status, true if it was enabled, false if not.
	 */
	public boolean enableHttps() {
		boolean priorState = _secureServiceEnabled;
		_secureServiceEnabled = true;
		return priorState;
	}
	/**
	 * Disables requests on the https protocol.
	 *
	 * This takes effect the next time the server is started.
	 *
	 * @return the prior https status, true if it was enabled, false if not.
	 */
	public boolean disableHttps() {
		boolean priorState = _secureServiceEnabled;
		_secureServiceEnabled = false;
		return priorState;
	}
	/**
	 * Sets the enabled status for requests on the https protocol.
	 *
	 * This takes effect the next time the server is started.
	 *
	 * @param newState true to enable https, false to disable.
	 *
	 * @return the prior https status, true if it was enabled, false if not.
	 */
	public boolean setHttpsActivation(boolean newState) {
		boolean priorState = _secureServiceEnabled;
		_secureServiceEnabled = newState;
		return priorState;
	}
	/**
	 * Returns the http port.
	 *
	 * @return The http protocol port number.
	 */
	public char httpPort() {
		return _httpPort;
	}
	/**
	 * Returns the https port.
	 *
	 * @return The https protocol port number.
	 */
	public char httpsPort() {
		return _httpsPort;
	}
	/**
	 * Set the value of the http protocol port.
	 *
	 * This takes effect the next time the server is started.
	 *
	 * @param port The port value to use when enabling the http service.
	 */
	public void setHttpPort(char port) {
		_httpPort = port;
	}
	/**
	 * Set the value of the https protocol port.
	 *
	 * This takes effect the next time the server is started.
	 *
	 * @param port The port value to use when enabling the https service.
	 */
	public void setHttpsPort(char sslPort) {
		_httpsPort = sslPort;
	}
	/**
	 * Binds the absPath in any incoming URL to the local file-system
	 * file or directory name filename.
	 *
	 * This content is available on either the http or https protocols.
	 *
	 * @param absPath A prefix of a URL. See the documentation under {@link HttpServer}
	 * for a detailed explanation of how absPath values are compared against an incoming URL.
	 * @param filename The local file system path of the static content to serve up.
	 *
	 * @threading
	 * This method is not thread safe. Calling this method on a server that has been started will
	 * produce unpredictable results.
	 */
	public void staticContent(string absPath, string filename) {
		ref<HttpService> handler = new StaticContentService(filename);
		post(PathHandler(absPath, handler, ServiceClass.ANY_SECURITY_LEVEL));
	}
	/**
	 * Binds the absPath in any incoming URL to the local file-system
	 * file or directory name filename.
	 *
	 * This content is only available on the https protocol.
	 *
	 * @param absPath A prefix of a URL. See the documentation under {@link HttpServer}
	 * for a detailed explanation of how absPath values are compared against an incoming URL.
	 * @param filename The local file system path of the static content to serve up.
	 *
	 * @threading
	 * This method is not thread safe. Calling this method on a server that has been started will
	 * produce unpredictable results.
	 */
	public void httpsStaticContent(string absPath, string filename) {
		ref<HttpService> handler = new StaticContentService(filename);
		post(PathHandler(absPath, handler, ServiceClass.SECURED_ONLY));
	}
	/**
	 * Binds the absPath in any incoming URL to the local file-system
	 * file or directory name filename.
	 *
	 * This content is only available on the http protocol.
	 *
	 * @param absPath A prefix of a URL. See the documentation under {@link HttpServer}
	 * for a detailed explanation of how absPath values are compared against an incoming URL.
	 * @param filename The local file system path of the static content to serve up.
	 *
	 * @threading
	 * This method is not thread safe. Calling this method on a server that has been started will
	 * produce unpredictable results.
	 */
	public void httpStaticContent(string absPath, string filename) {
		ref<HttpService> handler = new StaticContentService(filename);
		post(PathHandler(absPath, handler, ServiceClass.UNSECURED_ONLY));
	}
	/**
	 * Binds the absPath in any incoming URL to a service.
	 *
	 * This service is available on the http or https protocols.
	 *
	 * @param absPath A prefix of a URL. See the documentation under {@link HttpServer}
	 * for a detailed explanation of how absPath values are compared against an incoming URL.
	 * @param handler An instance of a class derived from HttpService that will process any matching
	 * requests.
	 *
	 * @threading
	 * This method is not thread safe. Calling this method on a server that has been started will
	 * produce unpredictable results.
	 */
	public void service(string absPath, ref<HttpService> handler) {
		post(PathHandler(absPath, handler, ServiceClass.ANY_SECURITY_LEVEL));
	}
	/**
	 * Binds the absPath in any incoming URL to a service.
	 *
	 * This service is only available on the https protocol.
	 *
	 * @param absPath A prefix of a URL. See the documentation under {@link HttpServer}
	 * for a detailed explanation of how absPath values are compared against an incoming URL.
	 * @param handler An instance of a class derived from HttpService that will process any matching
	 * requests.
	 *
	 * @threading
	 * This method is not thread safe. Calling this method on a server that has been started will
	 * produce unpredictable results.
	 */
	public void httpsService(string absPath, ref<HttpService> handler) {
		post(PathHandler(absPath, handler, ServiceClass.SECURED_ONLY));
	}
	/**
	 * Binds the absPath in any incoming URL to a service.
	 *
	 * This service is only available on the http protocol.
	 *
	 * @param absPath A prefix of a URL. See the documentation under {@link HttpServer}
	 * for a detailed explanation of how absPath values are compared against an incoming URL.
	 * @param handler An instance of a class derived from HttpService that will process any matching
	 * requests.
	 *
	 * @threading
	 * This method is not thread safe. Calling this method on a server that has been started will
	 * produce unpredictable results.
	 */
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
	/**
	 * Starts an initialized server.
	 *
	 * The server will be started with Internet scope, so requests coming from any internet
	 * interface to the system will reach this server.
	 */
	public void start() {
		start(ServerScope.INTERNET);
	}
	/**
	 * Starts an initialized server.
	 *
	 * The server will be started with provided scope.
	 *
	 * @param scope The scope of the socket connection(s) to use.
	 */
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
				logger.debug("listen failed\n");
				delete socket;
				return null;
			}
		} else {
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
	/**
	 * Stop listening on any open ports.
	 *
	 * Any running threads will soon terminate.
	 *
	 * Active requests will complete.
	 */
	public void stop() {
		if (_publicSocket != null)
			_publicSocket.close();
		if (_secureSocket != null)
			_secureSocket.close();
	}
	/**
	 * Wait for the server to shut down.
	 *
	 * The calling thread will block until all enabled
	 * protocol threads have terminated.
	 *
	 * Calling {@link stop} before calling this method should make
	 * this method terminate when any on-going http requests have completed.
	 */
	public void wait() {
		if (_httpThread != null) {
			_httpThread.join();
			delete _httpThread;
			_httpThread = null;
		}
		if (_publicSocket != null) {
			delete _publicSocket;
			_publicSocket = null;
		}
		if (_httpsThread != null) {
			_httpsThread.join();
			delete _httpsThread;
			_httpsThread = null;
		}
		if (_secureSocket != null) {
			delete _secureSocket;
			_secureSocket = null;
		}
		_requestThreads.waitForIdle();
	}

	void acceptLoop(ref<Socket> socket) {
		while (!socket.closed()) {
			ref<net.Connection> connection = socket.accept();
			if (connection != null) {
				ref<HttpContext> context = new HttpContext(this, connection);
//				logger.debug( "about to execute 'processHttpRequest' threads %d", _requestThreads.idleThreads());
				_requestThreads.execute(processHttpRequest, context);
			}
		}
	}

	boolean dispatch(ref<HttpRequest> request, ref<HttpResponse> response, boolean secured) {
		try {
			for (int i = 0; i < _handlers.length(); i++) {
				if (_handlers[i].absPath == "/") {
					request.serviceResource = request.url.substr(1);
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
						request.serviceResource = request.url.substr(_handlers[i].absPath.length() + 1);
					} else
						request.serviceResource = null;
	//				printf("hit handler %d absPath = %s\n", i, _handlers[i].absPath);
					return _handlers[i].handler.processRequest(request, response);
				}
			}
			logger.error("Failed request for %s from %s", request.serviceResource, request.connection().sourceIPv4());
		} catch (Exception e) {
			logger.error("Failed request for %s from %s: Uncaught exception! %s\n%s", 
								request.serviceResource, net.dottedIP(request.connection().sourceIPv4()), 
								e.message(), e.textStackTrace());
		}
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
		logger.debug( "Could not parse request from %s", net.dottedIP(context.connection.sourceIPv4()));
//		request.print();
		response.error(400);
	}
	response.close();
	delete context;
}
/**
 * The base class used for all services defined on {@link HttpServer}.
 *
 * This is an abstract class, so you must define a sub-class to provide the desired functionality.
 */
public class HttpService {
	/**
	 * This method is called from the HttpServer whenever a URL request arrives that matches this service's
	 * absPath prefix, provided during server initializaton.
	 *
	 * @param request The parsed HTTP request. The service can inspect that various fields, headers and
	 * parameters of the incoming request to decide how to respond.
	 * @param response The object that must be used to respond to the request.
	 *
	 * @return true if the socket connection for this request should be held open, false if the connection
	 * should be closed. For example, a WebSocketFactory will hold the connection open indefinitely after
	 * the inital request is done. For simple HTTP requests the return value should be false.
	 */
	public abstract boolean processRequest(ref<HttpRequest> request, ref<HttpResponse> response);
}
/**
 * The parsed HTTP request being processed by an HttpServer.
 *
 */
public class HttpRequest {
	/**
	 * The method of the request.
	 *
	 * This field will never be set to {@link Method.NO_CONTENTS} in a call to {@link HttpService.processRequest}.
	 *
	 * The field will have the value {@link Method.CUSTOM} if the supplied method does not match any of the
	 * pre-defined HTTP method strings exactly. The matching is case-sensitive. Use the methodString parameter 
	 * to distinguish different CUSTOM methods.
	 */
	public Method method;
	/**
	 * The literal string value of the HTTP method token.
	 */
	public string methodString;
	/**
	 * The url portion of the request, excluding any query string (and the ? character initiaing the query string).
	 */
	public string url;
	/**
	 * The query string portion of the URL in the request.
	 *
	 * Note that if no query string is present (no ? character appears), this field is set to null.
	 */
	public string query;
	/**
	 * The HTTP version string supplied with the request.
	 */
	public string httpVersion;
	/**
	 * The set of parsed headers.
	 */
	public string[string] headers;
	/**
	 * The url field value with the service's absPath prefix stripped away.
	 *
	 * If the service was defined with an absPath of "/", only the initial "/" character is stripped
	 * from the url.
	 *
	 * If any other absPath is defined for the service, then if the request URL string exactly matches the
	 * service's absPath, this field will be set to null. If the request URL is longer, then the absPath
	 * prefix is stripped including the path separator at the end of the prefix.
	 */
	public string serviceResource;
	
	private string[string] _parameters;			// These will be the parsed query parameters.
	private ref<net.Connection> _connection;
	/**
	 * The set of values returned in the method field of the HttpRequest class.
	 */
	public enum Method {
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
	/**
	 * To construct an HttpRequest, you must supply a live {@link parasol:net.Connection} object. All
	 * fields can then be intiialized the user code.
	 *
	 * This constructor is primarily useful to either test a service or spoof a request in a call to the
	 * service's processRequest method.
	 */
	public HttpRequest(ref<net.Connection> connection) {
		_connection = connection;
	}
	/**
	 * A convenience method to extract the family field of the source connection's network address.
	 *
	 * @return Any of the AF_* values defined in {@link native:net}. Most likely, the value will be
	 * {@link native:net.AF_INET}.
	 */
	public int sourceFamily() {
		return _connection.sourceAddress().sin_family;
	}
	/**
	 * A convenience method to extract the port field of the source connection's network address.
	 *
	 * @return The integer value of the source connection's port.
	 */
	public int sourcePort() {
		return _connection.sourceAddress().sin_port;
	}
	/**
	 * A convenience method to extract the IP field of the source connection's IPv4 network address.
	 *
	 * @return The value of the IP address field of the source connection's network address.
	 */
	public unsigned sourceIP() {
		return _connection.sourceAddress().sin_addr.s_addr;
	}
	/**
	 * Fetch the content length of the request.
	 *
	 * @return The integer value of the content-length HTTP header. If the header is absent or
	 * not a valid integer, the method returns zero.
	 */
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
	/**
	 * Fetches a query parameter by name.
	 *
	 * Parameter names are case sensitive.
	 *
	 * @param name The parameter name.
	 *
	 * @return The value of the named parameter, or null if the named parameter is not present in the request.
	 */
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
	/**
	 * Fetch the Connection object of the request.
	 *
	 * The Connection will generally still be open, allowing the service to respond to the reuqest.
	 *
	 * @return A reference to the Connection object of the request.
	 */
	public ref<net.Connection> connection() {
		return _connection;
	}
	/**
	 * A debugging method to print the result of the {@link toString} method onto the process' stdout stream.
	 */
	public void print() {
		process.stdout.write(toString());
	}
	/**
	 * Produce a string representation of the request object.
	 *
	 * This is a debugging aid. The format of the data is intended to be human readable.
	 *
	 * @return The string representation of the object.
	 */
	public string toString() {
		string result;

		unsigned ip = sourceIP();
		result.printf("Source family %d %s:%d\n", sourceFamily(), net.dottedIP(ip), sourcePort());
		result.printf("Method           %s(%s)\n", string(method), methodString);
		result.printf("Url              %s\n", url);
		if (query != null)
			result.printf("query            %s\n", query);
		result.printf("HTTP Version     %s\n", httpVersion);
		if (headers.size() > 0)
			result.printf("Headers:\n");
		for (string[string].iterator i = headers.begin(); i.hasNext(); i.next()) {
			result.printf("  %-20s %s\n", i.key(), i.get());
		}
		result.printf("body size: %d\n", contentLength());
		return result;
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
	 * The HTTP code returned from the server. For example, a 'page not found' error
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
 * The second phase involves the generation of headers. You are responsible for generating the headers
 * so that headers are not duplicated.
 *
 * Once you have written all headers, you can call {@link endOfHeaders} to signal that you have
 * no more headesr to include. If you transmit a response body, using methods like {@link printf},
 * {@link write} or {@link putc}, you do not need to call {@linnk endOfHeaders}. Those functions wil
 * call {@link endOfHeaders} thenselves on the first call in a response.
 */
public class HttpResponse {
	private ref<net.Connection> _connection;
	private boolean _statusWritten;
	private boolean _headersEnded;

	HttpResponse() {
		_connection = null;
	}
	
	HttpResponse(ref<net.Connection> connection) {
		_connection = connection;
	}
	
	void close() {
		if (!_statusWritten)
			throw IllegalOperationException("no status line");
		if (!_headersEnded)
			endOfHeaders();
		_connection.flush();
		_connection.close();
	}
	/**
	 * This writes content data to the connection.
	 *
	 * Calling this method before writing the status line will throw an 
	 * {@link parasol:exception.IllegalOperationException}.
	 *
	 * Calling this method before calling {@link endOfHeaders} will close the
	 * headers section.
	 *
	 * @param format A valid printf format string. See the description at {@link parasol:stream:Writer.printf}
	 * for details concerning the contents of a format string.
	 * @param arguments Zero or more arguments. The number and type of arguments is determined by the 
	 * contents of the format string.
	 */
	public void printf(string format, var... arguments) {
		if (!_statusWritten)
			throw IllegalOperationException("no status line");
		if (!_headersEnded)
			endOfHeaders();
		_connection.printf(format, arguments);
	}
	/**
	 * This writes content data to the connection.
	 *
	 * Calling this method before writing the status line will throw an 
	 * {@link parasol:exception.IllegalOperationException}.
	 *
	 * Calling this method before calling {@link endOfHeaders} will close the
	 * headers section.
	 *
	 * @param s The string to be written to the connection.
	 */
	public void write(string s) {
		if (!_statusWritten)
			throw IllegalOperationException("no status line");
		if (!_headersEnded)
			endOfHeaders();
		_connection.write(s);
	}
	/**
	 * This writes content data to the connection.
	 *
	 * Calling this method before writing the status line will throw an 
	 * {@link parasol:exception.IllegalOperationException}.
	 *
	 * Calling this method before calling {@link endOfHeaders} will close the
	 * headers section.
	 *
	 * @param data A pointer to an array of bytes.
	 * @param length The number of bytes to write to the connection.
	 */
	public void write(pointer<byte> data, int length) {
		if (!_statusWritten)
			throw IllegalOperationException("no status line");
		if (!_headersEnded)
			endOfHeaders();
		for (int i = 0; i < length; i++)
			_connection.putc(data[i]);
	}
	/**
	 * This writes content data to the connection.
	 *
	 * Calling this method before writing the status line will throw an 
	 * {@link parasol:exception.IllegalOperationException}.
	 *
	 * Calling this method before calling {@link endOfHeaders} will close the
	 * headers section.
	 *
	 * @param c The byte to be written to the connection.
	 */
	public void putc(byte c) {
		if (!_statusWritten)
			throw IllegalOperationException("no status line");
		if (!_headersEnded)
			endOfHeaders();
		_connection.putc(c);
	}
	/**
	 * A convenience function to write a standard status line for a number of error
	 * conditions.
	 *
	 * If the status line has already been written by error, redirect, ok or a direct call
	 * to statusLine, this method will throw an IllegalOperation Exception.
	 *
	 * <ul>
	 *		<li>400 <b>Bad Request</b>: The request could not be understood because of a syntax
	 *		error. Do not retry the request.
	 *		<li>401 <b>Unauthorized</b>: Either credentials were not supplied and are required, or
	 *		the supplied credentials were not recognized. 
	 *		<li>403 <b>Forbidden</b>: The request was recognized and the server refuses to fulfill it. 
	 *		Authorization will not help. The request should not be repeated. A server may choose to 
	 *		include diagnostic information in the response.
	 *		<li>404 <b>Not Found</b>: The reuested resource is unavailable. There is no indication of
	 *		the cause, whether retrying later might work.
	 *		<li>405 <b>Method Not Allowed</b>: The specified method is not allowed for the requested
	 *		URI. The response must include an Allow header with the list of recognized methods.
	 *		<li>410 <b>Gone</b>: The requested resource is gone and no forwarding address is known.
	 *		The client should remove links to this resource.
	 *		<li>500 <b>Internal Server Error</b>: The server deteted an internal error of some kind.
	 *		Diagnostic information should be supplied in the response.
	 *		<li>501 <b>Not Implemented</b>: The server does not support the functionality required
	 *		for this request. This is the appropriate response when a server does not recognize
	 *		the requested method for any resource.
	 * </ul>
	 */
	public void error(int statusCode) {
		string reasonPhrase;
		switch (statusCode) {
		case	400:	reasonPhrase = "Bad Request";			break;
		case	401:	reasonPhrase = "Unauthorized";			break;
		case	403:	reasonPhrase = "Forbidden";				break;
		case	404:	reasonPhrase = "Not Found";				break;
		case	405:	reasonPhrase = "Method Not Allowed";	break;
		case	410:	reasonPhrase = "Gone";					break;
		case	500:	reasonPhrase = "Internal Server Error";	break;
		case	501:	reasonPhrase = "Not Implemented";		break;
		default:
			throw IllegalOperationException(string(statusCode));
		}
		statusLine(statusCode, reasonPhrase);
	}
	/**
	 * Respond with a redirect to a given uri.
	 *
	 * This method writes the status line and possibly one or two headers.
	 *
	 * The recommendation for codes other than 304 is to follow this call by writing a short
	 * web page that contains a link the user can click on to get to 
	 * the intended destination.
	 *
	 * If the status line has already been written by error, redirect, ok or a direct call
	 * to statusLine, this method will throw an IllegalOperation Exception.
	 *
	 * <ul>
	 *		<li>300 <b>Multiple Choices</b>: Not widely used, the response should contain
	 *		multiple alternate representations with corresponding URI's. THere is no
	 *		standard for specifying the choises. The uri argument, if supplied, expresses
	 *		the preferred destination of the server.
	 *		<li>301 <b>Moved Permanently</b>: The requested URI has been permanently moved to 
	 *		a new location (the uri argument). The client should update any link information
	 *		to the new uri value.
	 *		<li>302 <b>Found</b>: The requested URI is temporarily found at the new location.
	 *		The client should continue to request the resource from the original location
	 *		and should not update any local links.
	 *		<li>303 <b>See Other</b>: The response to the request can be found under the uri
	 *		argument's location and should be retrieved with a GET request. The intent is
	 *		to allow a POST-activated script to redirect the user to another resource.
	 *		<li>304 <b>Not Modified</b>: This should occur in response to a conditional GET and should
	 *		not transmit the actual resource data. If the client does not have the resource's value
	 *		cached, it should re-issue the GET without the condition to fetch the value.
	 *		<li>305 <b>Use Proxy</b>: The client must access the requested resource through
	 *		the proxy given by the uri argument.
	 *		<li>306 <b>Temporary Redirect</b>: The requested URI is temporarily found at the new location.
	 *		The client should continue to request the resource from the original location
	 *		and should not update any local links.
	 * </ul>
	 * @param statusCode The status code to include in the status line. The
	 * values can only be 300 through 305 or 307. Calling this method with any other
	 * status code will throw an IllegalOperationException.
	 * @param uri The redirect URI, which willbe written to a Location header.
	 * The intention is that the browser should re-issue the request to the new location.
	 * If the value is null, no Location header is written.
	 */
	public void redirect(int statusCode, string uri) {
		switch (statusCode) {
		case 300:
			statusLine(300, "Multiple Choices");
			break;

		case 301:
			statusLine(301, "Moved Permanently");
			break;

		case 302:
			statusLine(302, "Found");
			break;

		case 303:
			statusLine(303, "See Other");
			break;

		case 304:
			statusLine(304, "Not Modified");
			break;

		case 305:
			statusLine(305, "Use Proxy");
			break;

		case 307:
			statusLine(307, "Temporary Redirect");
			break;

		default:
			throw IllegalOperationException(string(statusCode));
		}
		if (uri != null)
			header("Location", uri);
	}
	/**
	 * If the status line has already been written by error, redirect, ok or a direct call
	 * to statusLine, this method will throw an IllegalOperation Exception.
	 */
	public void ok() {
		statusLine(200, "OK");
	}
	/**
	 * If the status line has already been written by {@link error}, {@link redirect}, {@link ok}
	 * or a direct call to {@code statusLine}, this method will throw an IllegalOperation Exception.
	 *
	 * @param statusCode The three digit HTTP status code for an HTTP response message.
	 * @param reasonPhrase The text of the reason phrase to be included in the HTTP response status line.
	 */
	public void statusLine(int statusCode, string reasonPhrase) {
		if (_statusWritten)
			throw IllegalOperationException("status line already written");
		_statusWritten = true;
		_connection.printf("HTTP/1.1 %d %s\r\n", statusCode, reasonPhrase);
	}
	/**
	 * Add a header to the response.
	 *
	 * @param label The header name.
	 * @param value The value of the header.
	 */
	public void header(string label, string value) {
		if (!_statusWritten)
			throw IllegalOperationException("no status line");
		if (_headersEnded)
			throw IllegalOperationException("heaaders ended");
		_connection.printf("%s: %s\r\n", label, value);
	}
	/**
	 * Signal the end of the headers section of your response.
	 */
	public void endOfHeaders() {
		if (!_statusWritten)
			throw IllegalOperationException("no status line");
		_headersEnded = true;
		_connection.write("\r\n");
		_connection.flush();
	}
	/**
	 * Get the underlying socket Connection object.
	 *
	 * @return A reference to the socket Connection object.
	 */
	public ref<net.Connection> connection() {
		return _connection;
	}
	/**
	 * Flush your buffered response text to the connection.
	 *
	 * Under most circumstances, you will not need to call this method
	 * explicitly. Returning from your {@link processRequest} method
	 * will call this method for you.
	 *
	 * If you are using '100 Conitnue' to delay transmission of the message
	 * body, you will need to explicitly call this method to respond with your
	 * headers before you then read the sender's message body.
	 */
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
	/**
	 * The scheme of the URI, such as {@code http}, {@code https}, etc.
	 *
	 * This is all the text that appears ahead of the first colon character in the
	 * URI string.
	 *
	 * If no colon character appears in the URI, this field is set to null.
	 */
	public string scheme;
	/**
	 * The userinfo portion of the URI.
	 *
	 * This is the text that appears after the initial // and ahead of the first
	 * at-sign character in the URI string.
	 *
	 * If the URI has no initial // or no @ character between the // and the first slash
	 * character afterward, this field will be set to null.
	 */
	public string userinfo;
	/**
	 * The host portion of the URI.
	 *
	 * This is the portion of the URI string following any initial // and any user info
	 * string, but before the first slash of the path.
	 *
	 * If there is no initial // in the URI, the host field is set to null.
	 *
	 * The host string will contain a port value if it is included in the URI, but if a host
	 * does not include an explicit port, no default port value will be added. The host
	 * string is always the text that appeared in the original URI.
	 */
	public string host;
	/**
	 * The path portion of the URI.
	 *
	 * If the URI begins with a //, the path is the string from the next slash
	 * character. If there is no initial //, then the path begins after the colon character
	 * of the scheme.
	 *
	 * The path extends to the first question-mark or the first hash character.
	 *
	 * If the URI successfully parses, this field is never null.
	 */
	public string path;
	/**
	 * The query portion of the URI.
	 *
	 * If there is a question-mark character at the end of the path portion of the URI,
	 * this field is set to the text after the question-makr and up to any hash character.
	 *
	 * If no hash character appears in the URI, any query string extends to the end of the URI.
	 *
	 * If no question-mark character appears in the URI, this field is set to null.
	 */
	public string query;
	/**
	 * The fragment portion of the URI.
	 *
	 * If there is a hash character in the URI, this field is set to the text after the hash
	 * character up to the end of the URI.
	 *
	 * If no hash character appears in the URI, this field is set to null.
	 */
	public string fragment;
	/**
	 * The (possibly implied) port of the host portion of the URI.
	 *
	 * If no scheme appears in the URI, this value will be zero (and the {@link portDefaulted}
	 * field will be set to true).
	 *
	 * If a scheme does appear and the host string contains a port, the value is converted
	 * and stored in this field. If the value is not a valid port number (between 1 and 65536) 
	 * the {@link parse} method will throw an {@link IllegalOperationException}.
	 *
	 * If a scheme is specified with a host string that does not include a port, then this field
	 * is set to the default port for that scheme.
	 */
	public char port;
	/**
	 * Whether a port was set from the default for the scheme.
	 *
	 * The value is true if there is no scheme, or if there is a scheme but no port specified in
	 * the host string.
	 *
	 * If this field is false, the host string is present and does contain a value port value.
	 */
	public boolean portDefaulted;
	/**
	 * A success indicator for the last call to parse.
	 *
	 * This field is set to true if the last call to {@link parse} succeeded and no call to
	 * {@link reset) has been made or the field otherwise modified.
	 */
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
			scheme = uri.substr(0, colonIdx);

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
					// This is: scheme://authority path
					int atIdx = uri.indexOf('@', authIdx);
					if (atIdx > 0 && atIdx < pathIdx) {
						userinfo = uri.substr(authIdx, atIdx);
						authIdx = atIdx + 1;
					}
					int portIdx = uri.indexOf(':', authIdx);
					if (portIdx > 0 && portIdx < pathIdx) {
						boolean success;
						(port, success) = char.parse(uri.substr(portIdx + 1, pathIdx));
						if (!success || port == 0)
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
					host = uri.substr(authIdx, portIdx);
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
			fragment = uri.substr(fragIdx + 1);
		else
			fragIdx = uri.length();

		int quesIdx = uri.indexOf('?', pathIdx);
		if (quesIdx > 0)
			query = uri.substr(quesIdx + 1, fragIdx);
		else
			quesIdx = fragIdx;

		if (pathIdx < quesIdx)
			path = uri.substr(pathIdx, quesIdx);
		else
			path = "/";
		return parsed = true;
	}
	/**
	 * Clear the parsed field of this object.
	 *
	 * All public fields are cleared. Strings are set to null, the port field is set to zero
	 * and {@link portDefaulted} is set to true and {@link parsed} is set to false.
	 */
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
	/**
	 * Return the host, with the port value appended if it was defaulted.
	 */
	public string authority() {
		if (host == null)
			return host;
		string a = host;
		if (portDefaulted)
			a += ":" + string(port);
		return a;
	}
	/**
	 * Fetch the HTTP request URI.
	 *
	 * @return The portion of the parsed URI that would appear in an HTTP request line (excludes scheme and authority).
	 */
	public string httpRequestUri() {
		string result = path;

		if (query != null)
			result += "?" + query;
		return result;
	}
	/**
	 * Convert the parsed URI to a string.
	 *
	 * If the contents of this Uri object was composed by a successfil call to {@link parse}, then
	 * this will generally return the original URI string.
	 *
	 * If the fields were filled in explicitly (or selective fields modified after a call to
	 * {@link parse}), the resulting string may not be a well-formed URI. This method does not validate
	 * the fields.
	 */
	public string toString() {
		string result;

		if (scheme != null) {
			result = scheme + "://";
			if (userinfo != null)
				result += userinfo + "@";
			result += host;
			if (!portDefaulted)
				result += string(port);
		} else
			result = "";
		result += path;
		if (query != null)
			result += "?" + query;
		if (fragment != null)
			result += "#" + fragment;
		return result;
	}
}

private char[string] defaultPort = [
	"acap": 674, 
	"afp": 548, 
	"dict": 2628, 
	"dns": 53, 
	"ftp": 21, 
	"git": 9418, 
	"gopher": 70, 
	"http": 80, 
	"https": 443, 
	"imap": 143, 
	"ipp": 631, 
	"ipps": 631, 
	"irc": 194, 
	"ircs": 6697, 
	"ldap": 389, 
	"ldaps": 636, 
	"mms": 1755, 
	"msrp": 2855, 
	"mtqp": 1038, 
	"nfs": 111, 
	"nntp": 119, 
	"nntps": 563, 
	"pop": 110, 
	"prospero": 1525, 
	"redis": 6379, 
	"rsync": 873, 
	"rtsp": 554, 
	"rtsps": 322, 
	"rtspu": 5005, 
	"sftp": 22, 
	"smb": 445, 
	"snmp": 161, 
	"ssh": 22, 
	"svn": 3690, 
	"telnet": 23, 
	"ventrilo": 3784, 
	"vnc": 5900, 
	"wais": 210, 
	"ws": 80, 
	"wss": 443, 
];

class HttpParser {
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
		switch (_tokenValue) {
		case "OPTIONS":
			_request.method = HttpRequest.Method.OPTIONS;
			break;

		case "GET":
			_request.method = HttpRequest.Method.GET;
			break;

		case "HEAD":
			_request.method = HttpRequest.Method.HEAD;
			break;

		case "POST":
			_request.method = HttpRequest.Method.POST;
			break;

		case "PUT":
			_request.method = HttpRequest.Method.PUT;
			break;

		case "DELETE":
			_request.method = HttpRequest.Method.DELETE;
			break;

		case "TRACE":
			_request.method = HttpRequest.Method.TRACE;
			break;

		case "CONNECT":
			_request.method = HttpRequest.Method.CONNECT;
			break;

		default:
			_request.method = HttpRequest.Method.CUSTOM;
		}
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
	
					default:
						_connection.ungetc();
						return _tokenValue != null;
					}
				}

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
		if (t != HttpToken.TOKEN) {
			logger.error("HTTP response does not begin with a token");
			return false;
		}
		if (_tokenValue != "HTTP") {
			logger.error("HTTP response does not begin with HTTP");
			return false;
		}
		if (token() != HttpToken.SL) {
			logger.error("HTTP response does not begin with HTTP /");
			return false;
		}
		if (token() != HttpToken.TOKEN) {
			logger.error("HTTP response does not begin with HTTP / and a code token");
			return false;
		}
		response.httpVersion = _tokenValue;
		if (token() != HttpToken.SP) {
			logger.error("HTTP response does not begin with HTTP / code-token SP");
			return false;
		}
		if (token() != HttpToken.TOKEN) {
			logger.error("HTTP response does not begin with HTTP / code-token SP token");
			return false;
		}
		response.code = _tokenValue;
		if (token() != HttpToken.SP) {
			logger.error("HTTP response does not begin with HTTP / code=-token SP token SP");
			return false;
		}
		response.reason = readToEOL();
				
		for (;;) {
			t = token();
			if (t == HttpToken.CRLF)
				break;
			if (t != HttpToken.TOKEN) {
				logger.error("HTTP response header does not begin with a token");
				return false;
			}
			string name = _tokenValue;
			if (token() != HttpToken.CO) {
				logger.error("HTTP response header does not begin with a token CO");
				return false;
			}
			skipWhiteSpace();
			if (!fieldValue()) {
				logger.error("HTTP response header does not have a proper value");
				return false;
			}
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
//					logger.debug( "CTL '%s'", _tokenValue);
					return _previousToken = HttpToken.CTL;
				}
				_connection.ungetc();
//				logger.debug( "TOKEN %s", _tokenValue);
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
//					logger.debug( "TOKEN %s", _tokenValue);
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
//			logger.debug( "separator(%s)", string(sep));
			return _previousToken = sep;
		} else {
//			logger.debug( "TOKEN '%s' -> %s", _tokenValue, string(sep));
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
/**
 * This is the implementation class for hosting static content through an {@link HttpServer}.
 */
class StaticContentService extends HttpService {
	private string _filename;
	
	StaticContentService(string filename) {
		_filename = filename;
	}

	public boolean processRequest(ref<HttpRequest> request, ref<HttpResponse> response) {
//		logger.debug( "Static Content! fetching %s / %s", _filename, request.serviceResource);
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
			if (isDirectory(filename)) {
				filename += "/index.html";
				if (!exists(filename) || isDirectory(filename)) {
					response.error(404);
					return false;
				}
			}
			File f;
			if (f.open(filename)) {
				response.ok();
				f.seek(0, Seek.END);
				long size = f.tell(); 
				f.seek(0, Seek.START);
				response.header("Content-Length", string(size));
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
/**
 * Tests whether a given string is a valid DNS value.
 *
 * A string is a valid DNS label if it contains between 1 and 63 ASCII alpha-numeric characters and dashes.
 * Dashes may not appear as the first or last character of the label.
 * 
 * @param label The string to be tested.
 *
 * @return true if the label is a valid DNS label, false if the label argument is null, the empty string
 * or otherwise not a valid DNS label.
 */
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
/**
 * Tests whether a host string is well-formed.
 *
 * A host string is a sequence of one or more valid DNS labels separated by periods.
 *
 * @param host The string to test.
 *
 * @return true if the host arguemnt is a valid host string, false otherwise.
 */
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

