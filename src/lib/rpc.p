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
namespace parasol:rpc;

import parasol:exception.IllegalOperationException;
import parasol:exception.IOException;
import parasol:http;
import parasol:log;
import parasol:net;

private ref<log.Logger> logger = log.getLogger("parasol.rpc");
/**
 * A client application wanting to use HTTP/HTTPS to carry an RPC call to a server
 * should use this class to do so.
 */
public class Client<class PROXY> {
	private ref<http.Client> _client;
	/**
	 * Create a client for a simple HTTP request.
	 *
	 * You should use this constructor for http and https URL's.
	 *
	 * @param uri The parsed Uri object to use for the HTTP request.
	 */
	public Client(ref<http.Uri> uri) {
		_client = new http.Client(uri);
	}
	/**
	 * Create a client for a simple HTTP request.
	 *
	 * You should use this constructor for http and https URL's.
	 *
	 * @param url The url to use for the HTTP request.
	 */
	public Client(string url) {
		_client = new http.Client(url);
	}

	~Client() {
		delete _client;
	}
	/**
		Code should look like:

			rpc.Client c("my-url");
			PROXY x = c.proxy();
			returns = x.method(arguments);
			...
			delete x;
			// you can create a new proxy for the same client, or just let the
			// Client go out of scope.
	 */
	public PROXY proxy() {
		return PROXY.proxy(this);
	}

	private string call(string serializedArguments) {
		http.ConnectStatus status = _client.post(serializedArguments);
		if (status != http.ConnectStatus.OK)
			throw IOException(string(status));
		string reply;
		int contentLength;

		(reply, contentLength) = _client.readContent();
		if (reply == null || reply.length() < contentLength)
			throw IOException("Content missing or malformed");

		// Shut her down and await the next call.
		_client.reset();
		return reply;
	}
}
/*
private class BinaryProxy<class PROXY, class STUB> {
	// Use for webSocket clients
	public BinaryProxy(ref<Reader<PROXY, STUB>> reader) {
	}
/*
	public PROXY proxy() {
		return null;
	}

	public STUB stub() {
		return null;
	|
 */
}
*/
private class Reader<class PROXY, class STUB> implements http.WebSocketReader {
	private ref<http.WebSocket> _socket;
	private STUB _stub;
	private PROXY _proxy;

	public Reader(ref<http.WebSocket> socket) {
		_socket = socket;
	}
	/**
	 * readMessages
	 *
	 * This method is called from the read thread for a WebSocket. It continues
	 * reading messages until the protocol fails or a close is detected.
	 */
	public boolean readMessages() {
		for (;;) {
			byte[] message;
			boolean success;
			boolean sawClose;
		
			(success, sawClose) = _socket.readWholeMessage(&message);
			if (success) {
				if (message.length() == 0)
					continue;
				switch (message[0]) {
				case 'C':
				case 'R':
				default:
					logger.error("Received unknown message direction: %c (%d)\n", message[0], message[0]);
				}
			} else
				return sawClose;
		}
	}

}

public class Service<class I> extends http.Service {
	private I _object;

	public Service(I object) {
		_object = object;
	}

	public boolean processRequest(ref<http.Request> request, ref<http.Response> response) {
		//
		return false;
	}
}

public class Stub<class I> {
}

public class Proxy<class I> {
}

