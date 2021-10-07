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
	<li><span class=code>abstract</span>
	<li><span class=code>break</span>
	<li><span class=code>bytes</span>
	<li><span class=code>case</span>
	<li><span class=code>catch</span>
	<li><span class=code>class</span>
	<li><span class=code>continue</span>
	<li><span class=code>default</span>
	<li><span class=code>delete</span>
	<li><span class=code>do</span>
	<li><span class=code>else</span>
	<li><span class=code>enum</span>
	<li><span class=code>extends</span>
	<li><span class=code>false</span>
	<li><span class=code>final</span>
	<li><span class=code>finally</span>
	<li><span class=code>flags</span>
	<li><span class=code>for</span>
	<li><span class=code>function</span>
	<li><span class=code>if</span>
	<li><span class=code>implements</span>
	<li><span class=code>import</span>
	<li><span class=code>in</span>
	<li><span class=code>interface</span>
	<li><span class=code>lock</span>
	<li><span class=code>monitor</span>
	<li><span class=code>namespace</span>
	<li><span class=code>new</span>
	<li><span class=code>null</span>
	<li><span class=code>private</span>
	<li><span class=code>protected</span>
	<li><span class=code>public</span>
	<li><span class=code>return</span>
	<li><span class=code>self</span>
	<li><span class=code>static</span>
	<li><span class=code>super</span>
	<li><span class=code>switch</span>
	<li><span class=code>this</span>
	<li><span class=code>throw</span>
	<li><span class=code>true</span>
	<li><span class=code>try</span>
	<li><span class=code>void</span>
	<li><span class=code>while</span>
</ul>
