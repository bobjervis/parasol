<h2>{@level 2 Control Flow}</h2>

{@grammar}
{@production control_flow_statement <i>if_statement</i> }
{@production | <i>switch_statement</i> }
{@production | <i>looping_statement</i> }
{@production | <b>break ;</b>  }
{@production | <b>continue ;</b>  }
{@production | <b>return</b> [ <i>expression</i> ] <b>;</b>  }
{@production | <b>throw</b> <i>expression</i> <b>;</b>  }
{@production | <i>try_statement</i> }
{@end-grammar}

<h3>{@level 3 If Statements}</h3>

{@grammar}
{@production if_statement <b>if (</b> <i>expression</i> <b>)</b> <i>statement</i> [ <b>else</b> <i>statement</i> ] }
{@end-grammar}

An if statement provides a test expression.
If the expression evaluates to true, the first statement is performed.
If false, then any else statement that is supplied is performed instead.

<h3>{@level 3 Switch Statements}</h3>

{@grammar}
{@production switch_statement <b>switch (</b> <i>expression</i> <b>)</b> <i>statement</i>  }
{@production | <b>case</b> <i>expression</i> <b>:</b> <i>statement</i>  }
{@production | <b>default :</b> <i>statement</i>  }
{@end-grammar}

A switch statement evaluates the control expression which must have integral, string or enum type.
The statement following the controlling expression generally includes one or more case and default statements.
<p>
When evaluated, control transfers to the case statement whose expression value matches that of the switch.
If no case values match, control is transferred to any default statement in the switch.
<p>
If no default case exists and the control expression value does not match any case values, then control is transferred to the statement after the switch.

<h3>{@level 3 Looping Statements}</h3>

{@grammar}
{@production looping_statement <i>while_statement</i> }
{@production | <i>do_statement</i> }
{@production | <i>simple_for_statement</i> }
{@production | <i>scoped_for_statement</i> }
{@production | <i>for_in_statement</i> }
{@end-grammar}

<h4>{@level 4 While Loops}</h4>

{@grammar}
{@production while_statement <b>while (</b> <i>expression</i> <b>)</b> <i>statement</i>  }
{@end-grammar}

The expression of a while statement shall have boolean type. The expression is evaluated  
at the beginning of each loop. If the expression value is true, then the statement is executed.
Once complete, the loop resumes at the top, re-evaluating the expression until it evaluates to false.

<h4>{@level 4 Do-while Loops}</h4>

{@grammar}
{@production do_statement <b>do</b> <i>statement</i> <b>while (</b> <i>expression</i> <b>) ;</b>  }
{@end-grammar}

The expression of a do-while statement shall have boolean type.
The body statement of the do-while loop is executed.
Once complete the expression is evaluated and if it's value is true control returns 
to the body of the loop.

<h4>{@level 4 Simple For Loops}</h4>

{@grammar}
{@production simple_for_statement <b>for (</b> [ <i>expression</i> ] <b>;</b> [ <i>expression</i> ] <b>;</b> [ <i>expression</i> ] <b>)</b> <i>statement</i>  }
{@end-grammar}

The simple for loop consists of up to three expressions and a statement as the loop body.

<ul>
	<li> The first expression, if present, is evaluated once before any other part of the statement.
		The first expression is evaluated in a {@doc-link void-context void context}.
	<li> The second expression, if present, shall have boolean type.
		The second expression, if present, is evaluated immediately after the first expression, and then again at the
		beginning of each iteration.
		If the value is true, control transfers to the statement that is the body of the loop.
		If the value is false, control transfers to the next statement after this one.
		<br>
		If the second expression is absent, the loop is unconditionally executed on each iteration.
	<li> The third expression, if present, is evaluated after the body of the loop.
		The third expression is evaluated in a {@doc-link void-context void context}.
	<li> If control reaches this point in the loop, control transfers back to the top.
</ul>

This form of for-loop does not introduce a new lexical scope. If the expressions of a simple for loop 
contain {@doc-link def-assign defining assigment} operations, the scope of these declarations are the scope
enclosing the for statement.

<h4>{@level 4 Scoped For Loops}</h4>

{@grammar}
{@production scoped_for_statement <b>for (</b> <i>object_declaration</i> [ <i>expression</i> ] <b>;</b> [ <i>expression</i> ] <b>)</b> <i>statement</i>  }
{@end-grammar}

The scoped for statement has an object declaration, an optional test expression, an optional increment expression
and a statement as the loop body.

<ul>
	<li> If the object declaration has an initializer or constructor call, that is evaluated once before any other 
		part of the statement.
	<li> The second expression, if present, shall have boolean type.
		The second expression, if present, is evaluated immediately after the object declaration, and then again at the
		beginning of each iteration.
		If the value is true, control transfers to the statement that is the body of the loop.
		If the value is false, control transfers to the next statement after this one.
		<br>
		If the second expression is absent, the loop is unconditionally executed on each iteration.
	<li> The third expression, if present, is evaluated after the body of the loop.
		The third expression is evaluated in a {@doc-link void-context void context}.
	<li> If control reaches this point in the loop, control transfers back to the top.
</ul>

This form of for-loop introduces a new lexical scope. Any identifiers declared in the object declaration
of the loop, or if any expressions outside the loop body contain {@doc-link def-assign defining assigment} operations,
the scope of these declarations extends through the scoped for statement itself.

<h4>{@level 4 For-in Loops}</h4>

{@anchor for-in}
{@grammar}
{@production for_in_statement <b>for (</b> <i>identifier</i> <b>in</b> <i>expression</i> <b>)</b> <i>statement</i>  }
{@end-grammar}

The for-in statement includes an identifier, an expression and a statement as the loop body.
<p>
The identifier is a definition.
It's type is the element type of the expression's type.
<p>
The expression shall have {@doc-link shape shaped class}.

The expression in a <b>for</b>-<b>in</b> statement names a shape object, either a vector or map.
The statement iterates over all elements of the shaped object.
In each iteration, the variable named in the statement is assigned the index of the next element in the object.

<h3>{@level 3 Try Statements}</h3>

{@anchor try-stmt}
{@grammar}
{@production try_statement <b>try</b> <i>statement</i> [ <i>catch_clause</i> ] ... [ <b>finally</b> <i>statement</i> ] }
{@production catch_clause ( <b>catch (</b> <i>expression</i> <i>identifier</i> <b>)</b> <i>statement</i> ) ... }
{@end-grammar}

