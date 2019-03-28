import tensorflow as tf
from tensorflow.examples.tutorials.mnist import input_data

mnist = input_data.read_data_sets("MNIST_data/", one_hot=True)

X = tf.placeholder(tf.float32, [None, 784])
Y = tf.placeholder(tf.float32, [None, 10])

#p_keep_input = tf.Variable(1., dtype=tf.float32)
#p_keep_hidden1 = tf.Variable(1., dtype=tf.float32)
#p_keep_hidden2 = tf.Variable(1., dtype=tf.float32)
  

w_h = tf.Variable(tf.random_normal([784, 1024], stddev=0.01))
w_h2 = tf.Variable(tf.random_normal([1024, 625], stddev=0.01))
w_o = tf.Variable(tf.random_normal([625, 10], stddev=0.01))

b1 = tf.Variable(tf.random_normal([1024]))
b2 = tf.Variable(tf.random_normal([625]))

#X = tf.nn.dropout(X, p_keep_input)

h = tf.nn.relu(tf.matmul(X, w_h) + b1)

#h = tf.nn.dropout(h, p_keep_hidden1)

h2 = tf.nn.relu(tf.matmul(h, w_h2) + b2)

#h2 = tf.nn.dropout(h2, p_keep_hidden2)

py_x = tf.matmul(h2, w_o)

cost = tf.reduce_mean(tf.nn.softmax_cross_entropy_with_logits(logits=py_x, labels=Y))
train_op = tf.train.RMSPropOptimizer(0.001, 0.9).minimize(cost)
predict_acc = tf.reduce_mean(tf.cast(tf.equal(tf.argmax(py_x, 1), tf.argmax(Y, 1)), tf.float32))

epoch_count = 1000
batch_size = 50
keep_input = 0.8
keep_hidden = 0.75


with tf.Session() as sess:
    sess.run(tf.global_variables_initializer())
 
    step = 0
    for i in range(epoch_count):
        step += 1
        batch_x, batch_y = mnist.train.next_batch(batch_size)
        sess.run(train_op, feed_dict={X: batch_x, Y: batch_y})
        if step % 100 == 0:
            loss, acc = sess.run([cost, predict_acc], feed_dict={X: batch_x, Y: batch_y})
            print("Epoch: {}".format(step), "\tLoss: {:.6f}".format(loss), "\tTraining Accuracy: {:.5f}".format(acc))

    print("Testing Accuracy: {:0.5f}".format(sess.run(predict_acc, feed_dict={X: mnist.test.images, Y: mnist.test.labels})))
