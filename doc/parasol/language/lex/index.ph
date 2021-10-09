<h1>{@level 1 LEXICAL CONVENTIONS}</h1>

<ul>
	<li>{@topic identifiers.ph}
	<li>{@topic annotations.ph}
	<li>{@topic special-tokens.ph}
	<li>{@topic numbers.ph}
	<li>{@topic text-literals.ph}
	<li>{@topic white-space.ph}
</ul>

<p>
Parasol programs consist of a set of one or more text source files, one of which is designated as the 'main file'.
Each source file consists of a stream of <i>tokens</i> identified by a single forward pass over the source text possibly separated by runs of white space.
With a handful of exceptions, white space has no effect on tokenization other than to separate otherwise indistinguishable tokens.
<p>
Text may appear in any encoding, but the following documentation assumes some form of Unicode.
If your compiler does not support Unicode, it must describe how its supported character set is mapped to Unicode.
Parasol assigns special meaning to most of the characters in the ASCII (\u00 - \u7f) range.
Unicode characters that lie outside that range and which are classified as letters or decimal digits may be used in identifiers and numeric constants.
Unicode white space characters may be used as white space.
The exact set of characters which are so classified does vary from revision to revision of Unicode.
Currently the Parasol compiler is targeting the Unicode 8.0 version of the specification.
<p>
The goal is to provide non-English speaking programmers with facilities that make their own source code more readable to them.
Within the constraints of the character set that it supports, a Parasol compiler must allow combinations that would be confusing to a human reader (such as mixing ASCII digits with Thai digits in the same numeric constant).
Digits from any valid code point range can be used in Parasol decimal fractions, even though the decimal point (.), exponent (e or E) and exponent sign (+ or -) are restricted to the ASCII characters.

