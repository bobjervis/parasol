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
namespace parasol:net;

import parasol:exception;
import native:net;
import native:linux;
import native:C;
import parasol:runtime;
import parasol:pxi.SectionType;
import openssl.org:ssl;
import native:windows.WORD;

private byte[] localhost = [ 127, 0, 0, 1 ];

public enum ServerScope {
	LOCALHOST,						// The Socket is only visible on the same machine as the server.
	INTERNET,						// The Socket is visible across the Internet (using IPv4).
}

public enum Encryption {
	NONE,
	SSLv2,
	SSLv3,
	SSLv23,							// Best available SSL/TLS
	TLSv1,
	TLSv1_1,
	TLSv1_2,
	DTLSv1,							// DTLS 1.0
	DTLSv1_2,						// DTLS 1.2
	DTLS,							// DTLS 1.0 and 1.2
}

public class SocketException extends exception.Exception {
	public SocketException() {
		super();
	}

	public SocketException(string message) {
		super(message);
	}

	ref<SocketException> clone() {
		ref<SocketException> n = new SocketException(_message);
		n._exceptionContext = _exceptionContext;
		return n;
	}
	
}
/**
 * hostIPv4
 *
 * This method returns the host IPv4 address, if any, for the current host.
 * If there was any error, or there are no IPv4 interfaces defined, this returns
 * zero.
 */
public unsigned hostIPv4() {
	ref<linux.ifaddrs> ifAddresses;
	if (linux.getifaddrs(&ifAddresses) != 0) {
		printf("getifaddrs failed\n");
		return 0;
	}
	int i = 1;
	for (ref<linux.ifaddrs> ifa = ifAddresses; ; ifa = ifa.ifa_next, i++) {
		if (ifa == null) {
			printf("No identifiable IPv4 address to use\n");
			return 0;
		}
		if (ifa.ifa_addr.sa_family == net.AF_INET) {
			pointer<byte> ipa = pointer<byte>(&(ref<net.sockaddr_in>(ifa.ifa_addr).sin_addr));
			if (ipa[0] == 127 && ipa[1] == 0 && ipa[2] == 0 && ipa[3] == 1)
				continue;
			return *ref<unsigned>(ipa);
		}
	}
	printf("No internet addresses found\n");
	return 0;
}

private  monitor class SocketInit {
	boolean _done;
}

private SocketInit _init;

public class Socket {
	public static ref<Socket> create() {
		return create(Encryption.NONE, null);
	}

	public static ref<Socket> create(Encryption encryption, string cipherList) {
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			lock (_init) {
				if (!_done) {
					_done = true;
					net.WSADATA data;
					WORD version = 0x202;
					
					int result = net.WSAStartup(version, &data);
					if (result != 0) {
						// TODO: Make up an exception class for this error.
						printf("WSAStartup returned %d\n", result);
						assert(result == 0);
					}
				}
			}
		}
		ref<Socket> socket;
		if (encryption == Encryption.NONE)
			socket = new PlainSocket();
		else
			socket = new SSLSocket(encryption, cipherList);
		return socket;
	}

	private char _port;
	private int _socketfd;

	protected Socket() {
		_socketfd = net.socket(net.AF_INET, net.SOCK_STREAM, 0);
		if (_socketfd < 0)
			throw SocketException("Socket could not be created");
		int xx = 1;
		if (net.setsockopt(_socketfd, net.SOL_SOCKET, net.SO_REUSEADDR, &xx, xx.bytes) < 0)
			throw SocketException("Socket options could not be set");
	}

	public boolean bind(char port, ServerScope scope) {
		net.sockaddr_in s;
		pointer<byte> ip;
		
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
			string hostname = "";

			ref<net.hostent> localHost = net.gethostbyname(&hostname[0]);
			if (localHost == null) {
				printf("gethostbyname failed for '%s'\n", hostname);
				return false;
			}
			ip = net.inet_ntoa (*ref<unsigned>(*localHost.h_addr_list));
//			string n(localHost.h_name);
//			printf("hostent name = '%s' ip = '%s'\n", n, x);
			net.inet_addr(ip);
		} else if (runtime.compileTarget == SectionType.X86_64_LNX) {
			if (scope == ServerScope.LOCALHOST)
				ip = &localhost[0];
			else {					// must be INTERNET
				ref<linux.ifaddrs> ifAddresses;
				if (linux.getifaddrs(&ifAddresses) != 0) {
					printf("getifaddrs failed\n");
					return false;
				}
				int i = 1;
				for (ref<linux.ifaddrs> ifa = ifAddresses; ; ifa = ifa.ifa_next, i++) {
					if (ifa == null) {
						printf("No identifiable IPv4 address to use\n");
						return false;
					}
					if (ifa.ifa_addr.sa_family == net.AF_INET) {
						pointer<byte> ipa = pointer<byte>(&(ref<net.sockaddr_in>(ifa.ifa_addr).sin_addr));
						if (ipa[0] == 127 && ipa[1] == 0 && ipa[2] == 0 && ipa[3] == 1)
							continue;
						ip = ipa;
						break;
					}
				}
			}
		}
		string x(ip);
		s.sin_family = net.AF_INET;
		s.sin_addr.s_addr = *ref<unsigned>(ip);
		s.sin_port = net.htons(port);
//		printf("s = { %d, %x, %x }\n", s.sin_family, s.sin_addr.s_addr, s.sin_port);
		if (net.bind(_socketfd, &s, s.bytes) != 0) {
			printf("Binding failed to %d!", port);
			if (runtime.compileTarget == SectionType.X86_64_LNX)
				linux.perror(" ".c_str());
			printf("\n");
			net.closesocket(_socketfd);
			return false;
		}
//		printf("socketfd = %d\n", _socketfd);
		return true;
	}

	public boolean listen() {
		if (net.listen(_socketfd, net.SOMAXCONN) != 0) {
			printf("listen != 0: ");
			linux.perror(null);
			net.closesocket(_socketfd);
			return false;
		}else
			return true;
	}

	public ref<Connection> accept() {
		net.sockaddr_in a;
		int addrlen = a.bytes;
//		printf("&a = %p a.bytes = %d\n", &a, a.bytes);
		// TODO: Develop a test framework that allows us to test this scenario.
		int acceptfd = net.accept(_socketfd, &a, &addrlen);
//		printf("acceptfd = %d\n", acceptfd);
		if (acceptfd < 0) {
			printf("acceptfd < 0: ");
			linux.perror(null);
			net.closesocket(_socketfd);
			return null;
		}
		return createConnection(acceptfd, &a, addrlen);
	}

	protected abstract ref<Connection> createConnection(int acceptfd, ref<net.sockaddr_in> address, int addressLength);

	public void close() {
		net.closesocket(_socketfd);
		_socketfd = -1;
	}

	public boolean closed() {
		return _socketfd < 0;
	}

	// Client side API's

	public ref<Connection> connect(string hostname, char port) {
		unsigned ip;
		boolean success;

		if (port == 0)
			return null;
		(ip, success) = resolveHostName(hostname);
		if (!success)
			return null;
		net.sockaddr_in sock_addr;
		sock_addr.sin_family = net.AF_INET;
		sock_addr.sin_port = net.htons(port);
		sock_addr.sin_addr.s_addr = ip;
		int result = net.connect(_socketfd, &sock_addr, sock_addr.bytes);
		if (result != 0) {
			printf("net.connect failed: %d\n", result);
			return null;
		}
		ref<Connection> connection = createConnection(_socketfd, &sock_addr, sock_addr.bytes);
		return connection;
	}

	private unsigned, boolean resolveHostName(string hostname) {
		if (hostname == null)
			return 0, false;
		net.in_addr in;
		if (net.inet_aton(hostname.c_str(), &in) == 0) {
			ref<net.hostent> host = net.gethostbyname(hostname.c_str());
			if (host == null) {
				printf("gethostbyname failed for '%s'\n", hostname);
				return 0, false;
			}
			in.s_addr = *ref<unsigned>(*host.h_addr_list);
		}
		return in.s_addr, true;
	}

}

class Connection {
	@Constant
	private static int BUFFER_MAX = 8192;

	protected int _acceptfd;
	private net.sockaddr_in _address;
	private int _addressLength;
	private string _buffer;
	private string _inBuffer;
	private int _cursor;
	private int _actual;

	Connection(int acceptfd, ref<net.sockaddr_in> addr, int addrLen) {
		_address = *addr;
		_addressLength = addrLen;
		_acceptfd = acceptfd;
	}

	public int requestFd() {
		return _acceptfd;
	}

	public ref<net.sockaddr_in> sourceAddress() {
		return &_address;
	}

	public int sourceAddressLength() {
		return _addressLength;
	}

	public void diagnoseError() {
		linux.perror(null);
	}

	// These implement buffered writes using _buffer.

	public int printf(string format, var... parameters) {
		string s;

		s.printf(format, parameters);
		return write(s);
	}

	public int write(string s) {
		if (s.length() + _buffer.length() >= BUFFER_MAX) {
			int fill = BUFFER_MAX - _buffer.length();
			if (fill > 0) {
				_buffer.append(&s[0], fill);
				if (!flush())
					return fill;
			}
			_buffer = s.substring(fill);
		} else
			_buffer.append(s);
		return s.length();
	}

	public void putc(int c) {
		_buffer.append(byte(c));
		if (_buffer.length() >= BUFFER_MAX)
			flush();
	}

	public boolean flush() {
		if (_buffer.length() > 0) {
			if (write(&_buffer[0], _buffer.length()) != _buffer.length())
				return false;
			_buffer = "";
		}
		return true;
	}

	// These implement buffered reads using _inBuffer;

	public int read() {
		if (_cursor >= _actual) {
			if (_inBuffer.length() == 0)
				_inBuffer.resize(8192);
			_actual = read(&_inBuffer[0], _inBuffer.length());
			if (_actual <= 0) {
				text.printf("Failed to read from connection: %d\n", _actual);
				return -1;
			}
			_cursor = 0;
		}
		return _inBuffer[_cursor++];
	}

	public void ungetc() {
		_cursor--;
	}

	public string readHttpMessage() {
		string message;
		boolean empty = true;

		for (;;) {
			int c = read();
			if (c < 0)
				break;
			switch (c) {
			case '\r':
				message.append(byte(c));
				break;

			case '\n':
				message.append(byte(c));
				if (empty)
					return message;
				empty = true;
				break;

			default:
				empty = false;
				message.append(byte(c));
			}
		}
		return message;
	}

	public abstract boolean acceptSecurityHandshake();

	public abstract boolean initiateSecurityHandshake();

	public abstract int read(pointer<byte> buffer, int len);

	public abstract int write(pointer<byte> buffer, int length);

	public abstract void close();

	public abstract boolean secured();
}

class PlainSocket extends Socket {
	protected ref<Connection> createConnection(int acceptfd, ref<net.sockaddr_in> address, int addressLength) {
		return new PlainConnection(acceptfd, address, addressLength);
	}
}

class PlainConnection extends Connection {

	PlainConnection(int acceptfd, ref<net.sockaddr_in> addr, int addrLen) {
		super(acceptfd, addr, addrLen);
	}

	public boolean acceptSecurityHandshake() {
		return true;
	}

	public boolean initiateSecurityHandshake() {
		return true;
	}

	public int read(pointer<byte> buffer, int length) {
		return net.recv(_acceptfd, buffer, length, 0);
	}

	public int write(pointer<byte> buffer, int length) {
		return net.send(_acceptfd, buffer, length, 0);
	}

	public void close() {
		net.closesocket(_acceptfd);
	}

	public boolean secured() {
		return false;
	}
}

private monitor class InitSSL {
	boolean _done;
}

private InitSSL _init_ssl;

class SSLSocket extends Socket {
	private ref<ssl.SSL_CTX> _context;

	SSLSocket(Encryption encryption, string cipherList) {
		lock (_init_ssl) {
			if (!_done) {
				_done = true;
				printf("SSL_library_init\n");
				ssl.SSL_load_error_strings();
				ssl.SSL_library_init();
			}
		}
		ref<ssl.SSL_METHOD> method;
		switch (encryption) {
		case SSLv23:
			method = ssl.SSLv23_server_method();
			break;

		case TLSv1_2:
			method = ssl.TLSv1_2_server_method();
			break;

		default:
			assert(false);
		}
		_context = ssl.SSL_CTX_new(method);
		if (_context == null) {
			printf("SSL_CTX_new failed: %d\n", ssl.SSL_get_error(null, 0));
			printf("                %s\n", ssl.ERR_error_string(ssl.SSL_get_error(null, 0), null));
			for (;;) {
				long e = ssl.ERR_get_error();
				if (e == 0)
					break;
				printf("    %d %s\n", e, ssl.ERR_error_string(e, null));
			}
		}
		printf("Loading self-signed certificate.\n");
		ssl.SSL_CTX_use_certificate_file(_context, "test/certificates/self-signed.pem".c_str(), ssl.SSL_FILETYPE_PEM);
		ssl.SSL_CTX_set_client_CA_list(_context, ssl.SSL_load_client_CA_file("/etc/ssl/certs/ca-certificates.crt".c_str()));
		ssl.SSL_CTX_use_PrivateKey_file(_context, "test/certificates/self-signed.pem".c_str(), ssl.SSL_FILETYPE_PEM);
		printf("Loading DH parameters\n");
		ref<C.FILE> fp = C.fopen("test/certificates/dhparams.pem".c_str(), "r".c_str());
		if (fp == null)
			printf("Cannot open 'test/certificates/dhparams.pem' file\n");
		else {
			ref<ssl.DH> dh = ssl.PEM_read_DHparams(fp, null, null, "jrirba".c_str());
			C.fclose(fp);
			if (dh != null) {
				if (ssl.SSL_CTX_set_tmp_dh(_context, dh) != 1)
					printf("SSL_CTX_set_tmp_dh failed\n");
				else
					printf("SSL_CTX_set_tmp_dh succeeded\n");
				ssl.DH_free(dh);
			} else
				printf("PEM_read_DHparams failed\n");
		}
		if (cipherList != null) {
			printf("Setting cipher list to '%s'\n", cipherList);
			if (ssl.SSL_CTX_set_cipher_list(_context, cipherList.c_str()) == 0) {
				for (;;) {
					long e = ssl.ERR_get_error();
					if (e == 0)
						break;
					printf("    %d %s\n", e, ssl.ERR_error_string(e, null));
				}
			}
		}
		printf("SSL configuration loaded\n");
	}

	protected ref<Connection> createConnection(int acceptfd, ref<net.sockaddr_in> address, int addressLength) {
		return new SSLConnection(acceptfd, address, addressLength, _context);
	}
}

class SSLConnection extends Connection {
	private ref<ssl.SSL_CTX> _context;
	private ref<ssl.SSL> _ssl;

	SSLConnection(int acceptfd, ref<net.sockaddr_in> addr, int addrLen, ref<ssl.SSL_CTX> context) {
		super(acceptfd, addr, addrLen);
		_context = context;
	}

	public boolean acceptSecurityHandshake() {
		// Do the TLS handshake
//		printf("Starting TLS handshake...\n");
		ref<ssl.BIO> bio = ssl.BIO_new_socket(_acceptfd, ssl.BIO_NOCLOSE);
		_ssl = ssl.SSL_new(_context);
		if (_ssl == null) {
			printf("SSL_new failed: %d\n", ssl.SSL_get_error(null, 0));
			printf("                %s\n", ssl.ERR_error_string(ssl.SSL_get_error(null, 0), null));
			for (;;) {
				long e = ssl.ERR_get_error();
				if (e == 0)
					break;
				printf("    %d %s\n", e, ssl.ERR_error_string(e, null));
			}
			return false;
		}
/*
		printf("Ciphers:\n");
		for (int prio = 0; ; prio++) {
			pointer<byte> list = ssl.SSL_get_cipher_list(_ssl, prio);
			if (list == null)
				break;
			printf("[%d] %s\n", prio, list);
		}
 */
		ssl.SSL_set_accept_state(_ssl);
		ssl.SSL_set_bio(_ssl, bio, bio);
		int r = ssl.SSL_accept(_ssl);
		if (r == -1) {
			printf("SSL_accept failed: %d\n", ssl.SSL_get_error(null, 0));
			printf("                %s\n", ssl.ERR_error_string(ssl.SSL_get_error(null, 0), null));
			for (;;) {
				long e = ssl.ERR_get_error();
				if (e == 0)
					break;
				printf("    %d %s\n", e, ssl.ERR_error_string(e, null));
			}
			return false;
		}
		// TLS handshake completed and everything ok to proceed.

//		printf("AOK r = %d\n", r);

		return r == 1;
	}

	public boolean initiateSecurityHandshake() {
		return false;
	}

	public int read(pointer<byte> buffer, int length) {
		int x = ssl.SSL_read(_ssl, buffer, length);
		if (x <= 0) {
			printf("SSL_read failed return %d\n", x);
			diagnoseError();
			linux.perror("SSL_read".c_str());
		} else {
//			printf("SSLConnection.read:\n");
//			text.memDump(buffer, x);
		}
		return x;
	}

	public int write(pointer<byte> buffer, int length) {
		return ssl.SSL_write(_ssl, buffer, length);
	}

	public void diagnoseError() {
		printf("SSL call failed: %d\n", ssl.SSL_get_error(_ssl, 0));
		printf("                %s\n", ssl.ERR_error_string(ssl.SSL_get_error(_ssl, 0), null));
		for (;;) {
			long e = ssl.ERR_get_error();
			if (e == 0)
				break;
			printf("    %d %s\n", e, ssl.ERR_error_string(e, null));
		}
	}

	public void close() {
		ssl.SSL_free(_ssl);
		net.closesocket(_acceptfd);
	}

	public boolean secured() {
		return true;
	}
}

/**
 * Based on RFC 4648, perform a base-64 encoding of the byte array
 */
public string base64encode(byte[] data) {
	return base64encode(&data[0], data.length());
}

public string base64encode(pointer<byte> data, long length) {
	string result;
	
	while (length > 0) {
		int triplet;
		int digits;
		switch (length) {
		default:
			triplet = (data[0] << 16) + (data[1] << 8) + data[2];
			digits = 4;
			break;
			
		case 2:
			triplet = (data[0] << 16) + (data[1] << 8);
			digits = 3;
			break;
			
		case 1:
			triplet = data[0] << 16;
			digits = 2;
			break;
		}
		result.append(encoding[triplet >> 18]);
		result.append(encoding[(triplet >> 12) & 0x3f]);
		if (digits > 2) {
			result.append(encoding[(triplet >> 6) & 0x3f]);
			if (digits > 3)
				result.append(encoding[triplet & 0x3f]);
			else
				result.append("=");
		} else
			result.append("==");
		length -= 3;
		data += 3;
	}
	return result;
}

public byte[] base64decode(string data) {
	byte[] a;

	base64decode(data, &a);
	// a will be empty if the input string is not valid.
	return a;
}

public boolean base64decode(string data, ref<byte[]> a) {
	if (data.length() % 4 != 0)
		return false;
	for (int i = 0; i < data.length(); i += 4) {
		int b0 = decodeMap[data[i]];
		if (b0 < 0)
			return false;
		int b1 = decodeMap[data[i + 1]];
		if (b1 < 0)
			return false;
		a.append(byte((b0 << 2) + (b1 >> 4)));
		int b2 = decodeMap[data[i + 2]];
		if (b2 < -1)
			return false;
		if (b2 >= 0) {
			a.append(byte(((b1 & 15) << 4) + (b2 >> 2)));
			int b3 = decodeMap[data[i + 3]];
			if (b3 < -1)
				return false;
			if (b3 >= 0)
				a.append(byte(((b2 & 3) << 6) + b3));
		}	
	}
	return true;
}

private string encoding = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
private int[] decodeMap;
decodeMap.resize(256);
for (int i = 0; i < decodeMap.length(); i++)
	decodeMap[i] = -2;
for (int i = 0; i < encoding.length(); i++)
	decodeMap[encoding[i]] = i;
decodeMap['='] = -1;


