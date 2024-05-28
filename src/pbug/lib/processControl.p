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

public string PROCESS_CONTROL_PROTOCOL = "ProcessControl";
/**
 * These are the notifications sent to a manager describing state changes
 * detected in the client. There are also a set of control messages that
 * the controller uses to coordinate with the manager.
 */
public interface ProcessNotifications {

}
/**
 * These are the commands the manager send to the controller to intervene
 * in one way or another with the operation of the client. These may also include
 * queries about the state of the process and it's memory.
 */
public interface ProcessCommands {
}
