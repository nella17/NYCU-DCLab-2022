import numpy as np

def gen():
    m = np.random.randint(0, 0x100, (3, 3))
    s = '_'.join(hex(x)[2:].zfill(2) for x in m.flat)
    return s

sa = gen()
sb = gen()

sa = '4F_7E_57_0F_14_7B_21_4C_54'
sb = '17_28_3A_40_2F_33_6C_22_77'

def s2m(s):
    a = [int(x,16) for x in s.split('_')]
    m = np.matrix(np.reshape(a, (3,3)))
    return m

a = s2m(sa)
b = s2m(sb)
c = a * b

print(a)
print(sa)
print()

print(b)
print(sb)
print()

print(c)
