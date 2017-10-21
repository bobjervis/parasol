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

import parasol:net;
import native:net.gethostbyname;
import native:net.hostent;
import native:net.in_addr;
import native:net.inet_addr;
import native:net.inet_aton;
import native:net.inet_ntoa;
/**
 * HttpClient
 *
 * This class will accept either http, https, ws or wss URL's. If the ws or
 * wss protocols successfully connect, you can obtain the WebSocket created as a result of the
 * http request from the HttpClient using the webSocket method.
 */
public class HttpClient {
	private ref<net.Connection> _connection;
	private ref<HttpResponse> _response;

	private string _protocol;			// required for proper connection
	private string _username;
	private string _password;
	private string _hostname;			// required for proper connection
	private char _port;					// optional (default will be filled in from protocol)
	private string _path;
	private boolean _portDefaulted;
	private unsigned _resolvedIP;

	private string _cipherList;

	public HttpClient(string url) {
		// First, parse out the protocol and hostname.
		parseUrl(url);
	}

	~HttpClient() {
		delete _response;
		delete _connection;
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

	public boolean, unsigned get() {
		boolean hasWebSocket;
		boolean success;
		unsigned hostIP;

		(hasWebSocket, success, hostIP) = startRequest("GET", null);
		if (!success)
			return false, hostIP;
		if (hasWebSocket) {
		}
		return true, hostIP;
	}

	public boolean, unsigned post(string body) {
		boolean hasWebSocket;
		boolean success;
		unsigned hostIP;

		(hasWebSocket, success, hostIP) = startRequest("POST", body);
		if (!success)
			return false, hostIP;
		if (hasWebSocket) {
		}
		return true, hostIP;
	}

	private boolean, boolean, unsigned startRequest(string method, string body) {
		net.Encryption encryption;
		switch (_protocol) {
		case "https":
		case "wss":
			encryption = net.Encryption.SSLv23;
			break;

		default:
			encryption = net.Encryption.NONE;
		}
		ref<net.Socket> socket = net.Socket.create(encryption, _cipherList);
		if (socket == null)
			return false, false, 0;
		ref<net.Connection> connection;
		unsigned ip;
		(connection, ip) = socket.connect(_hostname, _port);
		if (connection == null) {
			delete socket;
			return false, false, ip;
		}
		if (!connection.initiateSecurityHandshake()) {
			printf("Failed security handshake\n");
			delete connection;
			delete socket;
			return false, false, ip;
		}
//		delete socket;
		boolean expectWebSocket;
		// We have a good Connection object, so we are ready for the next stage, send the headers...
		_connection = connection;
		string path;
		if (_path.length() > 0)
			path = _path;
		else
			path = "/";
//		printf("Composing HTTP request...\n");
		_connection.printf("%s %s HTTP/1.1\r\n", method, path);
		// TODO: add other headers...
		switch (_protocol) {
		case "ws":
		case "wss":
			_connection.write("Upgrade: websocket\r\n");
			expectWebSocket = true;
		}
		_connection.printf("Host: %s:%d\r\n", _hostname, _port);
		_connection.write("User-Agent: Parasol/0.1.0\r\n");
		_connection.write("Accept: text/html; charset=UTF-8\r\n");
		//_connection.write("Accept-Encoding: gzip, deflate, br\r\n");
		_connection.write("Accept-Language: en-US,en;q=0.8\r\n");
		if (body.length() > 0)
			_connection.printf("Content-Length: %d\r\n", body.length());
		_connection.printf("\r\n");
		if (body.length() > 0)
			_connection.write(body);
		_connection.flush();
//		printf("HTTP request sent...\n");
		HttpParser parser(_connection);
		_response = new HttpResponse(null);
		if (!parser.parseResponse(_response)) {
			printf("Malformed response\n");
			return false, false, ip;
		}
		return expectWebSocket, true, ip;
	}

	public ref<net.Connection> connection() {
		return _connection;
	}

	public boolean isWebSocket() {
		return false;
	}

	public ref<WebSocket> webSocket() {
		return null;
	}

	public void setCipherList(string cipherList) {
		_cipherList = cipherList;
	}

	public string hostname() {
		return _hostname;
	}

	public string protocol() {
		return _protocol;
	}

	public char port() {
		return _port;
	}

	public string username() {
		return _username;
	}

	public string password() {
		return _password;
	}

	public boolean portDefaulted() {
		return _portDefaulted;
	}

	public string path() {
		return _path;
	}

	public ref<HttpResponse> response() {
		return _response;
	}
}

private char[string] defaultPort = [
	"http": 80,
	"https": 443,
	"ws": 80,
	"wss": 443
];
