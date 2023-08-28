<h2>{@level 2 Source Structure}</h2>

<h3>{@level 3 Source Files}</h3>

{@grammar}
{@production unit ( <i>statement</i> ) ...}
{@end-grammar}

<p>		
The top-level structure of a Parasol source <i>unit</i> is a sequence of <i>statements</i>.
One possible representation of a unit is as a text source file.
Possible units include inline text that can be compiled and run from within Parasol programs.
<p>
Note that the statements can include executable code expressions as well as declarations with initializers.
<p>
{@anchor static-initializers}
The executable statements in a unit collectively form the <i>static initializers</i> of the unit.
The static-initializers are executed in lexical order within a unit.
<p>
All static-initializers execute on a single thread.
The code being executed can spawn threads to perform initialization tasks or to serve as a daemon
of some kind.

