local _M = {};

local proto = require("prototype");

local realmeta = debug.getmetatable;
local type = type;
local tonumber = tonumber;

-- Tests for capabilities.
--
-- Each can_* function returns 'true' if the operation it represents
-- can be performed on the operand(s), or 'false' if it cannot.
--
-- Versions taking 2 or more parameters return 'true' if and only if
-- *all* arguments support the requested operation. For example, the
-- capabilities relating to binary operators take two parameters and returns
-- true if that binary operation will not fail on account of the types
-- of the arguments. Note that a built-in operation or metamethod invoked
-- when the operation is attempted might still raise an error.

local function has_metamethod(x, meta)
	local xmt = realmeta(x);
	return (xmt and (type(xmt[meta]) == "function"));
end

local function can_arith(x, y, meta)
	local xnum = tonumber(x);
	local ynum = tonumber(y);
	return ((xnum and ynum) or (has_metamethod(x, meta)) or (has_metamethod(y, meta)));
end

local ariths = { "add", "sub", "mul", "div", "mod", "pow" };
local ipairs = ipairs;
for _, v in ipairs(ariths) do
	_M["can_" .. v] = function(x,y)
		return can_arith(x, y, "__"..v);
	end;
end

function _M.can_unm(x)
	return tonumber(x) or (has_metamethod(x, "__unm"));
end

function _M.can_concat(x, y)
	return proto.typesof(x, y):match("[ns][ns]") or (has_metamethod(x, "__concat")) or (has_metamethod(y, "__concat"));
end

function _M.can_len(x)
	return proto.typesof(x):match("[st]") or has_metamethod(x, "__len");
end

-- Note that == always works between any two objects without error.
-- can_eq thus deviates from the standard by returning true IF
-- AND ONLY IF the arguments are the same type, AND...
-- - that type is "number" or "string", OR
-- - either argument defines a metamethod.
-- In other words, it returns true if an equality test may be based on
-- more than a reference-identity test.
local function can_compare(x, y, meta)
	local types_match = proto.typesof(x, y):match("^(.)%1$");
	return types_match and (types_match:match("[ns]") or has_metamethod(x, meta) or has_metamethod(y, meta));
end
local compares = { "eq", "lt", "le" };
for _, v in ipairs(compares) do
	_M["can_" .. v] = function(x, y)
		return can_compare(x, y, "__"..v);
	end;
end

function _M.can_index(x)
	return type(x) == "table" or has_metamethod(x, "__index");
end

function _M.can_newindex(x)
	return type(x) == "table" or has_metamethod(x, "__newindex");
end

function _M.can_call(x)
	return type(x) == "function" or has_metamethod(x, "__call");
end

function _M.can_len(x)
	return type(x) == "string" or type(x) == "table" or has_metamethod(x, "__len");
end

return _M;
