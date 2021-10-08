<h2>{@level 2 Text Literals}</h2>

<h3>{@level 3 String Literals}</h3>

A sequence of characters enclosed in quotation marks is a string literal.
Unescaped newline characters may not appear within a string literal.

<h3>{@level 3 Character Literals}</h3>

A sequence of characters enclosed in apostrophes is a character literal.
Unescaped newline characters may not appear within a character literal.
<p>
The text within a character literal may only represent a single character.
Thus the text can be a single character itself, or a single escape sequence that represents a character.

<h3>{@level 3 Escape Sequences}</h3>

Within string literals, character literals or escaped identifiers, the backslash character (\) may be used to initiate an <i>escape sequence</i>.
Each escape sequence represents a single character.
Two escape sequences that produce the same Unicode code point are equivalent.
<p>
The following are the defined two-character escape sequences (and their equivalent ASCII character value):
<ul>
	<li>\\ Backslash
	<li>\a Audible Bell
	<li>\b Backspace
	<li>\f Form Feed
	<li>\n Newline
	<li>\r Carriage Return
	<li>\t Horizontal Tab
	<li>\v Vertical Tab
	<li>\&quot; Quotation Mark
	<li>\&apos; Apostrophe
	<li>\` Grave Accent
</ul>

Longer escape sequences begin with the following pair:
<ul>
	<li>\u <i>or</i>
	<li>\U Unicode code point escape. 
	The initial characters are followed by one or more hexadecimal digits. 
	The value of the hexadecimal number must be a valid Unicode code point.
	<li>\x <i>or</i>
	<li>\X Hexadecimal escape. 
	The initial characters are followed by one or more hexadecimal digits. 
	The value of the hexadecimal number must be between 0 and 255 decimal.
	<li>\0 <i>or</i>
	<li>\1 <i>or</i>
	<li>\2 <i>or</i>
	<li>\3 <i>or</i>
	<li>\4 <i>or</i>
	<li>\5 <i>or</i>
	<li>\6 <i>or</i>
	<li>\7 Octal escape. The initial characters are followed by zero or more octal digits. The value of the octal number must be between 0 and 255 decimal.
</ul>

A backslash character followed by a newline itself is a special escape sequence that represents no character at all.
Instead, it may appear within a literal to allow the literal to span two or more lines of text.
<p>
All other characters following a backslash are invalid escape sequences.
<p>
Any token containing an invalid escape sequence or a sequence whose value is out of range is an invalid token.

