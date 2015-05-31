#pragma once
#define null 0

class BaseEvent_ {
public:
	void removeHandler(void* h) {
		if (h == null)
			return;
		if (handlers == null)
			return;
		if (h == handlers)
			handlers = handlers->next;
		else {
			for (BaseHandler_* hh = handlers; ; hh = hh->next) {
				if (hh->next == null)
					return;
				if (hh->next == h) {
					hh->next = hh->next->next;
					break;
				}
			}
		}
		if (!((BaseHandler_*)h)->busy)
			delete h;
		else
			((BaseHandler_*)h)->removed = true;
	}

	void removeHandlers() {
		while (handlers)
			removeHandler(handlers);
	}

	bool has_listeners() { return handlers != 0; }

protected:
	BaseEvent_() {
		handlers = null;
	}

	~BaseEvent_() {
		while (handlers)
			removeHandler(handlers);
	}

	struct BaseHandler_ {
		virtual ~BaseHandler_() { }

		BaseHandler_*	next;
		bool			busy;				// busy is true whenever the handler function is being called
		bool			removed;			// removed is true whenever the handler was removed while busy
	};

	void* append(BaseHandler_* h) {
		h->busy = false;
		h->removed = false;
		h->next = handlers;
		handlers = h;
		return h;
	}

	BaseHandler_*	handlers;
};

class Event : public BaseEvent_ {
public:
	template<class T, class M>
	void* addHandler(T* object, void (T::*func)(M), M m) {
		return append(new ObjectHandler1<T, M>(object, func, m));
	}

	template<class T, class M, class N>
	void* addHandler(T* object, void (T::*func)(M, N), M m, N n) {
		return append(new ObjectHandler2<T, M, N>(object, func, m, n));
	}

	template<class T, class M, class N, class O>
	void* addHandler(T* object, void (T::*func)(M, N, O), M m, N n, O o) {
		return append(new ObjectHandler3<T, M, N, O>(object, func, m, n, o));
	}

	template<class T>
	void* addHandler(T* object, void (T::*func)()) {
		return append(new ObjectHandler<T>(object, func));
	}

	template<class M, class N>
	void* addHandler(void (*func)(M, N), M m, N n) {
		return append(new FunctionHandler2<M, N>(func, m, n));
	}

	void* addHandler(void (*func)()) {
		return append(new FunctionHandler(func));
	}

	void fire() {
		for (BaseHandler_* h = handlers; h; ) {
			h->busy = true;
			((Handler*)h)->fire();
			h->busy = false;
			BaseHandler_* hNext = h->next;
			if (h->removed)
				delete h;
			h = hNext;
		}
	}

private:
	struct Handler : public BaseHandler_{
		virtual void fire() = 0;
	};
	template<class T>
	class ObjectHandler : public Handler {
	public:
		ObjectHandler(T* object, void (T::*func)()) {
			this->object = object;
			this->func = func;
		}

		virtual void fire() {
			(object->*func)();
		}
	private:
		T* object;
		void (T::*func)();
	};

	template<class T, class M>
	class ObjectHandler1 : public Handler {
	public:
		ObjectHandler1(T* object, void (T::*func)(M), M m) {
			this->object = object;
			this->func = func;
			this->m = m;
		}

		virtual void fire() {
			(object->*func)(m);
		}
	private:
		T* object;
		void (T::*func)(M);
		M m;
	};

	template<class T, class M, class N>
	class ObjectHandler2 : public Handler {
	public:
		ObjectHandler2(T* object, void (T::*func)(M, N), M m, N n) {
			this->object = object;
			this->func = func;
			this->m = m;
			this->n = n;
		}

		virtual void fire() {
			(object->*func)(m, n);
		}
	private:
		T* object;
		void (T::*func)(M, N);
		M m;
		N n;
	};

	template<class T, class M, class N, class O>
	class ObjectHandler3 : public Handler {
	public:
		ObjectHandler3(T* object, void (T::*func)(M, N, O), M m, N n, O o) {
			this->object = object;
			this->func = func;
			this->m = m;
			this->n = n;
			this->o = o;
		}

		virtual void fire() {
			(object->*func)(m, n, o);
		}
	private:
		T* object;
		void (T::*func)(M, N, O);
		M m;
		N n;
		O o;
	};

	class FunctionHandler : public Handler {
	public:
		FunctionHandler(void (*func)()) {
			this->func = func;
		}

		virtual void fire() {
			func();
		}
	private:
		void (*func)();
	};

	template<class M, class N>
	class FunctionHandler2 : public Handler {
	public:
		FunctionHandler2(void (*func)(M, N), M m, N n) {
			this->func = func;
			this->m = m;
			this->n = n;
		}

		virtual void fire() {
			func(m, n);
		}
	private:
		void (*func)(M, N);
		M m;
		N n;
	};
};

template<class A>
class Event1 : public BaseEvent_ {
public:
	template<class T, class M>
	void* addHandler(T* object, void (T::*func)(A, M), M m) {
		return append(new ObjectHandler1<T, M>(object, func, m));
	}

	template<class T, class M, class N>
	void* addHandler(T* object, void (T::*func)(A, M, N), M m, N n) {
		return append(new ObjectHandler2<T, M, N>(object, func, m, n));
	}

	template<class T>
	void* addHandler(T* object, void (T::*func)(A)) {
		return append(new ObjectHandler<T>(object, func));
	}

	void* addHandler(void (*func)(A)) {
		return append(new FunctionHandler(func));
	}

	void fire(A a) {
		for (BaseHandler_* h = handlers; h; ) {
			h->busy = true;
			((Handler*)h)->fire(a);
			h->busy = false;
			BaseHandler_* hNext = h->next;
			if (h->removed)
				delete h;
			h = hNext;
		}
	}

private:
	struct Handler : public BaseHandler_ {
		virtual void fire(A) = 0;
	};
	template<class T>
	class ObjectHandler : public Handler {
	public:
		ObjectHandler(T* object, void (T::*func)(A)) {
			this->object = object;
			this->func = func;
		}

		virtual void fire(A a) {
			(object->*func)(a);
		}
	private:
		T* object;
		void (T::*func)(A);
	};

	template<class T, class M>
	class ObjectHandler1 : public Handler {
	public:
		ObjectHandler1(T* object, void (T::*func)(A, M), M m) {
			this->object = object;
			this->func = func;
			this->m = m;
		}

		virtual void fire(A a) {
			(object->*func)(a, m);
		}
	private:
		T* object;
		void (T::*func)(A, M);
		M m;
	};

	template<class T, class M, class N>
	class ObjectHandler2 : public Handler {
	public:
		ObjectHandler2(T* object, void (T::*func)(A, M, N), M m, N n) {
			this->object = object;
			this->func = func;
			this->m = m;
			this->n = n;
		}

		virtual void fire(A a) {
			(object->*func)(a, m, n);
		}
	private:
		T* object;
		void (T::*func)(A, M, N);
		M m;
		N n;
	};

	class FunctionHandler : public Handler {
	public:
		FunctionHandler(void (*func)(A)) {
			this->func = func;
		}

		virtual void fire(A a) {
			func(a);
		}
	private:
		void (*func)(A);
	};
};

template<class A, class B>
class Event2 : public BaseEvent_ {
public:
	template<class T, class M, class N>
	void* addHandler(T* object, void (T::*func)(A, B, M, N), M m, N n) {
		return append(new ObjectHandler2<T, M, N>(object, func, m, n));
	}

	template<class T, class M>
	void* addHandler(T* object, void (T::*func)(A, B, M), M m) {
		return append(new ObjectHandler1<T, M>(object, func, m));
	}

	template<class T>
	void* addHandler(T* object, void (T::*func)(A, B)) {
		return append(new ObjectHandler<T>(object, func));
	}

	void* addHandler(void (*func)(A, B)) {
		return append(new FunctionHandler(func));
	}

	void fire(A a, B b) {
		for (BaseHandler_* h = handlers; h; ) {

			h->busy = true;
			((Handler*)h)->fire(a, b);
			h->busy = false;
			BaseHandler_* hNext = h->next;
			if (h->removed)
				delete h;
			h = hNext;
		}
	}

private:
	struct Handler : public BaseHandler_ {
		virtual void fire(A, B) = 0;
	};
	template<class T>
	class ObjectHandler : public Handler {
	public:
		ObjectHandler(T* object, void (T::*func)(A, B)) {
			this->object = object;
			this->func = func;
		}

		virtual void fire(A a, B b) {
			(object->*func)(a, b);
		}
	private:
		T* object;
		void (T::*func)(A, B);
	};

	template<class T, class M>
	class ObjectHandler1 : public Handler {
	public:
		ObjectHandler1(T* object, void (T::*func)(A, B, M), M m) {
			this->object = object;
			this->func = func;
			this->m = m;
		}

		virtual void fire(A a, B b) {
			(object->*func)(a, b, m);
		}
	private:
		T* object;
		void (T::*func)(A, B, M);
		M m;
	};

	template<class T, class M, class N>
	class ObjectHandler2 : public Handler {
	public:
		ObjectHandler2(T* object, void (T::*func)(A, B, M, N), M m, N n) {
			this->object = object;
			this->func = func;
			this->m = m;
			this->n = n;
		}

		virtual void fire(A a, B b) {
			(object->*func)(a, b, m, n);
		}
	private:
		T* object;
		void (T::*func)(A, B, M, N);
		M m;
		N n;
	};

	class FunctionHandler : public Handler {
	public:
		FunctionHandler(void (*func)(A, B)) {
			this->func = func;
		}

		virtual void fire(A a, B b) {
			func(a, b);
		}
	private:
		void (*func)(A, B);
	};
};

template<class A, class B, class C>
class Event3 : public BaseEvent_ {
public:
	template<class T>
	void* addHandler(T* object, void (T::*func)(A, B, C)) {
		return append(new ObjectHandler<T>(object, func));
	}

	template<class T, class M>
	void* addHandler(T* object, void (T::*func)(A, B, C, M), M m) {
		return append(new ObjectHandler1<T, M>(object, func, m));
	}

	template<class T, class M, class N>
	void* addHandler(T* object, void (T::*func)(A, B, C, M, N), M m, N n) {
		return append(new ObjectHandler2<T, M, N>(object, func, m, n));
	}

	void* addHandler(void (*func)(A, B, C)) {
		return append(new FunctionHandler(func));
	}

	void fire(A a, B b, C c) {
		for (BaseHandler_* h = handlers; h; ) {
			h->busy = true;
			((Handler*)h)->fire(a, b, c);
			h->busy = false;
			BaseHandler_* hNext = h->next;
			if (h->removed)
				delete h;
			h = hNext;
		}
	}

private:
	struct Handler : public BaseHandler_ {
		virtual void fire(A, B, C) = 0;
	};
	template<class T>
	class ObjectHandler : public Handler {
	public:
		ObjectHandler(T* object, void (T::*func)(A, B, C)) {
			this->object = object;
			this->func = func;
		}

		virtual void fire(A a, B b, C c) {
			(object->*func)(a, b, c);
		}
	private:
		T* object;
		void (T::*func)(A, B, C);
	};

	template<class T, class M>
	class ObjectHandler1 : public Handler {
	public:
		ObjectHandler1(T* object, void (T::*func)(A, B, C, M), M m) {
			this->object = object;
			this->func = func;
			this->m = m;
		}

		virtual void fire(A a, B b, C c) {
			(object->*func)(a, b, c, m);
		}
	private:
		T* object;
		void (T::*func)(A, B, C, M);
		M m;
	};

	template<class T, class M, class N>
	class ObjectHandler2 : public Handler {
	public:
		ObjectHandler2(T* object, void (T::*func)(A, B, C, M, N), M m, N n) {
			this->object = object;
			this->func = func;
			this->m = m;
			this->n = n;
		}

		virtual void fire(A a, B b, C c) {
			(object->*func)(a, b, c, m, n);
		}
	private:
		T* object;
		void (T::*func)(A, B, C, M, N);
		M m;
		N n;
	};

	class FunctionHandler : public Handler {
	public:
		FunctionHandler(void (*func)(A, B, C)) {
			this->func = func;
		}

		virtual void fire(A a, B b, C c) {
			func(a, b, c);
		}
	private:
		void (*func)(A, B, C);
	};
};

template<class A, class B, class C, class D>
class Event4 : public BaseEvent_ {
public:
	template<class T>
	void* addHandler(T* object, void (T::*func)(A, B, C, D)) {
		return append(new ObjectHandler<T>(object, func));
	}

	void* addHandler(void (*func)(A, B, C, D)) {
		return append(new FunctionHandler(func));
	}

	void fire(A a, B b, C c, D d) {
		for (BaseHandler_* h = handlers; h; ) {
			h->busy = true;
			((Handler*)h)->fire(a, b, c, d);
			h->busy = false;
			BaseHandler_* hNext = h->next;
			if (h->removed)
				delete h;
			h = hNext;
		}
	}

private:
	struct Handler : BaseHandler_ {
		virtual void fire(A, B, C, D) = 0;
	};
	template<class T>
	class ObjectHandler : public Handler {
	public:
		ObjectHandler(T* object, void (T::*func)(A, B, C, D)) {
			this->object = object;
			this->func = func;
		}

		virtual void fire(A a, B b, C c, D d) {
			(object->*func)(a, b, c, d);
		}
	private:
		T* object;
		void (T::*func)(A, B, C, D);
	};

	class FunctionHandler : public Handler {
	public:
		FunctionHandler(void (*func)(A, B, C, D)) {
			this->func = func;
		}

		virtual void fire(A a, B b, C c, D d) {
			func(a, b, c, d);
		}
	private:
		void (*func)(A, B, C, D);
	};
};
