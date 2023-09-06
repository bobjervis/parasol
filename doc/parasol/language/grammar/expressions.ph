<h2>{@level 2 Expressions}</h2>

For an explanation of how types are assigned to expressions, see {@doc-link Types-in-Expressions Type in Expressions}.

<h3>{@level 3 Binary Operations}</h3>

{@grammar}
{@production expression <i>assignment</i> }
{@production | <i>expression</i> <b>,</b> <i>assignment</i> }
{@end-grammar}

<h4>{@level 4 Assignment}</h4>

{@grammar}
{@production assignment <i>conditional</i> }
{@production | <i>assignment</i> <b>=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>:=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>+=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>-=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>*=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>/=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>%=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>&=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>^=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>|=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>&lt;&lt;=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>&gt;&gt;=</b> <i>assignment</i> }
{@production | <i>assignment</i> <b>&gt;&gt;&gt;=</b> <i>assignment</i> }
{@end-grammar}

The left operand of an assignment operator shall be a {@doc-link mod-lvalue modifiable lvalue}.

<h5>{@level 5 Defining Assignment}</h5>

{@anchor def-asg}
The defining assignment operator (<span class=code>:=</span>) combines the declaration of the
left operand with assigning the value of the right operand to the left.

The left operand of a defining assignment shall be an identifier and shall be a definition.

The type of the left operand shall be declared to be the type of the right operand.




{@grammar}
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
{@end-grammar}


<h3>{@level 3 Unary Operations}</h3>

{@grammar}
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
{@production | <b>\0</b> [ <i>octal</i> ] ... }
{@production | <b>\x</b> <i>hex_digit</i> [ <i>hex_digit</i> ] ... }
{@production | <b>\X</b> <i>hex_digit</i> [ <i>hex_digit</i> ] ... }
{@production | <b>\u</b> <i>hex_digit</i> [ <i>hex_digit</i> ] ... }
{@production | <b>\U</b> <i>hex_digit</i> [ <i>hex_digit</i> ] ... }
{@end-grammar}
<p>


