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

private  monitor _init {
	boolean _done;
}
public class Socket {

	public static ref<Socket> create(Encryption encryption) {
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
			socket = new SSLSocket(encryption);
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

	public boolean bind(string hostname, char port, ServerScope scope) {
		net.sockaddr_in s;
		pointer<byte> ip;
		
		if (runtime.compileTarget == SectionType.X86_64_WIN) {
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
			printf("Binding failed!");
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
}

class Connection {
	int _acceptfd;
	net.sockaddr_in _address;
	int _addressLength;

	Connection(int acceptfd, ref<net.sockaddr_in> addr, int addrLen) {
		_address = *addr;
		_addressLength = addrLen;
		_acceptfd = acceptfd;
	}

	public int requestFd() {
		return _acceptfd;
	}

	public abstract boolean acceptSecurityHandshake();

	public abstract int read(pointer<byte> buffer, int len);

	public abstract int write(pointer<byte> buffer, int length);

	public abstract void close();
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

	public int read(pointer<byte> buffer, int length) {
		return net.recv(_acceptfd, buffer, length, 0);
	}

	public int write(pointer<byte> buffer, int length) {
		return net.send(_acceptfd, buffer, length, 0);
	}

	public void close() {
		net.closesocket(_acceptfd);
	}
}

class SSLSocket extends Socket {
	private ref<ssl.SSL_CTX> _context;

	SSLSocket(Encryption encryption) {
		ref<ssl.SSL_METHOD> method;
		switch (encryption) {
		case SSLv23:
			method = ssl.SSLv23_server_method();
			break;

		default:
			assert(false);
		}
		_context = ssl.SSL_CTX_new(ssl.SSLv23_server_method());
//		ssl.SSL_CTX_set_client_CA_list(_context, ssl.SSL_load_client_CA_file(x));
//		ssl.SSL_CTX_use_PrivateKey_file(_context, y, ssl.SSL_FILETYPE_PEM);
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
		ref<ssl.BIO> bio = ssl.BIO_new_socket(_acceptfd, ssl.BIO_NOCLOSE);
		_ssl = ssl.SSL_new(_context);
		ssl.SSL_set_accept_state(_ssl);
		ssl.SSL_set_bio(_ssl, bio, bio);
		int r = ssl.SSL_accept(_ssl);
		// TLS handshake completed and everything ok to proceed.
		return r == 1;
	}

	public int read(pointer<byte> buffer, int length) {
		return ssl.SSL_read(_ssl, buffer, length);
	}

	public int write(pointer<byte> buffer, int length) {
		return ssl.SSL_write(_ssl, buffer, length);
	}

	public void close() {
		ssl.SSL_free(_ssl);
	}
}

/**
 * Based on RFC 4648, performa a base-64 encoding of the byte array
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

private string encoding = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
