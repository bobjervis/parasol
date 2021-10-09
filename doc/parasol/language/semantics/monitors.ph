<h2>{@level 2 Monitors}</h2>

A monitor is a synchronization primitive (see the 
<a href="https://en.wikipedia.org/wiki/Monitor_(synchronization)">Wikipedia article</a>) first developed in the early 1970's that is quite versatile. 
Java synchronized blocks combined with the wait and notify methods provide essentially monitor semantics.
Parasol makes monitors a little more explicit than Java does, and adds some extra capabilities.
<p>
A Parasol monitor is a special form of class with three discrete capabilities:
<ul>
	<li>Thread exclusion. 
	The <span class=code>lock</span> statement ensures that a given block of code can only be executed by one thread at a time.
	This makes it relatively easy to ensure that modifications to shared data are carried out in a predictable and atomic manner.
	<li>Semaphores. 
	The <span class=code>wait()</span> and <span class=code>notify()</span> primitives allow threads to wait for resources to 
	become available without wasting time repeatedly testing conditions.
	<li>Protected members. 
	A monitor can be declared with embedded members. 
	These member objects can only be accessed from within a <span class=code>lock</span> statement. 
	This exceeds Java in that there is no way to formally associate any data objects with a specific synchronized block in Java. 
	Many synchronization patterns involve locking one or more data objects under the protection of a specific lock. 
	In Parasol, this is expressed by declaring the protected objects within the monitor that protects them.
</ul>

<h3>{@level 3 Monitor Declarations}</h3>

A globally defined class named <span class=code>Monitor</span> implements the synchronization primitives of the wait and notify 
methods as well as the support for the lock statement itself.
<p>
You can declare objects of type Monitor or dynamically allocate one using a <b>new</b> expression. 
It is an object like any other.
<p>
You may also declare a special kind of class called a <i>monitor class</i>.
A monitor class declaration has the same syntax as a normal class declaration except that the 
keyword <span class=code>monitor</span> appears immediately before the <span class=code>class</span> keyowrd.
<p>
Example:

{@code
    monitor class F &lbrace;
        int m;
    &rbrace;
}
<p>
A monitor class declaration declares a class, not an object.
A monitor class may extend another class or implement any number of interfaces.
There are limitations on the classes that a monitor class can extend.
<p>
The following declarations are equivalent:
<p>
{@code
    monitor class M &lbrace; ... &rbrace;
}
<p>
and
<p>
{@code
    monitor class M extends Monitor &lbrace; ... &rbrace;
}
<p>
In other words, a monitor class has an implied base class of Monitor.
A monitor class may extend another class T only if T <= Monitor.
<p>
Member objects declared inside a monitor class are _guarded_ by that monitor.
Member objects of a monitor class may only be accessed inside a lock statement for that monitor.
<p>
Methods in a monitor class may be called from anywhere that the method is visible.
Calling a monitor method from outside a lock of that monitor implicitly locks the monitor for the duration of the method call.
<p>
You do not have to use members.
If you declare a monitor without any contents at all, you may still synchronize methods using <span class=code>lock</span>
statements and even <span class=code>wait</span> or <span class=code>notify</span> methods..
<p>
The following declarations are equivalent:
<p>
{@code
    monitor class M &lbrace;
    &rbrace;
    M mon;`
}
<p>
and
<p>
{@code
    Monitor mon;
}

<h3>{@level 3 Common Methods}</h3>

In the formal semantics of Parasol, an implementation must define the following methods for each monitor:
<ul>
	<li><span class=code>void notify()</span>
	<li><span class=code>void notifyAll()</span>
	<li><span class=code>void wait()</span>
	<li><span class=code>void wait(long timeout)</span>
	<li><span class=code>void wait(long timeout, int nanos)</span>
</ul>

<h3>{@level 3 Lock Statements}</h3>

Lock statements in Parasol are very similar to <b>synchronized</b> statements in Java.
Both limit one thread at a time to enter the body of the statement.
However, where Java allows you to name any Java object in the <b>synchronized</b> expression, Parasol requires that you name a <span class=code>Monitor</span> object there instead.
<p>
Since locks are never common relative to objects (at least in any reasonable program), Java does not allocate storage for lock references in each object.
Instead it uses some variation of a lookup to find the associated lock, if any, for an object and creates one as needed.
Thus, Java trades time for space.
<p>
Parasol, by forcing you to create and name the monitors you are going to use, avoids this trade-off at runtime.
This should not be an excessive burden.
It also avoids possible confusion since you cannot accidentally lock a random wrong object.
<p>
Parasol, like Java, guarantees that no matter how a thread leaves a locked block, the lock will be released.
So, returning, breaking or continuing from inside a lock statement will all release locks as needed.
Similarly, if an exception is thrown from inside a lock statement and caught outside, the lock will be released.

<h3>{@level 3 Anonymous Locks}</h3>

<i><b>This feature is not yet implemented. Using an anonymous lock will trigger an assertion failure in the compiler.</b></i>
<p>
You may write a lock statement that does not name a monitor. For example, the following statement is valid:
<p>
{@code
    lock &lbrace;
        logFile.write("Some text");
    &rbrace;
}
<p>
In this case, the call to logFile.write will occur atomically with respect to other threads in the same process. In effect, a hidden monitor is used that is unique to this statement. 
If more than one anonymous lock statement occurs in a program, each lock is independent of all others. 
If you wish to coordinate multiple patches of code you must use a named monitor to do so.
<p>
You may not call monitor methods inside an anonymous lock statement.

<h3>{@level 3 Monitor Methods}</h3>

You may declare methods inside a monitor.
Unlike monitor member objects, monitor methods may be declared with public or private visibility (or left anonymous).
Unlike monitor member objects, public or namespace-private methods may be called from either within a lock statement or outside any lock statement.
<p>
Monitor methods called from outside a lock statement will automatically lock the monitor.
All monitor methods behave as if their outermost block had a lock statement as in:
<p>
{@code
    monitor class a &lbrace;
        public int foo() &lbrace;
        &rbrace;
    &rbrace;
}
<p>
is equivalent to
<p>
{@code
    monitor class a &lbrace;
        public int foo() lock(*this) &lbrace;
        &rbrace;
    &rbrace;
}`

<h3>{@level 3 Use of <b>this</b> and <b>super</b>}</h3>

You may use both <span class=code>this</span> and <span class=code>super</span> inside a monitor method exactly as if the method were defined in a class.
<p>
The <span class=coe>this</span> keyword refers to the instance of the monitor enclosing the method itself.
It has <span class=code>ref&lt;&gt;</span> type, so since lock statements require an expression of a monitor type, 
you will need an indirection operator (<span class=code>*</span>).
<p>
The <span class=code>super</span> keyword is provided so that if you override the definition of any of the common methods (e.g. <span class=code>notify</span>), 
you can still call the base-method.

