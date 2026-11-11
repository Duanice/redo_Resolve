#!/usr/bin/env python3
"""Check the NVBit trace for the 16-element paired vector-add experiment."""
import collections
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "evidence/mem_trace.log"
launch = re.compile(r"Kernel name (vecAdd(?:Reduced)?)\(.* - grid launch id (\d+)")
access = re.compile(r"grid_launch_id (\d+) - CTA.* - (LDG|STG)[^ ]* - (.*)")
names = {}
addresses = collections.defaultdict(lambda: collections.defaultdict(list))

with open(path, encoding="utf-8") as stream:
    for line in stream:
        if match := launch.search(line):
            names[int(match[2])] = match[1]
        if match := access.search(line):
            values = [int(value, 16) for value in re.findall(r"0x[0-9a-fA-F]+", match[3])]
            addresses[int(match[1])][match[2]].extend(value for value in values if value)

assert len(names) == 24 and len(addresses) == 24, (len(names), len(addresses))
for pair in range(12):
    original = addresses[2 * pair]
    reduced = addresses[2 * pair + 1]
    assert names[2 * pair] == "vecAdd"
    assert names[2 * pair + 1] == "vecAddReduced"
    for trace in (original, reduced):
        assert len(trace["LDG"]) == 32 and len(trace["STG"]) == 16
        assert len(set(trace["LDG"])) == 32
        assert len(set(trace["STG"])) == 16
        assert sorted(set(trace["STG"])) == list(range(min(trace["STG"]), min(trace["STG"]) + 16 * 8, 8))
    assert set(original["LDG"]) == set(reduced["LDG"])
    assert set(original["STG"]).isdisjoint(reduced["STG"])

print("PASS: 24 launches / 12 pairs; each reads 32 doubles and writes 16 doubles")
print("PASS: paired kernels read identical input addresses and use separate outputs")
