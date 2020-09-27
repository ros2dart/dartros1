import rospy
from std_msgs.msg import String

def main():
  rospy.init_node('Publisher')
  r = rospy.Rate(10)
  pub = rospy.Publisher('chatter', String, queue_size=10)
  while not rospy.is_shutdown():
    hello = "hello world {}".format(rospy.get_time())
    pub.publish(hello)
    r.sleep()


if __name__ == "__main__":
  try:
    main()
  except rospy.ROSInterruptException:
    pass