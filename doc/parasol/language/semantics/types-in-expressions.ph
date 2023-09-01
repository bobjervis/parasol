<h2>{@level 2 Types in Expressions}</h2>
{@anchor Types-in-Expressions}

<h3>{@level 3 Void Contexts}</h3>

{@anchor void-context}
A <i>void context</i> is a place in the grammar where an expression appears that is not
evaluated to produce a specific value.
For example, the expression in an {@doc-link expr-stmt expression statement} is a void
context.
<p>
In a void context, the expression can have any type or can have void type.

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
<tr><td><b>=</b> <b>:=</b> <b>+=</b> <b>-=</b> <b>*=</b> <b>/=</b> <b>%=</b> <b>&=</b> <b>^=</b> <b>|=</b> <b>&lt;&lt;=</b> <b>&gt;&gt;=</b> <b>&gt;&gt;&gt;=</b></td><td>right</td><td>The <b>&gt;&gt;&gt;=</b> operator is a shift-assignment in which the left-hand operand does an unsigned right shift in-place, even if the integral type on the left is signed.</td></tr>
</table>
