<h2>{@level 2 Numbers}</h2>

Numbers are sequences of one or more digits and other characters that comprise a single numeric value.
The type of a number depends on the form, value and context of the number itself.
Integer constants have some integral type and floating point numbers have some floating type.
Integer constants have the smallest signed integral type that can represent the constant's value.
Floating point numbers have the smallest floating type that can represent the constant's magnitude and will have a 
representation in the native numeric format closest in value to the exact value of the constant.
A floating point number with a type specifier (letter f) has float type and must be representable as a float.

<h3>{@level 3 Decimal Integers}</h3>

A sequence of one or more decimal digits beginning with a non-zero digit is a <i>decimal integer</i>.
The value of the constant is the decimal value of the digits.
Any extended Unicode decimal digit character is allowed and is interpreted according to the value assigned it in the Unicode version 8.0 specification.
<p>
Examples:
<pre>
    67
	3
	425364756750204
	1000000000
</pre>

<h3>{@level 3 Hexadecimal Integers}</h3>

A sequence of one or more hexadecimal digits (0-9, a-f or A-F) preceded by a 0x or 0X is a <i>hexadecimal integer</i>.
The value of the constant is the value of the digits following the 0x in the hexadecimal number system.
While the letters of a hexadecimal digit string are constrained to the ASCII range, digit characters 
can be any Unicode version 8.0 decimal digit and is interpreted according to the value assigned it in the specification.
<p>
Examples:
<pre>
    0x0F
	0Xffa1
	0x0
</pre>

<h3>{@level 3 Octal Integers}</h3>

A sequence of one or more octal digits (0-7) beginning with a zero digit is an <i>octal integer</i>.
The value of the constant is the value of the digits in the octal number system.
Any extended Unicode decimal digit character whose value is between 0 and 7, inclusive, is allowed 
and is interpreted according to the value assigned it in the Unicode version 8.0 specification.
<p>
Examples:
<pre>
    045
	077
</pre>

<h3>{@level 3 Floating Point Numbers}</h3>

A sequence of one or more decimal digits with a period (decimal point) followed 
by an optional exponent and/or an optional type specifier is a <i>floating point number</i>.
An exponent is the letter <b>e</b> or <b>E</b> followed by an optional plus (+) or minus (-) sign and 
one or more decimal digits.
A type specifier is the letter <b>f</b> or <b>F</b>.
Any extended Unicode decimal digit character is allowed and is interpreted according to the value 
assigned it in the Unicode version 8.0 specification.
<p>
Examples:
<pre>
    0.0
	7.
	.123
	12.5f
	1.5e+17
</pre>

