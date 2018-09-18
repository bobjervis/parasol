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
import parasol:net;
import parasol:text;
import native:net.gethostbyname;
import native:net.hostent;
import native:net.in_addr;
import native:net.inet_addr;
import native:net.inet_aton;
import native:net.inet_ntoa;

private ref<log.Logger> logger = log.getLogger("parasol.http.client");

/**
 * This function escapes certain characters in the URI (Universal Resource Identifier) passed
 * as a parameter.
 * 
 * ASCII Alphanumeric characters, unreserved characters and characters that have special meaning
 * in a URI, such as a slash character, are not escaped. All extended Unicode characters are
 * escaped.
 *
 * An escaped character is replaced in the returned string with a three character sequence, a
 * percent sign (%), then two hexadecimal digits (where upper-case letters are used).
 */
public string encodeURI(string uri) {
	string result;

	for (int i = 0; i < uri.length(); i++) {
		byte c = uri[i];
		switch (c) {
		case	';':
		case	',':
		case	'/':
		case	'?':
		case	':':
		case	'@':
		case	'&':
		case	'=':
		case	'+':
		case	'$':
		case	'-':
		case	'_':
		case	'.':
		case	'!':
		case	'~':
		case	'*':
		case	'\'':
		case	'(':
		case	')':
		case	'"':
		case	'0':
		case	'1':
		case	'2':
		case	'3':
		case	'4':
		case	'5':
		case	'6':
		case	'7':
		case	'8':
		case	'9':
		case	'a':
		case	'b':
		case	'c':
		case	'd':
		case	'e':
		case	'f':
		case	'g':
		case	'h':
		case	'i':
		case	'j':
		case	'k':
		case	'l':
		case	'm':
		case	'n':
		case	'o':
		case	'p':
		case	'q':
		case	'r':
		case	's':
		case	't':
		case	'u':
		case	'v':
		case	'w':
		case	'x':
		case	'y':
		case	'z':
		case	'A':
		case	'B':
		case	'C':
		case	'D':
		case	'E':
		case	'F':
		case	'G':
		case	'H':
		case	'I':
		case	'J':
		case	'K':
		case	'L':
		case	'M':
		case	'N':
		case	'O':
		case	'P':
		case	'Q':
		case	'R':
		case	'S':
		case	'T':
		case	'U':
		case	'V':
		case	'W':
		case	'X':
		case	'Y':
		case	'Z':
			result.append(c);
			break;

		default:
			result.append('%');
			result.printf("%2.2X", c);
		}
	}
	return result;
}
/**
 * This function escapes certain characters in the URI (Universal Resource Identifier) passed
 * as a parameter.
 * 
 * This is the function to use when you have a parameter or query string that may have special
 * characters in it that are not allowed in a URI. Apply this function to each query parameter
 * before you compose the URI. This is less likely to cause errors in the URI than to compose
 * first and use {@link parasol:http.encodeURI}.
 *
 * ASCII Alphanumeric characters and unreserved characters. All extended Unicode characters are
 * escaped.
 *
 * An escaped character is replaced in the returned string with a three character seuqence, a
 * percent sign (%), then two hexadecimal digits (where upper-case letters are used).
 */
public string encodeURIComponent(string component) {
	string result;

	for (int i = 0; i < component.length(); i++) {
		byte c = component[i];
		switch (c) {
		case	'-':
		case	'_':
		case	'.':
		case	'!':
		case	'~':
		case	'*':
		case	'\'':
		case	'(':
		case	')':
		case	'"':
		case	'0':
		case	'1':
		case	'2':
		case	'3':
		case	'4':
		case	'5':
		case	'6':
		case	'7':
		case	'8':
		case	'9':
		case	'a':
		case	'b':
		case	'c':
		case	'd':
		case	'e':
		case	'f':
		case	'g':
		case	'h':
		case	'i':
		case	'j':
		case	'k':
		case	'l':
		case	'm':
		case	'n':
		case	'o':
		case	'p':
		case	'q':
		case	'r':
		case	's':
		case	't':
		case	'u':
		case	'v':
		case	'w':
		case	'x':
		case	'y':
		case	'z':
		case	'A':
		case	'B':
		case	'C':
		case	'D':
		case	'E':
		case	'F':
		case	'G':
		case	'H':
		case	'I':
		case	'J':
		case	'K':
		case	'L':
		case	'M':
		case	'N':
		case	'O':
		case	'P':
		case	'Q':
		case	'R':
		case	'S':
		case	'T':
		case	'U':
		case	'V':
		case	'W':
		case	'X':
		case	'Y':
		case	'Z':
			result.append(c);
			break;

		default:
			result.append('%');
			result.printf("%2.2X", c);
		}
	}
	return result;
}
/**
 * NOT YET IMPLEMENTED
 *
 * Do not call this function as it currently just returns its parameter value.
 */
public string decodeURI(string uri) {
	string result;

	for (int i = 0; i < uri.length(); i++) {
		switch (uri[i]) {
		default:
			result.append(uri[i]);
		}
	}
	return result;
}
/**
 * NOT YET IMPLEMENTED
 *
 * Do not call this function as it currently just returns its parameter value.
 */
public string decodeURIComponent(string component) {
	string result;

	for (int i = 0; i < component.length(); i++) {
		switch (component[i]) {
		default:
			result.append(component[i]);
		}
	}
	return result;
}

public class URIError extends Exception {
	public URIError(string message) {
		super(message);
	}
}

/**
 * Initiates a simple HTTP request or opens a Web Socket.
 *
 * This class will accept either http, https, ws or wss URL's. If the ws or
 * wss protocols successfully connect, you can obtain the WebSocket created as a result of the
 * http request from the HttpClient using the {@link parasol:http.HttpClient.webSocket webSocket} method.
 *
 * You can repeat the same URL request again with this object, but the only change you can make
 * that would alter the request itself is you can add another header with {@link setHeader} or
 * change the cipher list using {@link setCipherList}.
 */
public class HttpClient {
	private ref<net.Connection> _connection;
	private ref<WebSocket> _webSocket;
	private ref<HttpParsedResponse> _response;

	private string _protocol;			// required for proper connection
	private string _username;
	private string _password;
	private string _hostname;			// required for proper connection
	private char _port;					// optional (default will be filled in from protocol)
	private string _path;
	private boolean _portDefaulted;
	private unsigned _resolvedIP;
	private string _webSocketProtocol;
	private string _additionalHeaders;

	private string _cipherList;
	/**
	 * Create a client for a simple HTTP request.
	 *
	 * You should use this constructor for http and https URL's.
	 *
	 * @param url The url to use for the HTTP request.
	 */
	public HttpClient(string url) {
		// First, parse out the protocol and hostname.
		parseUrl(url);
	}
	/**
	 * Create a client for a Web Socket request.
	 *
	 * Use this constructor when you wan tto obtain a Web Socket. The 
	 * webSocketProtocol parameter specifies a protocol that the server
	 * expects to see.
	 *
	 * @param url The url to use for the HTTP request.
	 * @param webSocketProtocol A protocol string that describes how
	 * you expect to use the Web Socket
	 */
	public HttpClient(string url, string webSocketProtocol) {
		parseUrl(url);
		_webSocketProtocol = webSocketProtocol;
	}

	~HttpClient() {
		delete _response;
		delete _connection;
		delete _webSocket;
	}
	/**
	 * Add a header to the request.
	 *
	 * Call this method before any request initiation methods (like {@link get} or {@link post}).
	 *
	 * The HttpClient code will automatically include the following headers
	 *
	 * <table>
	 * <tr>
	 *     <th>Name</th>
	 *     <th>Value</th>
	 *     <th>Notes</th>
	 * </tr>
	 * <tr>
	 *     <td class=nowrap><span class=code>Accept</span></td>
	 *     <td class=nowrap><span class=code>charset=UTF-8</span></td>
	 *     <td></td>
	 * </tr>
	 * <tr>
	 *     <td class=nowrap><span class=code>Accept-Language</span></td>
	 *     <td class=nowrap><span class=code>en-US,en;q=0.8</span></td>
	 *     <td></td>
	 * </tr>
	 * <tr>
	 *     <td class=nowrap><span class=code>Content-Length</span></td>
	 *     <td>***</td>
	 *     <td>Only included on POST methods. Contains the length of the body in bytes.</td>
	 * </tr>
	 * <tr>
	 *     <td class=nowrap><span class=code>Host</span></td>
	 *     <td>***</td>
	 *     <td>Contains the host name and port parsed from the url passed in the constructor. A port
	 *         will always be included, defaulting to 80 for http and ws protocols and 443 for https
	 *         and wss.</td>
	 * </tr>
	 * <tr>
	 *     <td class=nowrap><span class=code>Sec-WebSocket-Key</span></td>
	 *     <td>***</td>
	 *     <td>Only used for ws and wss URL's. Contains a random key string (base-64 encoded).</td>
	 * </tr>
	 * <tr>
	 *     <td class=nowrap><span class=code>Sec-WebSocket-Protocol</span></td>
	 *     <td>***</td>
	 *     <td>Only used for ws and wss URL's. Contains the Web Socket protocol string supplied in the constructor.</td>
	 * </tr>
	 * <tr>
	 *     <td class=nowrap><span class=code>Upgrade</span></td>
	 *     <td class=nowrap><span class=code>websocket</span></td>
	 *     <td>Only used for ws and wss URL's.</td>
	 * </tr>
	 * <tr>
	 *     <td class=nowrap><span class=code>User-Agent</span></td>
	 *     <td class=nowrap><span class=code>Parasol/0.1.0</span></td>
	 *     <td>Identifies that this class produced the request, along with its version.</td>
	 * </tr>
	 * </table>
	 *
	 * In the current implementation you cannot specify any of these headers in this method call.
	 *
	 * @param name The header name to use
	 * @param value The value string to use for the header
	 */
	public void setHeader(string name, string value) {
		_additionalHeaders.printf("%s: %s\r\n", name, value);
	}

	private void parseUrl(string url) {
		int colonIdx = -1;
		int hostIdx;
		for (int i = 0; i < url.length(); i++) {
			if (colonIdx == -1 && url[i] == ':')
				colonIdx = i;
			else if (url[i] == '/') {
				if (i != colonIdx + 1) {					// The first slash does not immediately follow the protocol
					// This will leave the URL unparsed, so a call to get() or post() will fail.
					return;
				}
				if (colonIdx == -1)
					_protocol = "file";
				else
					_protocol = url.substring(0, colonIdx);
				if (i + 1 < url.length() && url[i + 1] == '/') {
					hostIdx = i + 2;
					int nextSlash = url.indexOf('/', hostIdx);
					if (nextSlash == -1)
						nextSlash = url.length();
					else
						_path = url.substring(nextSlash);
					substring hostInfo(url, hostIdx, nextSlash);
					substring user;
					substring password;
					int atIdx = hostInfo.indexOf('@');
					int portIdx = hostInfo.indexOf(':', atIdx + 1);
					if (portIdx != -1) {
						boolean success;
						(_port, success) = char.parse(hostInfo.substring(portIdx + 1));
						if (!success)
							// This will leave the URL unparsed, so a call to get() or post() will fail.
							return;				
					} else {
						_port = defaultPort[_protocol];
						if (_port == 0)
							// This will leave the URL unparsed, so a call to get() or post() will fail.
							return;
						_portDefaulted = true;
					}
					if (atIdx != -1) {
						if (portIdx == -1)
							_hostname = string(hostInfo, atIdx + 1);
						else
							_hostname = string(hostInfo, atIdx + 1, portIdx);
						hostInfo = hostInfo.substring(0, atIdx);
						int passIdx = hostInfo.indexOf(':');
						if (passIdx == -1)
							_username = string(hostInfo);
						else {
							_username = string(hostInfo, 0, passIdx);
							_password = string(hostInfo, passIdx + 1);
						}
					} else {
						if (portIdx == -1)
							_hostname = string(hostInfo);
						else
							_hostname = string(hostInfo, 0, portIdx);
					}
//					printf("'%s' :// '%s' : '%s' @ '%s' : '%d' '%s'\n", _protocol, _username, _password, _hostname, _port, _path);
				}
				return;	
			}
		}
	}
	/**
	 * Issue a GET request.
	 *
	 * @return true if the request succeeded, false otherwise.
	 * @return The IPv4 ip address of the host. If the hostname failed to resolve
	 * or if the combination of constructor used and URL protocol are not compatible
	 * with the GET method, the returned ip value is 0.
	 */
	public boolean, unsigned get() {
		return startRequest("GET", null);
	}
	/**
	 * Issue a POST request.
	 *
	 *
	 * If the request is successful, the content of the response object may still indicate
	 * problems. Check the code, and if you expect a body
	 *
	 * @param body The body to accompany the request headers.
	 *
	 * @return true if the request succeeded, false otherwise.
	 * @return The IPv4 ip address of the host. If the hostname failed to resolve
	 * or if the combination of constructor used and URL protocol are not compatible
	 * with the POST method, the returned ip value is 0.
	 */
	public boolean, unsigned post(string body) {
		return startRequest("POST", body);
	}

	private boolean, unsigned startRequest(string method, string body) {
		net.Encryption encryption;
		switch (_protocol) {
		case "ws":
			if (_webSocketProtocol == null) {
				printf("No Web Socket protocol defined.\n");
				return false, 0;
			}
			if (method != "GET")
				return false, 0;
			encryption = net.Encryption.NONE;
			break;

		case "wss":
			if (_webSocketProtocol == null) {
				printf("No Web Socket protocol defined.\n");
				return false, 0;
			}
			if (method != "GET")
				return false, 0;
			encryption = net.Encryption.SSLv23;
			break;

		case "https":
			if (_webSocketProtocol != null) {
				printf("Web Socket protocol defined - not a web socket URL.\n");
				return false, 0;
			}
			encryption = net.Encryption.SSLv23;
			break;

		default:
			if (_webSocketProtocol != null) {
				printf("Web Socket protocol defined - not a web socket URL.\n");
				return false, 0;
			}
			encryption = net.Encryption.NONE;
		}

		ref<net.Socket> socket = net.Socket.create(encryption, _cipherList, null, null, null);
		if (socket == null)
			return false, 0;
		ref<net.Connection> connection;
		unsigned ip;
		(connection, ip) = socket.connect(_hostname, _port);
		if (connection == null) {
			delete socket;
			return false, ip;
		}
		if (!connection.initiateSecurityHandshake()) {
			delete connection;
			delete socket;
			return false, ip;
		}
		boolean expectWebSocket;
		// Delete any connection object left over from a previous request.
		delete _connection;
		// We have a good Connection object, so we are ready for the next stage, send the headers...
		_connection = connection;
		string path;
		if (_path.length() > 0)
			path = _path;
		else
			path = "/";
//		printf("Composing HTTP request...\n");
		_connection.printf("%s %s HTTP/1.1\r\n", method, path);
		string webSocketKey;
		switch (_protocol) {
		case "ws":
		case "wss":
			_connection.write("Upgrade: websocket\r\n");
			_connection.printf("Sec-WebSocket-Protocol: %s\r\n", _webSocketProtocol);
			webSocketKey = computeWebSocketKey(16);
			_connection.printf("Sec-WebSocket-Key: %s\r\n", webSocketKey);
			expectWebSocket = true;
		}
		_connection.printf("Host: %s:%d\r\n", _hostname, _port);
		_connection.write("User-Agent: Parasol/0.1.0\r\n");
		_connection.write("Accept: text/html; charset=UTF-8\r\n");
		_connection.write("Accept-Language: en-US,en;q=0.8\r\n");
		if (_additionalHeaders != null)
			_connection.write(_additionalHeaders);
		if (body.length() > 0)
			_connection.printf("Content-Length: %d\r\n", body.length());
		_connection.printf("\r\n");
		if (body.length() > 0)
			_connection.write(body);
		_connection.flush();
//		printf("HTTP request sent...\n");
		HttpParser parser(_connection);
		_response = new HttpParsedResponse();
		if (!parser.parseResponse(_response)) {
			printf("Malformed response\n");
			return false, ip;
		}
		if (expectWebSocket) {
			if (_response.code != "101") {
				printf("Expecting a Web Socket, not a 101 response.\n");
				_response.print();
				return false, ip;
			}
			string webSocketAccept = computeWebSocketAccept(webSocketKey);
			if (_response.headers["sec-websocket-accept"] != webSocketAccept) {
				printf("Web Socket Accept does not match Web Socket Key\n");
				return false, ip;
			}
			_webSocket = new WebSocket(_connection, false);
			_connection = null;					// The web socket takes possession of the connection object.
		}
		return true, ip;
	}
	/**
	 * Obtain the underlying network Connection object after a request has been
	 * issued.
	 *
	 * @return The connection, or null if a request has failed or has not been initiated.
	 */
	public ref<net.Connection> connection() {
		return _connection;
	}
	/**
	 * Obtain whether the request has a Web Socket.
	 *
	 * This method will always return false before a GET request has been initiated.
	 *
	 * @return true if there is currently a Web Socket object being held by this object
	 */
	public boolean hasWebSocket() {
		return _webSocket != null;
	}
	/**
	 * Extract the Web Socket from this object.
	 *
	 * Once extracted, the {@link hasWebSocket} value will be false and subsequent
	 * calls to this method will yield null.
	 *
	 * @return The value of the Web Socket stored in this object, or null if no such object
	 * is stored.
	 */
	public ref<WebSocket> webSocket() {
		ref<WebSocket> result = _webSocket;
		_webSocket = null;
		return result;
	}
	/**
	 * Set the cipher list to be used on an encrypted connection.
	 *
	 * This will only have an impact on encrypted requests (https and wss).
	 *
	 * You should not need to use this method unless there is some specific
	 * issue with the server you are trying to connect with.
	 *
	 * @param cipherList The SSL cipher-list string to use in the next request.
	 */
	public void setCipherList(string cipherList) {
		_cipherList = cipherList;
	}
	/**
	 * Get the parsed hostname from the URL.
	 *
	 * @return The host name parsed from the URL.
	 */
	public string hostname() {
		return _hostname;
	}
	/**
	 * Get the protocol from the URL.
	 *
	 * If no protocol was specified, the <span class=code>file</span> protocol
	 * will be returned.
	 *
	 * @return The protocol of the parsed URL.
	 */
	public string protocol() {
		return _protocol;
	}
	/**
	 * Get the port from the URL.
	 *
	 * If no port is specified, the port defaults to 80 for http and ws protocols,
	 * or 443 for https and wss protocols).
	 *
	 * @return The port of the parsed URL.
	 */
	public char port() {
		return _port;
	}
	/**
	 * Get the username, if any, from the URL.
	 *
	 * @return The username of the parsed URL, or null if none was specified.
	 */
	public string username() {
		return _username;
	}
	/**
	 * Get the password, if any, from the URL.
	 *
	 * @return The password of the parsed URL, or null if none was specified.
	 */
	public string password() {
		return _password;
	}
	/**
	 * Get whether the port value was defaulted (i.e. not specified).
	 *
	 * @return true if the URL did not include a port, false if it did.
	 */
	public boolean portDefaulted() {
		return _portDefaulted;
	}
	/**
	 * Get the path portion of the URL.
	 *
	 * @return the path port of the URL.
	 */
	public string path() {
		return _path;
	}
	/**
	 * Obtain the response to the request.
	 *
	 * This method returns null (has no response object) before a request is
	 * initiated, or if the request failed before a response could be received, or
	 * if the response text from the server is not valid.
	 *
	 * A request that produces a response of say 404 will have a reponse object, so
	 * be sure to examine the response code before taking any further action.
 	 *
	 * @return The value of the HTTPResponse, if any.
	 */
	public ref<HttpParsedResponse> response() {
		return _response;
	}
}

private char[string] defaultPort = [
	"http": 80,
	"https": 443,
	"ws": 80,
	"wss": 443
];
