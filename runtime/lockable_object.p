/*
   Copyright 2015 Robert Jervis

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
 */
namespace parasol:thread;

import parasol:time;
/**
 * This class implemeents a base class capable of coordinating locks such that there are three possible states the object could be in:
 *<ul>
 *    <li>Unlocked. In this state, it is assumed that no read or write operations can be carried out.
 *    <li>Read Locked. In this state, read operations can be carried out and can assume the object's state will not change.
 *    <li>Write Locked. In this state, one thread has established a write lock on the object. That thread only may modify the object
 *		arbitrarily.
 *</ul>
 *
 * The object in this sense can not only include the object derived from LockableObject, but also any private data structures that
 * are associated with the object for the purposes of locking.
 *
 * One could also imagine, such as in a database, LockableObject's for each table and for each row in those tables.
 *
 * {@threading}
 *
 * The correct pattern to use a LockableObject is as follows:
 *
 * To code a task that must modify an object, use the following:
 *
 * {@code
 *        LockableObject object;
 *
 *        object.lockWrite();
 *        try {
 *            <i>Code that modifies the object.</i>
 *        \} finally {
 *            object.releaseWrite();
 *        \}
 * }
 *
 * To code a task that must modify an object, but will time out after some interval use the following:
 *
 * {@code
 *        LockableObject object;
 *        time.Duration timeout;
 *
 *        if (object.lockWrite(timeout)) {
 *            try {
 *                <i>Code that modifies the object.</i>
 *            \} finally {
 *                object.releaseWrite();
 *            \}
 *        else {
 *            // handle timeout errors here
 *        \}
 * }
 *
 * To code a task that must read some part of an object's state:
 *
 * {@code
 *        LockableObject object;
 *
 *        object.lockRead();
 *        try {
 *            <i>Code that reads information from the object.</i>
 *        \} finally {
 *            object.releaseRead();
 *        \}
 * }
 *
 * To code a task that must read some part of an object's state, but will time out:
 *
 * {@code
 *        LockableObject object;
 *        time.Duration timeout;
 *
 *        if (object.lockRead(timeout)) {
 *            try {
 *                <i>Code that reads information from the object.</i>
 *            \} finally {
 *                object.releaseRead();
 *            \}
 *        \}
 * }
 *
 * Nesting locks is entirely possible. 
 * One must use care when nesting locks that every code site that nests locks
 * from two objects A and B must always lock them in the same order.
 * Whether thread locking detects deadlocks is specific to the implementation,
 * so taking locks in different orders has the potential either to deadlock,
 * freezing the deadlocked threads and holding all locked objects (and any other
 * Monitors as well).
 * 
 */
public class LockableObject {
	Monitor queue;
	int writerCount;
	int readerCount;
	ref<Chain> first;		// chain of waiting threads
	ref<Chain> last;
	/**
	 * Lock the object for writing.
	 *
	 * The thread will wait indefinitely for the lock to be established.
	 */
	public void lockWrite() {
		lock (queue) {
			if (writerCount > 1 ||
				readerCount > 0 || first != null) {
				Chain c(LockType.WRITE);

				append(&c);
				wait();
				remove(&c);
			}
			writerCount++;
		}
	}
	/**
	 * Lock the object for writing.
	 *
	 * The thread will wait for some duration for the lock to be established.
	 *
	 * @param timeout The amount of time to wait for the lock to be
	 * established.
	 *
	 * @return true if the lock was set, false otherwise.
	 */
	public boolean lockWrite(time.Duration timeout) {
		lock (queue) {
			if (writerCount > 0 ||
				readerCount > 0 ||
				first != null) {
				Chain c(LockType.WRITE);

				append(&c);
				if (wait(timeout)) 
					remove(&c);
				else {
					remove(&c);
					return false;
				}
			}
			writerCount++;
		}
		return true;
	}

	public void releaseWrite() {
		lock (queue) {
			writerCount--;
			if (first != null)
				notify();
		}
	}
	/**
	 * Lock the object for Reading.
	 *
	 * The thread will wait indefinitely for the lock to be established.
	 */
	public boolean lockRead() {
		return lockRead(time.Duration.infinite);
	}
	/**
	 * Lock the object for Reading.
	 *
	 * The thread will wait some duration for the lock to be established.
	 */
	public boolean lockRead(time.Duration timeout) {
		lock (queue) {
			boolean counted;
			if (writerCount > 0 ||
				first != null) {
				Chain c(LockType.READ);

				append(&c);
				boolean success = wait(timeout);
				if (c.lockType == LockType.READ_COUNTED)
					counted = true;
				else
					remove(&c);
				if (!success)
					return false;
			}
			if (!counted) {
				readerCount++;
				for (ref<Chain> c = first; c != null && c.lockType == LockType.READ; c = c.next) {
					c.lockType = LockType.READ_COUNTED;
					remove(c);
					readerCount++;
					notify();
				}
			}
			return true;
		}
	}

	public void releaseRead() {
		lock (queue) {
			readerCount--;
			if (readerCount == 0 &&
				first != null)
				notify();
		}
	}

	void append(ref<Chain> c) {
		c.previous = last; 
		if (last != null)
			last.next = c;
		else
			first = c;
	}

	void remove(ref<Chain> c) {
		if (c.previous != null)
			c.previous.next = c.next;
		else
			first = c.next;
		if (c.next == null)
			last = c.previous;
	}
}

enum LockType {
	READ,
	READ_COUNTED,		// A READ lock that is found in the queue after
						// s
	WRITE
}

class Chain {
	ref<Chain>	previous;
	ref<Chain> next;
	LockType lockType;

	Chain(LockType lt) {
		lockType = lt;
	}
}

	
