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

	void dispose() {
	}
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
	ref<WebSocketVolatileData> rpcWebSocket;

	~WebSocketTransport() {
		delete reader;
		delete socket;
	}

	void dispose() {
		if (rpcWebSocket != null) {
			rpcWebSocket.shutdown();
			rpcWebSocket.waitForDisconnect();
			ws := rpcWebSocket;
			rpcWebSocket = null;
			ws.unrefer();			// This WebSocketTransport is embedded as a member of rpcWebSocket.
		}
	}

	void initialize(ref<WebSocketVolatileData> rpcWebSocket) {
		this.rpcWebSocket = rpcWebSocket;
	}

	string call(string serializedArguments) {
		string s;
		s.printf("C%d;", manager.getNextMessageID());
		ref<http.Rendezvous> r = manager.createRendezvous(s);
		if (r == null)
			return null;
		s.append(serializedArguments);
		rpcWebSocket.refer();
//		logger.memDump(log.DEBUG, "rpc.ws.call", &s[0], s.length(), 0);
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
		rpcWebSocket.unrefer();
		if (shouldThrow)
			throw IOException("Connection closed before reply");
		return s;
	}

	void postReturns(string key, byte[] body) {
//		logger.memDump(log.DEBUG, "rpc.ws.return " + key, &body[0], body.length(), 0);
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

	public void logTo(string path) {
		_client.logTo(path);
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
 * This is a default interface you can use for an rpc end point that accepts no method calls.
 *
 * This is of almost no value to am HTTP rpc, since there is only one interface to implement,
 * you will almost always want some method calls to be made.
 *
 * For a WebSocket protocol where you have two interfaces, either one can be NoMethods, depending
 * on your needs.
 */
public interface NoMethods {
}
/**
 * A value you can pass to any rpc parameter that expects an object that implements the 
 * {@link NoMethods} interface.
 */
public NoMethods noMethods = null;
/**
 * The web socket-based rpc.Client object is instantiated once for each distinct http request 
 * 
 * After you connect and obtain the downstream proxy object, you can discard the Client object.
 * You must remember to delete the proxy object when you're done with it.
 *
 * In general, the sequence of calls to properly initialize an RPC proxy is as follows:
 *
 * <ol>
 *     <li>Create the Client, giving it a url, WebSocket protocol matching the server and a
 *	       downstream object to implements the client side of the API.
 *		   If there are no methods on the downstream interface, you may pass {@link noMethods} as the
 *		   downstream interface pointer.
 *	   <li>Optionally, call the onDisconnect() method.
 *		   If you don't set the onDisconnect handler, you will only discover that the server
 *		   side has initiated a disconnect by having a call to the downstream proxy throw
 *		   an exception.
 *		   Even if you establish a disconnect handler, there is a race between any local calls 
 *		   through the proxy and a call to the disconnectHandler.
 *	   <li>Call the proxy method to obtain the upstream proxy. 
 *		   Each successful call to the proxy method will establish a new connection.
 *		   The underlying WebSocket is held open until you delete the proxy object.
 * </ol>
 *
 * You can choose to retain the Client object for multiple connections.
 * You can even call proxy a second time while the first WebSocket is still open.
 *
 * The only way to initiate a shutdown of the WebSocket for a given connection is to delete
 * the proxy object.
 *
 * If you want to know the IP address of the server, you can explicitly call the connect()
 * method before calling proxy().
 * Calling the connect() method twice without calling proxy() in between will automatically
 * close the first connection.
 */
public class Client<class UPSTREAM, class DOWNSTREAM> extends http.Client {
	ref<WebSocket<DOWNSTREAM, UPSTREAM>> _socket;
	UPSTREAM _upstreamProxy;
	DOWNSTREAM _downstreamObject;
	http.DisconnectListener _disconnectListener;
	/**
	 * Create a client for a web socket request.
	 *
	 * You should use this constructor for ws and wss URL's.
	 *
	 * @param url The url to use for the HTTP request.
	 * @param protocol The web socket protocol to submit to the server.
	 * @param object An object that implements the downstream interface. If you don't want to
	 * implement any downstream methods, pass the Client.noDownstream object.
	 */
	public Client(string url, string protocol, DOWNSTREAM object) {
		super(url, protocol);
		_downstreamObject = object;
	}

	public ~Client() {
		delete _socket;
	}
	/**
	 */
	public void onDisconnect(http.DisconnectListener disconnectListener) {
		_disconnectListener = disconnectListener;
		if (_socket != null)
			_socket.onDisconnect(_disconnectListener);
	}
	/**
	 * For clients that want information about the remote server.
	 *
	 * Normally, you wouldn't issue this step, you would just call
	 * proxy() to connect for you.
	 *
	 * @return The connection status of your call.
	 * @return The IPv4 address of the remote server.
	 */
	public http.ConnectStatus, unsigned connect() {
		http.ConnectStatus status;
		unsigned ip;
		(status, ip) = get();
		if (status != http.ConnectStatus.OK)
			return status, ip;
		// Take ownership of any web socket object the underlying
		// http.Client created for you.
		ws := webSocket();
		if (ws == null)
			return http.ConnectStatus.WEB_SOCKET_REFUSED, ip;

		// If there's any socket object still hanging around from a previous connect() call,
		// delete it now.

		delete _socket;

		_socket = new WebSocket<DOWNSTREAM, UPSTREAM>(ws, _downstreamObject);
		_socket.onDisconnect(_disconnectListener);
		_socket.startReader();
		return http.ConnectStatus.OK, ip;
	}
	/**
	 * Fetch the client proxy object.
	 *
	 * You may call this once per connection. The returned object is self-contained.
	 *
	 * @return The proxy object for the upstream interfacce.
	 * If you have not gotten a successful connect() method call before calling proxy()
	 * this method returns a null.
	 * If you have already called this method once after a successful connect() call,
	 * the method will return a null until you make another successful connect() call.
	 */
	public UPSTREAM proxy() {
		if (_socket == null && connect() != http.ConnectStatus.OK)
			return null;
		result := _socket.proxy();
		// This ensures that once you have the proxy, the client object can go away without killing the proxy.
		_socket = null;
		return result;
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

	~ClientProxy() {
		_transport.dispose();
	}
}

public class WebSocketFactory<class UPSTREAM, class DOWNSTREAM> extends http.WebSocketFactory {
	public WebSocketFactory() {}

	public boolean start(ref<http.Request> request, ref<http.Response> response) {
		if (!prefilter(request, response))
			return false;
		ref<http.WebSocket> ws = new http.WebSocket(response.connection(), true);
		ref<WebSocket<UPSTREAM, DOWNSTREAM>> s = new WebSocket<UPSTREAM, DOWNSTREAM>(ws, null);
		if (!notifyCreation(request, s)) {
			delete s;
			return false;
		}
		s.startReader();
		return true;
	}

	public boolean prefilter(ref<http.Request> request, ref<http.Response> response) {
		return true;
	}

	public boolean notifyCreation(ref<http.Request> request, ref<WebSocket<UPSTREAM, DOWNSTREAM>> socket) {
		return true;
	}
}

monitor class WebSocketVolatileData extends thread.RefCounted implements http.DisconnectListener {
	http.DisconnectListener _disconnectListener;
	private boolean _disconnected;
	/**
	 * A caller calls this method on the web socket to register a client
	 * disconnect event handler.
	 *
	 * @threading This method is not thread-safe. It is recommended that this method
	 * is called before calling {@link readWholeMessage}, since a client-disconnect can be
	 * triggered when that method reads from the connection.
	 *
	 * @param disconnectListener The interface to call when the client disconnect event occurs.
	 * It takes the param value as its first argument and a boolean indicating
	 * whether the disconnect was a normal close (true) or an error (false).
	 * @param param The value to pass to the function when it is called.
	 */
	public void onDisconnect(http.DisconnectListener disconnectListener) {
		_disconnectListener = disconnectListener;
	}

	void disconnect(boolean normalClose) {
		if (!_disconnected) {
			if (_disconnectListener != null)
				_disconnectListener.disconnect(normalClose);
			_disconnected = true;
			notifyAll();
		}
	}

	public void waitForDisconnect() {
		if (!_disconnected)
			wait();
	}

	public void shutdown() {
	}

}

public class WebSocket<class OBJECT, class PROXY> extends WebSocketVolatileData {
	private WebSocketTransport _transport;
	PROXY _downstreamProxy;
	OBJECT _upstreamObject;

	public WebSocket(ref<http.WebSocket> socket, OBJECT object) {
		_transport.initialize(this);
		_transport.socket = socket;
		socket.onDisconnect(this);
		_upstreamObject = object;
		_downstreamProxy = PROXY.proxy(&_transport);
	}
	/**
	 * Set the upstream object handling remote calls into this local object.
	 *
	 * @param object An interface object that will handle incoming calls to
	 * the OBJECT interface.
	 *
	 * @threading This method is not thread safe. Call it only during the
	 * {@link WebSocketFactory.notifyCreation notifyCreation} call in the {@link WebSocketFactory}.
	 */
	public void setObject(OBJECT object) {
		_upstreamObject = object;
	}

	void startReader() {
		_transport.reader = new WebSocketReader<OBJECT, PROXY>(&_transport, _upstreamObject, _downstreamProxy);
		_transport.socket.startReader(_transport.reader);
	}

	public void shutdown() {
		shutDown(http.WebSocket.CLOSE_NORMAL, "");
	}
	/**
	 * Write a shutdown message.
	 *
	 * A single-frame message with an {@link http.WebSocket.OP_CLOSE} opcode is sent. The cause and reason values
	 * are formatted according to the WebSocket protocol.
	 *
	 * @threading This method is thread-safe.
	 *
	 * @param cause The cause of the shutdown. Possible values include {@link http.WebSocket.CLOSE_NORMAL}, {@link http.WebSocket.CLOSE_GOING_AWAY},
	 * {@link http.WebSocket.CLOSE_PROTOCOL_ERROR} or {@link http.WebSocket.CLOSE_BAD_DATA}.
	 * @param reason A reason string that provides additional details about the cause.
	 */
	public void shutDown(short cause, string reason) {
		_transport.socket.shutDown(cause, reason);
	}
	/**
	 * If this WebSocket was created by the HTTP server, return the downstream
	 * proxy object for the new WebSocket.
	 *
	 * @return If this WebSocket was created by the server, a non-null proxy
	 * object that is connected to the downstream end of the connection.
	 */
	public PROXY proxy() {
		return _downstreamProxy;
	}
	/**
	 * If this WebSocket was created by the HTTP server, return the upstream
	 * stub object for the new WebSocket.
	 *
	 * @return If this WebSocket was created by the server, a non-null
	 * object that is connected to the upstream end of the connection.
	 */
	public OBJECT object() {
		return _upstreamObject;
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

class WebSocketReader<class OBJECT, class PROXY> extends AbstractWebSocketReader {
	private CallProcessor<OBJECT> _processor;
	private ref<WebSocketTransport> _transport;
	private PROXY _proxy;
	private ref<thread.ThreadPool<int>> _callerThreads;

	WebSocketReader(ref<WebSocketTransport> transport, OBJECT object, PROXY proxy) {
		_processor = CallProcessor<OBJECT>(object);
		_transport = transport;
		_proxy = proxy;
		_callerThreads = new thread.ThreadPool<int>(4);
	}

	~WebSocketReader() {
		_callerThreads.shutdown();
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
		_transport.rpcWebSocket.refer();
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
					_transport.rpcWebSocket.refer();
					// _callerThreads is the pool that makes the actual call, so that
					// this thread can see if another call is coming in right behind this one.
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
				_transport.rpcWebSocket.unrefer();
				return sawClose;
			}
		}
	}

	private class CallParameters {
		byte[] message;
		ref<WebSocketReader<OBJECT, PROXY>> reader;
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
		string returns = _processor.call(&params);
		string reply;
		reply.printf("R%s%s", substring(&cp.message[1], index), returns);
		_transport.socket.write(reply);
		_transport.rpcWebSocket.unrefer();
		delete cp;
	}
}

public class Service<class I> extends http.Service {
	private CallProcessor<I> _processor;

	public Service(I object) {
		_processor = CallProcessor<I>(object);
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
		string returns = _processor.call(&params);
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
/**
 * The CallProcessor class does the actual deserialization-call-deserialization sequence.
 * It's only internal state is the identity of the interface object to be called. Each
 * interface has it's own method table informing the 'stub' method for that interface on what
 * the arguments and return types are. The stub method does all the heavy lifting.
 */
class CallProcessor<class I> {
	private I _object;

	CallProcessor() {}
	/**
	 * The main thing is to stash away the object interface pointer.
	 *
	 * @oaram object The interface object pointer to be called when
	 * this class tries to.
	 */
	CallProcessor(I object) {
		_object = object;
	}
	/**
	 * For now this is always false, meaning no special quick-return
	 * for void methods. Everything waits until the function returns.
	 */
	public boolean callingVoidMethod(ref<StubParams> params) {
		return false;
	}
	/**
	 */
	public string call(ref<StubParams> params) {
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


