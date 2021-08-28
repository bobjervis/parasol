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
 * THe Parasol cURL command script. THis is a tiny subset of the full cURL command, but the intention is that
 * for whatever options this script does support, that it mimics the behavior of the cURL command.
 */
class PcURLCommand extends process.Command {
	PcURLCommand() {
		finalArguments(0, int.MAX_VALUE, "<url>");
		description("Each of the URL's is fetched and written to the standard output. " +
					"\n" +
					"Only the http protocol is supported. " +
					"Only GET and POST methods are supported. " +
					"\n" +
					"Copyright (c) " + COPYRIGHT_STRING
					);
		verboseOption = booleanOption('v', null,
					"Enables verbose output.");
		helpOption('?', "help",
					"Displays this help.");
	}

	ref<process.Option<boolean>> verboseOption;
}

PcURLCommand command;
string[] urls;

int main(string[] args) {
	int result = 1;
	
	if (!command.parse(args))
		command.help();
	urls = command.finalArguments();
	if (urls.length() <= 0)
		command.help();
	int exitCode;
	for (int i = 0; i < urls.length(); i++) {
		http.HttpClient client(urls[i]);

		http.ConnectStatus result = client.get();
		if (result == http.ConnectStatus.OK) {
			ref<http.HttpParsedResponse> resp = client.response();
			if (resp == null) {
				printf("malformed or missing HTTP response header for url '%s'\n", urls[i]);
				exitCode = 1;
			} else {
				if (command.verboseOption.set())
					printf("HTTP Response %s to '%s'\n", resp.code, urls[i]);
				else if (resp.code != "200") {
					printf("ERROR: HTTP Response %s to '%s'\n", resp.code, urls[i]);
					exitCode = 1;
				} else {
					string contentLength = resp.headers["content-length"];
					if (contentLength != null) {
						int len = int.parse(contentLength);
						ref<net.Connection> conn = client.connection();
	
						if (conn == null) {
							printf("No connection object for '%s'\n", urls[i]);
							exitCode = 1;
						} else {
							byte[] buffer;
							int accumulated;
	
							buffer.resize(len);

							while (accumulated < len) {
								int actual = conn.read(&buffer[accumulated], buffer.length() - accumulated);

								accumulated += actual;
							}
							process.stdout.write(&buffer[0], accumulated);
						}
					} else {
						printf("Unknown content-length for '%s'\n", urls[i]);
						exitCode = 1;
					}

				}
			}
		} else {
			printf("GET of '%s' failed: %s\n", urls[i], string(result));
			exitCode = 1;
		}
	}
	return exitCode;
}