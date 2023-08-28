<h2>{@level 2 Declarations}</h2>

{@grammar}
{@production declaration [ <i>visibility</i> ] <i>entity_declaration</i>}
{@production entity_declaration [ <b>static</b> ] <i>object_declaration</i>  }
{@production | [ <i>qualifiers</i> ... ] <i>class_declaration</i> }  
{@production | [ <i>qualifiers</i> ... ] <i>enum_declaration</i>  }
{@production | <i>flags_declararion</i>  }
{@production | [ <b>static</b> ] <i>function_declaration</i>  }
{@production | <i>abstract_function_declaration</i>  }
{@production | <i>constructor</i>  }
{@production | <i>destructor</i>  }
{@production qualifiers <b>final</b>}
{@production | <b>static</b>}
{@end-grammar}

A <i>declaration</i> is executable if it contains an initializer other than a simple identifier, or an initializer
with a simple identifier declared with a type that has a default constructor. 

Any static object declaration that is executable may appear in a block or function. Such executable statements
will be part of the {@doc-link static-initializers static intitializers} for the enclosing unit.

A <i>declaration</i> of a class, an enum type, a flags type, any function, constructor or destructor is not
an executable statement.


<h3>{@level 3 Visibility}</h3>

{@grammar}
{@production visibility <b>public</b> }
{@production | <b>private</b> }
{@production | <b>protected</b> }
{@end-grammar}

If a visibility specifier appears at the beginning of a declaration, then all identifiers defined by that declaration
share that visibility.

<h3>{@level 3 Object Declarations}</h3>

{@grammar}
{@production object_declaration <i>expression initializer</i> [ <b>,</b> <i>initializer</i> ] ... <b>;</b> }
{@production initializer <i>identifier</i>}
{@production | <i>identifier</i> <b>=</b> <i>expression</i>}
{@production | <i>identifier</i> <b>(</b> <i>argument_list</i> <b>)</b> }
{@end-grammar}

An object declaration defines one or more object instances.
Each initializer defines an identifier (and optionally includes an initial value).
The initial expression declares the type of each initializer identifier.
<p>
An object declaration of an identifier with an argument list is an invocation of a constructor.

<h3>{@level 3 Classes}</h3>

{@grammar}
{@production class_declaration <i>class_core_declaration</i> }
{@production class_core_declaration <b>class</b> <i>identifier class_body</i> }
{@production | <b>class</b> <i>identifier</i> [ <b>=</b> <i>expression</i> ] <b>;</b> }
{@production class_body [ <i>template</i> ] [ <i>base</i> ] [ <i>implements_list</i> ] <i>block</i> }
{@production template <b>&lt;</b> [ <i>parameter</i> [ <b>,</b> <i>parameter</i> ] ... ] <b>&gt;</b> }
{@production base <b>extends</b> <i>expression</i> }
{@production implements_list <b>implements</b> <i>expression</i> [ <b>,</b> <i>expression</i> ] ...}
{@end-grammar}

A class declaration defines the identifier as a class name.
The class body includes whether the class is a template class (if the template part is included), 
has a base class (if the base part is included) or implements any interfaces (if the interfaces list is included).
The block defines the contents of the class, both members and methods.
<p>
A simple class declaration that uses an initializer expression does not declare a new type.
Instead the declared identifier has <i>the same class</i> as the initializer expression.
<p>
A class declaration with neither a class body nor an initializer is a class-valued variable object.
Currently, this form of declaration is not well supported.
Eventually, when the symbol table is fully generated at run-time, objects of this type will appear in the symbol table information.
<p>
In addition, at some future date, a class object such as this can be used in a manner similar to a <b>var</b> object.
Essentially, this will expand the ways in which dynamic code can be generated.
It may well be possible to produce better code than <b>var</b> variables might, because the code can be generated <i>at the time of processing</i> when the precise class value is known.

<h3>{@level 3 Monitors}</h3>

{@grammar}
{@production monitor_declaration <b>monitor</b> <i>identifier</i> <i>block</i> }
{@production | <b>monitor</b> <i>identifier</i> <b>;</b> }
{@end-grammar}

A monitor declaration defines the identifier of a monitor object.
The optional block may contain declarations of any number of contained member objects.
A monitor object may be locked by using a <b>lock</b> statement that designates a monitor object.
Once locked, the code within the body of the <b>lock</b> statement may reference the members of the monitor.
In addition, there are methods on the monitor object itself that can be used to provide a variety of thread synchronization mechanisms.

<h3>{@level 3 Enums}</h3>

{@grammar}
{@production enum_declaration <b>enum</b> <i>identifier</i> <b>&lbrace;</b> <i>enum_body</i> <b>&rbrace;</b> }
{@production enum_body <i>enum</i> [ <b>,</b> <i>enum</i> ] ... [ <b>,</b> ] [ <b>;</b> [ statement ] ... ]}
{@production enum <i>identifier</i> [ <i>parameter_list</i> ]}
{@end-grammar}
			
An enum declaration defines the identifier of an enum class.
If an enumeration declaration includes statements after the list of enumerated values, those statements define the members and methods of the enum class.

<h3>{@level 3 Flags}</h3>

{@grammar}
{@production flags_declaration <b>flags</b> <i>identifier</i> [ <i>base</i> ] <b>&lbrace;</b> [ <i>flag</i> [ <b>,</b> <i>flag</i> ] ... ] [ <b>,</b> ] <b>&rbrace;</b> }
{@production flag <i>identifier</i>}
{@end-grammar}

A flags declaration defines the identifier of a flags class.
The list of flag values are each assigned one bit, up to 64 in number.
<p>
Each instance of a flags class contains enough bits to hold all the defined flags for the class.

<h3>{@level 3 Function Definitions}</h3>

{@grammar}
{@production function_declaration <i>return_list name parameter_list function_body</i>}
{@production return_list <b>void</b>}
{@production | <i>expression</i> [ <b>,</b> <i>expression</i> ] ...}
{@production parameter_list <b>(</b> [ <i>parameter</i> [ <b>,</b> <i>parameter</i> ] ... ] <b>)</b> }
{@production parameter <i>expression</i> [ <b>...</b> ] <i>identifier</i> }
{@production function_body <i>block</i> }
{@production | <b>;</b>}
{@end-grammar}

A function declaration defines the name of a function and provides the specification of the return values, if any, 
the parameters for that function as well as the function implementation.
<p>
Note that if a function declaration has a semi-colon instead of a block as the function body, that declaration is a function object.
Unlike a function supplied with a block body at compile time, a function object can be modified at runtime.
When a function object is called, the function whose value was most recently assigned to the object is called.
<p>
Only the last parameter in a parameter list may include an ellipsis (<b>...</b>). That parameter is defined as a <i>variable argument list</i> parameter.
The type of the parameter is a vector of the type declared in the expression preceding the ellipsis.
Thus, the following:

{@code     void func(int... a) &lbrace;
    &rbrace;
}

The type of <span class=code>a</span> is vector of int.
<p>
All references to a variable argument list parameter inside the function behave exactly the same as if the parameter had been declared as a vector.
<p>
Calls to a function declared with a variable argument list parameter may pass an appropriately typed vector expression 
to that parameter as if it had been declared as an array object. 
Such a function may be called with a list that includes zero or more arguments in the final position, 
each of which can be coerced to the element type of the variable argument list parameter.


<h4>{@level 4 Abstract Functions}</h4>

{@grammar}
{@production abstract_function_declaration <b>abstract</b> <i>return_list name parameter_list</i> <b>;</b> }
{@end-grammar}

By including the keyword <b>abstract</b> in a function declaration makes an abstract function declaration.
In this form, there is no function body provided.

<h4>{@level 4 Constructors}</h4>

{@grammar}
{@production constructor <i>class_name parameter_list block</i> }
{@end-grammar}

A function declared with just the enclosing class name (and no return type expression) is a constructor.

<h4>{@level 4 Destructors}</h4>

{@grammar}
{@production destructor <b>~</b> <i>class_name</i> <b>()</b> <i>block</i> }
{@end-grammar}

A function declared with the enclosing class name preceded by a tilde token is a destructor.
Note that destructor must be declared with no parameters in the parameter list.

