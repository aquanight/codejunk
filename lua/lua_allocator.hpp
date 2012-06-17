#ifndef _LUA_ALLOCATOR_HPP
#define _LUA_ALLOCATOR_HPP

#pragma once

// C++ std::allocator style class for allocating contents in lua-managed memory.
// CONSEQUENTLY direct pointers can not be assumed safe outside of a given function block.
// lua_ptr addresses this issue.

#include <string>
#include <stdexcept>

extern "C"
{
#include <lua.h>
}

template <typename T>
class lua_allocator;

template <typename T>
class lua_ptr
{
private:
	lua_State* lua;
	lua_allocator<T>* allocator;
	lua_Integer ptridx;

public:
	friend class lua_allocator<T>;

	typedef T* pointer;
	typedef T& reference;
	typedef T const * const_pointer;
	typedef T const & const_reference;

	lua_ptr(lus_State* l, lua_allocator<T>* alloc, lua_Integer index)
		: lua(l), allocator(alloc), ptridx(index) {}

	lua_ptr(const lua_ptr& copy)
		: lua(copy.lua), allocator(copy.allocator), ptridx(copy.ptridx) {}
	
	~lua_ptr() {}

	// Pointers cannot be reassigned once created.
	lua_ptr& operator=(const lua_ptr& copy) = delete;

	pointer get()
	{
		lua_pushlightuserdata(lua, allocator);
		lua_gettable(lua, LUA_REGISTRYINDEX); // registry[allocator]
		lua_pushinteger(lua, ptridx);
		lua_gettable(lua, -2); // registry[allocator][ptridx]
		void* ptr = lua_touserdata(lua, -1);
		lua_pop(lua, 1); // Remove registry[allocator] from stack.
		return reinterpret_cast<pointer>(ptr);
	}

	const_pointer get() const
	{
		lua_pushlightuserdata(lua, allocator);
		lua_gettable(lua, LUA_REGISTRYINDEX); // registry[allocator]
		lua_pushinteger(lua, ptridx);
		lua_gettable(lua, -2); // registry[allocator][ptridx]
		void* ptr = lua_touserdata(lua, -1);
		lua_pop(lua, 1); // Remove registry[allocator] from stack.
		return reinterpret_cast<const_pointer>(ptr);
	}

	reference operator*() { return *get(); }

	const_reference operator*() const { return *get(); }

	pointer operator->() { return get(); }

	const_pointer operator->() const { return get(); }
};

template <typename T>
class lua_allocator
{
private:
	lua_State* lua;
	lua_Integer maxidx;

	// __gc metamethod for our heavy userdatas that hold the actual objects.
	static int udata_gc(lua_State* l)
	{
		// Parameter 1 = userdata being destructed.
		void* ud = lua_touserdata(l, 1);
		T* obj = reinterpret_cast<T*>(ud);
		obj->~obj(); // Destruct it.
	}

	// Gets the template instance's metatable onto the top of the tack.
	static void get_metatable(lua_State* l)
	{
		lua_pushlightuserdata(l, udata_gc);
		lua_gettable(l, LUA_REGISTRYINDEX);
		if (lua_isnil(l, -1))
		{
			lua_newtable(l);
			lua_pushlightuserdata(l, udata_gc);
			lua_pushvalue(l, -2);
			lua_pushcfunction(udata_gc);
			lua_setfield(l, -2, "__gc");
			lua_settable(l, LUA_REGISTRYINDEX);
		}
	}

public:
	typedef lua_ptr<T> pointer;
	typedef const lua_ptr<T> const_pointer;
	typedef lua_ptr<T>::reference reference;
	typedef lua_ptr<T>::const_reference const_reference;
	typedef size_t size_type;
	typedef ptrdiff_t difference_type;

	template <typename OtherT> struct rebind
	{
		typedef lua_allocator<OtherT> other;
	};

	lua_allocator(lua_State* l)
		: lua(l), maxidx(0)
	{
		lua_pushlightuserdata(l, this);
		lua_newtable(l);
		lua_settable(l, LUA_REGISTRYINDEX);
	}

	lua_allocator(const lua_allocator& copy)
		: lua(copy.lua), maxidx(0)
	{
		lua_pushlightuserdata(lua, this);
		lua_newtable(lua);
		lua_settable(lua, LUA_REGISTRYINDEX);
		// Should an allocator claim a copy of the references managed by the other allocator?
	}

	template <typename _Other> lua_allocator(const lua_allocator<_Other>& other)
		: lua(other.lua), maxidx(0)
	{
		lua_pushlightuserdata(lua, this);
		lua_newtable(lua);
		lua_settable(lua, LUA_REGISTRYINDEX);
	}

	lua_allocator(lua_allocator&& move)
		: lua(move.lua), maxidx(0)
	{
		lua_pushlightuserdata(lua, this); // reg[this] = ...
		lua_pushlightuserdata(lua, &move); // ... reg[move]
		lua_gettable(lua, LUA_REGISTRYINDEX); // get move's registry table
		lua_settable(lua, LUA_REGISTRYINDEX); // set it into our registry table
		lua_pushlightuserdata(l, &move); // reg[move] = ...
		lua_pushnil(lua); // ... nil
		lua_settable(lua, LUA_REGISTRYINDEX);
		move.lua = 0;
	}

	~lua_allocator()
	{
		if (lua)
		{
			// Remove our table from the registry. Any now-unreferenced objects will then be destructed.
			lua_pushlightuserdata(lua, this);
			lua_pushnil();
			lua_settable(lua, LUA_REGISTRYINDEX);
		}
	}

	template <typename _Other>
	bool operator==(const lua_allocator<_Other>& r) const
	{
		return this == &r;
	}

	template <typename _Other>
	bool operator!=(const lua_allocator<_Other>& r) const
	{
		return this != &r;
	}

	// Note: we don't bind the __gc metamethod here. We bind it
	// after successful construction via construct().
	pointer allocate(size_type sz, const void* hint = 0)
	{
		lua_pushlightuserdata(lua, this);
		lua_gettable(lua, LUA_REGISTRYINDEX);
		for (lua_Integer ix = 1; ix <= maxidx; ++ix)
		{
			lua_pushinteger(lua, idx);
			lua_gettable(lua, -2);
			if (lua_isnil(lua, -1))
			{
				lua_pop(l, 1); // Remove the nil.
				lua_pushinteger(lua, idx);
				void* ptr = lua_newuserdata(lua, sz);
				lua_settable(lua, -3);
				// We now have a valid pointer.
				// Remove the table.
				lua_pop(l, 1);
				return pointer(lua, this, idx);
			}
			lua_pop(lua, 1);
		}
		// No nil index found.
		lua_pushinteger(lua, ++maxidx);
		void* ptr = lua_newuserdata(lua, sz);
		lua_settable(lua, -3);
		// Remove the table.
		lua_pop(l, 1);
		return pointer(lua, this, maxidx);
	}

	void deallocate(pointer p, size_type sz)
	{
		if (p.lua != this->lua || p.allocator != this)
		{
			throw std::logic_error("Attempt to deallocate a lua object through the wrong allocator");
		}
		lua_pushlightuserdata(lua, this);
		lua_gettable(lua, LUA_REGISTRYINDEX);
		lua_pushinteger(p.ptridx);
		lua_pushnil();
		lua_settable(lua, -3);
		lua_pop(lua, 1); // Remove the table.
	}

	size_type max_size() const
	{
		return size_type(-1) / sizeof(T);
	}

	void construct(pointer p, const T& val)
	{
		if (p.lua != this->lua || p.allocator != this)
		{
			throw std::logic_error("Attempt to deallocate a lua object through the wrong allocator");
		}
		new (p.get()) T(val);
		lua_pushlightuserdata(lua, this);
		lua_gettable(lua, LUA_REGISTRYINDEX);
		lua_pushinteger(p,ptridx);
		lua_gettable(lua, -2);
		get_metatable(lua);
		lua_setmetatable(lua, -2);
		lua_pop(lua, 2);
	}

	template <typename... Args>
	void construct(pointer p, Args&&... args)
	{
		if (p.lua != this->lua || p.allocator != this)
		{
			throw std::logic_error("Attempt to deallocate a lua object through the wrong allocator");
		}
		new (p.get()) T(std::forward<Args>(args)...);
		lua_pushlightuserdata(lua, this);
		lua_gettable(lua, LUA_REGISTRYINDEX);
		lua_pushinteger(p,ptridx);
		lua_gettable(lua, -2);
		get_metatable(lua);
		lua_setmetatable(lua, -2);
		lua_pop(lua, 2);
	}

	void destroy(pointer p)
	{
		if (p.lua != this->lua || p.allocator != this)
		{
			throw std::logic_error("Attempt to deallocate a lua object through the wrong allocator");
		}
		p->~T();
		lua_pushlightuserdata(lua, this);
		lua_gettable(lua, LUA_REGISTRYINDEX);
		lua_pushinteger(p.ptridx);
		lua_gettable(lua, -2);
		lua_pushnil();
		lua_setmetatable(lua, -2);
		lua_pop(lua, 2);
	}
}

#endif
