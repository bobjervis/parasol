import parasol:file;

int main(string[] args) {
	for (int i = 0; i < args.length(); i++) {
		string filename = args[i];
		file.File f = file.openBinaryFile(filename);
		string text;
		boolean result;
		(text, result) = f.readAll();
		if (result) {
			printf("%s:\n", filename);
			memDump(&text[0], text.length(), 0);
		} else
			printf("Could not read %s\n", filename);
	}
	return 0;
}

