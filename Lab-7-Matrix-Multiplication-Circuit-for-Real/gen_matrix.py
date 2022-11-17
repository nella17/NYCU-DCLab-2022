import numpy as np
np.set_printoptions(formatter={
    'int': lambda x: hex(x)[2:].zfill(5 if x >= 0x100 else 2).upper()
})

size = (4, 4)
cnt = size[0] * size[1]

def gen():
    m = np.random.randint(0, 0x100, size).transpose()
    s = [hex(x)[2:].zfill(2) for x in m.flat]
    return s

# sa = gen()
# sb = gen()

with open('matrices.mem') as f:
    data = f.read().split('\n')
    sa = data[0:cnt]
    sb = data[cnt:cnt*2]

def s2m(s):
    a = [int(x,16) for x in s]
    m = np.matrix(np.reshape(a, size))
    return m.transpose()

a = s2m(sa)
b = s2m(sb)
c = a * b

print(a)
# print(sa)
print()

print(b)
# print(sb)
print()

print(c)
