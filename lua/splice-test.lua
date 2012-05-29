#!/usr/bin/env lua

local require = require("require").require;

local failcnt = 0;

local pack;
pack = table.pack or function(...)
	return { n = select("#", ...), ... };
end

local unpack = table.unpack or unpack;

local ins = table.insert;
local function keys(tbl)
	local res = {};
	for k, v in pairs(tbl) do
		ins(res, k);
	end
	return res;
end

local function test(cond, ...)
	if not cond then
		print("FAIL", ...);
		failcnt = failcnt + 1;
	else
		print("PASS", ...);
	end
	return not cond;
end

local _;

require("dump");
local tbl = require("tablefun");
local splice = tbl.splice;
require("functional").setup();

local print = print;
local dprn = dump:chain(print);

print("Setting up test table:");
x = { 1, 2, 5, 6 };
dprn(x);

print("First trial of splice - inserting 2 elements into the sequence.");
print("TEST: there should be no results returned");
_ = pack(splice(x, 3, 0, 3, 4));
test(_.n == 0, unpack(_, 1, _.n));

print("Verification of x:");
dprn(x);
print("TEST: There should only be 6 keys, from 1 through 6.");
_ = table.concat(keys(x), "|");
test(_ == "1|2|3|4|5|6", "See dump");

print("Second trial of splice - removing 3 elements from the sequence.");
print("TEST: there should be 3 results returned: 3, 4, 5");
_ = pack(splice(x, 3, 5));
test(table.concat(_, "|", 1, _.n) == "3|4|5", unpack(_, 1, _.n));

print("Verification of x:");
dprn(x);
print("TEST: There should only be 3 keys: 1, 2, and 3.");
_ = table.concat(keys(x), "|");
test(_ == "1|2|3", "See dump");

print("Third trial: a longer insertion of 4 random numbers.");
local rng = { math.random:iterate(1)(1000, 1000, 1000, 1000) };
print("The random numbers that will be inserted are:");
print(unpack(rng, 1, 4));

_ = pack(splice(x, 3, 0, unpack(rng, 1, 4)));
print("TEST: As before, there should be no results returned.");
test(_.n == 0, unpack(_, 1, _.n));

print("Verification of x:");
dprn(x);
print("THere should be now 7 keys: 1 through 7.");
_ = table.concat(keys(x), "|");
test(_ == "1|2|3|4|5|6|7", "See dump");

print("Final trial: replacing the 4 random numbers previously inserted");
print("with the correct sequence (3, 4, 5).");
_ = pack(splice(x, 3, 6, 3, 4, 5));
print("TEST: The 4 random numbers from before should have be returned.");
test(_.n == 4 and _[1] == rng[1] and _[2] == rng[2] and _[3] == rng[3] and _[4] == rng[4], unpack(_, 1, _.n));

print("Verification of x:");
dprn(x);
print("There should be now only 6 keys: 1 through 6.");
_ = table.concat(keys(x), "|");
test(_ == "1|2|3|4|5|6", "See dump");

print(("%d tests failed"):format(failcnt));

os.exit(failcnt > 0 and 1 or 0);
