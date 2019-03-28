import numpy as np
import math
import matplotlib.pyplot as plt
X = np.linspace(-10, 10, 201)
y = [1/(1+math.e**(-x)) for x in X]
plt.plot(X, y)
plt.show()

X1 = np.linspace(0.0001, 1, 100)
y1 = [(-math.log(x1)) for x1 in X1]
plt.plot(X1, y1)
plt.show()

X11 = np.linspace(0.0001, 1, 100)
y11 = [(-math.log(x11) * x11) for x11 in X11]
plt.plot(X11, y11)
plt.show()

X2 = np.linspace(0, 0.999999, 100)
y2 = [(-math.log(1-x2)) for x2 in X2]
plt.plot(X2, y2)
plt.show()

X21 = np.linspace(0, 0.999999, 100)
y21 = [(-math.log(1-x21) * (1-x21)) for x21 in X21]
plt.plot(X21, y21)
plt.show()