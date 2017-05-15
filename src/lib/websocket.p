/*
   Copyright 2015 Rovert Jervis

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
import openssl.org:crypto.SHA1;
import parasol:net.base64encode;
import parasol:text;

public class WebSocketService extends HttpService {
	private monitor _webSockets {
		ref<WebSocket>[string] _webSocketProtocols;
	}

	public void webSocketProtocol(string protocol, ref<WebSocket> webSocket) {
		ref<WebSocket> oldProtocol;
		lock (_webSockets) {
			oldProtocol = _webSocketProtocols[protocol];
			_webSocketProtocols[protocol] = webSocket;
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
				ref<WebSocket> ws;
				lock (_webSockets) {
					ws = _webSocketProtocols[p];
				}
				if (ws != null)
					return ws.processConnection(p, request, response);
			}
		}
		response.error(400);			// you gotta give me a matching protocol
		return false;
	}
}

public class WebSocket {
//	@Constant
	public static byte OP_STRING = 1;
//	@Constant
	public static byte OP_BINARY = 2;
	
	public int maxFrameSize;
	int _fd;
	private boolean _server;
	/**
	 * Construct a server-side WebSocket
	 */
	public WebSocket() {
		maxFrameSize = 1024;
		_server = true;
	}
	/**
	 * Construct a client-side WebSocket
	 */
	public WebSocket(int fd) {
		maxFrameSize = 1024;
		_fd = fd;
		_server = false;
	}
	
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
		_fd = response.fd();
		response.respond();
		start();
		return true;
	}
/*	
	public boolean readFinalClientHandshake() {
		byte[] frameBuffer;
		frameBuffer.resize(512);
		ref<MessageHeader> header;
		
		printf("in readFinal\n");
		int bufferEnd = recv(_fd, &frameBuffer[0], frameBuffer.length(), 0);
		printf("buffeerEnd = %d\n", bufferEnd);
		text.memDump(&frameBuffer[0], bufferEnd, 0);
		if (bufferEnd < 20) {
			shutDown();
			return false;
		}
		string s(frameBuffer);
		if (!s.startsWith("HTTP/1.1 101 Swithing Prototocls\r\n")) {
			shutDown();
			return false;
		}
		printf("Saw the last handshake!\n");
		return true;
	}
 */
	public void shutDown() {
		closesocket(_fd);
	}
	
	public boolean readWholeMessage(ref<byte[]> buffer) {
		boolean initialFrame = true;
		for (;;) {
			boolean lastFrame, success;
			int opcode;
			
			(lastFrame, opcode, success) = readFrame(buffer, initialFrame); 
			if (!success)
				break;
			if (lastFrame)
				return true;
			initialFrame = false;
		}
		return false;
	}
	
	public boolean, int, boolean readFrame(ref<byte[]> buffer, boolean initialFrame) {
		byte[] frameBuffer;
		frameBuffer.resize(512);
		ref<MessageHeader> header;
		boolean lastFrame;
		
		int bufferEnd = recv(_fd, &frameBuffer[0], frameBuffer.length(), 0);
		if (bufferEnd <= 0) {
			printf("bufferEnd = %d\n", bufferEnd);
			linux.perror(null);
			shutDown();
			return false, 0, false;
		}
		ref<MessageHeader> mh = ref<MessageHeader>(&frameBuffer[0]);
		int totalLength = mh.payloadLength();
		pointer<byte> payload = mh.payload();
		int offset = int(payload - &frameBuffer[0]);
		if (mh.masked()) {
			unsigned mask = mh.mask();
			int part = 24;
			for (int i = offset; i < bufferEnd; i++, part = (part - 8) & 0x1f) {
				frameBuffer[i] = byte(frameBuffer[i] ^ byte(mask >> part)); 
			}
		}
		buffer.append(&frameBuffer[offset], bufferEnd - offset);
		if (totalLength > bufferEnd - offset) {
			printf("Long frame\n");
			shutDown();
			return mh.fin(), mh.opcode(), false;
		}
		if (initialFrame) {
			switch (mh.opcode()) {
			case 1:
			case 2:
				break;
				
			default:					// Not valid in an initial frame
				printf("initial opcode == %d\n", mh.opcode());
				shutDown();
				return mh.fin(), mh.opcode(), false;
				
			case 8:				// connection close
			case 9:				// ping
			case 10:			// pong
				printf("Unfinished control frame %d\n", mh.opcode());
				shutDown();
				return mh.fin(), mh.opcode(), false;
			}
		} else if (mh.opcode() != 0) {
			switch (mh.opcode()) {
			default:					// Not valid in an initial frame
				printf("Unexpected non-zero opcode on non-initial frame\n");
				shutDown();
				return mh.fin(), mh.opcode(), false;
				
			case 8:				// connection close
			case 9:				// ping
			case 10:			// pong
				printf("Unfinished non-initial control frame %d\n", mh.opcode());
				shutDown();
				return mh.fin(), mh.opcode(), false;
			}
		}
		return mh.fin(), mh.opcode(), true;
	}
	
	public boolean send(string message) {
		return send(OP_STRING, &message[0], message.length());
	}
	
	public boolean send(byte opcode, pointer<byte> message, int length) {
		do {
			int frameLength = maxFrameSize <= length ? maxFrameSize : length;
			boolean lastFrame = frameLength < length;
			if (!sendFrame(opcode, lastFrame, message, frameLength))
				return false;
			length -= frameLength;
			message += frameLength;
		} while (length > 0);
		return true;
	}
	
	private boolean sendFrame(byte opcode, boolean lastFrame, pointer<byte> data, int length) {
		byte[] frame;
		
		if (!_server) {
			printf("Unsupported client-side WebSocket\n");
			shutDown();
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
		int result = send(_fd, &frame[0], frame.length(), 0);
		if (result == frame.length())
			return true;
		printf("WebSocket send failed\n");
		linux.perror(null);
		shutDown();
		return false;
	}
	
	public abstract void start(); 
	
	protected int fd() {
		return _fd;
	}
}

private class MessageHeader {
	private byte _opcode;
	private byte _payloadLength;
	
	boolean fin() {
		return (_opcode & 0x80) != 0;
	}
	
	boolean masked() {
		return (_payloadLength & 0x80) != 0;
	}
	
	int opcode() {
		return _opcode & 0x7f;
	}
	
	int payloadLength() {
		int rawLength = _payloadLength & 0x7f;
		
		switch (rawLength) {
		case 126:
			pointer<byte> pb = pointer<byte>(this);
			return pb[3] + (pb[2] << 8);
			
		case 127:
			pb = pointer<byte>(this);
			return pb[7] + (pb[6] << 8) + (pb[5] << 16) + (pb[4] << 24) + (pb[3] << 32) + (pb[2] << 40) + (pb[1] << 48) + (pb[0] << 54);
			
		default:
			return rawLength;
		}
		return rawLength;
	}
	
	unsigned mask() {
		if (masked()) {
			int rawLength = _payloadLength & 0x7f;
			pointer<byte> pb;
			
			switch (rawLength) {
			case 126:
				pb = pointer<byte>(this) + 4;
				break;
				
			case 127:
				pb = pointer<byte>(this) + 10;
				break;
				
			default:
				pb = pointer<byte>(this) + 2;
			}
			return unsigned((pb[0] << 24) + (pb[1] << 16) + (pb[2] << 8) + pb[3]); 
		} else
			return 0;
	}
	
	pointer<byte> payload() {
		int rawLength = _payloadLength & 0x7f;
		pointer<byte> pb;
		
		switch (rawLength) {
		case 126:
			pb = pointer<byte>(this) + 4;
			break;
			
		case 127:
			pb = pointer<byte>(this) + 10;
			break;
			
		default:
			pb = pointer<byte>(this) + 2;
		}
		if (masked())
			return pb + int.bytes; 
		else
			return pb;
	}
}