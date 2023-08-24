
<h2>{@level 2 Terms, Definitions and Symbols}</h2>
For the purposes of this reference, the following definitions apply.
Other terms are defined where they appear in italic text or on the left side of a syntax rule.
Terms explicitly defined in this document do not refer implicitly to similar terms defined elsewhere.

<h3>{@anchor access}{@level 3 access}</h3>

To read or modify the value of an object.
Where only one of these actions is meant, “read” or “modify” is used.
“Modify” includes the case where the new value is equal to the old.
Expressions that are not evaluated do not access objects.

<h3>{@anchor lvalue}{@level 3 lvalue}</h3>

An <i>lvalue</i> is an expression with an object type.
If an lvalue does not designate an object when it is evaluated, the behavior is undefined.
When an object is said to have a particular type, the type is specified by the lvalue used
to designate the object.
{@anchor mod-lvalue}
A <i>modifiable lvalue</i> is an lvalue that is not annotated as a constant, and if it is a class 
instance, has either a copy constructor or an assignment method and where all members are declared as 
modifiable lvalues.

