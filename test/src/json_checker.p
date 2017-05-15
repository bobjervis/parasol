/*
	json_checker.p
	
	This script will load and parse a json string.
	
	Uses the test suite data files from http://www.json.org/JSON_checker/
 */
import parasol:file;
import parasol:json;

int main(string[] args) {
	file.File f = file.openTextFile(args[0]);
	if (f.opened()) {
		string data;
		boolean success;
		
		(data, success) = f.readAll();
		if (!success) {
			printf("Failed reading from %s\n", args[0]);
			return 1;
		}
		f.close();
		
		var x;
		
		(x, success) = json.parse(data);
		if (success) {
			if (args[0].startsWith("fail")) {
				printf("JSON parser accepted file %s this is supposed to be invalid.\n", args[0]);
				return 1;
			}
			printf("PASS: Accepted %s\n", args[0]);
		} else {
			if (args[0].startsWith("pass")) {
				printf("JSON parser rejected file %s that is supposed to be valid.\n", args[0]);
				return 1;
			}
			printf("PASS: Rejected %s\n", args[0]);
		}
	} else {
		printf("Failed to open %s\n", args[0]);
		return 1;
	}
	return 0;
}
