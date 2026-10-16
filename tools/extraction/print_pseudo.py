import re

with open("/Users/arko.sen/Desktop/BfTest/Bf_Pseudocode.txt") as f:
    lines = f.readlines()

for i, l in enumerate(lines):
    print(f"{i+1:3d}: {l.rstrip()}")
