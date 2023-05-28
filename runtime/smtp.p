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
 * @ignore
 */
namespace parasol:smtp;

public class Mail {
	ref<libsmtp_session_struct> _session;

	public Mail() {
		_session = libsmtp_session_initialize();
	}

	~Mail() {
		libsmtp_session_free(_session);
	}
}

private class libsmtp_session_struct { 
	int serverFlags;
}

@Linux("libsmtp.so", "libsmtp_session_free")
private abstract void libsmtp_session_free(ref<libsmtp_session_struct> session);

@Linux("libsmtp.so", "libsmtp_session_initialize")
private abstract ref<libsmtp_session_struct> libsmtp_session_initialize();

