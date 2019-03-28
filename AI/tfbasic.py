# -*- coding: utf-8 -*-
import tensorflow as tf
import numpy as np

# Use softmax on vector.
x = [0., -1., 2., 3.]
softmax_x = tf.nn.softmax(x)

# Create 2D tensor and use soft max on the second dimension.
y = [5., 4., 6., 7., 5.5, 6.5, 4.5, 4.]
y_reshape = tf.reshape(y, [2, 2, 2])
softmax_y = tf.nn.softmax(y_reshape, 1)

session = tf.Session()
print("X")
print(x)
print("SOFTMAX X")
print(session.run(softmax_x))
print("Y")
print(session.run(y_reshape))
print("SOFTMAX Y")
print(session.run(softmax_y))

print("-------------------------")
s=tf.constant([1,1,2,3,4,5,10],dtype=tf.float32)
sm=tf.nn.softmax(s)

ai = []
with tf.Session()as sess:
	ai=sess.run(sm)
	print(sess.run(tf.argmax(sm)))

print(ai)
uu=data=np.array(ai)
print(uu.sum())