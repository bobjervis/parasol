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
import parasol:net.base64encode;
import parasol:net.Connection;
import parasol:random.Random;
import parasol:text;
import parasol:thread;
import parasol:thread.Thread;
import parasol:thread.currentThread;
import parasol:types.Queue;

private monitor class WebSocketServiceData {
	ref<WebSocketFactory>[string] _webSocketProtocols;
}

public class WebSocketService extends HttpService {
	private WebSocketServiceData _webSockets;

	public void webSocketProtocol(string protocol, ref<WebSocketFactory> webSocketFactory) {
		ref<WebSocketFactory> oldProtocol;
		lock (_webSockets) {
			oldProtocol = _webSocketProtocols[protocol];
			if (webSocketFactory == null)
				_webSocketProtocols.remove(protocol);
			else
				_webSocketProtocols[protocol] = webSocketFactory;
		}
		if (oldProtocol != null)
			delete oldProtocol;
	}
	
	public boolean processRequest(ref<HttpRequest> request, ref<HttpResponse> response) {
		if (request.method != HttpRequest.Method.GET) {
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

public class WebSocketFactory {
	boolean processConnection(string protocol, ref<HttpRequest> request, ref<HttpResponse> response) {
		string key = request.headers["sec-websocket-key"];
		if (key == null) {
			response.error(400);
			return false;
		}
		ref<Connection> connection = response.connection();
		if (!start(request, response, connection))
			return false;
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

	public abstract boolean start(ref<HttpRequest> request, ref<HttpResponse> response, ref<Connection> connection);
}

public string computeWebSocketKey(int byteCount) {
	Random rand;
	byte[] stuff = rand.getBytes(byteCount);
	return base64encode(stuff);
}

public string computeWebSocketAccept(string webSocketKey) {
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
			//	   to transmit an OP_CLOSE control frame will be pointless. Tht's fortunately the key
			//	   phrase: pointless, not harmful.
			
			if (_reader != null)
				ref<WebSocket>(this).shutDown(WebSocket.CLOSE_NORMAL, "normal close");

//			printf("about to join...\n");
			_readerThread = null;
		}
		return t;
	}

	public boolean stopWriting() {
		if (_shuttingDown)
			return false;
		_shuttingDown = true;
		if (_waitingWrites > 0)
			wait();
		return true;
	}

	public boolean enqueueWrite() {
		if (_shuttingDown)
			return false;
		_waitingWrites++;
		return true;
	}

	public void writeFinished() {
		if (_waitingWrites <= 0)
			assert(false);
		_waitingWrites--;
		if (_shuttingDown && _waitingWrites == 0)
			notify();
	}
}

private void readWrapper(address arg) {
//		printf("%s %p reader thread starting readMessages...\n", currentThread().name(), arg);
	boolean sawClose = ref<WebSocket>(arg).reader().readMessages();
	if (sawClose)
		ref<WebSocket>(arg).shutDown(WebSocket.CLOSE_NORMAL, "normal close");
	ref<WebSocket>(arg).discardReader();
}

public class WebSocket extends WebSocketVolatileData {
//	@Constant
	public static byte OP_STRING = 1;
//	@Constant
	public static byte OP_BINARY = 2;
//	@Constant
	public static byte OP_CLOSE = 8;
//	@Constant
	public static byte OP_PING = 9;
//	@Constant
	public static byte OP_PONG = 10;
//	@Constant
	public static byte OP_SHUTDOWN = 255;			// Not really a Web Socket operation - used internally

//	@Constant
	public static short CLOSE_NORMAL = 1000;
	public static short CLOSE_GOING_AWAY = 1001;
	public static short CLOSE_PROTOCOL_ERROR = 1002;
	public static short CLOSE_BAD_DATA = 1003;

	public int maxFrameSize;
	
	private ref<Connection> _connection;
	private boolean _server;
	private Random _random;				// For masking
	private byte[] _incomingData;		// A buffer of data being read from the websocket.
	private int _incomingLength;		// The number of bytes in the buffer.
	private int _incomingCursor;		// The index of the next byte to be read from the buffer.

	public WebSocket(ref<Connection> connection, boolean server) {
		maxFrameSize = 1024;
		_connection = connection;
		_server = server;
		_incomingData.resize(1024);
	}

	~WebSocket() {
		ref<Thread> readerThread = stopReading();
		
		if (readerThread != null) {
//			printf("about to join...\n");
			readerThread.join();
		}
//		printf("about to stop writing...\n");
		stopWriting();
//		printf("Socket cleaned up!\n");
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
	
	public boolean, int, boolean readFrame(ref<byte[]> buffer, boolean initialFrame) {
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
			payloadLength = s;
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
		
		int copied = drainBuffer(&(*buffer)[offset], int(payloadLength));
		
		while (copied < payloadLength) {
			int received = _connection.read(&(*buffer)[offset + copied], int(payloadLength - copied));
			if (received >= int(payloadLength - copied))
				break;
			copied += received;
			printf("received = %d copied = %d payloadLength= %d\n", received, copied, payloadLength);
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
				printf("initial opcode == %d\n", opcode & 0x7f);
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

			default:					// Not valid in an initial frame
				buffer.resize(offset);
				printf("Unexpected non-zero opcode (%d) on non-initial frame\n", opcode & 0x7f);
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
//			printf("About to read from connection %p\n", _connection);
			_incomingLength = _connection.read(&_incomingData[0], _incomingData.length());
			if (_incomingLength <= 0) {
				if (_incomingLength < 0) {
					printf("_incomingLength = %d\n", _incomingLength);
					linux.perror(null);
				}
				shutDown(CLOSE_BAD_DATA, "recv failed");
				return -1;
			}
			_incomingCursor = 0;
		}
		return _incomingData[_incomingCursor++];
	}

	public void write(string message) {
		writer.write(new Operation(this, OP_STRING, message));
	}

	public void write(byte opcode, string message) {
		writer.write(new Operation(this, opcode, message));
	}

	public void shutDown(short cause, string reason) {
		writer.write(new Operation(this, cause, reason));
//		if (_readerThread != null) {
//			printf("%s %p Waiting on reader thread...\n", currentThread().name(), this);
//			_readerThread.join();
//			printf("%s %p Reader thread joined.\n", currentThread().name(), this);
//		}
	}
	/**
	 * send
	 *
	 * A convenience method for sending a message that consists of a single string.
	 * It is transmitted as an OP_STRING.
	 */
	public boolean send(string message) {
		return send(OP_STRING, &message[0], message.length());
	}
	/**
	 * send
	 *
	 * A convenience method for sending a binary message. The byte array is transmitted
	 * as an OP_BINARY.
	 */
	public boolean send(byte[] message) {
		return send(OP_BINARY, &message[0], message.length());
	}
	/**
	 * send
	 *
	 * The lower-level method that gives you full control of the message op code and
	 * content. This can be used to send control messages as well as string or binary data
	 * messages.
	 */
	public boolean send(byte opcode, pointer<byte> message, int length) {
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
		printf("WebSocket send failed\n");
		linux.perror(null);
		_connection.close();
		return false;
	}
	
	protected ref<Connection> connection() {
		return _connection;
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

public interface WebSocketReader {
	boolean readMessages();
}
/**
 * Rendezvous
 *
 * When a WebSocket needs to make a call with a return value, the calling thread has to send
 * a message, then wait for the reply to the message. Because a WebSocket is full-duplex any
 * number of messages of any number of kinds can arrive before the reply that the calling thread
 * is waiting for arrives.
 *
 * So, the sender creates a Rendezvous object to track the reply.
 */
public monitor class Rendezvous {
	ref<WSPVolatileData> _proxy;
	string _key;
	public byte[] replyMessage;
	public boolean success;

	Rendezvous(ref<WSPVolatileData> proxy, string key) {
		_proxy = proxy;
		_key = key;
	}

	void postResult(byte[] message) {
		replyMessage = message;
		success = true;
		notify();
	}

	void abandon() {
		success = false;
		notify();
	}

	void cancel() {
		ref<Rendezvous> r = _proxy.extractRendezvous(_key);
		delete r;
	}
}

public monitor class WSPVolatileData {
	ref<Rendezvous>[string] _pendingMessages;
	int _nextMessage;
	boolean _shuttingDown;

	int getNextMessageID() {
		return _nextMessage++;
	}

	ref<Rendezvous> createRendezvous(string key) {
		if (_shuttingDown)
			return null;
		if (_pendingMessages[key] != null)
			return null;

		ref<Rendezvous> r = new Rendezvous(this, key);

		_pendingMessages[key] = r;
		return r;
	}

	ref<Rendezvous> extractRendezvous(string key) {
		ref<Rendezvous> r = _pendingMessages[key];
		_pendingMessages.remove(key);
		return r;
	}

	ref<Rendezvous>[] extractAllRendezvous() {
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
//			printf("%s %p notify...\n", currentThread().name(), this);
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
//		printf("%s writer got something to write opcode %d\n", currentThread().name(), op.opcode);
		if (op.opcode == WebSocket.OP_CLOSE) {
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

