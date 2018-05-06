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
namespace openssl.org:ssl;

import native:C;

@Linux("libssl.so.10", "BIO_new_socket")
public abstract ref<BIO> BIO_new_socket(int sock, int close_flag);

@Linux("libssl.so.10", "DH_free")
public abstract void DH_free(ref<DH> dh);

@Linux("libssl.so.10", "ERR_clear_error")
public abstract void ERR_clear_error();

@Linux("libssl.so.10", "ERR_error_string")
public abstract pointer<byte> ERR_error_string(long e, pointer<byte> buf);

@Linux("libssl.so.10", "ERR_get_error")
public abstract long ERR_get_error();

@Linux("libssl.so.10", "PEM_read_DHparams")
public abstract ref<DH> PEM_read_DHparams(ref<C.FILE> fp, ref<ref<DH>> x, int(pointer<byte>, int, int, address) cb, address u);

@Linux("libssl.so.10", "SSL_accept")
public abstract int SSL_accept(ref<SSL> ssl);

@Linux("libssl.so.10", "SSL_connect")
public abstract int SSL_connect(ref<SSL> ssl);

@Linux("libssl.so.10", "SSL_CTX_ctrl")
public abstract int SSL_CTX_ctrl(ref<SSL_CTX> ctx, int cmd, long varg, address parg);

@Linux("libssl.so.10", "SSL_CTX_load_verify_locations")
public abstract int SSL_CTX_load_verify_locations(ref<SSL_CTX> ctx, pointer<byte> CAfile, pointer<byte> CApath);

@Linux("libssl.so.10", "SSL_CTX_free")
public abstract void SSL_CTX_free(ref<SSL_CTX> ctx);

@Linux("libssl.so.10", "SSL_CTX_new")
public abstract ref<SSL_CTX> SSL_CTX_new(ref<SSL_METHOD> method);

@Linux("libssl.so.10", "SSL_CTX_set_cipher_list")
public abstract int SSL_CTX_set_cipher_list(ref<SSL_CTX> ctx, pointer<byte> str);

@Linux("libssl.so.10", "SSL_CTX_set_client_CA_list")
public abstract int SSL_CTX_set_client_CA_list(ref<SSL_CTX> ctx, ref<stack_st_X509_NAME> name_list);

public int SSL_CTX_set_options(ref<SSL_CTX> ctx, long options) {
	return SSL_CTX_ctrl(ctx, SSL_CTRL_OPTIONS, options, null);
}

public int SSL_CTX_set_tmp_dh(ref<SSL_CTX> ctx, ref<DH> dh) {
	return SSL_CTX_ctrl(ctx, SSL_CTRL_SET_TMP_DH, 0, dh);
}

@Linux("libssl.so.10", "SSL_CTX_use_certificate_file")
public abstract int SSL_CTX_use_certificate_file(ref<SSL_CTX> ctx, pointer<byte> file, int type);

@Linux("libssl.so.10", "SSL_CTX_use_PrivateKey_file")
public abstract int SSL_CTX_use_PrivateKey_file(ref<SSL_CTX> ctx, pointer<byte> file, int type);

@Linux("libssl.so.10", "SSL_free")
public abstract void SSL_free(ref<SSL> ssl);

@Linux("libssl.so.10", "SSL_get_cipher_list")
public abstract pointer<byte> SSL_get_cipher_list(ref<SSL> ssl, int priority);

@Linux("libssl.so.10", "SSL_get_error")
public abstract int SSL_get_error(ref<SSL> ssl, int return_value);

@Linux("libssl.so.10", "SSL_library_init")
public abstract int SSL_library_init();

@Linux("libssl.so.10", "SSL_load_client_CA_file")
public abstract ref<stack_st_X509_NAME> SSL_load_client_CA_file(pointer<byte> file);

@Linux("libssl.so.10", "SSL_load_error_strings")
public abstract void SSL_load_error_strings();

@Linux("libssl.so.10", "SSL_new")
public abstract ref<SSL> SSL_new(ref<SSL_CTX> context);

@Linux("libssl.so.10", "SSL_read")
public abstract int SSL_read(ref<SSL> ssl, address buf, int num);

@Linux("libssl.so.10", "SSL_set_accept_state")
public abstract void SSL_set_accept_state(ref<SSL> ssl);

@Linux("libssl.so.10", "SSL_set_bio")
public abstract void SSL_set_bio(ref<SSL> ssl, ref<BIO> rbio, ref<BIO> wbio);

@Linux("libssl.so.10", "SSL_set_connect_state")
public abstract void SSL_set_connect_state(ref<SSL> ssl);

@Linux("libssl.so.10", "SSL_set_fd")
public abstract int SSL_set_fd(ref<SSL> ssl, int fd);

@Linux("libssl.so.10", "SSL_use_PrivateKey_file")
public abstract int SSL_use_PrivateKey_file(ref<SSL> ssl, pointer<byte> file, int type);

@Linux("libssl.so.10", "SSL_write")
public abstract int SSL_write(ref<SSL> ssl, address buf, int num);

@Linux("libssl.so.10", "SSLv23_method")
public abstract ref<SSL_METHOD> SSLv23_method();

@Linux("libssl.so.10", "TLSv1_2_method")
public abstract ref<SSL_METHOD> TLSv1_2_method();

@Linux("libssl.so.10", "SSLv23_server_method")
public abstract ref<SSL_METHOD> SSLv23_server_method();

@Linux("libssl.so.10", "TLSv1_2_server_method")
public abstract ref<SSL_METHOD> TLSv1_2_server_method();

@Linux("libssl.so.10", "SSLv23_client_method")
public abstract ref<SSL_METHOD> SSLv23_client_method();

@Linux("libssl.so.10", "TLSv1_2_client_method")
public abstract ref<SSL_METHOD> TLSv1_2_client_method();

public class SSL_CTX {
}

public class SSL_METHOD {
}

public class BIO {
}

public class SSL {
}

public class stack_st_X509_NAME {
}

public class DH {
}

@Constant
public long SSL_OP_NO_SSLv2 =                                      0x01000000;
@Constant
public long SSL_OP_NO_SSLv3 =                                      0x02000000;

public int BIO_NOCLOSE = 0x00;
public int BIO_CLOSE = 0x01;

public int X509_FILETYPE_PEM   = 1;
public int X509_FILETYPE_ASN1  = 2;
public int X509_FILETYPE_DEFAULT = 3;


public int SSL_FILETYPE_ASN1  =     X509_FILETYPE_ASN1;
public int SSL_FILETYPE_PEM   =     X509_FILETYPE_PEM;

public int SSL_CTRL_SET_TMP_DH = 3;
public int SSL_CTRL_OPTIONS = 32;

@Constant
public int SSL_ERROR_NONE =                  0;
@Constant
public int SSL_ERROR_SSL =                   1;
@Constant
public int SSL_ERROR_WANT_READ =             2;
@Constant
public int SSL_ERROR_WANT_WRITE =            3;
@Constant
public int SSL_ERROR_WANT_X509_LOOKUP =      4;
@Constant
public int SSL_ERROR_SYSCALL =               5;/* look at error stack/return
                                           * value/errno */
@Constant
public int SSL_ERROR_ZERO_RETURN =           6;
@Constant
public int SSL_ERROR_WANT_CONNECT =          7;
@Constant
public int SSL_ERROR_WANT_ACCEPT =           8;


