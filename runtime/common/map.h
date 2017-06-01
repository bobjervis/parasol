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
#pragma once
#ifdef MSVC
#include <crtdefs.h>
#endif
#include <stddef.h>

#define null 0

template<class A, class B>
class map {
public:
	map() {
		_entries = null;
		clear();
	}

	~map() {
		delete [] _entries;
	}

	B* get(A* key) {
		return &findEntry(key)->value;
	}

	const B* get(A* key) const {
		return &findEntry(key)->value;
	}

	bool probe(A* key) const {
		return findEntry(key)->valid;
	}
	/*
	 *	insert
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
	bool put(A* key, const B& value) {
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
	bool insert(A* key, const B& value) {
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
		for (map<A, B>::iterator i = begin(); i.valid(); i.next())
			delete (*i);
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
		bool valid() {
			return _index < _map->_allocatedEntries;
		}

		void next() {
			do
				_index++;
			while (_index < _map->_allocatedEntries &&
				   !_map->_entries[_index].valid);
		}

		B& operator* () {
			return _map->_entries[_index].value;
		}

		A* key() {
			return _map->_entries[_index].key;
		}

		iterator(const map<A, B>* m) {
			_map = m;
			_index = 0;
		}

		int					_index;
	private:
		const map<A, B>*	_map;
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
		A*		key;
		B		value;
		bool	valid;
	};

	Entry* findEntry(A* key) {
		int x = (((ptrdiff_t)key) >> 4) & (_allocatedEntries - 1);
		int startx = x;
		for(;;) {
			Entry* e = &_entries[x];
			if (!e->valid || e->key == key)
				return e;
			x++;
			if (x >= _allocatedEntries)
				x = 0;
		};
	}

	const Entry* findEntry(A* key) const {
		int x = (((ptrdiff_t)key) >> 4) & (_allocatedEntries - 1);
		int startx = x;
		for(;;) {
			Entry* e = &_entries[x];
			if (!e->valid || e->key == key)
				return e;
			x++;
			if (x >= _allocatedEntries)
				x = 0;
		};
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
