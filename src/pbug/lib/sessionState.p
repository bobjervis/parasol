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
namespace parasollanguage.org:debug.manager;

import parasol:net;
import parasol:process;
import parasollanguage.org:debug;

class SessionState {
	boolean debugApplication(ref<debug.PBugOptions> options, string exePath, string... arguments) {
		cmdLine := process.getCommandLine();
		if (cmdLine.length() < 2) {
			printf("Command line incomplete\n");
			return false;
		}
		if (!cmdLine[1].endsWith(".pxi")) {
			printf("First argument expected to name a .pxi file\n");
			return false;
		}
		// We're all set to spawn the 'manager' process.
		controller := new process.Process();
		string[] ctrlrArgs;
		ctrlrArgs.append(cmdLine[1]);
		ctrlrArgs.append("-c");
		ctrlrArgs.append("wss://" + net.dottedIP(net.hostIPv4()) + ":" + string(options.managerOption.value) + "/proc/control");
		ctrlrArgs.append(options.copiedOptions());
		if (!controller.spawn(cmdLine[0], ctrlrArgs)) {
			printf("Spawn of controller sub-process failed\n");
			return false;
		}
		return true;
	}
}

