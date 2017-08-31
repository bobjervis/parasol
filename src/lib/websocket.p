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
import parasol:text;

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
		response.statusLine(101, "Switching Protocols");
		string key = request.headers["sec-websocket-key"];
		if (key == null) {
			response.error(400);
			return false;
		}
		string value = key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
		byte[] hash;
		
		hash.resize(20);
		
		SHA1(&value[0], value.length(), &hash[0]);
		string v = base64encode(hash);
		response.header("Sec-WebSocket-Accept", v);
		response.header("Connection", "Upgrade");
		response.header("Upgrade", "websocket");
		response.header("Sec-Websocket-Protocol", protocol);
		response.endOfHeaders();
		ref<Connection> connection = response.connection();
		response.respond();
		start(connection);
		return true;
	}

	public abstract void start(ref<Connection> connection);
}

public class WebSocket {
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
	public static short CLOSE_NORMAL = 1000;
	public static short CLOSE_GOING_AWAY = 1001;
	public static short CLOSE_PROTOCOL_ERROR = 1002;
	public static short CLOSE_BAD_DATA = 1003;

	public int maxFrameSize;
	
	private ref<Connection> _connection;
	private boolean _server;
	private byte[] _incomingData;		// A buffer of data being read from the websocket.
	private int _incomingLength;		// The number of bytes in the buffer.
	private int _incomingCursor;		// The index of the next byte to be read from the buffer.

	public WebSocket(ref<Connection> connection, boolean server) {
		maxFrameSize = 1024;
		_connection = connection;
		_server = server;
		_incomingData.resize(1024);
	}
	
	public void shutDown(short cause, string reason) {
		byte[] closeFrame;
		
		printf("websocket shutDown (%d, %s)\n", cause, reason);
		networkOrder(&closeFrame, cause);
		networkOrder(&closeFrame, reason);
		send(OP_CLOSE, &closeFrame[0], closeFrame.length());
		_connection.close();
	}
	
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
		
		if (copied < payloadLength) {
			int received = _connection.read(&(*buffer)[offset + copied], int(payloadLength - copied));
			if (received < int(payloadLength - copied)) {
				printf("received = %d\n", received);
				linux.perror(null);
				shutDown(CLOSE_BAD_DATA, "recv failed");
				return false, 0, false;
			}
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
			shutDown(CLOSE_NORMAL, "Responding to close");
			return true, 8, true;
			
		case 9:				// ping
			send(OP_PONG, &(*buffer)[offset], int(payloadLength));
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
				printf("_incomingLength = %d\n", _incomingLength);
				linux.perror(null);
				shutDown(CLOSE_BAD_DATA, "recv failed");
				return -1;
			}
			_incomingCursor = 0;
		}
		return _incomingData[_incomingCursor++];
	}
	
	public boolean send(string message) {
		return send(OP_STRING, &message[0], message.length());
	}
	
	public boolean send(byte[] message) {
		return send(OP_BINARY, &message[0], message.length());
	}
	
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
		
		if (!_server) {
			printf("Unsupported client-side WebSocket\n");
			shutDown(CLOSE_PROTOCOL_ERROR, "Trying to send frames from a non-server endpoint (masking not supported)");
			return false;
		}
		if (lastFrame)
			opcode |= 0x80;
		frame.append(opcode);
		
		if (length > 65535) {
			frame.append(127);
			frame.append(0);
			frame.append(0);
			frame.append(0);
			frame.append(0);
			frame.append(byte(length >> 24));
			frame.append(byte(length >> 16));
			frame.append(byte(length >> 8));
			frame.append(byte(length));			
		} else if (length > 125) {
			frame.append(126);
			frame.append(byte(length >> 8));
			frame.append(byte(length));			
		} else
			frame.append(byte(length));
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

