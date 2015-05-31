for (int i = 0; i < '0'; i++) {
	byte b = byte(i);
	assert(!b.isDigit());
}
for (int i = '0'; i <= '9'; i++) {
	byte b = byte(i);
	assert(b.isDigit());
}
for (int i = '9' + 1; i <= 0xff; i++) {
	byte b = byte(i);
	assert(!b.isDigit());
}
