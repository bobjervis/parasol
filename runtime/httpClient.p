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

import parasol:exception.IllegalOperationException;
import parasol:log;
import parasol:net;
import parasol:text;
import parasol:time;
import native:net.gethostbyname;
import native:net.hostent;
import native:net.in_addr;
import native:net.inet_addr;
import native:net.inet_aton;
import native:net.inet_ntoa;

private ref<log.Logger> logger = log.getLogger("parasol.http.client");
/**
 * Content type value for xml data.
 */
public string XML_CONTENT_TYPE = "application/xml";
/**
 * The name of the content-md5 header.
 */
public string CONTENT_MD5_HEADER = "content-md5";
/**
 * The name of the content-length header.
 */
public string CONTENT_LENGTH_HEADER = "content-length";
/**
 * The name of the content-type header.
 */
public string CONTENT_TYPE_HEADER = "content-type";
/**
 * The date format string appropriate to produce an RFC 822-compatible date format without the
 * z time zone element.
 */
public string RFC822_DATE_FORMAT_STR_MINUS_Z = "EEE, dd mm yy HH:MM:SS";
/**
 * The date format string appropriate to produce an RFC 822-compatible date format with the
 * z time zone element.
 */
public string RFC822_DATE_FORMAT_STR_WITH_Z = "EEE, dd mm yy HH:MM:SS xx";
/**
 * Convert a time to RFC 822 format in the local time zone.
 *
 * @param t The time to convert.
 *
 * @return The converted date/time string.
 */
public string toRfc822LocalTime(time.Instant t) {
	time.Date d(t);
	return d.format(RFC822_DATE_FORMAT_STR_WITH_Z);
}
/**
 * Convert a time to RFC 822 format in the UTC (GMT) time zone.
 *
 * @param t The time to convert.
 *
 * @return The converted date/time string.
 */
public string toRfc822UTCTime(time.Instant t) {
	time.Date d(t, &time.UTC);
	return d.format(RFC822_DATE_FORMAT_STR_MINUS_Z);
}
/**
 * Convert a time to RFC 822 format in the local time zone.
 *
 * @param t The time to convert.
 *
 * @return The converted date/time string.
 */
public string toRfc822LocalTime(time.Time t) {
	time.Date d(t);
	return d.format(RFC822_DATE_FORMAT_STR_WITH_Z);
}
/**
 * Convert a time to RFC 822 format in the UTC (GMT) time zone.
 *
 * @param t The time to convert.
 *
 * @return The converted date/time string.
 */
public string toRfc822UTCTime(time.Time t) {
	time.Date d(t, &time.UTC);
	return d.format(RFC822_DATE_FORMAT_STR_MINUS_Z);
}
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
 *
 * @param uri The uri string to be encoded.
 *
 * @return The encoded uri string.
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
 *
 * @param component The component string to be encoded.
 *
 * @return The encoded component string.
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
 * This returns the uri string in a form that replaces certain escape sequences with the escaped character values.
 *
 * Certain escaped characters are not changed: ; , / ? : @ & = + $ #
 *
 * These characters have significance in the parsing of a URI and unescaping them could yield and invalid uri.
 *
 * @param uri The uri string to be decoded.
 *
 * @return The decode URI with certain escape sequences replaced with their character values.
 *
 * @exception URIError when the input uri string contains malformed % escape sequences (such as a percent character
 * as the last character of the uri string).
 */
public string decodeURI(string uri) {
	string result;

	for (int i = 0; i < uri.length(); i++) {
		byte c = uri[i];
		switch (c) {
		case	'%':
			if (i + 2 !< uri.length() || !uri[i + 1].isHexDigit() || !uri[i + 2].isHexDigit())
				throw URIError(uri);
			byte b;
			i++;
			if (uri[i].isDigit())
				b = byte(uri[i] - '0');
			else
				b = byte(10 + uri[i].toLowerCase() - 'a');
			i++;
			int b2;
			if (uri[i].isDigit())
				b2 = byte(uri[i] - '0');
			else
				b2 = byte(10 + uri[i].toLowerCase() - 'a');
			b = byte((b << 4) + b2);
			if ((b & 0x80) == 0) {
				switch (b) {
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
				case	'#':
					result.append('%');
					result.append(uri[i - 1]);
					result.append(uri[i]);
					break;

				default:
					result.append(byte(b));
				}
			} else
					result.append(byte(b));
			break;

		default:
			result.append(c);
			break;
		}
	}
	return result;
}
/**
 * This returns a URI component with all escaped characters converted to their unescaped value.
 *
 * @param component The URI component, possibly containing escape sequences.
 *
 * @return The converted component string with no escape sequences present.
 *
 * @exception URIError when the input component string contains malformed % escape sequences (such as a percent character
 * as the last character of the component string).
 */
public string decodeURIComponent(string component) {
	string result;

	for (int i = 0; i < component.length(); i++) {
		byte c = component[i];
		switch (c) {
		case	'%':
			if (i + 2 !< component.length() || !component[i + 1].isHexDigit() || !component[i + 2].isHexDigit())
				throw URIError(component);
			byte b;
			i++;
			if (component[i].isDigit())
				b = byte(component[i] - '0');
			else
				b = byte(10 + component[i].toLowerCase() - 'a');
			i++;
			byte b2;
			if (component[i].isDigit())
				b2 = byte(component[i] - '0');
			else
				b2 = byte(10 + component[i].toLowerCase() - 'a');
			result.append(byte((b << 4) + b2));
			break;

		default:
			result.append(c);
			break;
		}
	}
	return result;
}
/**
 * This exception is thrown from the decode functions when the encoded input is malformed.
 */
public class URIError extends Exception {
	/**
	 * The constructor takes a message.
	 *
	 * @param message The message to be returned by the {@link message} method.
	 */
	public URIError(string message) {
		super(message);
	}
}
/**
 * Reports the either success or a reason for failure.
 */
public enum ConnectStatus {
	/**
	 * Connection succeeded.
	 */
	OK,
	/**
	 * Connection failed, you provided a web socket URL, but no protocol.
	 */
	NO_PROTOCOL,
	/**
	 * Connection failed, you provided a web socket URL, but did not use GET.
	 */
	WS_NOT_GET,
	/**
	 * Connection failed, you provided a web socket protocol, but not a web socket URL.
	 */
	WS_PROTOCOL_NOT_ALLOWED,
	/**
	 * Connection failed, you could not obtain a socket.
	 */
	NO_SOCKET,
	/**
	 * Connection failed, call to socket connect failed.
	 */
	CONNECT_FAILED,
	/**
	 * Connection failed, you asked for a secure connection, but the handshake failed.
	 */
	SSL_HANDSHAKE_FAILED,
	/**
	 * Connection failed, the response header was not formatted correctly.
	 */
	MALFORMED_RESPONSE,
	/**
	 * Connection failed, you provided a web socket URL, but the server would not 
	 * give you a web socket connection.
	 */
	WEB_SOCKET_REFUSED,
	/**
	 * Connection failed, the web socket accept header did not match the expected value.
	 */
	WEB_SOCKET_ACCEPT_MISMATCH
}
/**
 * Initiates a simple HTTP request or opens a Web Socket.
 *
 * This class will accept either http, https, ws or wss URL's. If the ws or
 * wss protocols successfully connect, you can obtain the WebSocket created as a result of the
 * http request from the Client using the {@link parasol:http.Client.webSocket webSocket} method.
 *
 * You can repeat the same URL request again with this object, but the only change you can make
 * that would alter the request itself is you can add another header with {@link setHeader} or
 * change the cipher list using {@link setCipherList}.
 *
 * Once you have established a web socket connection, you can delete the http.Client.
 */
public class Client {
//	@Constant
	private static string USER_AGENT = "Parasol/0.1.0";

	private ref<net.Connection> _connection;
	private ref<WebSocket> _webSocket;
	private ref<ParsedResponse> _response;

	private Uri _uri;			// required for proper connection
	private unsigned _resolvedIP;
	private string _webSocketProtocol;
	private string[string] _headers;
	private string[string] _queryParameters;
	private ref<log.Logger> _logger;

	private string _cipherList;
	/**
	 * The user agent string to be included in requests.
	 *
	 * The default value is 'Parasol/0.1.0'.
	 * 
	 * If you explicitly define a user-agent header, this member is ignored.
	 */
	public string userAgent;
	/**
	 * Create a client for a simple HTTP request.
	 *
	 * You should use this constructor for http and https URL's.
	 *
	 * @param uri The parsed Uri object to use for the HTTP request.
	 */
	public Client(ref<Uri> uri) {
		_uri = *uri;
		userAgent = USER_AGENT;
		_headers["host"] = _uri.authority();
	}
	/**
	 * Create a client for a simple HTTP request.
	 *
	 * You should use this constructor for http and https URL's.
	 *
	 * @param url The url to use for the HTTP request.
	 */
	public Client(string url) {
		_uri.parseURI(url);
		userAgent = USER_AGENT;
		_headers["host"] = _uri.authority();
	}
	/**
	 * Create a client for a Web Socket request.
	 *
	 * Use this constructor when you want to obtain a Web Socket. The 
	 * webSocketProtocol parameter specifies a protocol that the server
	 * expects to see.
	 *
	 * @param url The url to use for the HTTP request.
	 * @param webSocketProtocol A protocol string that describes how
	 * you expect to use the Web Socket
	 */
	public Client(string url, string webSocketProtocol) {
		_uri.parseURI(url);
		userAgent = USER_AGENT;
		_webSocketProtocol = webSocketProtocol;
		_headers["host"] = _uri.host + ":" + string(_uri.port);
	}

	~Client() {
		reset();
	}
	/**
	 * Specify that you want logging done to the indicated logger path.
	 */
	public void logTo(string loggerPath) {
		if (loggerPath == null)
			_logger = null;
		else
			_logger = log.getLogger(loggerPath);
	}
	/**
	 * This method resets the client after a request has been issued.
	 *
	 * If this method is called before an HTTP request has actualy been issued
	 * the call has no effect. Calling this method twice without issuing another
	 * request also has no effect.
	 *
	 * Any open connection is closed.
	 */
	public void reset() {
		delete _response;
		delete _connection;
		delete _webSocket;
		_response = null;
		_connection = null;
		_webSocket = null;
	}
	/**
	 * Add a header to the request.
	 *
	 * Call this method before any request initiation methods (like {@link get} or {@link post}).
	 *
	 * The Client code will automatically include the following headers
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
	 * You may specify these headers explicitly, except for Upgrade, Sec-Websocket-Key and
	 * Sec-WebSocket-Protocol on a web socket request. For web socket requests, these headers
	 * are generated and any explicit values you provided are replaced with the computed values.
	 *
	 * Header names are not case sensitive. Defining headers whose names only differ in case will
	 * only define the last call and any prior values are discarded.
	 *
	 * @param name The header name to use
	 * @param value The value string to use for the header
	 */
	public void setHeader(string name, string value) {
		_headers[name.toLowerCase()] = value;
	}
	/**
	 * Check whether a given header is currently defined.
	 *
	 * @param name The header name to use
	 *
	 * @return true if the given header is currently defined, false otherwise.
	 */
	public boolean hasHeader(string name) {
		return _headers.contains(name.toLowerCase());
	}
	/**
	 * The given query parameter is defined.
	 *
	 * Query parameters defined in this way use the ?key=value&key=value syntax for the query
	 * parameter string included in the submitted url
	 *
	 * If you supply multiple values for the same key using this method, only the last supplied
	 * value is retained.
	 *
	 * Both the key and value strings of a query parameter are encoded using {@link encodeURIComponent}
	 * function.
	 *
	 * @param key The key of the query parameter.
	 * @param value The value of the parameter.
	 */
	public void addQueryParameter(string key, string value) {
		_queryParameters[key] = value;
	}
	/**
	 * Issue a GET request.
	 *
	 * Note that a ConnectStatus of either {@link ConnectStatus.WEB_SOCKET_REFUSED} or
	 * {@link ConnectStatus.WEB_SOCKET_ACCEPT_MISMATCH} are returned with a properly
	 * formatted response. All other failing ConnectStatus values leave the response
	 * null.
	 *
	 * Even if the CoonectStatus is OK, you must still examine the {@link ParsedResponse.code}
	 * field returned by calling the {@link response} method. Only if the code is 200
	 * can you assume that your request actually succeeded. There are even circumstances where
	 * a server transmits their own error pages that set the code to 200 while not giving
	 * up the desired information.
	 * 
	 * @return The connection status of the request. A value of {@link ConnectStatus.OK}
	 * indicates the request produced a valid response. All other values indicate some sort
	 * of error occurred.
	 * @return The IPv4 ip address of the host. If the hostname failed to resolve
	 * or if the combination of constructor used and URL protocol are not compatible
	 * with the GET method, the returned ip value is 0.
	 */
	public ConnectStatus, unsigned get() {
		return startRequest("GET", null);
	}
	/**
	 * Issue a POST request.
	 *
	 * If the request is successful, the content of the response object may still indicate
	 * problems. Check the code, and if you expect a body, check that the body is present.
	 *
	 * Even if the CoonectStatus is OK, you must still examine the {@link ParsedResponse.code}
	 * field returned by calling the {@link response} method. Only if the code is 200
	 * can you assume that your request actually succeeded. There are even circumstances where
	 * a server transmits their own error pages that set the code to 200 while not giving
	 * up the desired information.
	 *
	 * @param body The body to accompany the request headers.
	 *
	 * @return The connection status of the request. A value of {@link ConnectStatus.OK}
	 * indicates the request produced a valid response. All other values indicate some sort
	 * of error occurred.
	 * @return The IPv4 ip address of the host. If the hostname failed to resolve
	 * or if the combination of constructor used and URL protocol are not compatible
	 * with the POST method, the returned ip value is 0.
	 */
	public ConnectStatus, unsigned post(string body) {
		text.StringReader reader(&body);
		return post(&reader);
	}
	/**
	 * Issue a POST request.
	 *
	 * If the request is successful, the content of the response object may still indicate
	 * problems. Check the code, and if you expect a body, check that the body is present.
	 *
	 * Even if the CoonectStatus is OK, you must still examine the {@link ParsedResponse.code}
	 * field returned by calling the {@link response} method. Only if the code is 200
	 * can you assume that your request actually succeeded. There are even circumstances where
	 * a server transmits their own error pages that set the code to 200 while not giving
	 * up the desired information.
	 *
	 * @param body A Reader containing the body to accompany the request headers.
	 *
	 * @return The connection status of the request. A value of {@link ConnectStatus.OK}
	 * indicates the request produced a valid response. All other values indicate some sort
	 * of error occurred.
	 * @return The IPv4 ip address of the host. If the hostname failed to resolve
	 * or if the combination of constructor used and URL protocol are not compatible
	 * with the POST method, the returned ip value is 0.
	 *
	 * @exception IllegalOperationException thrown if the body Reader object returns false
	 * for {@link Reader.hasLength}.
	 */
	public ConnectStatus, unsigned post(ref<Reader> body) {
		return startRequest("POST", body);
	}
	/**
	 * Issue a PUT request.
	 *
	 * If the request is successful, the content of the response object may still indicate
	 * problems. Check the code, and if you expect a body, check that the body is present.
	 *
	 * Even if the CoonectStatus is OK, you must still examine the {@link ParsedResponse.code}
	 * field returned by calling the {@link response} method. Only if the code is 200
	 * can you assume that your request actually succeeded. There are even circumstances where
	 * a server transmits their own error pages that set the code to 200 while not giving
	 * up the desired information.
	 *
	 * @param body The body to accompany the request headers.
	 *
	 * @return The connection status of the request. A value of {@link ConnectStatus.OK}
	 * indicates the request produced a valid response. All other values indicate some sort
	 * of error occurred.
	 * @return The IPv4 ip address of the host. If the hostname failed to resolve
	 * or if the combination of constructor used and URL protocol are not compatible
	 * with the POST method, the returned ip value is 0.
	 */
	public ConnectStatus, unsigned put(string body) {
		text.StringReader reader(&body);
		return put(&reader);
	}
	/**
	 * Issue a PUT request.
	 *
	 * If the request is successful, the content of the response object may still indicate
	 * problems. Check the code, and if you expect a body, check that the body is present.
	 *
	 * Even if the CoonectStatus is OK, you must still examine the {@link ParsedResponse.code}
	 * field returned by calling the {@link response} method. Only if the code is 200
	 * can you assume that your request actually succeeded. There are even circumstances where
	 * a server transmits their own error pages that set the code to 200 while not giving
	 * up the desired information.
	 *
	 * @param body A Reader containing the body to accompany the request headers.
	 *
	 * @return The connection status of the request. A value of {@link ConnectStatus.OK}
	 * indicates the request produced a valid response. All other values indicate some sort
	 * of error occurred.
	 * @return The IPv4 ip address of the host. If the hostname failed to resolve
	 * or if the combination of constructor used and URL protocol are not compatible
	 * with the POST method, the returned ip value is 0.
	 *
	 * @exception IllegalOperationException thrown if the body Reader object returns false
	 * for {@link Reader.hasLength}.
	 */
	public ConnectStatus, unsigned put(ref<Reader> body) {
		return startRequest("PUT", body);
	}

	private ConnectStatus, unsigned startRequest(string method, ref<Reader> body) {
		net.Encryption encryption;
		switch (_uri.scheme) {
		case "ws":
			if (_webSocketProtocol == null) {
				if (_logger != null)
					logRecord(ConnectStatus.NO_PROTOCOL, null);
				return ConnectStatus.NO_PROTOCOL, 0;
			}
			if (method != "GET") {
				if (_logger != null)
					logRecord(ConnectStatus.WS_NOT_GET, null);
				return ConnectStatus.WS_NOT_GET, 0;
			}
			encryption = net.Encryption.NONE;
			break;

		case "wss":
			if (_webSocketProtocol == null) {
				if (_logger != null)
					logRecord(ConnectStatus.NO_PROTOCOL, null);
				return ConnectStatus.NO_PROTOCOL, 0;
			}
			if (method != "GET") {
				if (_logger != null)
					logRecord(ConnectStatus.WS_NOT_GET, null);
				return ConnectStatus.WS_NOT_GET, 0;
			}
			encryption = net.Encryption.SSLv23;
			break;

		case "https":
			if (_webSocketProtocol != null) {
				if (_logger != null)
					logRecord(ConnectStatus.WS_PROTOCOL_NOT_ALLOWED, null);
				return ConnectStatus.WS_PROTOCOL_NOT_ALLOWED, 0;
			}
			encryption = net.Encryption.SSLv23;
			break;

		default:
			if (_webSocketProtocol != null) {
				if (_logger != null)
					logRecord(ConnectStatus.WS_PROTOCOL_NOT_ALLOWED, null);
				return ConnectStatus.WS_PROTOCOL_NOT_ALLOWED, 0;
			}
			encryption = net.Encryption.NONE;
		}

		ref<net.Socket> socket = net.Socket.create(encryption, _cipherList, null, null, null);
		if (socket == null) {
			if (_logger != null)
				logRecord(ConnectStatus.NO_SOCKET, null);
			return ConnectStatus.NO_SOCKET, 0;
		}
		ref<net.Connection> connection;
		unsigned ip;
		(connection, ip) = socket.connect(_uri.host, _uri.port);
		if (connection == null) {
			delete socket;
			if (_logger != null)
				logRecord(ConnectStatus.CONNECT_FAILED, null);
			return ConnectStatus.CONNECT_FAILED, ip;
		}
		if (!connection.initiateSecurityHandshake()) {
			delete connection;
			delete socket;
			if (_logger != null)
				logRecord(ConnectStatus.SSL_HANDSHAKE_FAILED, null);
			return ConnectStatus.SSL_HANDSHAKE_FAILED, ip;
		}
		boolean expectWebSocket;
		// Delete any connection object left over from a previous request.
		delete _connection;
		// We have a good Connection object, so we are ready for the next stage, send the headers...
		_connection = connection;
		string path;
		if (_uri.path.length() > 0)
			path = _uri.httpRequestUri();
		else
			path = "/";
//		printf("Composing HTTP request...\n");
		_connection.printf("%s %s", method, path);
		for (string[string].iterator i = _queryParameters.begin(); i.hasNext(); i.next()) {
			string key = encodeURIComponent(i.key());
			string value = encodeURIComponent(i.get());
			_connection.printf("&%s=%s", key, value);
		}
		_connection.write(" HTTP/1.1\r\n");
		string webSocketKey;
		switch (_uri.scheme) {
		case "ws":
		case "wss":
			setHeader("Upgrade", "websocket");
			setHeader("Sec-WebSocket-Protocol", _webSocketProtocol);
			webSocketKey = computeWebSocketKey(16);
			setHeader("Sec-WebSocket-Key", webSocketKey);
			expectWebSocket = true;
		}
		if (_headers["user-agent"] == null)
			_headers["user-agent"] = userAgent;
		if (_headers["accept"] == null)
			_headers["accept"] = "text/html; charset=UTF-8";
		if (_headers["accept-language"] == null)
			_headers["accept-language"] = "en-US,en;q=0.8";
		boolean writeBody;
		if (body != null) {
			if (_headers["content-length"] == null) {
				if (!body.hasLength())
					throw IllegalOperationException("cannot determine content-length");
				if (body.length() > 0)
					_headers["content-Length"] = string(body.length());		
			}
			if (body.length() > 0)
				writeBody = true;
		} else {
			switch (method) {
			case "POST":
			case "PUT":
				_headers["content-length"] = "0";		
				break;

			default:
				_headers.remove("content-length");
			}
		}
		for (string[string].iterator i = _headers.begin(); i.hasNext(); i.next())
			_connection.printf("%s: %s\r\n", i.key(), i.get());
		_connection.printf("\r\n");
		if (writeBody)
			_connection.write(body);
		_connection.flush();
//		printf("HTTP request sent...\n");
		HttpParser parser(_connection);
		delete _response;
		_response = new ParsedResponse();
		if (!parser.parseResponse(_response)) {
			if (_logger != null)
				logRecord(ConnectStatus.MALFORMED_RESPONSE, _response);
			delete _response;
			_response = null;
			return ConnectStatus.MALFORMED_RESPONSE, ip;
		}
		if (expectWebSocket) {
			if (_response.code != "101") {
				if (_logger != null)
					logRecord(ConnectStatus.WEB_SOCKET_REFUSED, _response);
				return ConnectStatus.WEB_SOCKET_REFUSED, ip;
			}
			string webSocketAccept = computeWebSocketAccept(webSocketKey);
			if (_response.headers["sec-websocket-accept"] != webSocketAccept) {
				if (_logger != null)
					logRecord(ConnectStatus.WEB_SOCKET_ACCEPT_MISMATCH, _response);
				return ConnectStatus.WEB_SOCKET_ACCEPT_MISMATCH, ip;
			}
			_webSocket = new WebSocket(_connection, false);
			_connection = null;					// The web socket takes possession of the connection object.
		}
		if (_logger != null)
			logRecord(ConnectStatus.OK, _response);
		return ConnectStatus.OK, ip;
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
	public string host() {
		return _uri.host;
	}
	/**
	 * Get the protocol from the URL.
	 *
	 * If no protocol was specified, the <span class=code>file</span> protocol
	 * will be returned.
	 *
	 * @return The protocol of the parsed URL.
	 */
	public string scheme() {
		return _uri.scheme;
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
		return _uri.port;
	}
	/**
	 * Get the userinfo, if any, from the URL.
	 *
	 * @return The username of the parsed URL, or null if none was specified.
	 */
	public string userinfo() {
		return _uri.userinfo;
	}
	/**
	 * Get whether the port value was defaulted (i.e. not specified).
	 *
	 * @return true if the URL did not include a port, false if it did.
	 */
	public boolean portDefaulted() {
		return _uri.portDefaulted;
	}
	/**
	 * Get the path portion of the URL.
	 *
	 * @return the path port of the URL.
	 */
	public string path() {
		return _uri.path;
	}
	/**
	 * Get the query portion of the URL.
	 *
	 * @return the query port of the URL.
	 */
	public string query() {
		return _uri.query;
	}
	/**
	 * Get the fragment portion of the URL.
	 *
	 * @return the fragment port of the URL.
	 */
	public string fragment() {
		return _uri.fragment;
	}
	/**
	 * Get the headers map for the current client.
	 *
	 * The keys of the map are all in lower-case. Modifying the header map will alter the set of
	 * headers the next request will include. Inserting a key with upper-case letters will cause
	 * the named header to be included, even though a {@link hasHeader} call would report false for
	 * the same string.
	 *
	 * @return A reference to the map of headers. 
	 */
	public ref<string[string]> headers() {
		return &_headers;
	}
	/**
	 * This is a debugging aid.
	 *
	 * The function prints the parsed URI with the set of currently defined headers.
	 */
	public void print() {
		printf("URI: %s\n", _uri.toString());
		printf("Headers:\n");
		for (string[string].iterator i = _headers.begin(); i.hasNext(); i.next()) {
			printf("    %-20s %s\n", i.key(), i.get());
		}
	}
	/**
	 * This method returns the log record string that would be generated based on the current
	 * seetings of the Client.
	 *
	 * The format of the record string is JSON, as in:
	 *
	 *<pre>{@code
	 *    &lbrace;
	 *        "URI":"<i>The URI of this Client object</i>",
	 *        "headers":&lbrace;
	 *            "<i>lowercase name of the header</i>":"<i>The value of the header</i>",
	 *            ...
	 *        &rbrace;
	 *    &rbrace;
	 *</pre>}
	 *
	 * @return A JSON string containing the URI and headers as an object.
	 */
	public void logRecord(ConnectStatus status, ref<ParsedResponse> response) {
		string record = "{";
		record.printf("\"URI\":\"%s\",\"headers\":{", _uri.toString().escapeJSON());
		boolean firstTime = true;
		for (key in _headers) {
			if (firstTime)
				firstTime = false;
			else
				record += ",";
			record.printf("\"%s\":\"%s\"", key.escapeJSON(), _headers[key].escapeJSON());
		}
		record.printf("},\"status\":\"%s\"", string(status));
		if (response != null)
			record.printf(",\"response\":%s", response.logRecord());
		record += "}";
		if (status == ConnectStatus.OK)
			_logger.info(record);
		else
			_logger.error(record);
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
	 * @return The value of the response, if any.
	 */
	public ref<ParsedResponse> response() {
		return _response;
	}
	/**
	 * Read the contents, if any, in the response.
	 *
	 * @return The content, as a string. Note that binary data can be transmitted from some servers,
	 * so whether the returned value is valid UTF-8 text depends on the request and the server. If
	 * the connection read fewer bytes than the header specified, the string is truncated to the amount
	 * of data actually returned. If there is no content-length header, or its value is malformed, or
	 * there is no open connection to the server, null is returned.
	 * @return The specified content-length header value, if present and well-formed. If the 
	 * content-length header is missing, the value -1 is returned. If the content-length header is present
	 * but malformed, the return value is -2.
	 */
	public string, int readContent() {
		string contentLength = _response.headers["content-length"];
		if (contentLength == null)
			return null, -1;
		string reply;
		int cl;
		boolean success;

		(cl, success) = int.parse(contentLength);
		if (success) {
			if (cl < 0)
				return null, -2;
			int specifiedContentLength = cl;
			if (specifiedContentLength == 0)
				return "", 0;
			if (_connection == null)
				return null, specifiedContentLength;
			// Allow for the full content length header value.
			reply.resize(cl);
			pointer<byte> buffer = &reply[0];
			while (cl > 0) {
				int ch = _connection.read();
				if (ch < 0)
					break;
				*buffer++ = byte(ch);
				cl--;
			}
			reply.resize(specifiedContentLength - cl);
			return reply, specifiedContentLength;
		} else
			return null, -2;
	}
}
