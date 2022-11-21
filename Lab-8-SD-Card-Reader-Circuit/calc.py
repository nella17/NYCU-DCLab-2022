import re
data = open('./test.txt').read()
ary = re.findall(r'\b\S+\b', data)
ary3 = list(filter(lambda x: len(x) == 3, ary))
c3 = len(ary3)
c = len(ary)
print(hex(c3), hex(c), len(bin(c)[2:]))
print(ary3)
