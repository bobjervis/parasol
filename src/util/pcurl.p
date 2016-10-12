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
import parasol:commandLine;
import parasol:file;
import parasol:process;

/*
 * Date and Copyright holder of this code base.
 */
string COPYRIGHT_STRING = "2015 Robert Jervis";
/*
 * THe Parasol cURL command script. THis is a tiny subset of the full cURL command, but the intention is that
 * for whatever options this script does support, that it mimics the behavior of the cURL command.
 */
class PcURLCommand extends commandLine.Command {
	finalArguments(0, int.MAX_VALUE, "<url>");
	description("Each of the URL's is fetched and written to the standard output. " +
				"\n" +
				"Only the http protocol is supported. " +
				"Only GET and POST methods are supported. " +
				"\n" +
				"Copyright (c) " + COPYRIGHT_STRING
				);
	verboseArgument = booleanArgument('v', null,
				"Enables verbose output.");
	helpArgument('?', "help",
				"Displays this help.");

	ref<commandLine.Argument<boolean>> verboseArgument;
}

PcURLCommand command;
string[] urls;

int main(string[] args) {
	int result = 1;
	
	if (!command.parse(args))
		command.help();
	urls = command.finalArgs();
	if (urls.length() <= 0)
		command.help();
	for (int i = 0; i < urls.length(); i++) {
		HttpClient client(urls[i]);
	}
}