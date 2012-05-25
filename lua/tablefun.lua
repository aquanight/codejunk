local _M = {};

-- Returns a table view that contains only the specified keys.
-- If the keys are integers, they are accessed through view[1 .. j] in order.
function _M.slice(tbl, ...)
	local keymap = {}
	local arg = { n = select("#", ...), ... };
	for i = 1, arg.n, 1 do
		if type(arg[i]) == "number" then
			local ip, fp = math.modf(arg[i]);
			if fp == 0 and ip > 0 then
				-- Positive Integer.
				table.insert(keymap, arg[i]);
			else
				-- Non-integer or negative integer (or 0)
				keymap[i] = arg[i];
			end
		elseif arg[i] ~= nil then
			-- Not a number
			keymap[i] = arg[i];
		end
	end
	local mt = {
		__index = function(t, k)
			local realkey = keymap[k];
			if realkey == nil then
				return nil;
			end
			return tbl[realkey];
		end,
		__newindex = function(t, k, v)
			local realkey = keymap[k];
			if realkey == nil then
				error("Attempt to create a table element through a slice view");
			end
			tbl[realkey] = v;
		end
	};
	return setmetatable({}, mt);
end

-- As slice(), but sequence indexes are not re-ordered.
function _M.rawslice(tbl, ...)
	local keymap = {}
	local arg = { n = select("#", ...), ... };
	for i = 1, arg.n, 1 do
		keymap[i] = arg[i];
	end
	local mt = {
		__index = function(t, k)
			local realkey = keymap[k];
			if realkey == nil then
				return nil;
			end
			return tbl[realkey];
		end,
		__newindex = function(t, k, v)
			local realkey = keymap[k];
			if realkey == nil then
				error("Attempt to create a table element through a slice view");
			end
			tbl[realkey] = v;
		end
	};
	return setmetatable({}, mt);
end

-- Creates a "chain" of tables where any index not found in the first
-- is looked up in the next.
-- When retrieving, any index not found in any table results in 'nil'. __index metamethod is respected.
-- When storing, any index not found in any table is created in the first table. __index metamethod is respected
-- to find the first table that has the index, __newindex is respected, if applicable, on the table that is chosen.
function _M.chain(...)
	local arg = { n = select("#", ...), ... };
	assert(arg.n >= 1, "No tables provided to 'chain'");
	for i = 1, arg.n, 1 do
		assert(type(arg[i]) == "table", ("bad argument #%d to 'chain' (table expected, got %s)"):format(i, type(arg[i])));
	end
	local mt = {
		__index = function(t, k)
			for i = 1, arg.n, 1 do
				local val = arg[i][k];
				if val ~= nil then
					return val;
				end
			end
			return nil;
		end,
		__newindex = function(t, k, v)
			for i = 1, arg.n, 1 do
				local val = arg[i][k];
				if val ~= nil then
					arg[i][k] = v;
					return;
				end
			end
			arg[1] = v;
		end
	};
	return setmetatable({}, mt);
end

-- Creates a view of a table where elements have a mutator function applied to them when retrieved.
-- If a 'reverse' mutator is applied, this view supports creating/assigning elements as well.
-- Both mutators are passed the key and value, and are expected to return the value to either return to the
-- indexer or store in the table.
function _M.map(tbl, mut, ...)
	local arg = { n = select("#", ...), ... };
	local rev = arg[1] or nil;
	assert(type(tbl) == "table", ("bad argument #1 to 'map' (table expected, got %s)"):format(type(tbl)));
	assert(type(mut) == "function", ("bad argument #2 to 'map' (function expected, got %s)"):format(type(mut)));
	if rev ~= nil then
		assert(type(rev) == "function", ("bad argument #3 to 'map' (function or nil expected, got %s)"):format(type(rev)));
	end
	local mt = {
		__index = function(t, k)
			return mut(k, tbl[k]);
		end,
		__newindex = function(t, k, v)
			assert(rev, "This table view is read-only");
			tbl[k] = rev(k, v);
		end
	};
	return setmetatable({}, mt);
end

-- Creates a read-only view of the table.
local realmeta = debug.getmetatable;
local pairs = pairs;
local ipairs = ipairs;
function _M.readonly(tbl)
	assert(type(tbl) == "table", ("bad argument #1 to 'readonly' (table expected, got %s)"):format(type(tbl)));
	local rmt = realmeta(tbl);
	local mt = {};
	-- Wrap the metamethods. We wrap __(new)index differently.
	local wrappedmetas = { "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__concat", "__eq", "__lt", "__le", "__call", "__pairs", "__ipairs", "__next", "__len" };
	for i, v in ipairs(wrappedmetas) do
		local mm = rawget(rmt, v); -- Do not allow __index lookup of metamethods, to simulate actual metamethod lookups.
		if type(mm) == "function" then -- The metamethod is a function (lua ignores non-function metas, even if they have a __call).
			mt[v] = function(t, ...)
				-- t will be our proxy object, so replace it with the real table
				return mm(tbl, ...);
			end;
		end
	end
	mt.__metatable = rmt.__metatable or rmt;
	mt.__newindex = function(t, k, v)
		error("This table view is read-only");
	end;
	mt.__index = function(t, k)
		return tbl[k];
	end;
	return setmetatable({}, mt);
end

return _M;
