#!/usr/bin/env lua

-- Returns true if the object inherits indexes from 'what', false otherwise.
-- This is based on following __index metamethods until a match is found.
-- If __index is nil or a function, it is considered the end of a chain, but "class"
-- tables using a function __index can have a metaproperty __isa to point to another table.
local function isa(obj, what)
	local seen = {}; -- Used to prevent loops
	local mt, clz;
	assert(obj ~= nil);
	assert(what ~= nil);
	mt = debug.getmetatable(obj);
	while true do
		-- No metatable? We're done here.
		if mt == nil then
			return false
		end
		clz = mt.__index;
		-- No __index? We're done here.
		if clz == nil then
			return false
		end
		-- Is this our target?
		if clz == what then
			return true
		end
		-- Only tables can be searched recursively.
		if type(clz) ~= "table" then
			-- Does the metatable have an __isa table ?
			if type(mt.__isa) == "table" then
				clz = mt.__isa
				-- Is it our target?
				if clz == what then
					return true
				end
			else
				-- No __index or __isa table, we're done here.
				return false;
			end
		end
		-- Have we seen this before?
		if seen[clz] then
			return false
		else
			seen[clz] = true
		end
		-- Check the __index/__isa table.
		mt = debug.getmetatable(clz);
	end
end

local A, B, C = {}, {}, {};

setmetatable(C, { __index = B } );
setmetatable(B, { __index = A } );

A.a = "A-ness";
B.b = "B-ness";
C.c = "C-ness";
A.__index = A;
B.__index = B;
C.__index = C;
A.type = "A";
B.type = "B";
C.type = "C";

local oa, ob, oc = {}, {}, {};

setmetatable(oa, A);
setmetatable(ob, B);
setmetatable(oc, C);

print("oa type is:", oa.type);
print("ob type is:", ob.type);
print("oc type is:", oc.type);
print("---", "oa.", "ob.", "oc.");
print(".a", oa.a, ob.a, oc.a);
print(".b", oa.b, ob.b, oc.b);
print(".c", oa.c, ob.c, oc.c);

print("3 is a string: ", isa(3, string));
print("'3' is a string: ", isa('3', string));
print("isa()", "oa", "ob", "oc");
print("A", isa(oa, A), isa(ob, A), isa(oc, A));
print("B", isa(oa, B), isa(ob, B), isa(oc, B));
print("C", isa(oa, C), isa(ob, C), isa(oc, C));

print("Test isa() with __index function")
local D = {};
D.d = "D-ness";
D.__index = D;
setmetatable(D, { __index = function(t,k) return C[k] end });
local od = {};
setmetatable(od, D);
print("od.a : ", od.a);
print("od.b : ", od.b);
print("od.c : ", od.c);
print("od.d : ", od.d);
print("od is-a A", isa(od, A));
print("od is-a B", isa(od, B));
print("od is-a C", isa(od, C));
print("od is-a D", isa(od, D));
print("Test __isa");
getmetatable(D).__isa = C;
print("od is-a A", isa(od, A));
print("od is-a B", isa(od, B));
print("od is-a C", isa(od, C));
print("od is-a D", isa(od, D));
