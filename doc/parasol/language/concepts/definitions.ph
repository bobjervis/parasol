<h3>{@level 3 Definitions}</h3>

An identifier can denote an object, a class, a function, a member of a class or a namespace.
The same identifier can denote different entities at different points in the program.
Except for in namespace names, each identifier that appears in a valid Parasol program will have at least one appearance where it is a 
<i>definition</i>.
In namespace names, the full string of identifiers and punctuation name a namespace, but none of those 
identifiers constitutes a definition.
<p>
Whether an instance of an identifier is a definition is determined by context from the grammatical position
in which it appears.

<h4>{@level 4 In For-in Loops}</h4>

The initial identifier in a {@doc-link for-in for-in loop} is a definition.
The entity defined is an object that has the element type of the shaped type of the expression following 
the keyword <b>in</b>.

<h4>{@level 4 In Catch Clauses}</h4>

The identifier following the initial expression in a catch clause of a {@doc-link try-stmt try statement}
is a definition.
The entity defined is an object that has type Exception or some type derived from Exception.

<h4>{@level 4 In Object Declarations}</h4>

The initial identifier in each initializer that appears in an {@doc-link obj-decl object declaration} is
a definition.
The entity defined depends on context. 
In the body of a class but outside a member function of the class, an object declaration defines a class member.
Otherwise, an object declaration defines one or more objects that have the type of the 
initial expression in the object declaration.

<h4>{@level 4 In Class Declarations}</h4>

The identifier immediately after the <b>class</b> keyword in a {@doc-link class-decl class declaration} 
is a definition.
The entity defined is a class.

<h4>{@level 4 In Enumerations}</h4>

The identifier immediately after the <b>enum</b> keyword is an {@doc-link enum-decl enumeration declaration}
is a definition.
The entity defined is a class.

Each initial identifier in the {@doc-link enum-inst enumeration instances} is a definition.
The entity defined is an object with the type of the enumeration in which it is located.

<h4>{@level 4 In Flags}</h4>

The identifier immediately after the <b>flags</b> keyword is an {@doc-link flags-decl flags declaration}
is a definition.
The entity defined is a class.

Each initial identifier in the {@doc-link flags-inst flags instances} is a definition.
The entity defined is an object with the type of the flags class in whic it is located.

<h4>{@level 4 In Function Definitions}</h4>

The function name identifier in a {@doc-link func-def function definition} is a definition.
The entity defined is a function with a type consisting of the return types included in the return list
and parameter types included in the parameter list.

Each trailing identifier in the {@doc-link func-param function parameters} is a definition.
The entity defined is an object with the type of the expression in the parameter containing the identifier.

<h4>{@level 4 In Defining Assignments}</h4>

The left operand, which is an identifier, of a {@doc-link def-asg defining assignment} operator is a
definition.
The entity defined is an object with the type of the right operand.



