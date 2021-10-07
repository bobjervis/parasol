
<h2>{@level 2 EXECUTION SEQUENCE}</h2>
A Parasol program begins execution with all functions and static and constant objects in existence.
A single process is created that begins executing the program.
It does so by calling each entry function in turn.
<p>
Entry functions within a single unit are executed in the same order as they appear within the unit.
All entry functions of one unit are executed after all the entry functions of all subordinate units.
When a new process within the same program is spawned, the entry functions are not executed again.
If all of the entry functions return, then the function exit is called with an argument of 0.
<p>
When the last process in a program calls exit, that process calls each of the cleanup functions.
Within a unit, cleanup functions are called in the reverse order in which they appear.
All cleanup functions of a unit are called before any cleanup functions in any subordinate units.
<p>
If entry and cleanup functions exist within a single unit, then each cleanup function will be executed only if any preceding entry function has returned.
If a cleanup function occurs before any entry functions in a unit, it will be executed only if all entry functions in subordinate units have returned. 
<p>
The cleanup functions are called with a single argument that is the exit status passed to the exit function.
The return value of a cleanup function becomes the new exit status and is passed to the next cleanup function.
In this way, cleanup functions can examine the exit status and modify their behavior accordingly.
The exit status returned to the operating system is the exit status returned by the last cleanup function.
<p>
A user program must contain at least one entry function.
<p>
If two units do not subordinate one another, the relative order of execution of entry and cleanup functions in those units is unspecified.
<p>
<b>Example:</b>
<p>
Note: This example uses obsolete syntax.
This should be reviewed and almost certainly corrected.
Do not use this material.

<pre>
  	i:  	int = 0;
   	a:  	entry () =
          	{
          	i = 1;
          	}
 
  	b:  	cleanup (exitcode: int) int =
          	{
          	return exitcode - 1;
          	}
 
  	c:  	entry () =
          	{
          	exit(i);
          	}
 
  	d:  	cleanup (int) int =
          	{
          	return 2;
          	}
</pre>
In this example, function a is executed first, then function c.
Since it calls exit, function d is never called, but function b is.
Therefore, the value passed to b is 1 (the value of i set in a).
The exit code is then changed to 0.