'''
$ python dist_trainer.py --ps_hosts=localhost:2222 --worker_hosts=localhost:2223,localhost:2224 --job_name=ps --task_index=0
$ python dist_trainer.py --ps_hosts=localhost:2222 --worker_hosts=localhost:2223,localhost:2224 --job_name=worker --task_index=0
$ python dist_trainer.py --ps_hosts=localhost:2222 --worker_hosts=localhost:2223,localhost:2224 --job_name=worker --task_index=1 --serving_mode=true
'''

import argparse
import sys
import time

import tensorflow as tf
from tensorflow.examples.tutorials.mnist import input_data

FLAGS = None
epoch_count = 1000

def main(_):
  ps_hosts = FLAGS.ps_hosts.split(",")
  worker_hosts = FLAGS.worker_hosts.split(",")
  
  # Create a cluster from the parameter server and worker hosts.
  cluster = tf.train.ClusterSpec({"ps": ps_hosts, "worker": worker_hosts})

  # Create and start a server for the local task.
  server = tf.train.Server(cluster, job_name=FLAGS.job_name, task_index=FLAGS.task_index)
 
  with tf.device("/job:ps/task:0"):
    w_h = tf.Variable(tf.random_normal([784, 1024], stddev=0.01))
    w_h2 = tf.Variable(tf.random_normal([1024, 625], stddev=0.01))
    w_o = tf.Variable(tf.random_normal([625, 10], stddev=0.01))
    b1 = tf.Variable(tf.random_normal([1024]))
    b2 = tf.Variable(tf.random_normal([625]))
	
  if FLAGS.job_name == "ps":
    server.join()

  elif FLAGS.job_name == "worker":

    with tf.device("/job:worker/task:%d" % FLAGS.task_index):
      X = tf.placeholder(tf.float32, [None, 784])
      Y = tf.placeholder(tf.float32, [None, 10])
      h = tf.nn.relu(tf.matmul(X, w_h) + b1)
      h2 = tf.nn.relu(tf.matmul(h, w_h2) + b2)
      py_x = tf.matmul(h2, w_o)
	
    # Assigns ops to the local worker by default.
    with tf.device(tf.train.replica_device_setter(worker_device="/job:worker/task:%d" % FLAGS.task_index, cluster=cluster)):
      # Build model...
      cost = tf.reduce_mean(tf.nn.softmax_cross_entropy_with_logits(logits=py_x, labels=Y))
      global_step = tf.contrib.framework.get_or_create_global_step()

      train_op = tf.train.AdagradOptimizer(0.01).minimize(cost, global_step=global_step)
      predict_acc = tf.reduce_mean(tf.cast(tf.equal(tf.argmax(py_x, 1), tf.argmax(Y, 1)), tf.float32))

    # read data
    mnist = input_data.read_data_sets("MNIST_data/", one_hot=True)

    # The StopAtStepHook handles stopping after running given steps.
    hooks=[tf.train.StopAtStepHook(last_step=1000000)]

    # The MonitoredTrainingSession takes care of session initialization,
    # restoring from a checkpoint, saving to a checkpoint, and closing when done
    # or an error occurs.
    with tf.train.MonitoredTrainingSession(master=server.target, is_chief=(FLAGS.task_index == 0), hooks=hooks) as mon_sess:
      if FLAGS.serving_mode:
        print("********************Excute predict***************")
        print("*************************************************")
        while True:
          acc = mon_sess.run([predict_acc], feed_dict={X: mnist.test.images, Y: mnist.test.labels})
          print("Test Accuracy: {}".format(acc))
          time.sleep(5)
		  
      else:
        #mon_sess.run(tf.global_variables_initializer())
        step = 0 if (FLAGS.task_index == 0) else 1
        batch_size = 1000	  
        while not mon_sess.should_stop():
          # Run a training step asynchronously.
          # See `tf.train.SyncReplicasOptimizer` for additional details on how to
          # perform *synchronous* training.
          # mon_sess.run handles AbortedError in case of preempted PS.
          step += 2
          batch_x, batch_y = mnist.train.next_batch(batch_size)
          mon_sess.run(train_op, feed_dict={X: batch_x, Y: batch_y})
          loss, acc = mon_sess.run([cost, predict_acc], feed_dict={X: batch_x, Y: batch_y})
          print("Epoch: {}".format(step/2), "\tLoss: {:.6f}".format(loss), "\tTraining Accuracy: {:.5f}".format(acc))


if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.register("type", "bool", lambda v: v.lower() == "true")
  # Flags for defining the tf.train.ClusterSpec
  parser.add_argument(
      "--ps_hosts",
      type=str,
      default="",
      help="Comma-separated list of hostname:port pairs"
  )
  parser.add_argument(
      "--worker_hosts",
      type=str,
      default="",
      help="Comma-separated list of hostname:port pairs"
  )
  parser.add_argument(
      "--job_name",
      type=str,
      default="",
      help="One of 'ps', 'worker'"
  )
  # Flags for defining the tf.train.Server
  parser.add_argument(
      "--task_index",
      type=int,
      default=0,
      help="Index of task within the job"
  )
  parser.add_argument(
      "--serving_mode",
      type=bool,
      default=False,
      help="Index of task within the job"
  )
  FLAGS, unparsed = parser.parse_known_args()
  tf.app.run(main=main, argv=[sys.argv[0]] + unparsed)