#!/usr/bin/env lua

assert(not package.loaded.extformat, "Do not run this test library with extformat preloaded!");

-- Get a known good string.format for private use
local _fmt = string.format;

local pass = 0;
local fail = 0;

require[[extformat]];

local function print_fmt(fmt, ...)
	print(_fmt(fmt, ...));
end

-- At this point, string.format is the NEW string.format being tested. _fmt is the OLD built-in string.format!

local function test_format(expected, format, ...)
	-- if 'expected' is nil then we expect a failure.
	io.write(_fmt('TEST CASE: formatting %s ... ', format));
	local ok, actual = pcall(string.format, format, ...);
	-- Are we expecting a failure?
	if expected == nil then
		-- Failure expected
		if ok then
			print_fmt("FAILURE: error expected! Returned string is {{%s}}", actual);
			fail = fail + 1;
		else
			print_fmt("PASS: error expected. Error returned is {{%s}}", actual);
			pass = pass + 1;
		end
	else
		-- Result expected
		if ok then
			if actual == expected then
				print_fmt("PASS: result was {{%s}}", actual);
				pass = pass + 1;
			else
				print_fmt("FAILURE: expected {{%s}}, got {{%s}}", expected, actual);
				fail = fail + 1;
			end
		else
			print_fmt("FAILURE: expected {{%s}, got error\n%s", expected, actual);
			fail = fail + 1;
		end
	end
end

-- Simple string formatting
test_format("hello", "%s", "hello");

-- Simple numeric formatting
test_format("42", "%d", 42);
test_format("-42", "%d", -42);

-- Numeric signing flags.
test_format("+42", "%+d", 42);
test_format("-42", "%+d", -42);
test_format(" 42", "% d", 42);
test_format("-42", "% d", -42);

-- Width formatting.
test_format("  hello", "%7s", "hello");
test_format("hello  ", "%-7s", "hello");

-- Numeric width formatting
test_format("     42", "%7d", 42);
test_format("    -42", "%7d", -42);
test_format("42     ", "%-7d", 42);
test_format("-42    ", "%-7d", -42);
-- Width and signing flag integration
test_format("    +42", "%+7d", 42);
test_format("    -42", "%+7d", -42);
test_format("     42", "% 7d", 42);
test_format("    -42", "% 7d", -42);

-- Zero-filling
test_format("0000042", "%07d", 42);
test_format("-000042", "%07d", -42);
-- Zero-filling with signing flags
test_format("+000042", "%+07d", 42);
test_format("-000042", "%+07d", -42);
test_format(" 000042", "% 07d", 42);
test_format("-000042", "% 07d", -42);

-- Hexadecimal
test_format("2a", "%x", 42);
test_format("2A", "%X", 42);
test_format("0x2a", "%#x", 42);
test_format("0X2A", "%#X", 42);
test_format("     2a", "%7x", 42);
test_format("     2a", "%+7x", 42);
test_format("     2a", "% 7x", 42);
test_format("000002a", "%07x", 42);
test_format("000002a", "% 07x", 42);
test_format("   0x2a", "%#7x", 42);
test_format("0x0002a", "%#07x", 42);

-- Double-precision formatting. Keep numbers at power-of-two for accuracy.
test_format("2", "%d", 2.25);
test_format("2.25", "%g", 2.25);
test_format("2.250000e+00", "%e", 2.25);
test_format("2.250000E+00", "%E", 2.25);
test_format("2.250000", "%f", 2.25);
-- Big numbers
test_format("225000000", "%d", 2.25E8);
test_format("2.25e+08", "%g", 2.25E8);
test_format("2.25E+08", "%G", 2.25E8);
test_format("2.250000e+08", "%e", 2.25E8);
test_format("2.250000E+08", "%E", 2.25E8);
test_format("225000000.000000", "%f", 2.25E8);

-- Hexadecimal
test_format("0xb.5p+6", "%a", 724);
test_format("0XB.5P+6", "%A", 724);
test_format("   0xb.5p+6", "%11a", 724);
test_format("  -0xb.5p+6", "%11a", -724);
test_format("  +0xb.5p+6", "%+11a", 724);
test_format("  -0xb.5p+6", "%+11a", -724);
test_format("0xb.5000p+6", "%011a", 724);
test_format("-0xb.500p+6", "%011a", -724);
test_format("+0xb.500p+6", "%+011a", 724);
test_format("-0xb.500p+6", "%+011a", -724);
test_format(" 0xb.500p+6", "% 011a", 724);
test_format("-0xb.500p+6", "% 011a", -724);

-- Precision
test_format("hell", "%.4s", "hello");
test_format("2.25", "%.3g", 2.25);
test_format("2.250", "%.3f", 2.25);
test_format("0xd.1b34p+26", "%.4a", 879546549);
test_format("0xd.1b3p+26", "%.3a", 879546549);
test_format("0xd.1bp+26", "%.2a", 879546549);
test_format("0xd.2p+26", "%.1a", 879546549);
test_format("0xdp+26", "%.0a", 879546549);

-- Argument widths
test_format("  hello", "%*s", 7, "hello");
test_format("hello  ", "%-*s", 7, "hello");
test_format("hello  ", "%*s", -7, "hello");

-- Explicit selection
test_format("hello 42", "%1$s %2$d", "hello", 42);
test_format("hello 42", "%2$s %1$d", 42, "hello");
test_format("  hello", "%1$*2$s", "hello", 7);
test_format("hello  ", "%1$*2$s", "hello", -7);

-- %p
local x = {};
test_format(tostring(x), "table: %p", x);

-- Failure modes
test_format(nil, "%s");
test_format(nil, "%d", "hello");

print("RESULTS:");
print("Passed: " .. pass);
print("Failed: " .. fail);
local pct = 100*pass/(pass+fail)
print_fmt("Grade: %.1f%%", pct);
