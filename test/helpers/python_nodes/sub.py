import rospy
from std_msgs.msg import String, Bool
pub = None
def callback(data):
  print(data)
  pub.publish(True)

def main():
  rospy.init_node('Subscriber')
  pub = rospy.Publisher('got_it', Bool, queue_size=10)
  sub = rospy.Subscriber('chatter', String, callback)
  rospy.spin()

if __name__ == "__main__":
  try:
    main()
  except rospy.ROSInterruptException:
    pass