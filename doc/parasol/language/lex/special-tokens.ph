<h2>{@level 2 Special Tokens}</h2>

These tokens are composed of one or more printable non-alphanumeric characters (the name of the token follows each character sequence):
<p>
The first table of tokens appear as operators in expressions.
<p>
<table>
<thead>
<tr><td>Token</td><td>Description</td></tr>
</thead>
<tr><td class=code>&amp;</td><td>Ampersand - either Address-of or Bitwise And</td></tr>
<tr><td class=code>&amp;&amp;</td><td>Logical And</td></tr>
<tr><td class=code>&amp;=</td><td>And assignment</td></tr>
<tr><td class=code>|</td><td>Bitwise inclusive or</td></tr>
<tr><td class=code>||</td><td>Logical or</td></tr>
<tr><td class=code>|=</td><td>Inclusive or assignment</td></tr>
<tr><td class=code>^</td><td>Bitwise exclusive or</td></tr>
<tr><td class=code>^=</td><td>Exclusive or assignment</td></tr>
<tr><td class=code>+</td><td>Plus</td></tr>
<tr><td class=code>+=</td><td>Plus assignment</td></tr>
<tr><td class=code>++</td><td>Increment</td></tr>
<tr><td class=code>-</td><td>Minus</td></tr>
<tr><td class=code>-=</td><td>Minus assignment</td></tr>
<tr><td class=code>--</td><td>Decrement</td></tr>
<tr><td class=code>/</td><td>Division</td></tr>
<tr><td class=code>/=</td><td>Divide assignment</td></tr>
<tr><td class=code>%</td><td>Remainder</td></tr>
<tr><td class=code>%=</td><td>Remainder assignment</td></tr>
<tr><td class=code>*</td><td>Asterisk - either Indirection or multiplication</td></tr>
<tr><td class=code>*=</td><td>Multiply assignment</td></tr>
<tr><td class=code>?</td><td>Question mark</td></tr>
<tr><td class=code>~</td><td>Bit complement</td></tr>
<tr><td class=code>.</td><td>Dot</td></tr>
<tr><td class=code>..</td><td>Range</td></tr>
<tr><td class=code>==</td><td>Equal</td></tr>
<tr><td class=code>===</td><td>Identical</td></tr>
<tr><td class=code>&lt;</td><td>Less than</td></tr>
<tr><td class=code>&lt;=</td><td>Less than or equal</td></tr>
<tr><td class=code>&lt;&gt;</td><td>Less than or greater than</td></tr>
<tr><td class=code>&lt;&gt;=</td><td>Less than, greater than or equal (not a NaN)</td></tr>
<tr><td class=code>&gt;</td><td>Greater than</td></tr>
<tr><td class=code>&gt;=</td><td>Greater than or equal</td></tr>
<tr><td class=code>!</td><td>Logical Not</td></tr>
<tr><td class=code>!=</td><td>Not equal</td></tr>
<tr><td class=code>!==</td><td>Not identical</td></tr>
<tr><td class=code>!&lt;</td><td>Not less than</td></tr>
<tr><td class=code>!&lt;=</td><td>Not less than or equal</td></tr>
<tr><td class=code>!&lt;&gt;</td><td>Not less than or greater than</td></tr>
<tr><td class=code>!&lt;&gt;=</td><td>Not less than, greater than or equal (is a NaN)</td></tr>
<tr><td class=code>!&gt;</td><td>Not greater than</td></tr>
<tr><td class=code>!&gt;=</td><td>Not greater than or equal</td></tr>
<tr><td class=code>[</td><td>Left square bracket</td></tr>
<tr><td class=code>]</td><td>Right square bracket</td></tr>
</table>
<p>
The following tokens may appear in expressions or as punctuation in statements.
<p>
<table>
<thead>
<tr><td>Token</td><td>Description</td></tr>
</thead>
<tr><td class=code>,</td><td>Comma</td></tr>
<tr><td class=code>:</td><td>Colon</td></tr>
<tr><td class=code>(</td><td>Left parenthesis</td></tr>
<tr><td class=code>)</td><td>Right parenthesis</td></tr>
</table>
<p>
The following tokens only appear as punctuation in statements, never in expressions.
<p>
<table>
<thead>
<tr><td>Token</td><td>Description</td></tr>
</thead>
<tr><td class=code>...</td><td>Ellipsis</td></tr>
<tr><td class=code>;</td><td>Semi-colon</td></tr>
<tr><td class=code>{</td><td>Left curly brace</td></tr>
<tr><td class=code>}</td><td>Right curly brace</td></tr>
</table>
