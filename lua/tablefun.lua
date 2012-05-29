local _M = {};

local sprintf = string.format;
local tonumber = tonumber;
local assert = assert;

--I do this a lot so...
local function assertf(cond, format, ...)
	return assert(cond, sprintf(format, ...));
end

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

-- "splice" removes a sequence of elements from the table and returns them (as table.remove does),
-- and optionally inserts a new sequence of elements in its place.
-- Only the table's sequence portion is affected.
-- If the caller uses the key "n" for the table's length, it is the caller's responsibility to update the
-- value.
-- Syntax: splice(tbl[, start[, end[, ...]]]);
-- If 'start' is absent it defaults to 1.
-- If 'end' is absent it defaults to #tbl.
-- The '...' portion inserts a new range of items. The range at 'start' and 'end' is expanded or collapsed
-- according to the length of the new item set. Note that the resulting table might no longer be a sequence!
_M.splice = assert(package.loadlib("./tablefun.so", "table_splice"));

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
	assert(type(tbl) == "table", sprintf("bad argument #1 to 'map' (table expected, got %s)", type(tbl)));
	assert(type(mut) == "function", sprintf("bad argument #2 to 'map' (function expected, got %s)", type(mut)));
	if rev ~= nil then
		assert(type(rev) == "function", sprintf("bad argument #3 to 'map' (function or nil expected, got %s)", type(rev)));
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
	assert(type(tbl) == "table", sprintf("bad argument #1 to 'readonly' (table expected, got %s)", type(tbl)));
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

-- Tests if a table is a pure Lua 5.2 style sequence.
-- Returns true if and only if:
-- - Key [1] exists (does not contain 'nil').
-- - For any key x where x is a positive integer greater
--   than 1, if key [x] exists, then key [x - 1] also exists.
-- - If key ["n"] exists, it contains a positive integer equal
--   to the highest valid index as described above.
-- - The table contains no other keys.
-- Returns true if the table is a sequence.
-- Else returns false and a string explaining why.
local math = math;
local modf = math.modf;
function _M.is_pure_sequence(tbl)
	if tbl[1] == nil then
		return false, "No item at index [1]";
	end
	if tbl.n ~= nil then
		if type(tbl.n) ~= "number" then
			return false, sprintf('Value at ["n"] is not a number (type is %s)', type(tbl.n));
		else
			local _in, _fn = modf(tbl.n);
			if _in <= 0 or _fn ~= 0 then
				return false, sprintf('Value at ["n"] is not a positive integer (%g)', tbl.n);
			end
		end
	end
	for k,v in pairs(tbl) do
		if type(k) == "number" then
			local ik, fk = modf(k);
			if fk == 0 and ik > 0 then
				if tbl.n and ik > tbl.n then
					return false, sprintf('Value at ["n"] is incorrect. It is %g but an index at %g was found', tbl.n, k);
				end
				if tbl[k - 1] == nil then
					return false, sprintf('Gap at index [%g]', (k - 1));
				end
				if (k - 1) == k then
					-- The index is so large it cannot reach unit-precision. Fail it.
					return false, sprintf("Index [%g] is too large for sequence-level precision", k);
				end
			else
				return false, sprintf("Index [%g] is not a positive integer", k);
			end
		elseif k ~= "n" then
			return false, sprintf("Index [%q] is not a number", tostring(k));
		end
	end
	-- No issues found.
	return true;
end

return _M;
