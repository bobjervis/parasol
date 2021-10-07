<h2>{@level 2 Identifiers}</h2>

An identifier is a sequence of one or more characters beginning with a letter or underline character.
Subsequent characters may be letters, decimal number or underlines.
A letter is any Unicode code point whose General Category is some form of Letter.
A decimal number is any Unicode code point whose General Category is Decimal_Number.
The current Parasol compiler uses the <a href="http://www.unicode.org/versions/Unicode8.0.0/">Unicode,  Version 8 Standard</a>.
<p>
An identifier can be of any length and all characters are significant.
<h3>{@level 3 Escaped Identifiers}</h3>

An arbitrary string of characters can be enclosed in grave accent (`) characters to represent an identifier.
Between grave accents, backslash may appear as an escape and the resulting character is exactly as if the same escape sequence appeared in a string or character literal.
<p>
Identifiers enclosed in grave accent characters that are lexically identical to unenclosed identifiers are treated as the same identifier.
<p>
An un-escaped newline character may not appear within an escaped identifier.
<h3>{@level 3 Keywords}</h3>

The following identifiers are treated as keywords and may not appear as normal identifiers unless they are escaped (using grave accents):
<ul>
	<li>abstract
	<li>break
	<li>bytes
	<li>case
	<li>catch
	<li>class
	<li>continue
	<li>default
	<li>delete
	<li>do
	<li>else
	<li>enum
	<li>extends
	<li>false
	<li>final
	<li>finally
	<li>flags
	<li>for
	<li>function
	<li>if
	<li>implements
	<li>import
	<li>in
	<li>interface
	<li>lock
	<li>monitor
	<li>namespace
	<li>new
	<li>null
	<li>private
	<li>protected
	<li>public
	<li>return
	<li>self
	<li>static
	<li>super
	<li>switch
	<li>this
	<li>throw
	<li>true
	<li>try
	<li>void
	<li>while
</ul>
