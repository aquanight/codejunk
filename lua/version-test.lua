#!/usr/bin/env lua
local _req = require("require");

local cv = _req.cmp_versions;

print("Testing validation...");
assert(pcall(cv, "1.2a", "cvs.1.2z-pre34"), "FAIL: Validation (valid)");
assert(not pcall(cv, "xyz", "asdf"), "FAIL: Validation (invalid)");
print("Test passed");

print("Testing identity...");
assert(cv("1.2", "1.2" ) == 0, "FAIL: Identity");
assert(cv("1.2", "1.02") == 0, "FAIL: Equality");
print("Test passed");

print("Testing CVS prefix...");
assert(cv("cvs.1.2", "1.2"    ) > 0, "FAIL: CVS prefix (greater)");
assert(cv("1.2"    , "cvs.1.2") < 0, "FAIL: CVS prefix (lesser)");
assert(cv("cvs.1.2", "cvs.1.2") ==0, "FAIL: CVS prefix (equality)");
print("Test passed");

print("Testing version component...");
assert(cv("1.2"  , "2.1"  ) < 0, "FAIL: Version component (lesser)");
assert(cv("1.2.4", "1.2.3") > 0, "FAIL: Version component (depth)");
print("Test passed");

print("Testing letter suffix...");
assert(cv("1.2a", "1.2b") < 0, "FAIL: Letter suffix");
assert(cv("1.2b", "1.2b") ==0, "FAIL: Letter equality");
assert(cv("1.3a", "1.2f") > 0, "FAIL: Letter/version");
print("Test passed");

print("Testing release suffix...");
assert(cv("1.2_p1"   , "1.2_p0"       ) > 0, "FAIL: Release suffix");
assert(cv("1.2_beta3", "1.2_p1"       ) < 0, "FAIL: Release suffix");
assert(cv("1.2_p1"   , "1.2_rc2"      ) > 0, "FAIL: Release suffix");
assert(cv("1.2_rc1"  , "1.2_pre2"     ) > 0, "FAIL: Release suffix");
assert(cv("1.2_pre1" , "1.2_beta2"    ) > 0, "FAIL: Release suffix");
assert(cv("1.2_beta1", "1.2_alpha2"   ) > 0, "FAIL: Release suffix");
assert(cv("1.2_p3"   , "1.2_p3"       ) ==0, "FAIL: Release suffix");
assert(cv("1.2"      , "1.2_p0"       ) < 0, "FAIL: Release suffix");
assert(cv("1.2"      , "1.2_rc9999999") > 0, "FAIL: Release suffix");
print("Test passed");
