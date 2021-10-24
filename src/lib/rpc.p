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

import parasol:exception.IllegalArgumentException;
import parasol:exception.IllegalOperationException;
import parasol:exception.IOException;
import parasol:http;
import parasol:log;
import parasol:net;
import parasol:runtime;
import parasol:text;
import parasol:thread;

private ref<log.Logger> logger = log.getLogger("parasol.rpc");

public class ClientTransport {

	public abstract string call(string serializedArguments);
}

class HttpTransport extends ClientTransport {
	protected ref<http.Client> _client;

	HttpTransport() {}

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

class WebSocketTransport extends ClientTransport {
	ref<http.WebSocket> socket;
	ref<AbstractWebSocketReader> reader;
	http.RendezvousManager manager;
	int serial;

	WebSocketTransport() {}

	string call(string serializedArguments) {
		string s;

		s.printf("C%d;", manager.getNextMessageID());
		ref<http.Rendezvous> r = manager.createRendezvous(s);
		if (r == null)
			return null;
		s.append(serializedArguments);
		socket.write(http.WebSocket.OP_BINARY, s);
		s = null;

		boolean shouldThrow;
		lock (*r) {
			wait();

			if (success) {
				s.resize(replyMessage.length());
				for (int i = 0; i < s.length(); i++)
					s[i] = replyMessage[i];
			} else
				shouldThrow = true;
		}
		delete r;
		if (shouldThrow)
			throw IOException("Connection closed before reply");
		return s;
	}

	void postReturns(string key, byte[] body) {
		ref<http.Rendezvous> r = manager.extractRendezvous(key);
		if (r != null)
			r.postResult(body);
		else
			logger.error("no rendezvous for '%s'", key);
	}
}
/**
 * A client application wanting to use HTTP/HTTPS to carry an RPC call to a server
 * should use this class to do so.
 */
public class Client<class PROXY> extends HttpTransport {
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
/**
 * The web socket-based rpc.Client object is instantiated once for each distinct http request 
 * 
 *
 */
public class Client<class UPSTREAM, class DOWNSTREAM> extends http.Client {
	ref<WebSocket<UPSTREAM, DOWNSTREAM>> _socket;
	/**
	 * Create a client for a web socket request.
	 *
	 * You should use this constructor for ws and wss URL's.
	 *
	 * @param url The url to use for the HTTP request.
	 * @param protocol The web socket protocol to submit to the server.
	 */
	public Client(string url, string protocol) {
		super(url, protocol);
	}

	public http.ConnectStatus, unsigned connect() {
		http.ConnectStatus status;
		unsigned ip;

		(status, ip) = get();
		if (status != http.ConnectStatus.OK)
			return status, ip;
		// Take ownership of any web socket object the underlying
		// http.Client created for you.
		ref<http.WebSocket> ws = webSocket();
		if (ws == null)
			return http.ConnectStatus.WEB_SOCKET_REFUSED, ip;
		// 
		_socket = new WebSocket<UPSTREAM, DOWNSTREAM>(ws);
		return http.ConnectStatus.OK, ip;
	}

	public ref<WebSocket<UPSTREAM, DOWNSTREAM>> socket() {
		return _socket;
	}
}
/**
 * This is the base class for all proxy classes. Each distinct interface
 * that is declared will create a proxy class with this as it's base class.
 *
 * Only internally generated code will ever reference this base class.
 */
class ClientProxy {
	protected ref<ClientTransport> _transport;

	ClientProxy(ref<ClientTransport> transport) {
		_transport = transport;
	}
}

public class WebSocketFactory<class UPSTREAM, class DOWNSTREAM> extends http.WebSocketFactory {
	public WebSocketFactory() {}

	public boolean start(ref<http.Request> request, ref<http.Response> response) {
		if (!prefilter(request, response))
			return false;
		ref<http.WebSocket> ws = new http.WebSocket(response.connection(), true);
		ref<WebSocket<UPSTREAM, DOWNSTREAM>> s = new WebSocket<UPSTREAM, DOWNSTREAM>(ws);
		if (!notifyCreation(request, s)) {
			delete s;
			return false;
		}
		return true;
	}

	public boolean prefilter(ref<http.Request> request, ref<http.Response> response) {
		return true;
	}

	public boolean notifyCreation(ref<http.Request> request, ref<WebSocket<UPSTREAM, DOWNSTREAM>> socket) {
		return true;
	}
}

monitor class WebSocketVolatileData {
	private void (address, boolean) _disconnectFunction;
	private address _disconnectParameter;
	private boolean _disconnected;
	/**
	 * A caller calls this method on the web socket to register a client
	 * disconnect event handler.
	 *
	 * @threading This method is not thread-safe. It is recommended that this method
	 * is called before calling {@link readWholeMessage}, since a client-disconnect can be
	 * triggered when that method reads from the connection.
	 *
	 * @param func The function to call when the client disconnect event occurs.
	 * It takes the param value as its first argument and a boolean indicating
	 * whether the disconnect was a normal close (true) or an error (false).
	 * @param param The value to pass to the function when it is called.
	 */
	public void onDisconnect(void (address, boolean) func, address param) {
		_disconnectFunction = func;
		_disconnectParameter = param;
	}

	void fireOnDisconnect(boolean normalClose) {
		if (_disconnectFunction != null)
			_disconnectFunction(_disconnectParameter, normalClose);
		_disconnected = true;
		notifyAll();
	}

	public void waitForDisconnect() {
		if (!_disconnected)
			wait();
	}
}

public class WebSocket<class UPSTREAM, class DOWNSTREAM> extends WebSocketVolatileData {
	private WebSocketTransport _transport;
	DOWNSTREAM _downstreamProxy;
	UPSTREAM _upstreamProxy;
	UPSTREAM _upstreamObject;

	public WebSocket(ref<http.WebSocket> socket) {
		_transport.socket = socket;
		socket.onDisconnect(disconnectWrapper, this);
	}

	~WebSocket() {
		printf("In destructor 1\n");
		delete _transport.reader;
		printf("In destructor 2\n");
		delete _transport.socket;
		printf("In destructor 3\n");
		// Only one of these will be non-null 
		delete _downstreamProxy;
		printf("In destructor 4\n");
		delete _upstreamProxy;
		printf("In destructor 5\n");
	}
	/**
	 * Write a shutdown message.
	 *
	 * A single-frame message with an {@link OP_CLOSE} opcode is sent. The cause and reason values
	 * are formatted according to the WebSocket protocol.
	 *
	 * @threading This method is thread-safe.
	 *
	 * @param cause The cause of the shutdown. Possible values include {@link CLOSE_NORMAL}, {@link CLOSE_GOING_AWAY},
	 * {@link CLOSE_PROTOCOL_ERROR} or {@link CLOSE_BAD_DATA}.
	 * @param reason A reason string that provides additional details about the cause.
	 */
	public void shutDown(short cause, string reason) {
		_transport.socket.shutDown(cause, reason);
	}

	private static void disconnectWrapper(address arg, boolean normalClose) {
		ref<WebSocket<UPSTREAM, DOWNSTREAM>>(arg).disconnect(normalClose);
	}

	void disconnect(boolean normalClose) {
		fireOnDisconnect(normalClose);
//		delete this;
	}
	/**
	 * If this WebSocket was created by the HTTP server, return the downstream
	 * proxy object for the new WebSocket.
	 *
	 * @return If this WebSocket was created by the server, a non-null proxy
	 * object that is connected to the downstream end of the connection.
	 */
	public DOWNSTREAM downstreamProxy() {
		return _downstreamProxy;
	}
	/**
	 * If this WebSocket was created by the HTTP server, return the upstream
	 * stub object for the new WebSocket.
	 *
	 * @return If this WebSocket was created by the server, a non-null
	 * object that is connected to the upstream end of the connection.
	 */
	public UPSTREAM upstreamObject() {
		return _upstreamObject;
	}
	/**
	 * If this WebSocket was created by the HTTP client, return the upstream
	 * proxy object for the new WebSocket.
	 *
	 * @return If this WebSocket was created by the client, a non-null proxy
	 * object that is connected to the upstream end of the connection.
	 */
	public UPSTREAM upstreamProxy() {
		return _upstreamProxy;
	}
	/**
	 * This is called by the connecting client/server to implement the communicatins pathways between
	 * the upstrema and downstream objects with the web socket between them.
	 */
	public UPSTREAM configure(DOWNSTREAM stub) {
		UPSTREAM proxy = UPSTREAM.proxy(&_transport);
		_upstreamProxy = proxy;
		_transport.reader = new WebSocketReader<UPSTREAM, DOWNSTREAM>(&_transport, proxy, stub);
		_transport.socket.startReader(_transport.reader);
		return proxy;
	}

	public DOWNSTREAM configure(UPSTREAM stub) {
		DOWNSTREAM proxy = DOWNSTREAM.proxy(&_transport);
		_upstreamObject = stub;
		_downstreamProxy = proxy;
		_transport.reader = new WebSocketReader<DOWNSTREAM, UPSTREAM>(&_transport, proxy, stub);
		_transport.socket.startReader(_transport.reader);
		return proxy;
	}

	void postReturns(string key, byte[] body) {
		_transport.postReturns(key, body);
	}

	public ref<http.WebSocket> socket() {
		return _transport.socket;
	}
}

class AbstractWebSocketReader implements http.WebSocketReader {
	public abstract boolean readMessages();
}

class WebSocketReader<class PROXY, class STUB> extends AbstractWebSocketReader {
	private CallProcessor<STUB> _processor;
	private ref<WebSocketTransport> _transport;
	private PROXY _proxy;
	private ref<thread.ThreadPool<int>> _callerThreads;

	WebSocketReader(ref<WebSocketTransport> transport, PROXY proxy, STUB stub) {
		_processor.initialize(stub);
		_transport = transport;
		_proxy = proxy;
		_callerThreads = new thread.ThreadPool<int>(4);
	}

	~WebSocketReader() {
		_callerThreads.shutdown();
		delete _proxy;
		delete _callerThreads;
	}

	/**
	 * readMessages
	 *
	 * This method is called from the read thread for a WebSocket. It continues
	 * reading messages until the protocol fails or a close is detected.
	 *
	 * The message format consists of a prefix, either C or R followed by a serial number (in decimal)
	 * and a semi-colon. For C messages, the prefix is followed by a method ID and serialized
	 * arguments. For R messages, the prefix is followed by serialized return values.
	 *
	 * The body of C messages must be passed to the stub
	 */
	public boolean readMessages() {
//		logger.debug("%p in %s readMessages, socket %p connection %p", this, _transport.socket.server() ? "server" : "client", _transport.socket, _transport.socket.connection());
		for (;;) {
			byte[] message;
			boolean success;
			boolean sawClose;
		
			(success, sawClose) = _transport.socket.readWholeMessage(&message);
			if (success) {
				if (message.length() == 0)
					continue;
				switch (message[0]) {
				case 'C':
					ref<CallParameters> cp = new CallParameters;
					cp.message = message;
					cp.reader = this;
					_callerThreads.execute(callStubWrapper, cp);
					break;

				case 'R':
					int index = message.find(';');
					if (index < 0) {
						logger.memDump(log.ERROR, "No prefix separator for return message", &message[0], message.length(), 0);
						break;
					}
					message[0] = 'C';
					byte[] body;
					body.slice(message, index + 1, message.length());
					_transport.postReturns(string(&message[0], index + 1), body);
					break;

				default:
					logger.error("Received unknown message direction: %c (%x)", message[0], message[0]);
				}
			} else {
				// After we have received all responses and the socket has shut down, we need to clear all the calling
				// threads waiting for responses.
				ref<http.Rendezvous>[] pending = _transport.manager.extractAllRendezvous();
				for (int i = 0; i < pending.length(); i++)
					pending[i].abandon();
				return sawClose;
			}
		}
	}

	private class CallParameters {
		byte[] message;
		ref<WebSocketReader<PROXY, STUB>> reader;
	}

	private static void callStubWrapper(address arg) {
		ref<CallParameters> cp = ref<CallParameters>(arg);
		cp.reader.callStub(cp);
	}

	private void callStub(ref<CallParameters> cp) {
		int index = cp.message.find(';');
		if (index < 0) {
			logger.memDump(log.ERROR, "Message has no prefix separator.", &cp.message[0], cp.message.length(), 0);
			return;
		}
		int methodEnd = cp.message.find(';', index + 1);
		if (methodEnd < 0) {
			logger.memDump(log.ERROR, "Message has no method id.", &cp.message[0], cp.message.length(), 0);
			return;
		}
		StubParams params;
		params.methodID = substring(&cp.message[index + 1], methodEnd - (index + 1));
		pointer<byte> pb = &cp.message[methodEnd + 1];
		params.arguments = &pb;
		string returns = _processor.process(&params);
		string reply;
		reply.printf("R%s%s", substring(&cp.message[1], index), returns);
		_transport.socket.write(reply);
		delete cp;
	}
}

public class Service<class I> extends http.Service {
	private CallProcessor<I> _processor;

	public Service(I object) {
		_processor.initialize(object);
	}

	public boolean processRequest(ref<http.Request> request, ref<http.Response> response) {
		if (request.method != http.Request.Method.POST) {
			logger.debug("Not a post!");
			response.error(405);
			return false;
		}
		string content = request.readContent();
		int index = content.indexOf(';');
		if (index < 0) {
			response.error(400);
			return false;
		}
		boolean releasedCaller;
		StubParams params;
		params.methodID = substring(&content[0], index);
		pointer<byte> pb = &content[index + 1];
		params.arguments = &pb;
		// If the selected method returns void, go ahead and respond as if the call works.
		if (_processor.callingVoidMethod(&params)) {
			response.ok();
			response.header("Content-Length", "0");
			response.endOfHeaders();
			response.respond();
			releasedCaller = true;
		}
		// Now do the call locally
		string returns = _processor.process(&params);
		if (releasedCaller)
			return false;
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

class CallProcessor<class I> {
	private I _object;

	public void initialize(I object) {
		_object = object;
	}

	public boolean callingVoidMethod(ref<StubParams> params) {
		return false;
	}

	public string process(ref<StubParams> params) {
		return I.stub(_object, params);
	}

	public I object() {
		return _object;
	}
}

string hexify(string argument) {
	string output;

	for (i in argument)
		output.printf("%2.2x", argument[i]);
	return output;
}

/*
 * By being a unique class that no user code could involve in an interface, this
 * gurantees that the stub method doesn't collide
 */
class StubParams {
	substring methodID;
	ref<pointer<byte>> arguments;
}

