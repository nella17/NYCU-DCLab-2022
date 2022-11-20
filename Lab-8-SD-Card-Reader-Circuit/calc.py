import re
data = open('./test.txt').read()
ary = re.findall(r'\b\S{3,3}\b', data)
print(hex(len(ary)))
