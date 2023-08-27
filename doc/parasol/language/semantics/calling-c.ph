<h2>{@level 2 Calling C Code}</h2>

Parasol supports a relatively robust mechanism for interacting with C code libraries.
A number of C types have directly equivalent Parasol types.
Parasol does not have a link step, so you cannot call C code in a static-linked library.
You can, however, call a Linux shared-object or Windows dynamic-linked library.
<p>
Parasol can call C++ functions that are declared as extern "C".
It is not possible to call methods on C++ classes.
<p>
Parasol does not support calling C functions that take a variable number of arguments.
<p>
At present, Parasol cannot directly refer to C global variables.

<h3>{@level 3 Declaring a C Function}</h3>

In order to call C code, you must have a Parasol declaration of the C function you wish to call.
C functions must be declared at unit scope using the abstract type qualifier, even though the 
declaration is not inside a class.
You must also annotate the declaration with the name of the dynamic library and how the name 
is spelled in that library.
<p>
For example, if you wanted to call the C abs function, you would need a declaration such as:

{@code
    @Windows("msvcrt.dll", "abs")
    @Linux("libc.so.6", "abs")
    public abstract int abs(int value);
}

You may declare any number of C functions from any number of different libraries.
Any that you do not call from your Parasol code will not load the library named in the annotation.
Note that you will have to be sure that the named library in any function you do call is in 
your LD_LIBRARY_PATH for Linux programs.

Typically, Parasol code will declare all external C code for any platform that the program might be 
run on, but will use conditional code to control whether, for example, the Linux or the Windows functions
will actually be called.

<h3>{@level 3 Type Compatibility}<h3>

