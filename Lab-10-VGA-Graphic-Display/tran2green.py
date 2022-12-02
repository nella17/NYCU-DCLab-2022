from PIL import Image
import numpy as np
from sys import argv

i = argv[1]
o = i.replace('png', 'ppm')

img = Image.open(i).convert("RGBA")
data = np.array(img)

data[(data == data[0][0]).all(axis = -1)] = [0, 255, 0, 255]

img = Image.fromarray(data)
img.save(o)
