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
namespace mysql.com:mysql;

import native:C;
/*
	Note: The following information was taken from the Connector/C include files. They are intended
	to provide a developer with ready access to the mysql Connector/C library, version 6.1.10. TO use this
	binding with any other version of the library will require that the following text be adjusted to reflect
	the database client include files with that version.
 */
public class my_bool = boolean;
public class my_ulonglong = long;
public class my_socket = int;

public class MYSQL {
  NET           net;                    /* Communication parameters */
  pointer<byte> connector_fd;          /* ConnectorFd for SSL */
  pointer<byte> host,user,passwd,unix_socket,server_version,host_info;
  pointer<byte> info, db;
  ref<CHARSET_INFO> charset;
  ref<MYSQL_FIELD> fields;
  MEM_ROOT      field_alloc;
  my_ulonglong affected_rows;
  my_ulonglong insert_id;               /* id if insert on table with NEXTNR */
  my_ulonglong extra_info;              /* Not used */
  long thread_id;              /* Id for connection in server */
  long packet_length;
  unsigned  port;
  long client_flag,server_capabilities;
  unsigned  protocol_version;
  unsigned  field_count;
  unsigned  server_status;
  unsigned  server_language;
  unsigned  warning_count;
  st_mysql_options options;
  mysql_status status;
  byte _padding0_;
  byte _padding1_;
  byte _padding2_;
  my_bool       free_me;                /* If free in mysql_close */
  my_bool       reconnect;              /* set to 1 if automatic reconnect */

  /* session-wide random string */
  byte          scramble0, scramble1, scramble2, scramble3, scramble4, scramble5, scramble6, scramble7;
  byte          scramble8, scramble9, scramble10, scramble11, scramble12, scramble13, scramble14, scramble15;
  byte          scramble16, scramble17, scramble18, scramble19, scramble20;
  my_bool unused1;
  address unused2, unused3, unused4, unused5;

  ref<LIST> stmts;                     /* list of all statements */
  ref<st_mysql_methods> methods;
  address thd;
  /*
    Points to boolean flag in MYSQL_RES  or MYSQL_STMT. We set this flag
    from mysql_stmt_close if close had to cancel result set of this object.
  */
  ref<my_bool> unbuffered_fetch_owner;
  /* needed for embedded server - no net buffer to store the 'info' */
  pointer<byte> info_buffer;
  address extension;
}

enum mysql_status {
  MYSQL_STATUS_READY, MYSQL_STATUS_GET_RESULT, MYSQL_STATUS_USE_RESULT,
  MYSQL_STATUS_STATEMENT_GET_RESULT
}

class st_mysql_options {
  unsigned connect_timeout, read_timeout, write_timeout;
  unsigned port, protocol;
  long client_flag;
  pointer<byte> host,user,password,unix_socket,db;
  ref<st_dynamic_array> init_commands;
  pointer<byte> my_cnf_file,my_cnf_group, charset_dir, charset_name;
  pointer<byte> ssl_key;                                /* PEM key file */
  pointer<byte> ssl_cert;                               /* PEM cert file */
  pointer<byte> ssl_ca;                                 /* PEM CA file */
  pointer<byte> ssl_capath;                             /* PEM directory of CA-s? */
  pointer<byte> ssl_cipher;                             /* cipher to use */
  pointer<byte> shared_memory_base_name;
  long max_allowed_packet;
  my_bool use_ssl;                              /* Deprecated ! Former use_ssl */
  my_bool compress,named_pipe;
  my_bool unused1;
  my_bool unused2;
  my_bool unused3;
  my_bool unused4;
  byte _padding_; 					// because mysql_option in C has alignment > 1
  mysql_option methods_to_use;
  pointer<byte> ci;
	/*
	The member tranlsated here as ci is a unon of the following two fields:
	union {
    /*
      The ip/hostname to use when authenticating
      client against embedded server built with
      grant tables - only used in embedded server
    */
    char *client_ip;

    /*
      The local address to bind when connecting to
      remote server - not used in embedded server
    */
    char *bind_address;
	*/
  my_bool unused5;
  /* 0 - never report, 1 - always report (default) */
  my_bool report_data_truncation;

  /* function pointers for local infile support */
  int (ref<address>, pointer<byte>, address) local_infile_init;
  int (address, pointer<byte>, unsigned) local_infile_read;
  void (address) local_infile_end;
  int (address, pointer<byte>, unsigned) local_infile_error;
  address local_infile_userdata;
  ref<st_mysql_options_extention> extension;
}

enum mysql_option {
  MYSQL_OPT_CONNECT_TIMEOUT, MYSQL_OPT_COMPRESS, MYSQL_OPT_NAMED_PIPE,
  MYSQL_INIT_COMMAND, MYSQL_READ_DEFAULT_FILE, MYSQL_READ_DEFAULT_GROUP,
  MYSQL_SET_CHARSET_DIR, MYSQL_SET_CHARSET_NAME, MYSQL_OPT_LOCAL_INFILE,
  MYSQL_OPT_PROTOCOL, MYSQL_SHARED_MEMORY_BASE_NAME, MYSQL_OPT_READ_TIMEOUT,
  MYSQL_OPT_WRITE_TIMEOUT, MYSQL_OPT_USE_RESULT,
  MYSQL_OPT_USE_REMOTE_CONNECTION, MYSQL_OPT_USE_EMBEDDED_CONNECTION,
  MYSQL_OPT_GUESS_CONNECTION, MYSQL_SET_CLIENT_IP, MYSQL_SECURE_AUTH,
  MYSQL_REPORT_DATA_TRUNCATION, MYSQL_OPT_RECONNECT,
  MYSQL_OPT_SSL_VERIFY_SERVER_CERT, MYSQL_PLUGIN_DIR, MYSQL_DEFAULT_AUTH,
  MYSQL_OPT_BIND,
  MYSQL_OPT_SSL_KEY, MYSQL_OPT_SSL_CERT,
  MYSQL_OPT_SSL_CA, MYSQL_OPT_SSL_CAPATH, MYSQL_OPT_SSL_CIPHER,
  MYSQL_OPT_SSL_CRL, MYSQL_OPT_SSL_CRLPATH,
  MYSQL_OPT_CONNECT_ATTR_RESET, MYSQL_OPT_CONNECT_ATTR_ADD,
  MYSQL_OPT_CONNECT_ATTR_DELETE,
  MYSQL_SERVER_PUBLIC_KEY,
  MYSQL_ENABLE_CLEARTEXT_PLUGIN,
  MYSQL_OPT_CAN_HANDLE_EXPIRED_PASSWORDS,
  MYSQL_OPT_SSL_ENFORCE,
  MYSQL_OPT_MAX_ALLOWED_PACKET, MYSQL_OPT_NET_BUFFER_LENGTH,
  MYSQL_OPT_TLS_VERSION,
  MYSQL_OPT_SSL_MODE
}

class st_mysql_options_extention {
}

class st_mysql_methods {
}

class st_dynamic_array {
}

public class CHARSET_INFO {
/*
  uint      number;
  uint      primary_number;
  uint      binary_number;
  uint      state;
  const char *csname;
  const char *name;
  const char *comment;
  const char *tailoring;
  const uchar *ctype;
  const uchar *to_lower;
  const uchar *to_upper;
  const uchar *sort_order;
  MY_UCA_INFO *uca; /* This can be changed in apply_one_rule() */
  const uint16     *tab_to_uni;
  const MY_UNI_IDX *tab_from_uni;
  const MY_UNICASE_INFO *caseinfo;
  const struct lex_state_maps_st *state_maps; /* parser internal data */
  const uchar *ident_map; /* parser internal data */
  uint      strxfrm_multiply;
  uchar     caseup_multiply;
  uchar     casedn_multiply;
  uint      mbminlen;
  uint      mbmaxlen;
  uint      mbmaxlenlen;
  my_wc_t   min_sort_char;
  my_wc_t   max_sort_char; /* For LIKE optimization */
  uchar     pad_char;
  my_bool   escape_with_backslash_is_dangerous;
  uchar     levels_for_compare;
  uchar     levels_for_order;

  MY_CHARSET_HANDLER *cset;
  MY_COLLATION_HANDLER *coll;
 */
}

class LIST {
	ref<LIST> prev, next;
	address data;
}

public class NET {
  ref<Vio> vio;
  pointer<byte> buff,buff_end,write_pos,read_pos;
  my_socket fd;                                 /* For Perl DBI/dbd */
  /*
    The following variable is set if we are doing several queries in one
    command ( as in LOAD TABLE ... FROM MASTER ),
    and do not want to confuse the client with OK at the wrong time
  */
  long remain_in_buf,length, buf_length, where_b;
  long max_packet,max_packet_size;
  unsigned pkt_nr,compress_pkt_nr;
  unsigned write_timeout, read_timeout, retry_count;
  int fcntl;
  ref<unsigned>  return_status;
  byte reading_or_writing;
  char save_char;
  my_bool unused1; /* Please remove with the next incompatible ABI change */
  my_bool unused2; /* Please remove with the next incompatible ABI change */
  my_bool compress;
  my_bool unused3; /* Please remove with the next incompatible ABI change. */
  /*
    Pointer to query object in query cache, do not equal NULL (0) for
    queries in cache that have not stored its results yet
  */
  /*
    Unused, please remove with the next incompatible ABI change.
  */
  pointer<byte> unused;
  unsigned last_errno;
  byte error;
  my_bool unused4; /* Please remove with the next incompatible ABI change. */
  my_bool unused5; /* Please remove with the next incompatible ABI change. */
  /** Client library error message buffer. Actually belongs to struct MYSQL. */
  byte last_error0;
  long last_error1, last_error2, last_error3, last_error4, last_error5, last_error6, last_error7, last_error8, last_error9, last_error10;
  long last_error11, last_error12, last_error13, last_error14, last_error15, last_error16, last_error17, last_error18, last_error19, last_error20;
  long last_error21, last_error22, last_error23, last_error24, last_error25, last_error26, last_error27, last_error28, last_error29, last_error30;
  long last_error31, last_error32, last_error33, last_error34, last_error35, last_error36, last_error37, last_error38, last_error39, last_error40;
  long last_error41, last_error42, last_error43, last_error44, last_error45, last_error46, last_error47, last_error48, last_error49, last_error50;
  long last_error51, last_error52, last_error53, last_error54, last_error55, last_error56, last_error57, last_error58, last_error59, last_error60;
  long last_error61, last_error62, last_error63;
  byte last_error506, last_error507, last_error508, last_error509, last_error510, last_error511, last_error512;
  /** Client library sqlstate buffer. Set along with the error message. */
  byte sqlstate1, sqlstate2, sqlstate3, sqlstate4, sqlstate5, sqlstate6;
  /**
    Extension pointer, for the caller private use.
    Any program linking with the networking library can use this pointer,
    which is handy when private connection specific data needs to be
    maintained.
    The mysqld server process uses this pointer internally,
    to maintain the server internal instrumentation for the connection.
  */
  address extension;
}

class Vio {
}

public class MYSQL_ROW = pointer<pointer<byte>>;

public class MYSQL_FIELD {
/*
  char *name;                 /* Name of column */
  char *org_name;             /* Original column name, if an alias */
  char *table;                /* Table of column if column was a field */
  char *org_table;            /* Org table name, if table was an alias */
  char *db;                   /* Database for table */
  char *catalog;              /* Catalog for table */
  char *def;                  /* Default value (set by mysql_list_fields) */
  unsigned long length;       /* Width of column (create length) */
  unsigned long max_length;   /* Max width for selected set */
  unsigned int name_length;
  unsigned int org_name_length;
  unsigned int table_length;
  unsigned int org_table_length;
  unsigned int db_length;
  unsigned int catalog_length;
  unsigned int def_length;
  unsigned int flags;         /* Div flags */
  unsigned int decimals;      /* Number of decimals in field */
  unsigned int charsetnr;     /* Character set */
  enum enum_field_types type; /* Type of field. See mysql_com.h for types */
  void *extension;
 */
}

class MYSQL_RES {
}

class MEM_ROOT {
  ref<USED_MEM> free;                  /* blocks with free memory in it */
  ref<USED_MEM> used;                  /* blocks almost without free memory */
  ref<USED_MEM> pre_alloc;             /* preallocated block */
  /* if block have less memory it will be put in 'used' list */
  C.size_t min_malloc;
  C.size_t block_size;               /* initial block size */
  unsigned block_num;          /* allocated blocks counter */
  /*
     first free block in queue test counter (if it exceed
     MAX_BLOCK_USAGE_BEFORE_DROP block will be dropped in 'used' list)
  */
  unsigned first_block_usage;

  void () error_handler;

  PSI_memory_key m_psi_key;
}

class USED_MEM {
}

class PSI_memory_key = unsigned;

@Linux("libmysqlclient.so", "mysql_close")
public abstract void mysql_close(ref<MYSQL> mysql);

@Linux("libmysqlclient.so", "mysql_errno")
public abstract unsigned mysql_errno(ref<MYSQL> mysql);

@Linux("libmysqlclient.so", "mysql_fetch_lengths")
public abstract pointer<long> mysql_fetch_lengths(ref<MYSQL_RES> result);

@Linux("libmysqlclient.so", "mysql_fetch_row")
public abstract MYSQL_ROW mysql_fetch_row(ref<MYSQL_RES> result);

@Linux("libmysqlclient.so", "mysql_field_count")
public abstract int mysql_field_count(ref<MYSQL> mysql);

@Linux("libmysqlclient.so", "mysql_free_result")
public abstract void mysql_free_result(ref<MYSQL_RES> result);

@Linux("libmysqlclient.so", "mysql_init")
public abstract ref<MYSQL> mysql_init(ref<MYSQL> mysql);

@Linux("libmysqlclient.so", "mysql_get_server_info")
public abstract pointer<byte> mysql_get_server_info(ref<MYSQL> mysql);

@Linux("libmysqlclient.so", "mysql_num_fields")
public abstract int mysql_num_fields(ref<MYSQL_RES> result);

@Linux("libmysqlclient.so", "mysql_query")
public abstract int mysql_query(ref<MYSQL> mysql, pointer<byte> stmt_str);

@Linux("libmysqlclient.so", "mysql_real_connect")
public abstract ref<MYSQL> mysql_real_connect(ref<MYSQL> mysql, pointer<byte> host, pointer<byte> user, pointer<byte> passwd, 
									pointer<byte> db, unsigned port, pointer<byte> unix_socket, long client_flag);

@Linux("libmysqlclient.so", "mysql_store_result")
public abstract ref<MYSQL_RES> mysql_store_result(ref<MYSQL> mysql);

unsigned CR_UNKNOWN_ERROR        = 2000;
unsigned CR_SOCKET_CREATE_ERROR  = 2001;
unsigned CR_CONNECTION_ERROR     = 2002;
unsigned CR_CONN_HOST_ERROR      = 2003;
unsigned CR_IPSOCK_ERROR         = 2004;
unsigned CR_UNKNOWN_HOST         = 2005;
unsigned CR_SERVER_GONE_ERROR    = 2006;
unsigned CR_VERSION_ERROR        = 2007;
unsigned CR_OUT_OF_MEMORY        = 2008;
unsigned CR_WRONG_HOST_INFO      = 2009;
unsigned CR_LOCALHOST_CONNECTION = 2010;
unsigned CR_TCP_CONNECTION       = 2011;
unsigned CR_SERVER_HANDSHAKE_ERR = 2012;
unsigned CR_SERVER_LOST          = 2013;
unsigned CR_COMMANDS_OUT_OF_SYNC = 2014;
unsigned CR_NAMEDPIPE_CONNECTION = 2015;
unsigned CR_NAMEDPIPEWAIT_ERROR  = 2016;
unsigned CR_NAMEDPIPEOPEN_ERROR  = 2017;
unsigned CR_NAMEDPIPESETSTATE_ERROR = 2018;
unsigned CR_CANT_READ_CHARSET    = 2019;
unsigned CR_NET_PACKET_TOO_LARGE = 2020;
unsigned CR_EMBEDDED_CONNECTION  = 2021;
unsigned CR_PROBE_SLAVE_STATUS   = 2022;
unsigned CR_PROBE_SLAVE_HOSTS    = 2023;
unsigned CR_PROBE_SLAVE_CONNECT  = 2024;
unsigned CR_PROBE_MASTER_CONNECT = 2025;
unsigned CR_SSL_CONNECTION_ERROR = 2026;
unsigned CR_MALFORMED_PACKET     = 2027;
unsigned CR_WRONG_LICENSE        = 2028;

/* new 4.1 error codes */
unsigned CR_NULL_POINTER         = 2029;
unsigned CR_NO_PREPARE_STMT      = 2030;
unsigned CR_PARAMS_NOT_BOUND     = 2031;
unsigned CR_DATA_TRUNCATED       = 2032;
unsigned CR_NO_PARAMETERS_EXISTS = 2033;
unsigned CR_INVALID_PARAMETER_NO = 2034;
unsigned CR_INVALID_BUFFER_USE   = 2035;
unsigned CR_UNSUPPORTED_PARAM_TYPE = 2036;

unsigned CR_SHARED_MEMORY_CONNECTION             = 2037;
unsigned CR_SHARED_MEMORY_CONNECT_REQUEST_ERROR  = 2038;
unsigned CR_SHARED_MEMORY_CONNECT_ANSWER_ERROR   = 2039;
unsigned CR_SHARED_MEMORY_CONNECT_FILE_MAP_ERROR = 2040;
unsigned CR_SHARED_MEMORY_CONNECT_MAP_ERROR      = 2041;
unsigned CR_SHARED_MEMORY_FILE_MAP_ERROR         = 2042;
unsigned CR_SHARED_MEMORY_MAP_ERROR              = 2043;
unsigned CR_SHARED_MEMORY_EVENT_ERROR            = 2044;
unsigned CR_SHARED_MEMORY_CONNECT_ABANDONED_ERROR = 2045;
unsigned CR_SHARED_MEMORY_CONNECT_SET_ERROR      = 2046;
unsigned CR_CONN_UNKNOW_PROTOCOL                 = 2047;
unsigned CR_INVALID_CONN_HANDLE                  = 2048;
unsigned CR_UNUSED_1                             = 2049;
unsigned CR_FETCH_CANCELED                       = 2050;
unsigned CR_NO_DATA                              = 2051;
unsigned CR_NO_STMT_METADATA                     = 2052;
unsigned CR_NO_RESULT_SET                        = 2053;
unsigned CR_NOT_IMPLEMENTED                      = 2054;
unsigned CR_SERVER_LOST_EXTENDED                 = 2055;
unsigned CR_STMT_CLOSED                          = 2056;
unsigned CR_NEW_STMT_METADATA                    = 2057;
unsigned CR_ALREADY_CONNECTED                    = 2058;
unsigned CR_AUTH_PLUGIN_CANNOT_LOAD              = 2059;
unsigned CR_DUPLICATE_CONNECTION_ATTR            = 2060;
unsigned CR_AUTH_PLUGIN_ERR                      = 2061;
unsigned CR_INSECURE_API_ERR                     = 2062;
