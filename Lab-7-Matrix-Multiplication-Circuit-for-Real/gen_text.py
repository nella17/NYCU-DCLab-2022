NULL = '\0'
HEAD = '\r\nThe matrix multiplication result is:\r\n'
BODY = ' [ ?????, ?????, ?????, ????? ]\r\n'

text = HEAD + BODY * 4
hexs = '\n'.join(hex(x)[2:].zfill(2) for x in text.encode())

with open('text.mem', 'w') as f:
    f.write(hexs)
