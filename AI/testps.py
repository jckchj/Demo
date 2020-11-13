'''
$ python D:/Tools/testps.py --ps_hosts=J-CHEN-PCG:2222 --worker_hosts=J-CHEN-PC:2223 --job_name=ps --task_index=0
$ python D:/Tools/testps.py --ps_hosts=J-CHEN-PCG:2222 --worker_hosts=J-CHEN-PC:2223 --job_name=worker --task_index=0
$ python D:/Tools/testps.py --ps_hosts=localhost:2222 --worker_hosts=localhost:2223,localhost:2224 --job_name=worker --task_index=1 --serving_mode=true
'''

import argparse
import sys
import time

import tensorflow as tf

def main(_):
  ps_hosts = FLAGS.ps_hosts.split(",")
  worker_hosts = FLAGS.worker_hosts.split(",")
  
  # Create a cluster from the parameter server and worker hosts.
  cluster = tf.train.ClusterSpec({"ps": ps_hosts, "worker": worker_hosts})

  # Create and start a server for the local task.
  server = tf.train.Server(cluster, job_name=FLAGS.job_name, task_index=FLAGS.task_index)
 	
  if FLAGS.job_name == "ps":
    server.join()

  elif FLAGS.job_name == "worker":

    variable_initializer = tf.random_uniform_initializer(-0.05, 0.05)
    bytes_per_term_bucket = 12 * 4
    term_hash_bucket_size = int(10 * 1024 * 1024 * 1024 / bytes_per_term_bucket)
    W_term_embeddings = tf.get_variable("W_term_embeddings", [term_hash_bucket_size, 12], dtype=tf.float32, initializer=variable_initializer)
    global_var_init_op = tf.variables_initializer(tf.global_variables())
    sess_config = tf.ConfigProto(
        device_filters=['/job:ps', '/job:worker/task:%d' % 0],
        allow_soft_placement=True,
        graph_options=tf.GraphOptions(enable_bfloat16_sendrecv=True))
    sess = tf.Session(target=server.target, config=sess_config)
    #sess.run([global_var_init_op], options=tf.RunOptions(timeout_in_ms=600 * 1000, trace_level=tf.RunOptions.FULL_TRACE), run_metadata=tf.RunMetadata())
    #print("Successfully initialized")
    #sess.run(tf.scatter_add(W_term_embeddings, term_hash_bucket_size - 1, [-0.3, -9.0, -12.1, 12.0, 1.0, 6.0, 3.0, 0.34, 3.9, 0.89, 0.13, 0.398090]))
    print(sess.run(tf.gather(W_term_embeddings, term_hash_bucket_size - 1)))

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