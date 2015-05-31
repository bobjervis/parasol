/*
   Copyright 2015 Rovert Jervis

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
#pragma once
#include "../common/string.h"

template<class A>
class dictionary {
public:
	dictionary() {
		_entries = null;
		clear();
	}

	~dictionary() {
		delete [] _entries;
	}

	A* get(const string& key) {
		return &findEntry(key)->value;
	}

	const A* get(const string& key) const {
		return &findEntry(key)->value;
	}

	bool probe(const string& key) const {
		return findEntry(key)->valid;
	}

	A first() const {
		for (int i = 0; i < _allocatedEntries; i++)
			if (_entries[i].valid)
				return _entries[i].value;
		static A a;
		return a;
	}
	/*
	 *	put
	 *
	 *	This method will add a new entry for the given
	 *	'key' is no entry exists for that key, or replace
	 *	the value if an entry already exists.
	 *
	 *	RETURNS:
	 *		true - if a new entry was created.
	 *		false - an entry already exists, and the value
	 *		was replaced.
	 */
	bool put(const string& key, const A& value) {
		Entry* e = findEntry(key);
		if (!e->valid) {
			if (tooFull()) {
				rehash();
				e = findEntry(key);
			}
			e->valid = true;
			e->key = key;
			e->value = value;
			_entriesCount++;
			return true;
		} else {
			e->value = value;
			return false;
		}
	}
	/*
	 * replace
	 *
	 * Lik eput, except that if the key was already
	 * defined, this method returns the previous value
	 * for the key.  An empty value is returned if the key
	 * was not already defined.  This empty value is the value
	 * constructed by a default constructor for the object,
	 * or zero if it is a scalar type.
	 */
	A replace(const string& key, const A& value) {
		Entry* e = findEntry(key);
		if (!e->valid) {
			static A empty;
			if (tooFull()) {
				rehash();
				e = findEntry(key);
			}
			e->valid = true;
			e->key = key;
			e->value = value;
			_entriesCount++;
			return empty;
		} else {
			A v = e->value;
			e->value = value;
			return v;
		}
	}
	/*
	 *	insert
	 *
	 *	This method will add a new entry for the given
	 *	'key' is no entry exists for that key.  If an entry
	 *	already exists for the key, it is not changed.
	 *
	 *	RETURNS:
	 *		true - if a new entry was created.
	 *		false - an entry already exists, no change to the
	 *		dictionary.
	 */
	bool insert(const string& key, const A& value) {
		Entry* e = findEntry(key);
		if (!e->valid) {
			if (tooFull()) {
				rehash();
				e = findEntry(key);
			}
			e->valid = true;
			e->key = key;
			e->value = value;
			_entriesCount++;
			return true;
		} else
			return false;
	}

	void deleteAll() {
		dictionary<A>::iterator i = begin();
		while (i.hasNext()) {
			delete (*i);
			i.next();
		}
		clear();
	}

	void clear() {
		delete [] _entries;
		_entries = null;
		_entriesCount = 0;
		_allocatedEntries = INITIAL_TABLE_SIZE / 2;
		rehash();
	}

	class iterator {
	public:
		bool hasNext() {
			return _index < _dictionary->_allocatedEntries;
		}

		void next() {
			do
				_index++;
			while (_index < _dictionary->_allocatedEntries &&
				   !_dictionary->_entries[_index].valid);
		}

		A& operator* () {
			return _dictionary->_entries[_index].value;
		}

		const string& key() {
			return _dictionary->_entries[_index].key;
		}

		iterator(const dictionary<A>* dict) {
			_dictionary = dict;
			_index = 0;
		}

		int						_index;
	private:
		const dictionary<A>*	_dictionary;
	};

	iterator begin() const {
		iterator i(this);
		if (_entriesCount == 0)
			i._index = _allocatedEntries;
		else {
			for (i._index = 0; i._index < _allocatedEntries; i._index++) {
				if (_entries[i._index].valid)
					break;
			}
		}
		return i;
	}

	int size() const { return _entriesCount; }

private:
	static const int INITIAL_TABLE_SIZE	= 64;		// must be power of two
	static const int REHASH_SHIFT = 3;				// rehash at ((1 << REHASH_SHIFT) - 1) / (1 << REHASH_SHIFT) keys filled

	struct Entry {
		string	key;
		A		value;
		bool	valid;
	};

	Entry* findEntry(const string& key) {
		int x = key.hashValue() & (_allocatedEntries - 1);
		for(;;) {
			Entry* e = &_entries[x];
			if (!e->valid || e->key == key)
				return e;
			x++;
			if (x >= _allocatedEntries)
				x = 0;
		}
	}

	const Entry* findEntry(const string& key) const {
		int x = key.hashValue() & (_allocatedEntries - 1);
		for(;;) {
			Entry* e = &_entries[x];
			if (!e->valid || e->key == key)
				return e;
			x++;
			if (x >= _allocatedEntries)
				x = 0;
		}
	}

	bool tooFull() {
		return _entriesCount > _rehashThreshold;
	}

	void rehash() {
		Entry* oldE = _entries;
		_allocatedEntries *= 2;
		_entries = new Entry[_allocatedEntries];
		memset(_entries, 0, _allocatedEntries * sizeof (Entry));
		int e = _entriesCount;
		_entriesCount = 0;
		for (int i = 0; e > 0; i++) {
			if (oldE[i].valid) {
				insert(oldE[i].key, oldE[i].value);
				e--;
			}
		}
		_rehashThreshold = (_allocatedEntries * ((1 << REHASH_SHIFT) - 1)) >> REHASH_SHIFT;
		delete [] oldE;
	}

	Entry*		_entries;
	int			_entriesCount;
	int			_allocatedEntries;
	int			_rehashThreshold;
};
