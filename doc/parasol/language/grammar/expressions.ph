<h2>{@level 2 Expressions}</h2>

{@grammar}
{@production expression <i>assignment</i> }
{@production | <i>expression</i> <b>,</b> <i>assignment</i> }
{@production assignment <i>conditional</i> }
{@production | <i>assignment</i> <b>=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>+=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>-=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>*=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>/=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>%=</b>  <i>assignment</i> }
{@production | <i>assignment</i> <b>&=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>^=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>|=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>&lt;&lt;=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>&gt;&gt;=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>&gt;&gt;&gt;=</b> <i>assignment</i> }
{@production conditional <i>binary</i> }
{@production | <i>binary</i> <b>?</b> <i>expression</i> <b>:</b> <i>conditional</i> }
{@production binary <i>unary</i> }
{@production | <i>binary</i> * <i>binary</i> }
{@production | <i>binary</i> <b>/</b> <i>binary</i> }
{@production | <i>binary</i> <b>%</b>  <i>binary</i> }
{@production | <i>binary</i> <b>+</b> <i>binary</i> }
{@production | <i>binary</i> <b>-</b> <i>binary</i> }
{@production | <i>binary</i> <b>&lt;&lt;</b> <i>binary</i> }
{@production | <i>binary</i> <b>&gt;&gt;</b> <i>binary</i> }
{@production | <i>binary</i> <b>&gt;&gt;&gt;</b> <i>binary</i> }
{@production | <i>binary</i> <b>..</b> <i>binary</i> }
{@production | <i>binary</i> <b>==</b> <i>binary</i> }
{@production | <i>binary</i> <b>!=</b> <i>binary</i> }
{@production | <i>binary</i> <b>===</b> <i>binary</i> }
{@production | <i>binary</i> <b>!==</b> <i>binary</i> }
{@production | <i>binary</i> <b>&lt;</b> <i>binary</i> }
{@production | <i>binary</i> <b>&gt;</b> <i>binary</i> }
{@production | <i>binary</i> <b>&gt;=</b> <i>binary</i> }
{@production | <i>binary</i> <b>&lt;=</b> <i>binary</i> }
{@production | <i>binary</i> <b>&lt;&gt;</b> <i>binary</i> }
{@production | <i>binary</i> <b>&lt;&gt;=</b> <i>binary</i> }
{@production | <i>binary</i> <b>!&gt;</b> <i>binary</i> }
{@production | <i>binary</i> <b>!&lt;</b> <i>binary</i> }
{@production | <i>binary</i> <b>!&gt;=</b> <i>binary</i> }
{@production | <i>binary</i> <b>!&lt;=</b> <i>binary</i> }
{@production | <i>binary</i> <b>!&lt;&gt;</b> <i>binary</i> }
{@production | <i>binary</i> <b>!&lt;&gt;=</b> <i>binary</i> }
{@production | <i>binary</i> <b>&</b> <i>binary</i> }
{@production | <i>binary</i> <b>^</b> <i>binary</i> }
{@production | <i>binary</i> <b>|</b> <i>binary</i> }
{@production | <i>binary</i> <b>&&</b> <i>binary</i> }
{@production | <i>binary</i> <b>||</b> <i>binary</i> }
{@production | <i>binary</i> <b>new</b> [ <i>placement</i> ] <i>binary</i> }
{@production | <i>binary</i> <b>delete</b> <i>binary</i> }
{@production unary <i>term</i> }
{@production | <i>reduction</i> }
{@production | <b>+</b> <i>unary</i> }
{@production | <b>-</b> <i>unary</i> }
{@production | <b>~</b> <i>unary</i> }
{@production | <b>&</b> <i>unary</i> }
{@production | <b>!</b> <i>unary</i> }
{@production | <b>++</b> <i>unary</i> }
{@production | <b>--</b><i>unary</i> }
{@production | <b>new</b> [ <i>placement</i> ] <i>unary</i> }
{@production | <b>delete</b> <i>unary</i> }
{@production placement <b>(</b> <i>expression</i> <b>)</b> }
{@production reduction <b>+=</b> <i>unary</i> }
{@end-grammar}

Binary operators obey precedence that is not expressed in the above grammar.
The following table includes each binary operator.
Operators that appear in the same row have the same precedence.
All operators on the same row have the specified associativity.
<p>
For operators that are not found in C, special notes provide some indication of what the operators mean.
<p>
<table class=precedence>
<thead><td>Operator(s)</td><td>Associativity</td><td>Special Notes</td></thead>
<tr><td><b>* /</b> <b>%</b> </td><td>left</td></tr>
<tr><td><b>+</b> <b>-</b></td><td>left</td></tr>
<tr><td><b>&lt;&lt;</b> <b>&gt;&gt;</b> <b>&gt;&gt;&gt;</b></td><td>left</td><td>The <b>&gt;&gt;&gt;</b> operator is an unsigned right shift, regardless of the type of the left hand operand.</td></tr>
<tr><td><b>..</b></td><td>left</td><td>The result of the dot-dot operator is an vector of integers in the specified interval. Operands must have integral type.</td></tr>
<tr><td><b>&lt;</b> <b>&gt;</b> <b>&gt;=</b> <b>&lt;=</b> <b>!&gt;</b> <b>!&lt;</b> <b>!&gt;=</b> <b>!&lt;=</b> <b>&lt;&gt;</b> <b>&lt;&gt;=</b> <b>!&lt;&gt;</b> <b>!&lt;&gt;=</b></td><td>left</td><td>The <b>!</b> (not) variants of each operator means the opposite of the corresponding operator without the exclamation. If either operand is a floating-point NaN, the positive operators report false. If either operand of the not operators is a NaN, then the operator reports true.</td></tr>
<tr><td><b>==</b> <b>!=</b> <b>===</b> <b>!==</b></td><td>left</td><td>The <b>===</b> is identity, for pointer types to distinguish between a class-defined equality and an actual pointer compare. The <b>!==</b> operator is <i>not identical</i>.</td></tr>
<tr><td><b>&</b></td><td>left</td></tr>
<tr><td><b>^</b></td><td>left</td></tr>
<tr><td><b>|</b></td><td>left</td></tr>
<tr><td><b>&&</b></td><td>left</td></tr>
<tr><td><b>||</b></td><td>left</td></tr>
<tr><td><b>new</b> <b>delete</b></td><td>left</td><td>Binary new and delete operators take a type expression and possible constructor as a unary <b>new</b> and <b>delete</b> would, but take a left-hand argument that is a <i>memory allocator</i>.</td></tr>
<tr><td><b>=</b> <b>+=</b> <b>-=</b> <b>*=</b> <b>/=</b> <b>%=</b> <b>&=</b> <b>^=</b> <b>|=</b> <b>&lt;&lt;=</b> <b>&gt;&gt;=</b> <b>&gt;&gt;&gt;=</b></td><td>right</td><td>The <b>&gt;&gt;&gt;=</b> operator is a shift-assignment in which the left-hand operand does an unsigned right shift in-place, even if the integral type on the left is signed.</td></tr>
</table>

For an explanation of how types are assigned to expressions, see:

[Types in Expressions](https://github.com/bobjervis/parasol/wiki/Types-in-Expressions)

<h3>{@level 3 Terms}</h3>

{@grammar}
{@production term <i>atom</i> }
{@production | <i>term</i> <b>++</b> }
{@production | <i>term</i> <b>--</b> }
{@production | <i>term</i> <b>(</b> [ <i>expression</i> [ <b>,</b> <i>expression</i> ] ... ] <b>)</b> }
{@production | <i>term</i> <b>[</b> [ <i>expression</i> ] <b>]</b> }
{@production | <i>term</i> <b>[</b> <i>expression</i> <b>:</b> [ <i>expression</i> ] <b>]</b> }
{@production | <i>term</i> <b>...</b> }
{@production | <i>term</i> <b>.</b> <i>identifier</i> }
{@production | <i>term</i> <b>.</b> <b>bytes</b> }
{@end-grammar}

<h3>{@level 3 Atoms}</h3>

{@grammar}
{@production atom <i>identifier</i> }
{@production | <i>integer</i> }
{@production | <i>character</i> }
{@production | <i>string</i> }
{@production | <i>floating_point</i> }
{@production | <b>this</b> }
{@production | <b>super</b> }
{@production | <b>true</b> }
{@production | <b>false</b> }
{@production | <b>null</b> }
{@production | <b>(</b> <i>expression</i> <b>)</b> }
{@production | <b>[</b> [ <i>value_initializer</i> [ <b>,</b> <i>value_initializer</i> ] ... [ <b>,</b> ] ] <b>]</b> }
{@production | <b>&lbrace;</b> [ <i>value_initializer</i> [ <b>,</b> <i>value_initializer</i> ] ... [ <b>,</b> ] ] <b>&rbrace;</b>  }
{@production | <b>class</b> <i>class_body</i> }
{@production | <b>function</b> <i>term</i> [ <i>block</i> ] }
{@production value_initializer	  [ <i>assignment</i> <b>:</b> ] <i>assignment</i> }
{@production identifier <i>identifier_initial</i> [ <i>identifier-following</i> ] ... }
{@production identifier_initial <b>_</b> }
{@production | any Unicode letter }
{@production identifier-following <b>_</b> }
{@production | any Unicode letter }
{@production | any Unicode digit }
{@production integer <i>nonzero</i> [ <i>digit</i> ] ... }
{@production | <i>zero</i> [ <i>octal</i> ] ... }
{@production | <i>zero</i> <b>x</b> <i>hex_digit</i> [ <i>hex_digit</i> ] ... }
{@production nonzero <b>1</b> | <b>2</b> | <b>3</b> | <b>4</b> | <b>5</b> | <b>6</b> | <b>7</b> | <b>8</b> | <b>9</b> }
{@production | any non-zero Unicode digit }
{@production zero <b>0</b> }
{@production | any Unicode zero digit }
{@production digit <i>nonzero</i> }
{@production | <i>zero</i> }
{@production octal <b>0</b> | <b>1</b> | <b>2</b> | <b>3</b> | <b>4</b> | <b>5</b> | <b>6</b> | <b>7</b> }
{@production | any Unicode digit less than 8 in value }
{@production hex_digit <i>digit</i> }
{@production | <b>a</b> | <b>b</b> | <b>c</b> | <b>d</b> | <b>e</b> | <b>f</b> | <b>A</b> | <b>B</b> | <b>C</b> | <b>D</b> | <b>E</b> | <b>F</b> }
{@production character <b>'</b> any character <b>'</b> }
{@production | <b>'</b> <i>escape</i> <b>'</b> }
{@production string <b>"</b> [ any character | <i>escape</i> ] ... <b>"</b> }
{@production escape <b>\a</b> }
{@production | <b>\b</b> }
{@production | <b>\f</b> }
{@production | <b>\n</b> }
{@production | <b>\r</b> }
{@production | <b>\t</b> }
{@production | <b>\v</b> }
{@production | <b>\\</b> }
{@production | <b>\0</b> <i>octal</i> }
{@production | <b>\x</b> <i>hex_digit</i> [ <i>hex_digit</i> ] ... }
{@production | <b>\X</b> <i>hex_digit</i> [ <i>hex_digit</i> ] ... }
{@production | <b>\u</b> <i>hex_digit</i> [ <i>hex_digit</i> ] ... }
{@production | <b>\U</b> <i>hex_digit</i> [ <i>hex_digit</i> ] ... }
{@end-grammar}
<p>


