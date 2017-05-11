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
namespace native:net;

import native:windows.WORD;

@Constant
public short AF_UNIX = 1;
@Constant
public short AF_INET = 2;
@Constant
public short AF_IMPLINK = 3;
@Constant
public short AF_PUP = 4;
@Constant
public short AF_CHAOS = 5;
@Constant
public short AF_NS = 6;
@Constant
public short AF_IPX = AF_NS;
@Constant
public short AF_ISO = 7;
@Constant
public short AF_OSI = AF_ISO;
@Constant
public short AF_ECMA = 8;
@Constant
public short AF_DATAKIT = 9;
@Constant
public short AF_CCITT = 10;
@Constant
public short AF_SNA = 11;
@Constant
public short AF_DECnet = 12;
@Constant
public short AF_DLI = 13;
@Constant
public short AF_LAT = 14;
@Constant
public short AF_HYLINK = 15;
@Constant
public short AF_APPLETALK = 16;
@Constant
public short AF_NETBIOS = 17;
@Constant
public short AF_VOICEVIEW = 18;
@Constant
public short AF_FIREFOX = 19;
@Constant
public short AF_UNKNOWN1 = 20;
@Constant
public short AF_BAN = 21;
@Constant
public short AF_ATM = 22;
@Constant
public short AF_INET6 = 23;
@Constant
public short AF_CLUSTER = 24;
@Constant
public short AF_12844 = 25;
@Constant
public short AF_IRDA = 26;
@Constant
public short AF_NETDES = 28;
@Constant
public short AF_TCNPROCESS = 29;
@Constant
public short AF_TCNMESSAGE = 30;
@Constant
public short AF_ICLFXBM = 31;
@Constant
public short AF_BTH = 32;
@Constant
public short AF_MAX = 33;

@Constant
public int SOCK_STREAM = 1;
@Constant
public int SOCK_DGRAM = 2;
@Constant
public int SOCK_RAW = 3;
@Constant
public int SOCK_RDM = 4;
@Constant
public int SOCK_SEQPACKET = 5;

@Constant
public int IPPROTO_IP = 0;
@Constant
public int IPPROTO_HOPOPTS = 0;
@Constant
public int IPPROTO_ICMP = 1;
@Constant
public int IPPROTO_IGMP = 2;
@Constant
public int IPPROTO_GGP = 3;
@Constant
public int IPPROTO_IPV4 = 4;
@Constant
public int IPPROTO_TCP = 6;
@Constant
public int IPPROTO_PUP = 12;
@Constant
public int IPPROTO_UDP = 17;
@Constant
public int IPPROTO_IDP = 22;
@Constant
public int IPPROTO_IPV6 = 41;
@Constant
public int IPPROTO_ROUTING = 43;
@Constant
public int IPPROTO_FRAGMENT = 44;
@Constant
public int IPPROTO_ESP = 50;
@Constant
public int IPPROTO_AH = 51;
@Constant
public int IPPROTO_ICMPV6 = 58;
@Constant
public int IPPROTO_NONE = 59;
@Constant
public int IPPROTO_DSTOPTS = 60;
@Constant
public int IPPROTO_ND = 77;
@Constant
public int IPPROTO_ICLFXBM = 78;

@Constant
public int IPPROTO_RAW = 255;
@Constant
public int IPPROTO_MAX = 256;

@Constant
public int WSADESCRIPTION_LEN = 256;
@Constant
public int WSASYS_STATUS_LEN = 128;

@Constant
public int SOMAXCONN = 0x7fffffff;

public class hostent {
	public pointer<byte> h_name;
	public pointer<pointer<byte>> h_aliases;
	public short h_addrtype;
	public short h_length;
	public pointer<pointer<byte>> h_addr_list;
}
// Need to reserve 16 bytes for the socket info. Parasol doesn't have unions or a notion of in-line fixed-size arrays yet.
// So we have to 'improvise'. Some code may require some extra porting effort.
public class sockaddr {
	public short  sa_family;
	public char  sa_data;
	public int	sa_fill1;
	public long sa_fill2;
}

public class sockaddr_in {
	public short   sin_family;
	public char sin_port;
    public in_addr sin_addr;
    private long sin_zero;
}

// Need to reserve 4 bytes for the address info. Parasol doesn't have unions or a notion of in-line fixed-size arrays yet.
// So we have to 'improvise'. Some code may require some extra porting effort.
public class in_addr {
	public unsigned s_addr;
}

public class sockaddr_in6 {
	public short sin6_family;
	public char sin6_port;
	public unsigned  sin6_flowinfo;
    public in6_addr sin6_addr;
    public unsigned sin6_scope_id;
}

public class sockaddr_in6_old {
	public short   sin6_family;        
	public char sin6_port;          
	public unsigned sin6_flowinfo;      
	public in6_addr sin6_addr;  
}

// Need to reserve 16 bytes for the address info. Parasol doesn't have unions or a notion of in-line fixed-size arrays yet.
// So we have to 'improvise'. Some code may require some extra porting effort.
public class in6_addr {
	public long long1;
	public long long2;
}

// Note: there is only one C function, but the most convenient way to get some semblance of type-safety (that is restricting
// the function calls to one of the sockaddr types) is to overload the various allowed signatures.
@Windows("ws2_32.dll", "accept")
@Linux("libc.so.6", "accept")
public abstract int accept(int socketfd, ref<sockaddr> addr, ref<int> addrlen);
@Windows("ws2_32.dll", "accept")
@Linux("libc.so.6", "accept")
public abstract int accept(int socketfd, ref<sockaddr_in> addr, ref<int> addrlen);
@Windows("ws2_32.dll", "accept")
@Linux("libc.so.6", "accept")
public abstract int accept(int socketfd, ref<sockaddr_in6> addr, ref<int> addrlen);
@Windows("ws2_32.dll", "accept")
@Linux("libc.so.6", "accept")
public abstract int accept(int socketfd, ref<sockaddr_in6_old> addr, ref<int> addrlen);

// Note: there is only one C function, but the most convenient way to get some semblance of type-safety (that is restricting
// the function calls to one of the sockaddr types) is to overload the various allowed signatures.
@Windows("ws2_32.dll", "bind")
@Linux("libc.so.6", "bind")
public abstract int bind(int s, ref<sockaddr> name, int nameLen);
@Windows("ws2_32.dll", "bind")
@Linux("libc.so.6", "bind")
public abstract int bind(int s, ref<sockaddr_in> name, int nameLen);
@Windows("ws2_32.dll", "bind")
@Linux("libc.so.6", "bind")
public abstract int bind(int s, ref<sockaddr_in6> name, int nameLen);
@Windows("ws2_32.dll", "bind")
@Linux("libc.so.6", "bind")
public abstract int bind(int s, ref<sockaddr_in6_old> name, int nameLen);

@Windows("ws2_32.dll", "gethostbyname")
@Linux("libc.so.6", "gethostbyname")
public abstract ref<hostent> gethostbyname(pointer<byte> name);

@Windows("ws2_32.dll", "htons")
@Linux("libc.so.6", "htons")
public abstract char htons(char u16);

@Windows("ws2_32.dll", "inet_addr")
@Linux("libc.so.6", "inet_addr")
public abstract unsigned inet_addr(pointer<byte> cp);

// Have to figure out what this is doing - does the argument need to be unsigned or in_addr or ref<in_addr>?
@Windows("ws2_32.dll", "inet_ntoa")
@Linux("libc.so.6", "inet_ntoa")
public abstract pointer<byte> inet_ntoa(unsigned in);

@Linux("libc.so.6", "inet_ntop")
public abstract pointer<byte> inet_ntop(int af, address src, pointer<byte> dst, unsigned size);

@Windows("ws2_32.dll", "listen")
@Linux("libc.so.6", "listen")
public abstract int listen(int socketfd, int backlog);

@Windows("ws2_32.dll", "setsockopt")
@Linux("libc.so.6", "setsockopt")
public abstract int setsockopt(int socketfd, int level, int optname, address optval, int optlen);

@Windows("ws2_32.dll", "socket")
@Linux("libc.so.6", "socket")
public abstract int socket(int af, int type, int protocol);

@Windows("ws2_32.dll", "closesocket")
@Linux("libc.so.6", "close")
public abstract int closesocket(int socketfd);

@Windows("ws2_32.dll", "recv")
@Linux("libc.so.6", "recv")
public abstract int recv(int fd, pointer<byte> buf, int len, int recvflags);

@Windows("ws2_32.dll", "send")
@Linux("libc.so.6", "send")
public abstract int send(int fd, pointer<byte> buf, int len, int sendflags);

@Windows("ws2_32.dll", "WSAGetLastError")
public abstract int WSAGetLastError();

@Windows("ws2_32.dll", "WSAStartup")
public abstract int WSAStartup(WORD wVersionRequested, ref<WSADATA> lpWSAData);

// WARNING: This class is currently defined to ensure enough space is reserved for it. Do not use any field
// after wHighVersion
public class WSADATA {
	  public WORD           wVersion;
	  public WORD           wHighVersion;
//	  char           szDescription[WSADESCRIPTION_LEN+1];
//	  char           szSystemStatus[WSASYS_STATUS_LEN+1];
	  long d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12, d13, d14, d15, d16;
	  long d17, d18, d19, d20, d21, d22, d23, d24, d25, d26, d27, d28, d29, d30, d31, d32;
	  byte filler1;
	  long s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15, s16;
	  byte filler2;
	  char iMaxSockets;
	  char iMaxUdpDg;
	  pointer<byte> lpVendorInfo;
}

@Constant
public int SOL_SOCKET = 1;
@Constant
public int SO_REUSEADDR = 2;


