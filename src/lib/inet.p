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
/**
 * Provides facilities for creating and minpulating sockets and socket connections, including support
 * for SSL encrypted sockets.
 */
namespace parasol:net;

import parasol:exception;
import parasol:log;
import native:net;
import native:linux;
import native:C;
import parasol:runtime;
import parasol:storage;
import parasol:stream;
import parasol:thread;
import openssl.org:ssl;
import native:windows.WORD;
import parasol:exception.IllegalOperationException;

private ref<log.Logger> logger = log.getLogger("parasol.net");

private byte[] localhost = [ 127, 0, 0, 1 ];
/**
 * The scope of the port bound to a socket server.
 */
public enum ServerScope {
	/**
	 * The socket is only visible on the same machine as the server.
	 */
	LOCALHOST,
	/**
	 * The socket is visible across the Internet (using IPv4).
	 */
	INTERNET,
}
/**
 * The particular form of encryption to use, if any.
 */
public enum Encryption {
	NONE,
	SSLv2,
	SSLv3,
	/**
	 * Best available SSL/TLS
	 */
	SSLv23,
	TLSv1,
	TLSv1_1,
	TLSv1_2,
	DTLSv1,							// DTLS 1.0
	DTLSv1_2,						// DTLS 1.2
	DTLS,							// DTLS 1.0 and 1.2
}
/**
 * Thrown in response to failure to properly create a socket.
 */
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
 * This method returns the host IPv4 address, if any, for the current host.
 *
 * @return The host's IPv4 address. If there was any error, or there are no
 * IPv4 interfaces defined, this returns zero.
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
/**
 * The abstract base class for all sockets.
 */
public class Socket {
	/**
	 * Create an unencrypted socket.
	 *
	 * @return The created socket object.
	 *
	 * @exception SocketException Thrown if the socket could not be created.
	 */
	public static ref<Socket> create() {
		return create(Encryption.NONE, null, null, null, null);
	}
	/**
	 * Create a socket.
	 *
	 * @param encryption The form of encryption to use on the socket.
	 * @param cipherList An optional list of ciphers to use. If null, then a default set of ciphers is selected.
	 * @param certificatesFile The path of a certificates file to be used for connection negotiation.
	 * @param privateKeyFile The path of a private key file to be used for connection negotiation.
	 * @param dhParamsFile The path of a DH parameters file to be used in connection negotiation.
	 *
	 * @return The created socket object.
	 *
	 * @exception SocketException Thrown if the socket could not be created.
	 */
	public static ref<Socket> create(Encryption encryption, string cipherList, string certificatesFile, string privateKeyFile, string dhParamsFile) {
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			lock (_init) {
				if (!_done) {
					_done = true;
					net.WSADATA data;
					WORD version = 0x202;
					
					int result = net.WSAStartup(version, &data);
					if (result != 0) {
						// TODO: Make up an exception class for this error.
						logger.debug("WSAStartup returned %d\n", result);
						assert(result == 0);
					}
				}
			}
		}
		ref<Socket> socket;
		if (encryption == Encryption.NONE)
			socket = new PlainSocket();
		else
			socket = new SSLSocket(encryption, cipherList, certificatesFile, privateKeyFile, dhParamsFile);
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

	~Socket() {
		net.closesocket(_socketfd);
	}
	/**
	 * This call transforms the socket into a server-side socket and binds it to the designated port id.
	 *
	 * @param port The port to use, or zero if the system should choose a port number.
	 * @param scope The scope to use for the binding.
	 *
	 * @return true if the socket could be bound to the indicated port with the intended scope, false
	 * otherwise.
	 */
	public boolean bind(char port, ServerScope scope) {
		net.sockaddr_in s;
		pointer<byte> ip;
		
		if (runtime.compileTarget == runtime.Target.X86_64_WIN) {
			string hostname = "";

			ref<net.hostent> localHost = net.gethostbyname(&hostname[0]);
			if (localHost == null) {
				logger.debug("gethostbyname failed for '%s'\n", hostname);
				return false;
			}
			ip = net.inet_ntoa (*ref<unsigned>(*localHost.h_addr_list));
//			string n(localHost.h_name);
//			logger.debug("hostent name = '%s' ip = '%s'\n", n, x);
			net.inet_addr(ip);
		} else if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			if (scope == ServerScope.LOCALHOST)
				ip = &localhost[0];
			else {					// must be INTERNET
				ref<linux.ifaddrs> ifAddresses;
				if (linux.getifaddrs(&ifAddresses) != 0) {
					logger.debug("getifaddrs failed\n");
					return false;
				}
				int i = 1;
				for (ref<linux.ifaddrs> ifa = ifAddresses; ; ifa = ifa.ifa_next, i++) {
					if (ifa == null) {
						logger.debug("No identifiable IPv4 address to use\n");
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
//		logger.debug("s = { %d, %x, %x }\n", s.sin_family, s.sin_addr.s_addr, s.sin_port);
		if (net.bind(_socketfd, &s, s.bytes) != 0) {
			if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
				string buffer = linux.strerror(linux.errno());
				logger.debug("Binding failed to %d, %s", port, buffer);
			} else
				logger.debug("Binding failed to %d", port);
			net.closesocket(_socketfd);
			return false;
		}
		if (port == 0) {
			net.sockaddr_in this_addr;
			net.socklen_t len = net.socklen_t(this_addr.bytes);

			net.getsockname(_socketfd, ref<net.sockaddr>(&this_addr), &len);
			_port = net.ntohs(this_addr.sin_port); 
		} else
			_port = port;
//		logger.debug("socketfd = %d port = %d", _socketfd, _port);
		return true;
	}
	/**
	 * Listen for an incoming connection.
	 *
	 * Once bound to a port, a server-side socket must listen for incoming connections.
	 *
	 * @return true if the listen step succeeded, false otherwise.
	 */
	public boolean listen() {
		if (net.listen(_socketfd, net.SOMAXCONN) != 0) {
			string buffer = linux.strerror(linux.errno());
			logger.debug("listen failed %s", buffer);
			net.closesocket(_socketfd);
			return false;
		}else
			return true;
	}
	/**
	 * Accept an incoming connection.
	 *
	 * After a socket is bound and is listening, it must call accept to create a connection.
	 *
	 * @return The open connection on success, null on failure.
	 */
	public ref<Connection> accept() {
		net.sockaddr_in a;
		int addrlen = a.bytes;
		// TODO: Develop a test framework that allows us to test this scenario.
		int acceptfd = net.accept(_socketfd, &a, &addrlen);
		if (acceptfd < 0) {
			string buffer = linux.strerror(linux.errno());
			logger.debug("accept on port %d failed %s", _port, buffer);
			net.closesocket(_socketfd);
			return null;
		}
		return createConnection(acceptfd, &a, addrlen);
	}
	/**
	 * An abstract method that must be implemented by one of the Socket subclasses to create connection in 
 	 * response to an accept or connect call.
	 *
	 * @param fd The file descriptor to use for the connection.
	 * @param address The socket address data for the connection.
	 * @param addressLength The size in bytes of the socket address information.
	 *
	 * @return The created connection object.
	 */
	protected abstract ref<Connection> createConnection(int fd, ref<net.sockaddr_in> address, int addressLength);
	/**
	 * Close a socket.
	 */
	public void close() {
		net.closesocket(_socketfd);
		_socketfd = -1;
	}
	/**
	 * Check whether a socket is closed.
	 *
	 * @return true if the socket is closed, false if it is open.
	 */
	public boolean closed() {
		return _socketfd < 0;
	}
	/**
	 * The port this socket is using.
	 *
	 * Before calling bind or connect, the value will be zero.
	 *
	 * @return the value of the port the socket is using. If the bind call used port 0, this value
	 * will be the port selected by the system.
	 */
	public char port() {
		return _port;
	}

	// Client side API's

	/**
	 * Connect to a designated host and port combination.
	 *
	 * This must be called on a closed socket. It will make this a client-side socket.
	 *
	 * @param hostname Either an IPv4 dotted IP address or a DNS name to be resolved t runtime.
	 * @param port The non-zero port to connect to on the named host.
	 *
	 * @return The open connection, or null if the connection failed.
	 * @return The IPv4 address of the host afer name resolution. If name resolution failed, this value
	 * will be zero (the connection will also be null, because you cannot connect to IP address 0).
	 */
	public ref<Connection>, unsigned connect(string hostname, char port) {
		unsigned ip;
		boolean success;

		if (port == 0)
			return null, 0;
		(ip, success) = resolveHostName(hostname);
		if (!success)
			return null, 0;
		net.sockaddr_in sock_addr;
		sock_addr.sin_family = net.AF_INET;
		sock_addr.sin_port = net.htons(port);
		sock_addr.sin_addr.s_addr = ip;
		int result = net.connect(_socketfd, &sock_addr, sock_addr.bytes);
		if (result != 0) {
			logger.debug("net.connect failed: %d\n", result);
			return null, ip;
		}
		ref<Connection> connection = createConnection(_socketfd, &sock_addr, sock_addr.bytes);
		return connection, ip;
	}

	private unsigned, boolean resolveHostName(string hostname) {
		if (hostname == null)
			return 0, false;
		net.in_addr inet;
		if (net.inet_aton(hostname.c_str(), &inet) == 0) {
			ref<net.hostent> host = net.gethostbyname(hostname.c_str());
			if (host == null) {
				logger.debug("gethostbyname failed for '%s'\n", hostname);
				return 0, false;
			}
			inet.s_addr = *ref<unsigned>(*host.h_addr_list);
		}
		return inet.s_addr, true;
	}

}

// TODO: Implement unread() without using the buffering code in the Reader itself.

class ConnectionReader extends Reader {
	private ref<Connection> _connection;
	private int _lastRead;
	private boolean _unreadCalled;

	public ConnectionReader(ref<Connection> connection) {
		_connection = connection;
		_lastRead = stream.EOF;
	}

	public int _read() {
		byte b;
		if (_unreadCalled) {
			b = byte(_lastRead);
			_unreadCalled = false;
		} else {
			int i = _connection.read(pointer<byte>(&b), 1);
			if (i <= 0)
				return _lastRead = stream.EOF;
			else
				_lastRead = b;
		}
		return b;
	}

	public void unread() {
		if (_lastRead != stream.EOF)
			_unreadCalled = true;
	}

	public int read(ref<byte[]> buffer) {
		if (_unreadCalled) {
			buffer.resize(1);
			(*buffer)[0] = byte(_lastRead);
			_unreadCalled = false;
			return 1;
		} else {
			_lastRead = stream.EOF;
			return _connection.read(&(*buffer)[0], buffer.length());
		}
	}

	public long read(address buffer, long length) {
		if (_unreadCalled) {
			*ref<byte>(buffer) = byte(_lastRead);
			_unreadCalled = false;
			return 1;
		} else {
			_lastRead = stream.EOF;
			return _connection.read(pointer<byte>(buffer), int(length));
		}
	}

	public int read(ref<char[]> buffer) {
		if (_unreadCalled) {
			_unreadCalled = false;
			throw IllegalOperationException("read char array after unread");
			return 1;
		} else {
			_lastRead = stream.EOF;
			return _connection.read(pointer<byte>(&(*buffer)[0]), buffer.length() * char.bytes);
		}
	}
}

class ConnectionWriter extends Writer {
	private ref<Connection> _connection;

	public ConnectionWriter(ref<Connection> connection) {
		_connection = connection;
	}

	protected void _write(byte c) {
		_connection.putc(c);
	}
}
/**
 * This is an abstract base class to provide generalized access to encrypted or unencrypted socket
 * connections.
 *
 * Data written to a connection is buffered. You will need to call {@link flush} to force the written
 * data out to the wire.
 *
 * Data read from a connection is also buffered.
 *
 * Connections are bidirectional. You may interleave reads and writes on the same connection, and may
 * have one thread reading from the connection while anotehr thread writes to the connection.
 */
public class Connection {
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

	~Connection() {
		flush();
//		logger.debug("~Connection %p %d\n", this, _acceptfd);
		net.closesocket(_acceptfd);
	}
	/**
	 * The connection's file descriptor.
	 */
	public int requestFd() {
		return _acceptfd;
	}
	/**
	 * The Internet address of the source for this connection.
	 *
	 * This will typically be of interest to server-side threads that may want
	 * to log the IP addresses of accepted connections.
	 *
	 * @return A reference to the connectin's address structure. Do not modify this data.
	 */
	public ref<net.sockaddr_in> sourceAddress() {
		return &_address;
	}
	/**
	 * Get the length of the data in the {@link sourceAddress} address object.
	 *
	 * @return The length in bytes of the address data.
	 */
	public int sourceAddressLength() {
		return _addressLength;
	}
	/**
	 * Get the IPv4 address of the connection.
	 *
	 * @return The IPv4 address of the connection if it is an AI_INET connection. Zero otherwise.
	 */
	public unsigned sourceIPv4() {
		if (_address.sin_family == net.AF_INET) {
			return _address.sin_addr.s_addr;
		} else
			return 0;
	}
	/**
	 * A crude debugging aid to dump pertinent information after an error.
	 *
	 * @param ret The return value of the failing call.
	 */
	public void diagnoseError(int ret) {
		linux.perror(null);
	}

	// These implement buffered writes using _buffer.

	/**
	 * Print formatted output to the connection.
	 *
	 * @param format The format. The string uses the specification defined for {@link stream.Writer.printf}.
	 * @param parameters The value parameters to be printed using the specified format.
	 *
	 * @return The number of bytes written to the connection.
	 *
	 * @threading This call is not thread-safe.
	 */
	public int printf(string format, var... parameters) {
		string s;

		s.printf(format, parameters);
		return write(s);
	}
	/**
	 * Write string data to the connection.
	 *
	 * @param s The string to write.
	 *
	 * @return The number of bytes written to the connection.
	 *
	 * @threading This call is not thread-safe.
	 */
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
	/**
	 * Copy the contents of a reader to a connection/
	 *
	 * This method will read from the Reader object until it reports end-of-file.
	 *
	 * @param reader The Reader object to read from.
	 *
	 * @return The total number of bytes written to the connection.
	 *
	 * @threading This call is not thread-safe.
	 */
	public int write(ref<Reader> reader) {
		byte[] b;
		b.resize(8096);
		int totalWritten = 0;
		for (;;) {
			int actual = reader.read(&b);
			if (actual <= 0)
				break;
			for (int i = 0; i < actual; i++)
				putc(b[i]);
			totalWritten += actual;
		}
		return totalWritten;
	}
	/**
	 * Write a byte to the connection.
	 *
	 * @param c The byte value to be written.
	 *
	 * @threading This call is not thread-safe.
	 */
	public void putc(int c) {
		_buffer.append(byte(c));
		if (_buffer.length() >= BUFFER_MAX)
			flush();
	}
	/**
	 * Flush buffered output data to the connection.
	 *
	 * @return true if the write to the connection succeeded, false otherwise.
	 *
	 * @threading This call is not thread-safe.
	 */
	public boolean flush() {
		if (_buffer.length() > 0) {
			if (write(&_buffer[0], _buffer.length()) != _buffer.length())
				return false;
			_buffer = "";
		}
		return true;
	}

	// These implement buffered reads using _inBuffer;

	/**
	 * Read a byte from the connection.
	 *
	 * This data is read from an internal buffer.
	 *
	 * @return The next byte value, or -1 on end-of-file.
	 */
	public int read() {
		if (_cursor >= _actual) {
			if (_inBuffer.length() == 0)
				_inBuffer.resize(8192);
			_actual = read(&_inBuffer[0], _inBuffer.length());
			if (_actual <= 0) {
				if (_actual < 0)
					logger.error("Failed to read from connection %d: %d\n", _acceptfd, _actual);
//				else
//					logger.debug( "Read 0 bytes from connection %d", _acceptfd);
				return -1;
			}

//			logger.memDump(log.DEBUG, "Read buffer", &_inBuffer[0], _actual, 0);
			_cursor = 0;
		}
		return _inBuffer[_cursor++];
	}
	/**
	 * Unread the last byte read from the buffer.
	 *
	 * Note: If the last call to {@link read} reported end-of-file, calling this
	 * method is undefined.
	 */
	public void ungetc() {
		_cursor--;
	}
	/**
	 * Read lines of text from the connection until either end-of-file or a blank
	 * line is read.
	 *
	 * @return All lines of text including the last, blank, line. If the last text is
	 * not a blank line, thenend-of-file was read.
	 */
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
	/**
	 * Obtain a Reader that can be used to collect data from the Connection.
	 *
	 * The Reader will use the read buffer of the Connecction.
	 *
 	 * @return A Reader object positioned at the current location on the file stream.
	 */
	public abstract ref<Reader> getReader();
	/**
	 * Obtain a Writer that can be used to send data to the Connection.
	 *
	 * @return A Writer object that will write through to the underlying Connection.
	 */
	public abstract ref<Writer> getWriter();
	/**
	 * On a server-side connection, accept the security handshake.
	 *
	 * On an unencrypted Connection, this call has no affect.
	 *
	 * Calling this menthod on a client-side connection is undefined.
	 *
	 * If the securtiy handshale fails, the appropriate action is to close the connection.
	 *
	 * @return true if the security handshake succeeded, false otherwise.
	 */
	public abstract boolean acceptSecurityHandshake();
	/**
	 * On a client-side connection, initiate the security handshake.
	 *
	 * On an unencrypted Connection, this call has no effect.
	 *
	 * Calling this method on a server-side connection is undefined.
	 */
	public abstract boolean initiateSecurityHandshake();
	/**
	 * Read a block of data from the connection.
	 *
	 * This call does not use the read buffer. Do not mix calls using this method
	 * with either a Reader (obtained from {@link getReader}) or other read calls.
	 *
	 * @param buffer An array of bytes of at least length {@code len} to hold the data.
	 * @param len The maximum amount of data to read.
	 *
	 * @return The number of bytes read. A value of 0 indicates end-of-file. A value of
	 * -1 indicates some sort of error.
	 */
	public abstract int read(pointer<byte> buffer, int len);
	/**
	 * Write a block of data to the connection.
	 *
	 * This call writes a block of data to the connection, ignoring the contents
	 * of the write buffer.
	 *
	 * Mixing calls to this method with calls to other write methods is undefeind.
	 *
	 * @param buffer An array of {@code lnegth} bytes containing the data to write.
	 * @param length The number of bytes to write.
	 *
	 * @return The number of bytes written or -1 on error.
	 */
	public abstract int write(pointer<byte> buffer, int length);
	/**
	 * Close a connection.
	 *
	 * Flushes any partially filled write buffer and closes the network connection.
	 */
	public abstract void close();
	/**
	 * Text whether this connection is encrypted.
	 *
	 * @return true if the connection is secured (i.e. encrypted), false if not encrypted.
	 */
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

	public ref<Reader> getReader() {
		if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			storage.File f(_acceptfd);
			return f.getBinaryReader();
		} else
			return new ConnectionReader(this);
	}

	public ref<Writer> getWriter() {
		if (runtime.compileTarget == runtime.Target.X86_64_LNX) {
			storage.File f(_acceptfd);
			return f.getBinaryWriter();
		} else
			return new ConnectionWriter(this);
	}

	public int read(pointer<byte> buffer, int length) {
		return net.recv(_acceptfd, buffer, length, 0);
	}

	public int write(pointer<byte> buffer, int length) {
		return net.send(_acceptfd, buffer, length, 0);
	}

	public void close() {
		flush();
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
	string _cipherList;
	string _certificatesFile;
	string _privateKeyFile;
	string _dhParamsFile;
	ref<ssl.SSL_METHOD> _method;

	private monitor class SSLContextPool {
		private map<ref<ssl.SSL_CTX>, ref<thread.Thread>> _contexts;

		~SSLContextPool() {
			_contexts.deleteAll();
		}

		public ref<ssl.SSL_CTX> getContext(ref<thread.Thread> t) {
			return _contexts[t];
		}

		public void setContext(ref<thread.Thread> t, ref<ssl.SSL_CTX> context) {
//			logger.debug( "thread %s <- context %p", t.name(), context);
			_contexts[t] = context;
		}
	}

	private SSLContextPool _contextPool;

	SSLSocket(Encryption encryption, string cipherList, string certificatesFile, string privateKeyFile, string dhParamsFile) {
		lock (_init_ssl) {
			if (!_done) {
				_done = true;
//				logger.debug("SSL_library_init\n");
				ssl.SSL_load_error_strings();
				ssl.SSL_library_init();
			}
		}
		switch (encryption) {
		case SSLv23:
			_method = ssl.SSLv23_method();
			break;

		case TLSv1_2:
			_method = ssl.TLSv1_2_method();
			break;

		default:
			assert(false);
		}
//		logger.debug("SSL configuration loaded\n");
		_cipherList = cipherList;
		_certificatesFile = certificatesFile;
		_privateKeyFile = privateKeyFile;
		_dhParamsFile = dhParamsFile;
	}

	protected ref<Connection> createConnection(int acceptfd, ref<net.sockaddr_in> address, int addressLength) {
		return new SSLConnection(acceptfd, address, addressLength, this);
	}

	public ref<ssl.SSL_CTX> getContext() {
		ref<thread.Thread> t = thread.currentThread();
		ref<ssl.SSL_CTX> context = _contextPool.getContext(t);
		if (context == null) {
			context = createSSLContext(_method, _cipherList, _certificatesFile, _privateKeyFile, _dhParamsFile);
			if (context == null)
				return null;
			_contextPool.setContext(t, context);
		}
		return context;
	}

	public ref<ssl.SSL_CTX> createSSLContext(ref<ssl.SSL_METHOD> method, string cipherList, string certificatesFile, string privateKeyFile, string dhParamsFile) {
		ref<ssl.SSL_CTX> context = ssl.SSL_CTX_new(method);
		if (context == null) {
			logger.error("SSL_CTX_new failed: %d", ssl.SSL_get_error(null, 0));
			logger.debug( "                %s", ssl.ERR_error_string(ssl.SSL_get_error(null, 0), null));
			for (;;) {
				long e = ssl.ERR_get_error();
				if (e == 0)
					break;
				logger.debug("    %d %s", e, ssl.ERR_error_string(e, null));
			}
			return null;
		}
		ssl.SSL_CTX_set_options(context, ssl.SSL_OP_NO_SSLv2);
		if (certificatesFile != null) {
	//		logger.debug("Loading self-signed certificate.\n");
			ssl.SSL_CTX_use_certificate_file(context, certificatesFile.c_str(), ssl.SSL_FILETYPE_PEM);
			ssl.SSL_CTX_set_client_CA_list(context, ssl.SSL_load_client_CA_file("/etc/ssl/certs/ca-certificates.crt".c_str()));
		}
		if (privateKeyFile != null)
			ssl.SSL_CTX_use_PrivateKey_file(context, privateKeyFile.c_str(), ssl.SSL_FILETYPE_PEM);
		if (dhParamsFile != null) {
	//		logger.debug("Loading DH parameters\n");
			ref<C.FILE> fp = C.fopen(dhParamsFile.c_str(), "r".c_str());
			if (fp == null)
				logger.debug("Cannot open '%s' file", dhParamsFile);
			else {
				ref<ssl.DH> dh = ssl.PEM_read_DHparams(fp, null, null, "jrirba".c_str());
				C.fclose(fp);
				if (dh != null) {
					if (ssl.SSL_CTX_set_tmp_dh(context, dh) != 1)
						logger.debug("SSL_CTX_set_tmp_dh failed");
	//				else
	//					logger.debug("SSL_CTX_set_tmp_dh succeeded\n");
					ssl.DH_free(dh);
				} else
					logger.debug("PEM_read_DHparams failed");
			}
		}
		if (cipherList != null) {
//			logger.debug("Setting cipher list to '%s'\n", cipherList);
			if (ssl.SSL_CTX_set_cipher_list(context, cipherList.c_str()) == 0) {
				logger.error("Could not load cipher list");
				for (;;) {
					long e = ssl.ERR_get_error();
					if (e == 0)
						break;
					logger.debug("    %d %s", e, ssl.ERR_error_string(e, null));
				}
			}
		}
//		logger.debug( "context created for %d", _acceptfd);
		return context;
	}

}

class SSLConnection extends Connection {
	private ref<SSLSocket> _socket;
	private ref<ssl.SSL_CTX> _context;
	private ref<ssl.SSL> _ssl;
	private ref<ssl.BIO> _bio;

	SSLConnection(int acceptfd, ref<net.sockaddr_in> addr, int addrLen, ref<SSLSocket> socket) {
		super(acceptfd, addr, addrLen);
//		logger.debug( "new SSLConnection(%d, -)\n", acceptfd); 
		_socket = socket;
	}

	public boolean acceptSecurityHandshake() {
		if (!initializeContext())
			return false;
		// Do the TLS handshake
//		logger.debug("Starting TLS handshake...");
		_bio = ssl.BIO_new_socket(_acceptfd, ssl.BIO_NOCLOSE);
		_ssl = ssl.SSL_new(_context);
		if (_ssl == null) {
			logger.debug( "SSL_new failed: %d", ssl.SSL_get_error(null, 0));
			logger.debug( "                %s", ssl.ERR_error_string(ssl.SSL_get_error(null, 0), null));
			for (;;) {
				long e = ssl.ERR_get_error();
				if (e == 0)
					break;
				logger.debug( "    %d %s", e, ssl.ERR_error_string(e, null));
			}
			return false;
		}
/*
		logger.debug("Ciphers:\n");
		for (int prio = 0; ; prio++) {
			pointer<byte> list = ssl.SSL_get_cipher_list(_ssl, prio);
			if (list == null)
				break;
			logger.debug("[%d] %s\n", prio, list);
		}
 */
		ssl.SSL_set_accept_state(_ssl);
		ssl.SSL_set_bio(_ssl, _bio, _bio);
//		logger.debug( "_ssl %p before SSL_accept", _ssl);
		int r = ssl.SSL_accept(_ssl);
		if (r == -1) {
			logger.debug("SSL_accept failed: %d", ssl.SSL_get_error(_ssl, r));
			logger.debug("                %s", ssl.ERR_error_string(ssl.SSL_get_error(_ssl, r), null));
			for (;;) {
				long e = ssl.ERR_get_error();
				if (e == 0)
					break;
				logger.debug("    %d %s", e, ssl.ERR_error_string(e, null));
			}
			return false;
		}
		// TLS handshake completed and everything ok to proceed.
		return r == 1;
	}

	public boolean initiateSecurityHandshake() {
		if (!initializeContext())
			return false;
		// Do the TLS handshake
//		logger.debug("Starting TLS handshake...\n");
//		ref<ssl.BIO> bio = ssl.BIO_new_socket(_acceptfd, ssl.BIO_NOCLOSE);
		_ssl = ssl.SSL_new(_context);
		if (_ssl == null) {
			logger.debug("SSL_new failed: %d\n", ssl.SSL_get_error(null, 0));
			for (;;) {
				long e = ssl.ERR_get_error();
				if (e == 0)
					break;
				logger.debug("    %d %s\n", e, ssl.ERR_error_string(e, null));
			}
			return false;
		}
		if (ssl.SSL_set_fd(_ssl, _acceptfd) == 0) {
			logger.debug("SSL_set_fd failed\n");
		}
//		ssl.SSL_set_connect_state(_ssl);
//		ssl.SSL_set_bio(_ssl, bio, bio);
		int r = ssl.SSL_connect(_ssl);
		if (r < 1) {
			logger.debug("SSL_connect failed: %d\n", ssl.SSL_get_error(_ssl, r));
			logger.debug("                %s\n", ssl.ERR_error_string(ssl.SSL_get_error(_ssl, r), null));
			for (;;) {
				long e = ssl.ERR_get_error();
				if (e == 0)
					break;
				logger.debug("    %s\n", ssl.ERR_error_string(e, null));
			}
			return false;
		}
		return r == 1;
	}

	private boolean initializeContext() {
		if (_context == null) {
			_context = _socket.getContext();
//			logger.debug( "got context for %d: %p", _acceptfd, _context);
			if (_context == null)
				return false;
		}
		return true;
	}

	public ref<Reader> getReader() {
		return new ConnectionReader(this);
	}

	public ref<Writer> getWriter() {
		return new ConnectionWriter(this);
	}

	public int read(pointer<byte> buffer, int length) {
		for (;;) {
//			logger.debug("about to SSL_read\n");
			int x = ssl.SSL_read(_ssl, buffer, length);
//			logger.debug("Got %d bytes\n", x);
			if (x <= 0) {
				if (x == 0) {
					int err = ssl.SSL_get_error(_ssl, x);
					if (err == ssl.SSL_ERROR_SYSCALL) {
						if (ssl.ERR_get_error() == 0)
							return 0;
					} else if (err == ssl.SSL_ERROR_ZERO_RETURN)
						return 0;
					logger.debug("SSL_read of %d returned zero: %d\n", _acceptfd, ssl.SSL_get_error(_ssl, x));
					for (;;) {
						long e = ssl.ERR_get_error();
						if (e == 0)
							break;
						logger.debug("    %d %s\n", e, ssl.ERR_error_string(e, null));
					}
					return -1;
				} else if (x == -1) {
					// If the failure was caused by an interrupted system call, just re-start the read.
					switch (linux.errno()) {
					case linux.EINTR:
						continue;

					case linux.ECONNRESET:
						return 0;
					}
				}
				logger.debug("SSL_read failed return %d\n", x);
				diagnoseError(x);
			}
			return x;
		}
	}

	public int write(pointer<byte> buffer, int length) {
//		logger.debug("SSLConnection write to %d:\n", _acceptfd);
//		text.memDump(buffer, length);
		int result = ssl.SSL_write(_ssl, buffer, length);
		if (result < 0) {
			logger.error("SSL_write to %d failed result = %d %s", _acceptfd, result, linux.strerror(linux.errno()));
			diagnoseError(result);
		}
		return result;
	}

	public void diagnoseError(int ret) {
		logger.error("SSL call failed: %s", ssl_error_strings[ssl.SSL_get_error(_ssl, ret)]);
		for (;;) {
			long e = ssl.ERR_get_error();
			if (e == 0)
				break;
			logger.error("    %d %s", e, ssl.ERR_error_string(e, null));
		}
	}

	public void close() {
		flush();
//		logger.debug("SSL_close");
		if (_ssl != null) {
			ssl.SSL_free(_ssl);
			_ssl = null;
//			ssl.SSL_CTX_free(_context);
			_context = null;
		} else
			logger.debug("null _ssl indicates possible double close?");
		net.closesocket(_acceptfd);
//		logger.debug("SSL_closed done");
	}

	public boolean secured() {
		return true;
	}
}

string[] ssl_error_strings = [
	"SSL_ERROR_NONE",
	"SSL_ERROR_SSL",
	"SSL_ERROR_WANT_READ",
	"SSL_ERROR_WANT_WRITE",
	"SSL_ERROR_WANT_X509_LOOKUP",
	"SSL_ERROR_SYSCALL",
	"SSL_ERROR_ZERO_RETURN",
	"SSL_ERROR_WANT_CONNECT",
	"SSL_ERROR_WANT_ACCEPT"
];
/**
 * Based on RFC 4648, perform a base-64 encoding of the byte array
 *
 * @param data The array of data to encode.
 *
 * @return The encoded string.
 */
public string base64encode(byte[] data) {
	return base64encode(&data[0], data.length());
}
/**
 * Based on RFC 4648, perform a base-64 encoding of the byte array
 *
 * @param data The array of data to encode.
 * @param length The length of the data array.
 *
 * @return The encoded string.
 */
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
/**
 * Format a dotted-IP string from an IPv4 address.
 *
 * @param ipv4 The IP v4 host address.
 *
 * @return The formatted string, consisting of four groups of up to three decimal digits (value in the range 0-127)
 * separated by periods, from the low order to the high order byte of the address. Thus a hex ipv4 value of
 * {@code 0x12345678} is returned as "120.86.52.18".
 */
public string dottedIP(unsigned ipv4) {
	string s;
	s.printf("%d.%d.%d.%d", ipv4 & 0xff, (ipv4 >> 8) & 0xff, (ipv4 >> 16) & 0xff, ipv4 >> 24);
	return s; 
}
/**
 * Parse a dotted-ip string into an IP v4 address.
 *
 * @param dottedIP A string consisting of four groups each of up to three decimal digits, separated by periods.
 *
 * @return The IP v4 address.
 * @return true if the string was properly formatted, false otherwise.
 */
public unsigned, boolean parseDottedIP(string dottedIP) {
	string[] parts = dottedIP.split('.');
	if (parts.length() != 4)
		return 0, false;
	byte o1, o2, o3, o4;
	boolean success;

	(o1, success) = byte.parse(parts[0]);
	if (!success)
		return 0, false;
	(o2, success) = byte.parse(parts[1]);
	if (!success)
		return 0, false;
	(o3, success) = byte.parse(parts[2]);
	if (!success)
		return 0, false;
	(o4, success) = byte.parse(parts[3]);
	if (!success)
		return 0, false;
	return unsigned(o1 | (o2 << 8) | (o3 << 16) | (o4 << 24)), true;
}
/**
 * Based on RFC 4648, perform a base-64 decoding of a string.
 *
 * @param data The encoded base-64 data.
 *
 * @return The decoded data. If the input string is not well-formed, the contents of the array 
 * are undefined.
 * @return true if the data was well-formed, false otherwise.
 */
public byte[], boolean base64decode(string data) {
	byte[] a;

	if (data.length() % 4 != 0)
		return a, false;
	for (int i = 0; i < data.length(); i += 4) {
		int b0 = decodeMap[data[i]];
		if (b0 < 0)
			return a, false;
		int b1 = decodeMap[data[i + 1]];
		if (b1 < 0)
			return a, false;
		a.append(byte((b0 << 2) + (b1 >> 4)));
		int b2 = decodeMap[data[i + 2]];
		if (b2 < -1)
			return a, false;
		if (b2 >= 0) {
			a.append(byte(((b1 & 15) << 4) + (b2 >> 2)));
			int b3 = decodeMap[data[i + 3]];
			if (b3 < -1)
				return a, false;
			if (b3 >= 0)
				a.append(byte(((b2 & 3) << 6) + b3));
		}	
	}
	return a, true;
}

private string encoding = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
private int[] decodeMap;
decodeMap.resize(256);
for (int i = 0; i < decodeMap.length(); i++)
	decodeMap[i] = -2;
for (int i = 0; i < encoding.length(); i++)
	decodeMap[encoding[i]] = i;
decodeMap['='] = -1;



