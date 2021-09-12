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

class ClientBase {
	protected ref<http.Client> _client;

	string call(string serializedArguments) {
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
/**
 * A client application wanting to use HTTP/HTTPS to carry an RPC call to a server
 * should use this class to do so.
 */
public class Client<class PROXY> extends ClientBase {
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
}

void marshalInt(ref<string> output, ref<int> object) {
	int value = *object;
	if (value >= -128 && value <= 127) {
		(*output).append('1');
		(*output) += substring(pointer<byte>(&value), 1);
	} else if (value >= -32768 && value <= 32767) {
		(*output).append('S');
		(*output) += substring(pointer<byte>(&value), 2);
	} else {
		(*output).append('i');
		(*output) += substring(pointer<byte>(&value), 4);
	}
}
/**
 * This is the base class for all proxy classes. Each distinct interface
 * that is declared will create a proxy class with this as it's base class.
 *
 * Only internally generated code will ever reference this base class.
 */
class ClientProxy {
	// It doesn't matter what parameter we use for Client, no external
	// code will touch it.
	private ref<Client<int>> _client;

	ClientProxy(ref<Client<int>> client) {
		_client = client;
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
		if (request.method != http.Request.Method.POST) {
			response.error(405);
			return false;
		}
		logger.info("rpc.Service: %s", request.toString());
		StubParams params;
		string content = request.readContent();

		int index = content.indexOf(';');
		if (index < 0) {
			response.error(400);
			return false;
		}
		params.methodID = substring(&content[0], index);
		params.arguments = substring(content, index + 1);
/*		boolean releasedCaller;
		// If the selected method returns void, go ahead and respond as if the call works.
		if (I.stub(&params, false) != null) {
			response.ok();
			response.header("Content-Length", "0");
			response.endOfHeaders();
			response.respond();
			releasedCaller = true;
		}
 */
		string returns = I.stub(&params);
//		if (releasedCaller)
//			return false;
		// There should be returns for this method, check and respond accordingly.
		if (returns == null)
			response.error(500);
		else {
			response.ok();
			response.header("Content-Length", string(returns.length()));
			response.endOfHeaders();
			response.write(returns);
		}
		return false;
	}
}
/*
 * By being a unique class that no user code could involve in an interface, this
 * gurantees that the stub method doesn't collide
 */
class StubParams {
	substring methodID;
	substring arguments;
}


