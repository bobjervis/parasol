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

import native:net.closesocket;
import native:net.recv;
import native:net.send;
import native:linux;
import native:C;
import openssl.org:crypto.SHA1;
import parasol:log;
import parasol:net.base64encode;
import parasol:net.Connection;
import parasol:random;
import parasol:runtime;
import parasol:text;
import parasol:thread;
import parasol:thread.Thread;
import parasol:thread.currentThread;
import parasol:types.Queue;

private ref<log.Logger> logger = log.getLogger("parasol.http.websocket");

private monitor class WebSocketServiceData {
	ref<WebSocketFactory>[string] _webSocketProtocols;
}
/**
 * A service class that accepts web socket requests.
 *
 * When this object is passed to a Server object then HTTP GET requests to the service
 * URL will call this object to validate and complete the connection.
 *
 * During server configuration, one or more calls to {@link webSocketProtocol} should be made
 * to define the set of protocols recognized by the service.
 *
 * This class should not need to be extended to provide addtional validation. The {@link WebSocketFactory.start} abstract
 * method has access to the same Request data and can validate for a specific protocol.
 */
public class WebSocketService extends Service {
	private WebSocketServiceData _webSockets;
	/**
	 * Define a protocol for this web socket url.
	 *
	 * THis method should be called duting server initialization. Adding or removing protocols after the
	 * server begins processing requests may produce unpredictable results.
	 *
	 * @param protocol The protocol string that needs to be included in the sec-websocket-protocol header
	 * of the incoming HTTP request.
	 * @param webSocketFactory The {@link WebSocketFactory} object that will do final validation of the
	 * incoming request, or null to delete any currently defined .
	 */
	public void webSocketProtocol(string protocol, ref<WebSocketFactory> webSocketFactory) {
		ref<WebSocketFactory> oldFactory;
		lock (_webSockets) {
			oldFactory = _webSocketProtocols[protocol];
			if (webSocketFactory == null)
				_webSocketProtocols.remove(protocol);
			else
				_webSocketProtocols[protocol] = webSocketFactory;
		}
		delete oldFactory;
	}
	/**
	 * Process an HTTP request to validate that it is a valid web socket request.
	 *
	 * @param request the {@link Request} object containing the parsed HTTP request
	 * data.
	 * @param respose The {@link Response} object used to compose and send the
	 * response to the request.
	 *
	 * @return true if the request successfully made a WebSocket object, false otherwise.
	 */
	public boolean processRequest(ref<Request> request, ref<Response> response) {
		if (request.method != Request.Method.GET) {
			response.error(400);				// you gotta use GET
			return false;
		}
		string upgradeHeader = request.headers["upgrade"];
		if (upgradeHeader != null && upgradeHeader == "websocket") {
			string protocol = request.headers["sec-websocket-protocol"];
			if (protocol == null) {
				response.error(400);			// you gotta give me a protocol or two
				return false;
			}
			string[] protocolsAttempted = protocol.split(',');
			for (int i = 0; i < protocolsAttempted.length(); i++) {
				string p = protocolsAttempted[i].trim();
				ref<WebSocketFactory> wsf;
				lock (_webSockets) {
					wsf = _webSocketProtocols[p];
				}
				if (wsf != null)
					return wsf.processConnection(p, request, response);
			}
		}
		response.error(400);			// you gotta give me a matching protocol
		return false;
	}
}
/**
 * Factory class that creates WebSocket objects for requests.
 *
 * Each WebSocketFactory is defined to process one or more protocols. When a request comes in with
 * a Web Socket upgrade header and a protocol header naming this factory, the processConnection
 * method is called to complete the response.
 */
public class WebSocketFactory {
	boolean processConnection(string protocol, ref<Request> request, ref<Response> response) {
		string key = request.headers["sec-websocket-key"];
		if (key == null) {
			response.error(400);
			return false;
		}
		if (!start(request, response)) {
			response.error(400);
			return false;
		}
		response.statusLine(101, "Switching Protocols");
		string v = computeWebSocketAccept(key);
		response.header("Sec-WebSocket-Accept", v);
		response.header("Connection", "Upgrade");
		response.header("Upgrade", "websocket");
		response.header("Sec-Websocket-Protocol", protocol);
		response.endOfHeaders();
		response.respond();
		return true;
	}
	/**
	 * Start a Web Socket request.
	 *
	 * This method may implement security checks or other validation of the request before accepting the connection.
	 *
	 * @param request The incoming HTTP Request object.
	 *
	 * @param response The associated HTTP Response object.
	 *
	 * @return true if the request is acceptable and the connection should be confirmed as a valid Web Socket.
	 * false if the connection should be refused.
	 */
	public abstract boolean start(ref<Request> request, ref<Response> response);
}

string computeWebSocketKey(int byteCount) {
	byte[] stuff = random.getBytes(byteCount);
	return base64encode(stuff);
}

string computeWebSocketAccept(string webSocketKey) {
	string value = webSocketKey + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
	byte[] hash;
		
	hash.resize(20);
		
	SHA1(&value[0], value.length(), &hash[0]);
	return base64encode(hash);
}

private monitor class WebSocketVolatileData {
	protected int _waitingWrites;
	private boolean _shuttingDown;
	private ref<Thread>	_readerThread;
	private WebSocketReader _reader;
	private boolean _sentClose;

	public boolean startReader(WebSocketReader reader) {
		if (_readerThread != null)
			return false;
		_reader = reader;
		_readerThread = new Thread();
		_readerThread.start(readWrapper, this);
		return true;
	}

	public void discardReader() {
		_reader = null;
	}

	public WebSocketReader reader() {
		return _reader;
	}

	public ref<Thread> stopReading() {
		ref<Thread> t = _readerThread;
		if (_readerThread != null) {
			// I am counting on this being in a race with the readWrapper below, but that I don't care
			// if I lose. There are two scenarios to trigger a destructor call:
			//	a. We got an EOF on the reader thread. If that's the case, then _reader should be null
			//	   by the time we get here.
			// 	b. The creator of this web socket has decided that they are done with the object, so
			//	   there is no need for any further message exchange, except an OP_CLOSE from us.
			//	   The catch with this case is that any number of issues could drop the connection and
			//	   cause the reader thread to stop the moment the _reader test is applied. Thus, any effort
			//	   to transmit an OP_CLOSE control frame will be pointless. That's fortunately the key
			//	   phrase: pointless, not harmful.
			
			if (_reader != null) {
//				logger.debug("stopReading... _waitingWrites %d _shuttingDown %s", _waitingWrites, _shuttingDown ? "true" : "false");
				ref<WebSocket>(this).shutDown(WebSocket.CLOSE_NORMAL, "normal close");
				_sentClose = true;
			}

//			printf("about to join...\n");
			_readerThread = null;
		}
		return t;
	}

	public boolean stopWriting() {
		if (_shuttingDown)
			return false;
		_shuttingDown = true;
//		logger.format(log.DEBUG, "stopWriting... _waitingWrites %d _shuttingDown %s", _waitingWrites, _shuttingDown ? "true" : "false");
		if (_waitingWrites > 0)
			wait();
		return true;
	}

	public boolean enqueueWrite() {
//		logger.format(log.DEBUG, "enqueueWrite... _waitingWrites %d _shuttingDown %s", _waitingWrites, _shuttingDown ? "true" : "false");
		if (_shuttingDown)
			return false;
		_waitingWrites++;
		return true;
	}

	public void writeFinished() {
//		logger.format(log.DEBUG, "writeFinished... _waitingWrites %d _shuttingDown %s", _waitingWrites, _shuttingDown ? "true" : "false");
		if (_waitingWrites <= 0)
			assert(false);
		_waitingWrites--;
		if (_shuttingDown && _waitingWrites == 0)
			notify();
	}

	public boolean sentClose() {
		return _sentClose;
	}
}

private void readWrapper(address arg) {
	ref<WebSocket> socket = ref<WebSocket>(arg);

	boolean sawClose;

	for (;;) {
		try {
			sawClose = socket.reader().readMessages();
			break;
		} catch (Exception e) {
			logger.error("Unexpected exception reading WebSocket message: %s\n%s", e.message(), e.textStackTrace());
		}
	}
//	logger.format(log.DEBUG, "%s.readWrapper sawClose %s", socket.server() ? "server" : "client", sawClose ? "true" : "false");
	if (sawClose && !socket.sentClose())
		socket.shutDown(WebSocket.CLOSE_NORMAL, "normal close");
//	else
//		logger.format(log.ERROR, "Abnormal close on WebSocket %d", socket.connection().requestFd());
	socket.discardReader();
//	if (socket.server())
	socket.disconnect(sawClose);
}
/**
 * An object that implements the Web Socket message frame protocol once an HTTP message has determined
 * that a usccessful Web Socket request has been sent or received.
 *
 * Note that the same object is used for either the client or server side of the connection. Since the Web
 * Socket protocol is symmetric and once the connection has been established, subsequent message transmission
 * and reception is the same regardless of role.
 *
 * Shutting down a conversation with a web socket requires a handshake. Whichever end of the conversation
 * that wants to discontinue the connection may call the {@link shutDown} method to inform the other end
 * of the connection. The shutDown includes a cause number and a reason string.
 *
 * Calling shutDown starts the process, but because of the need for handshake, there is an event generated
 * from the web socket when the shutDown sequence had been completed and the local data structures can be
 * taken apart.
 *
 * This is the disconnect event. Calling code can register an {@link onDisconnect} handler function which will
 * be called. Once called, the webSocket is ready to complete it's cleanup.
 */
public class WebSocket extends WebSocketVolatileData {
	/**
	 * This op code is used for string messages.
	 */
	@Constant
	public static byte OP_STRING = 1;
	/**
	 * This op code is used for binary data messages.
	 */
	@Constant
	public static byte OP_BINARY = 2;
	/**
	 * This op code is used for a close message.
	 */
	@Constant
	public static byte OP_CLOSE = 8;
	/**
	 * This op code is used for the initial message of a ping-pong exchange.
	 */
	@Constant
	public static byte OP_PING = 9;
	/**
	 * This op code is used for the reply message of a pig-pong exchange.
	 */
	@Constant
	public static byte OP_PONG = 10;
	@Constant
	static byte OP_SHUTDOWN = 255;			// Not really a Web Socket operation - used internally
	/**
	 * A normal, non-error close
	 */
	@Constant
	public static short CLOSE_NORMAL = 1000;
	/**
	 * The end-point is going away.
	 */
	@Constant
	public static short CLOSE_GOING_AWAY = 1001;
	/**
	 * This close was initiated because a protocol error was detected
	 */
	@Constant
	public static short CLOSE_PROTOCOL_ERROR = 1002;
	/**
	 * This close was initiated because of bad data detected on the socket.
	 */
	@Constant
	public static short CLOSE_BAD_DATA = 1003;
	/**
	 * The maximum size for a frame this object will write.
	 *
	 * This value has no effect on incoming frames. The processing code will always accept frames of any
	 * length.
	 *
	 * @threading 
	 */
	public int maxFrameSize;
	
	private ref<Connection> _connection;
	private boolean _server;
	private random.Random _random;				// For masking
	private byte[] _incomingData;		// A buffer of data being read from the websocket.
	private int _incomingLength;		// The number of bytes in the buffer.
	private int _incomingCursor;		// The index of the next byte to be read from the buffer.
	private void (address, boolean) _disconnectFunction;
	private address _disconnectParameter;
	/**
	 * Constructor.
	 *
	 * It is assumed that the connection has completed whatever initial handshake was needed. The HTTP
	 * message handler constructs the WebSocket object with the correct connection object and the correct
	 * server setting.
	 *
	 * @param connection An open connection, such as an HTTP connection that has completed the WebSocket
	 * request protocol.
	 * @param server true if this is a server-side WebSocket. There are small differences in the frame
	 * headers, so a server-side connection cannot successfully communicate with another server-side connection.
	 */
	public WebSocket(ref<Connection> connection, boolean server) {
		maxFrameSize = 1024;
		_connection = connection;
		_server = server;
//		if (server && connection != null)
//			logger.debug("Creating Web socket for socket %d", connection.requestFd());
//		else if (connection != null)
//			logger.debug("Creating client wb socket for socket %d", connection.requestFd());
		_incomingData.resize(1024);
	}

	~WebSocket() {
		ref<Thread> readerThread = stopReading();
		
		if (readerThread != null) {
//			logger.debug("about to join...\n");
			readerThread.join();
		}
//		logger.debug("about to stop writing...\n");
		stopWriting();
//		logger.debug("Socket %d cleaned up!\n", _connection.requestFd());
		delete _connection;
	}
	/**
	 * readWholeMessage
	 *
	 * This method reads one message from the WebSocket. It is not thread-safe.
	 *
	 * The text of the message, if any, is returned in the byte array buffer argument.
	 *
	 * The two boolean return values are:
	 *	success		true if a message was received successfully. The contents of the buffer are the message.
	 *	sawClose	true if instead of a data message, we saw a 'close' control message. No further reads
	 *				will succeed after receiving this indicator. The appropriate action is to reply with
	 *				a 'close' control message and then close the connection.
	 *
	 * Note: in the current implementation, only one of the two flags can be true. If both are false, the
	 * appropriate action is to send a 'close' control message and close the connection.
	 *
	 * @threading This method is not thread safe.
	 */
	public boolean, boolean readWholeMessage(ref<byte[]> buffer) {
		boolean initialFrame = true;
		for (;;) {
			boolean lastFrame, success;
			int opcode;
			
			(lastFrame, opcode, success) = readFrame(buffer, initialFrame); 
			if (!success)
				break;
			if (lastFrame) {
				// If we got a close and this is not the initial frame, we might see a partial message in buffer. Do we care? 
				if (opcode == 8)
					return false, true;
				else
					return true, false;
			}
			if (opcode < 8)
				initialFrame = false;
		}
		return false, false;
	}
	/**
	 * @return true if this is the last frame of the message or false if more frames follow.
	 * @return The opcode of the message.
	 */
	boolean, int, boolean readFrame(ref<byte[]> buffer, boolean initialFrame) {
		boolean lastFrame;
		
		int opcode = getc();
		if (opcode < 0)
			return false, 0, false;
		int payloadLengthByte = getc();
		if (payloadLengthByte < 0)
			return false, 0, false;
		
		long payloadLength;
		
		boolean success;
		switch (payloadLengthByte & 0x7f) {
		case 126:
			short s;
			(s, success) = readShort();
			payloadLength = char(s);
			if (!success)
				return false, 0, false;
			break;
			
		case 127:
			(payloadLength, success) = readLong();
			if (!success)
				return false, 0, false;
			break;
			
		default:
			payloadLength = payloadLengthByte & 0x7f;
		}
		
		unsigned mask;

		if ((payloadLengthByte & 0x80) != 0) {		// It is a masked frame
			(mask, success) = readMask();
			if (!success)
				return false, 0, false;
		}
		
		int offset = buffer.length();
		buffer.resize(int(offset + payloadLength));
		
//		logger.format(log.DEBUG, "offset = %d payloadLength = %d buffer = %p", offset, payloadLength, buffer);
		int copied = drainBuffer(&(*buffer)[offset], int(payloadLength));
		
		while (copied < payloadLength) {
			int received = _connection.read(&(*buffer)[offset + copied], int(payloadLength - copied));
			if (received >= int(payloadLength - copied))
				break;
			copied += received;
//			logger.format(log.DEBUG, "received = %d copied = %d payloadLength= %d", received, copied, payloadLength);
		}
		// Unmask the frame data if necessary
		if (mask != 0) {
			int part = 24;
			for (int i = offset; i < offset + payloadLength; i++, part = (part - 8) & 0x1f) {
				(*buffer)[i] = byte((*buffer)[i] ^ byte(mask >> part)); 
			}
		}
		if (initialFrame) {
			switch (opcode & 0x7f) {
			case 1:
			case 2:
				return (opcode & 0x80) != 0, opcode & 0x7f, true;
				
			default:					// Not valid in an initial frame
				buffer.resize(offset);
				logger.error("initial opcode == %d", opcode & 0x7f);
				shutDown(CLOSE_BAD_DATA, "Unexpected opcode");
				return false, opcode & 0x7f, false;
				
			case 8:				// connection close
			case 9:				// ping
			case 10:			// pong
				break;
			}
		} else {
			switch (opcode & 0x7f) {
			case 0:
				return (opcode & 0x80) != 0, opcode & 0x7f, true;

			default:					// Not valid in a non-initial frame
				buffer.resize(offset);
				logger.error("Unexpected non-zero opcode (%d) on non-initial frame", opcode & 0x7f);
				shutDown(CLOSE_PROTOCOL_ERROR, "Unexpected opcode");
				return false, opcode & 0x7f, false;
				
			case 8:				// connection close				
			case 9:				// ping
			case 10:			// pong
				break;
			}
		}
		switch (opcode & 0x7f) {
		case 8:				// connection close
			buffer.resize(offset);
			return true, OP_CLOSE, true;
			
		case 9:				// ping
			string pong(&(*buffer)[offset], int(payloadLength));

			writer.write(new Operation(this, OP_PONG, pong));
			buffer.resize(offset);
			return false, OP_PING, true;
			
		case 10:			// pong
			buffer.resize(offset);
			return false, OP_PONG, true;
		}
		// Should never get here.
		buffer.resize(offset);
		return false, opcode & 0x7f, true;
	}

	private short, boolean readShort() {
		int high = getc();
		if (high < 0)
			return 0, false;
		int low = getc();
		if (low < 0)
			return 0, false;
		return short((high << 8) + low), true;
	}
	
	private unsigned, boolean readMask() {
		int bits24 = getc();
		if (bits24 < 0)
			return 0, false;
		int bits16 = getc();
		if (bits16 < 0)
			return 0, false;
		int bits8 = getc();
		if (bits8 < 0)
			return 0, false;
		int bits0 = getc();
		if (bits0 < 0)
			return 0, false;
		return unsigned((bits24 << 24) + (bits16 << 16) + (bits8 << 8) + bits0), true;
	}
	
	private long, boolean readLong() {
		int bits56 = getc();
		if (bits56 < 0)
			return 0, false;
		int bits48 = getc();
		if (bits48 < 0)
			return 0, false;
		int bits40 = getc();
		if (bits40 < 0)
			return 0, false;
		int bits32 = getc();
		if (bits32 < 0)
			return 0, false;
		int bits24 = getc();
		if (bits24 < 0)
			return 0, false;
		int bits16 = getc();
		if (bits16 < 0)
			return 0, false;
		int bits8 = getc();
		if (bits8 < 0)
			return 0, false;
		int bits0 = getc();
		if (bits0 < 0)
			return 0, false;
		return (long(bits56) << 56) + (long(bits48) << 48) + (long(bits40) << 40) + (long(bits32) << 32) + (bits24 << 24) + (bits16 << 16) + (bits8 << 8) + bits0, true;
	}
	
	private int drainBuffer(pointer<byte> loc, int count) {
		int remaining = _incomingLength - _incomingCursor;
		if (remaining > count)
			remaining = count;
		C.memcpy(loc, &_incomingData[_incomingCursor], remaining);
		_incomingCursor += remaining;
		return remaining;
	}
	
	private int getc() {
		if (_incomingCursor >= _incomingLength) {
			_incomingLength = _connection.read(&_incomingData[0], _incomingData.length());
			if (_incomingLength <= 0) {
				if (_incomingLength < 0)
					logger.error("connection read failed: %s", linux.strerror(linux.errno()));
//				logger.debug("CLOSE_BAD_DATA - recv failed");
				shutDown(CLOSE_BAD_DATA, "recv failed");
				return -1;
			}
			_incomingCursor = 0;
		}
		return _incomingData[_incomingCursor++];
	}
	/**
	 * Write a string message.
	 *
	 * This is equivalent to calling the two-argument {@link write} method
	 * with an opcode of {@link OP_STRING}.
	 *
	 * @threading This method is thread-safe.
	 *
	 * @param message The message text.
	 */
	public void write(string message) {
		writer.write(new Operation(this, OP_STRING, message));
	}
	/**
	 * Write a message with an arbitrary opcode.
	 *
	 * @threading This method is thread-safe.
	 *
	 * @param opcode One of the defined opcodes ({@link OP_STRING}, {@link OP_BINARY}, {@link OP_CLOSE},
	 * {@link OP_PING} or {@link OP_PONG}. Passing any other value for the opcode is undefined.
	 */
	public void write(byte opcode, string message) {
		writer.write(new Operation(this, opcode, message));
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
		writer.write(new Operation(this, cause, reason));
//		if (_readerThread != null) {
//			printf("%s %p Waiting on reader thread...\n", currentThread().name(), this);
//			_readerThread.join();
//			printf("%s %p Reader thread joined.\n", currentThread().name(), this);
//		}
	}
	/**
	 * A server calls this method on the web socket to register a client
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
	/**
	 * This method is called on the server side of a WebSocket to let the server
	 * know when this happens.
	 *
	 * @param normalClose true if the client disconnected with a normal close, false
	 * if there was an error.
	 */
	void disconnect(boolean normalClose) {
		if (_disconnectFunction != null)
			_disconnectFunction(_disconnectParameter, normalClose);
	}
	/**
	 * send
	 *
	 * A convenience method for sending a message that consists of a single string.
	 * It is transmitted as an OP_STRING.
	 */
	boolean send(string message) {
		return send(OP_STRING, &message[0], message.length());
	}
	/**
	 * send
	 *
	 * A convenience method for sending a binary message. The byte array is transmitted
	 * as an OP_BINARY.
	 */
	boolean send(byte[] message) {
		return send(OP_BINARY, &message[0], message.length());
	}
	/**
	 * send
	 *
	 * The lower-level method that gives you full control of the message op code and
	 * content. This can be used to send control messages as well as string or binary data
	 * messages.
	 */
	boolean send(byte opcode, pointer<byte> message, int length) {
		do {
			int frameLength = maxFrameSize <= length ? maxFrameSize : length;
			boolean lastFrame = frameLength >= length;
			if (!sendFrame(opcode, lastFrame, message, frameLength))
				return false;
			length -= frameLength;
			message += frameLength;
			opcode = 0;
		} while (length > 0);
		return true;
	}
	
	private boolean sendFrame(byte opcode, boolean lastFrame, pointer<byte> data, int length) {
		byte[] frame;
		byte maskBit;

		if (!_server)
			maskBit = 0x80;
		if (lastFrame)
			opcode |= 0x80;
		frame.append(opcode);
		
		if (length > 65535) {
			frame.append(byte(maskBit | 127));
			frame.append(0);
			frame.append(0);
			frame.append(0);
			frame.append(0);
			frame.append(byte(length >> 24));
			frame.append(byte(length >> 16));
			frame.append(byte(length >> 8));
			frame.append(byte(length));			
		} else if (length > 125) {
			frame.append(byte(maskBit | 126));
			frame.append(byte(length >> 8));
			frame.append(byte(length));			
		} else
			frame.append(byte(maskBit | length));
		if (!_server) {
			unsigned mask = _random.next();
			frame.append(byte(mask >> 24));
			frame.append(byte(mask >> 16));
			frame.append(byte(mask >> 8));
			frame.append(byte(mask));
			int part = 24;
			for (int i = 0; i < length; i++, part = (part - 8) & 0x1f)
				data[i] = byte(data[i] ^ byte(mask >> part)); 
		}
		frame.append(data, length);
//		printf("Sending:\n");
//		text.memDump(&frame[0], frame.length(), 0);
		int result = _connection.write(&frame[0], frame.length());
		if (result == frame.length())
			return true;
		_connection.close();
		return false;
	}
	/**
	 * Retrieve the underlying connection for this WebSocket.
	 *
	 * @return The connection used to construct the object.
	 */
	public ref<Connection> connection() {
		return _connection;
	}
	/**
	 * Retrieve the server/client role of the WebSocket.
	 *
	 * @return true if this is a server-side WebSocket, false if client-side.
	 */
	public boolean server() {
		return _server;
	}
}

private void networkOrder(ref<byte[]> output, short x) {
	output.append(byte(x >> 8));
	output.append(byte(x));
}

private void networkOrder(ref<byte[]> output, string x) {
	for (int i = 0; i < x.length(); i++)
		output.append(x[i]);
}
/**
 * A class that is serving as either a proxy or stub connected to a Web Socket will
 * implement this interface.
 *
 * It is possible to write your own code to read from a Web Socket, but the framework
 * makes it easier to manage, since the Web Socket itself will spawn the reader thread
 * for you, using the {@link parasol:http.WebSocket.startReader} method.
 */
public interface WebSocketReader {
	/**
	 * The implementor of this method should call {@link parasol:http.WebSocket.readWholeMessage}
	 * in a loop to obtain each message and respond appropriately.
	 *
	 * @return Returns true if the last call to readWholeMessage returned true for the sawClose
	 * return value. The effect of returning true is to send a close frame and then shut down
	 * the Web Socket connection. Returning false will skip the send and close the connection
	 * immediately.
	 *
	 * While the connection will get closed either way, the Web Socket protocol requires the
	 * close frame reply when you receive a close frame yourself. The remote party could respond
	 * badly if you do not properly reply on a close request.
	 */
	boolean readMessages();
}
/**
 * An object generated by each send-half of a message pair and matched by a response-half of the pair.
 *
 * When a WebSocket needs to make a call with a return value, the calling thread has to send
 * a message, then wait for the reply to the message. Because a WebSocket is full-duplex any
 * number of messages of any number of kinds can arrive before the reply that the calling thread
 * is waiting for arrives.
 *
 * So, the sender creates a Rendezvous object to track the reply.
 */
public monitor class Rendezvous {
	ref<RendezvousManager> _proxy;
	string _key;
	/**
	 * The message body of the reply-half of a message pair.
	 *
	 * This is a copy of the text passed in the called to {@link postReply}. Note that if the 
	 * object is notified due to the Web socket being closed before receipt of a response-message,
	 * this member will be an empty array.
	 *
	 * @threading Do not check the value of this member until a call to {@link wait} has retuend.
	 */
	public byte[] replyMessage;
	/**
	 * An indicator of a successfully posted response-half message.
	 *
	 * If the value is true, {@link postResult} was called. If the value is false, the Web Socket
	 * was closed before the response-half message was received.
	 *
	 * @threading Do not check the value of this member until a call to {@link wait} has retuend.
	 */
	public boolean success;

	Rendezvous(ref<RendezvousManager> proxy, string key) {
		_proxy = proxy;
		_key = key;
	}
	/**
	 * Marshalling code should call this method with the message body text after a response-half message
	 * has been received.
	 *
	 * Typically this method will be called only once per object. Calling both {@link abandon} and this method on
	 * the same object is undefined. Since in normal usage, the this object was obtained by a call to
	 * {@link RendezvousManager.extractRendezvous} method, only one calling thread will get the object.
	 *
	 * @param message The message text. Whether this message text includes or excludes the key itself is
	 * up to the calling code.
	 *
	 * @threading This method is thread safe. 
	 */
	public void postResult(byte[] message) {
		replyMessage = message;
		success = true;
		notify();
	}
	/**
	 * Marshalling code should call this method after a Web Socket is closed, or when the protocol can determine
	 * that this object's response-half message is either never going to arrive or can be ignored.
	 *
	 * Typically this method will be called only once per object. Calling both {@link postResult} and this method on
	 * the same object is undefined. Since in normal usage, the this object was obtained by a call to
	 * {@link RendezvousManager.extractRendezvous} method, only one calling thread will get the object.
	 *
	 * @threading This method is thread safe. 
	 */
	public void abandon() {
		success = false;
		notify();
	}
	/**
	 * This method can be called to cancel this object in it's pending set.
	 *
	 * There is a race, since the threads that might call this method are usually not the methods that would
	 * call {@link postResult} or {@link abandon}, there is a race between potential calls and there is no
	 * guarantee that this method will, in fact, remove the pending object before another thread posts results for it. 
	 *
	 * @return true if the call actually cancelled the call before results came in, false if there was no
	 * Rendezvous with the given key under management.
	 */
	public boolean cancel() {
		ref<Rendezvous> r = _proxy.extractRendezvous(_key);
		delete r;
		return r != null;
	}
}
/**
 * Base class useful for implementing synchronous send-reply message pairs.
 *
 * This is a support class that can be used to build a synchronous call-response message pair. These give you the
 * functionality of an RPC. The typical approach would be to implement your proxy class by extending {@code RendezvousManager}
 * and implementing {@link WebSocketReader}. The messages on the web socket need to be defined so that a call-response
 * pair have a key string that uniquely identifies the pair. The derived class implements the marshalling logic to generate
 * a message that contains the key string plus the set of marshalled RPC parameters. This code will call 
 * {@link createRendesvous} to create a {@link Rendezvous} object. The send-side thread then calls the {@link Monitor.wait}
 * method of the {@link Rendezvous} object to wait for the response message. If the Web Socket is closed, then all pending
 * {@link Rendezvous} objects will be notified in order to release the waiting threads.
 *
 * The {@link WebSocketReader.readMessages} method will parse the incoming response message body and extract the message key.
 * That code will then call {@link extractRendezvous} to retrieve the send-side {@link Rendezvous} object and notify it
 * with the response message body using the {@link Rendezvous.postResult} message.
 *
 * The following code will typically appear in a {@link WebSocketReader.readMessages} method after the last message has been
 * read. This sequence will empty the pending queue of the object and notify all waiting threads indicating the calls were
 * not successful.
 *
 *<pre>{@code
 *		ref\<http.Rendezvous\>[] pending = extractAllRendezvous();
 *		for (i in pending)
 *			pending[i].abandon();
 *}</pre>
 */
public monitor class RendezvousManager {
	ref<Rendezvous>[string] _pendingMessages;
	int _nextMessage;
	boolean _shuttingDown;
	/**
	 * Gets a unique integer that can be used as part of the message pair key string.
	 *
	 * @return A unique integer.
	 *
	 * @threading This method is thread safe. Each call is guaranteed to return a unique value.
	 */
	public int getNextMessageID() {
		return _nextMessage++;
	}
	/**
	 * Creates a {@link Rendezvous} object for the indicated key.
	 *
	 * @param key The key string to use for retrieving a reference to the same object.
	 *
	 * @return The created {@link Rendezvous} object, or null if the Web Socket is shutting down or the key
	 * string already exists in the list of pending messages.
	 */
	public ref<Rendezvous> createRendezvous(string key) {
		if (_shuttingDown)
			return null;
		if (_pendingMessages[key] != null)
			return null;

		ref<Rendezvous> r = new Rendezvous(this, key);

		_pendingMessages[key] = r;
		return r;
	}
	/**
	 * Retrieves the {@link Rendezvous} object corresponding to the indicated key.
	 *
	 * If the key matches an object, the object is forgotten and future calls to this method
	 * for the same key will return null. You can therefore recycle key strings if you can be certain
	 * that a given key has been extracted before a new {@link Rendezvous} object is created for the 
	 * same key.
	 *
	 * @param key the key string to use to locate the corresponding {@link Rendezvous} object.
	 *
	 * @return The matching {@link Rendezvous} object, or null if no such object exists.
	 */
	public ref<Rendezvous> extractRendezvous(string key) {
		ref<Rendezvous> r = _pendingMessages[key];
		_pendingMessages.remove(key);
		return r;
	}
	/**
	 * Retrieves all pending {@link Rendezvous} objects that have been created and not extracted.
	 *
	 * After this call is completed, all {@link Rendezvous} objects are gone and the manager object is empty.
	 *
	 * Calling this method also sets the shutdown flag, so future calls to {@link createRendezvoous} fail.
	 */
	public ref<Rendezvous>[] extractAllRendezvous() {
		_shuttingDown = true;
		ref<Rendezvous>[] results;
		for (ref<Rendezvous>[string].iterator i = _pendingMessages.begin(); i.hasNext(); i.next())
			results.append(i.get());
		_pendingMessages.clear();
		return results;
	}
}

class Operation {
	ref<WebSocket> webSocket;
	byte opcode;
	string message;
	short cause;

	Operation(ref<WebSocket> webSocket, byte opcode, string message) {
		this.webSocket = webSocket;
		this.opcode = opcode;
		this.message = message;
	}

	Operation(ref<WebSocket> webSocket, short cause, string reason) {
		this.webSocket = webSocket;
		this.opcode = WebSocket.OP_CLOSE;
		this.cause = cause;
		this.message = reason;
	}
}

monitor class MessageWriter {
	ref<Thread> _writeThread;

	Queue<ref<Operation>> _q;

	void write(ref<Operation> op) {
//		printf("%s %p writer.write\n", currentThread().name(), this);
		if (_writeThread == null) {
			_writeThread = new Thread("WebSocketWriter");
			_writeThread.start(writeWrapper, null);
		}
		if (op.webSocket == null || op.webSocket.enqueueWrite()) {
			_q.enqueue(op);
			notify();
		} else
			delete op;
	}

	ref<Operation> dequeue() {
//		printf("%s %p dequeue...\n", currentThread().name(), this);
		wait();
//		printf("%s %p un-waited...\n", currentThread().name(), this);
		return _q.dequeue();
	}

	ref<Thread> active() {
//		printf("%s %p trying to shutdown! writeThread = %p\n", currentThread().name(), this, _writeThread);
		return _writeThread;
	}
}

class MessageWriterShutDown {
	~MessageWriterShutDown() {
//		printf("destructor!\n");
		ref<Thread> t = writer.active();
		if (t != null) {
			writer.write(new Operation(null, WebSocket.OP_SHUTDOWN, null));
			t.join();
			delete t;
		}
	}
	
}

/**
 * writeWrapper
 *
 *	This method is the main loop of the WebSocket writer thread. Once started, it remains running waiting for
 *	some WebSocket to write some data.
 */
void writeWrapper(address arg) {
	for (;;) {
//		printf("%s writer waiting...\n", currentThread().name());
		ref<Operation> op = writer.dequeue();
//		logger.debug("Socket %d web write opcode %d len %d", op.webSocket != null && op.webSocket.connection() != null ? op.webSocket.connection().requestFd() : -1, op.opcode, op.message.length());
//		logger.dumpMemory(log.DEBUG, "message", &op.message[0], op.message.length(), 0);
		if (op.opcode == WebSocket.OP_CLOSE) {
//			logger.debug("%d Sending OP_CLOSE message: %d %s", op.webSocket.connection().requestFd(),
//									op.cause, op.message);
			byte[] closeFrame;

			networkOrder(&closeFrame, op.cause);
			networkOrder(&closeFrame, op.message);
			op.webSocket.send(WebSocket.OP_CLOSE, &closeFrame[0], closeFrame.length());
		} else if (op.opcode == WebSocket.OP_SHUTDOWN) {
//			printf("%s shutting down...\n", currentThread().name());
			delete op;
			break;
		} else
			op.webSocket.send(op.opcode, &op.message[0], op.message.length());
		op.webSocket.writeFinished();
		delete op;
	}
}

MessageWriter writer;

private MessageWriterShutDown writerShutDown;

