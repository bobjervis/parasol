
<h2>{@level 2 Execution Sequence}</h2>
A Parasol program begins execution with all functions and static and constant objects in existence.
A single process is created that begins executing the program.
<p>
All static initialization code is executed in sequence.
The static initializers within a unit are executed together.
The static initializers across units are executed in a partially determined order.
Units in a package will execute after all units in packages that are used by it.
<p>
After all static initializers have completed, if there is a function named main in the main unit of the
program, that fuction is called.
It is passed the list of command-line arguments according to conventions established by the tools used to
launch the program.
<p>
If at any point during the execution of the static initializers or any main function, the 
{@link parasol:process.exit process exit} is called, 
any unexecuted static initializers will be skipped along with any unexecuted portions of any main function 
in the program.
<p>
After all static initializers have finished, and any main function has completed, or after process exit has
been called, for any static objects that have been constructed and have destructors call those destructors 
in the reverse of the order in which they were constructed.
<p>
