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
{@production looping_statement <b>while (</b> <i>expression</i> <b>)</b> <i>statement</i>  }
{@production | <b>do</b> <i>statement</i> <b>while (</b> <i>expression</i> <b>) ;</b>  }
{@production | <b>for (</b> [ <i>expression</i> ] <b>;</b> [ <i>expression</i> ] <b>;</b> [ <i>expression</i> ] <b>)</b> <i>statement</i>  }
{@production | <b>for (</b> <i>identifier</i> <b>in</b> <i>expression</i> <b>)</b> <i>statement</i>  }
{@production | <b>for (</b> <i>expression identifier</i> <b>=</b> <i>expression</i> <b>;</b> [ <i>expression</i> ] <b>;</b> [ <i>expression</i> ] <b>)</b> <i>statement</i>  }
{@end-grammar}

A <b>for</b> statement using the <b>in</b> syntax variation declares a variable with the name <b>identifier</b> in a special scope that encloses the for statement, just like the multi-part for statement that has a declaration as its first part.
<p>
The expression in a <b>for</b>-<b>in</b> statement names a shape object, either a vector or map.
The statement iterates over all elements of the shaped object.
In each iteration, the variable named in the statement is assigned the index of the next element in the object.

<h3>{@level 3 Try Statements}</h3>

{@grammar}
{@production try_statement <b>try</b> <i>statement</i> [ <i>catch_clause</i> ] ... [ <b>finally</b> <i>statement</i> ] }
{@production catch_clause ( <b>catch (</b> <i>expression</i> <i>identifier</i> <b>)</b> <i>statement</i> ) ... }
{@end-grammar}

