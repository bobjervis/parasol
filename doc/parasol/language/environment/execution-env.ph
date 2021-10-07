
<h2>{@level 2 EXECUTION ENVIRONMENT}</h2>
A Parasol program initially consists of a set of objects and functions.
The program is started with a single process running in its arena.
Additional processes can be created in the arena and managed during the execution of the program.
<p> 
A program under Parasol is a collection of units which contain functions and objects.
If one unit imports another, the latter is considered to be subordinate to the former.
Units can import each other, either directly or indirectly through any number of other units.
<p>
Execution of a program is conducted by one or more processes.
Each process shares static and heap objects and functions.
Even automatic objects of one process can be accessed by another process (using a pointer).
<p>
In addition to processes spawned by the program being executed, other processes may be at work outside the program’s arena.
<p>
Each process executes operations sequentially, one operation at a time.
The normal flow of control of a process can be changed via calls, returns, conditional branches
and exceptions given in the definition of the function being executed.
The flow of control can also be changed by interrupts.
An exception is generated as a result of executing an operation, while an interrupt is caused by an event outside the process.