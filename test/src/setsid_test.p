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

import parasol:process;
import parasol:storage;
import parasol:text;
import native:linux;

int ptyMasterFd = linux.posix_openpt(linux.O_RDWR);
if (ptyMasterFd < 0) {
	linux.perror("posix_openpt".c_str());
	linux._exit(0);
}
linux.termios t;

linux.tcgetattr(ptyMasterFd, &t);
t.c_oflag |= linux.ONLRET;
if (linux.tcsetattr(ptyMasterFd, 0, &t) != 0) {
	linux.perror("tcsetattr".c_str());
	linux._exit(0);
}

int result = linux.grantpt(ptyMasterFd);
if (result != 0) {
	linux.perror("grantpt".c_str());
	linux._exit(0);
}
result = linux.unlockpt(ptyMasterFd);
if (result != 0) {
	linux.perror("unlockpt".c_str());
	linux._exit(0);
}

if (linux.fork() != 0) {
	//linux.ptsname_r(ptyMasterFd, &ctermid[0], linux.L_ctermid);
	//printf("Current pid = %d sid = %d ctermid = %s\n", linux.getpid(), linux.getsid(0), &ctermid[0]);
	byte[] buffer;

	buffer.resize(8192);
	
	string s;
	
	for (;;) {
		int actual = linux.read(ptyMasterFd, &buffer[0], buffer.length());
		if (actual < 0)
			linux.perror("read".c_str());
		if (actual <= 0)
			break;
		if (fd >= 0) {
			// Closing the slave...
			linux.close(fd);
			fd = -1;
		}
		text.memDump(&buffer[0], actual, 0);
	}
	linux._exit(0);
}

byte[] buffer;
buffer.resize(linux.PATH_MAX);
if (linux.ptsname_r(ptyMasterFd, &buffer[0], buffer.length()) != 0) {
	linux.perror("ptsname_r".c_str());
	linux._exit(0);
}
int fd = linux.open(&buffer[0], linux.O_RDWR);
if (fd < 3) {
	linux.perror("open".c_str());
	linux._exit(0);
}

if (linux.setsid() < 0) {
	linux.perror("setsid".c_str());
	linux._exit(0);
}
int ioc = linux.ioctl(ptyMasterFd, linux.TIOCSCTTY, 0);
if (ioc < 0) {
	linux.perror("ioctl".c_str());
	linux._exit(0);
}
linux.close(ptyMasterFd);

if (linux.dup2(fd, 0) != 0) {
	linux.perror("dup2 0".c_str());
	linux._exit(0);
}
if (linux.dup2(fd, 1) != 1) {
	linux.perror("dup2 1".c_str());
	linux._exit(0);
}
if (linux.dup2(fd, 2) != 2) {
	linux.perror("dup2 2".c_str());
	linux._exit(0);
}
linux.close(fd);

pointer<byte>[] fullArgs;

string s = "bash";

fullArgs.append(s.c_str());

//			for (int i= 0; i < args.length(); i++)
//				fullArgs.append(args[i].c_str());
fullArgs.append(null);

pointer<pointer<byte>> argv = &fullArgs[0];
linux.execv("/bin/bash".c_str(), argv);
linux._exit(-16);

