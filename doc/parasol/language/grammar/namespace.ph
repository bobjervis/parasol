<h2>{@level 2 Namespaces}</h2>

{@grammar}
{@production namespace_statement <b>namespace</b> <i>namespace</i> <b>;</b>  }
{@production import <b>import</b> [ <i>identifier</i> <b>=</b> ] <i>qualified_reference</i> <b>;</b> }
{@production namespace <i>domain</i> <b>:</b> <i>dotted_name</i> }
{@production domain <i>dotted_name</i> }
{@production qualified_reference <i>namespace</i> }
{@production | <i>namespace</i> <b>.</b> <i>dotted_name</i> }
{@production dotted_name <i>identifier</i> }
{@production | <i>dotted_name</i> <b>.</b> <i>identifier</i> }
{@end-grammar}

A <i>namespace statement</i> may occur at the file level only.
All objects in the file belong to the named namespace.
<p>
A namespace name consists of a domain followed by a colon followed one or more identifiers separated by dots.
By convention, with a few exceptions for implementation-supplied namespaces, the domain of a namespace is exactly 
an Internet domain name.
Thus, an appropriate namespace domain for interface code to connect Parasol programs 
to the OpenSSL library would be <span class=code>openssl.org</span>.
<p>
The namespace names under a domain can be organized into a hierarchy using dots to separate successive elements of the hierarchy.

<p>
You may import defined names from other namespaces through the <i>import statement</i>.
An import statement always includes a qualified reference to a defined name.
The named entity is either a namespace or a public defined identifier in that namespace.
<p>
The form of a namespace is two sets of identifiers, separated by dots. 
The set of identifiers to the left of the colon is the organization that defined the namespace.
The identifiers to the right of the colon name the namespace with the hierarchy of namespaces that have been defined by that organization.
<p>
The optional identifier and equal sign prefix in an import defines an alternate name for the symbol.
<p>
See the section on [Visibility, Namespaces and Imports]
(https://github.com/bobjervis/parasol/wiki/Scopes-and-Definitions#visibility-namespaces-and-imports)
 for a discussion of how namespaces and import statements interact.

