
<h2>{@level 0 GETTING STARTED}</h2>

<h3> Hello World </h3>

All happy programming language tutorials start the same way, with a program to print the phrase 'Hello World'.
While trivial, it also illustrates the level of effort you will need to do the minimum work in Parasol and you 
should be able to build upon that example.
<p>
In the case of Parasol you need to create a text file named <span class=code>hello.p</span> containing the 
following code:

<pre>
    printf("hello, world\n");
</pre>

Then run the following command in a shell terminal:

<pre>
    pc hello.p
</pre>

It will print the following:

<pre>
    hello, world
</pre>

That's it.
<p>
A Parasol program has one <i>main file</i> that is designated on the command-line.
That file contains at least one statement, but can contain as much code as you like.
<p>
A number of symbols, like <span class=code>printf</span>, are defined for all Parasol source files.
They provide a number of primitive data types, like <span class=code>int</span> for a 32-bit integer 
and a small number of functions like <span class=code>printf</span>.

<h3>Accessing Library Code and System Resources</h3>

You will quickly realize that the built-in symbols give you access to very little 
of the machine resources that you will probably want to manipulate, like files, internet
connections or physical devices.
In addition, you might want to use third-party libraries written in Parasol.
<p>
For those resources, you will need to import symbols.

<h4>Namespaces</h4>

Namespaces group symbols to manage the problem of naming things. 
Modern software development requires that we incorporate dozens of libraries of code
into large applications.
<p>
This allows developers to leverage others' work and build more powerful applications, 
while limiting complexity.
<p>
Most modern languages incorporate some similar concept. C++ uses namespaces, Java uses packages,
Python uses modules and Go uses packages.
<p>
Any Parasol source file that is not a main-file for an application must be assigned to one namespace.
Each namespace is identified by a compound string.
It consists of a <i>domain</i> and a <i>path</i>, separated by a colon character.
<p>
The domain is a string that is intended to be an Internet Domain Name System name.
The string you assign cannot be anything. 
It must be consistent with the domain name syntax of DNS.
<p>
The path of a Parasol namespace is a set of one or more identifiers separated by periods.
Most namespaces use a single identifier, but a hierarchy is formed when mulitple 
identifiers are used in a path.
<p>
For example, the Parasol runtime contains both a <span class=code>math</span> and a 
<span class=code>math.regression</span> namespace.
The <span class=code>math.regression</span> namespace contains a symbol, <span class=code>LinearRegression</span>.
Thus, depending on which symbol exactly you import, you may refer to the same symbol as:

{@code     math.regression.LinearRegression
    regression.LinearRegression
    LinearRegression
}

There are several special reserved namespaces. 
All namespaces in which the domain is a single identifier are reserved to the Parasol language itself.
The following namespace domains are currently used in some Parasl language namespace:

<table>
	<tr><th>Name</th><th>Description</th></tr>
	<tr><td>{@code native}</td><td>
			Namespaces in this domain describe non-Parasol libraries
			that are fundamental to the operation of the Parasol
			language runtime.
			They may be portable libraries, such as the <span class=code>native:C</span> namespace,
			or non-portable libraries, such as the <span class=code>native:linux</span> namespace.
			<p>
			Some Parasol implementations may exclude any or all native namespaces.
			In principle, on a system that has no C compiler, it may be possible to 
			implement a Parasol runtmie on top of another set of facilities entirely
			that collectively support the other Parasol namespace.
		</td></tr>
	<tr><td>{@code parasol}</td><td>
			Namepsaces in this domain describe parts of the Parasol runtime and 
			should be generally available on any Parasol implementation.
		</td></tr>
</table>

<h4>Imports</h4>

C++ and C use the <span class=code>extern</span> declaration to name a symbol that is defined elsewhere.
Parasol, Java, Python and Go use import to do the same thing.
Each language imposes slightly different syntax and rules for these statements. 


