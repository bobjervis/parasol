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
import parasol:http;
import parasol:net;
/*
 * Date and Copyright holder of this code base.
 */
string COPYRIGHT_STRING = "2015 Robert Jervis";
/*
 * The Parasol HTTP host command script. This command allows you to host a web site of static
 * content.
 */
class PHostCommand extends process.Command {
	PHostCommand() {
		finalArguments(1, 1, "<directory>");
		description("The named directory is hosted on a Web site. " +
					"\n" +
					"The site is hosted unencrypted, so take care in exposing " +
					"content on the URL to unintended audiences.");
		portOption = integerOption('p', "port", "The (unsecured) port this server will use (default 80).");
		localhostOption = booleanOption('l', "localhost", "Host the content using localhost, rather than the machines IP address.");
	}

	ref<process.Option<int>> portOption;
	
	ref<process.Option<boolean>> localhostOption;
}

PHostCommand phostCommand;
http.Server server;

int main(string[] args) {
	if (!phostCommand.parse(args))
		phostCommand.help();
	char port = 80;

	if (phostCommand.portOption.set())
		port = char(phostCommand.portOption.value);

	string[] params = phostCommand.finalArguments();
	server.setHttpPort(port);
	server.disableHttps();
	printf("Hosting %s on port %d\n", params[0], port);
	server.staticContent("/", params[0]);

	server.start(phostCommand.localhostOption.set() ? net.ServerScope.LOCALHOST : net.ServerScope.INTERNET);
	server.wait();

	return 0;
}
