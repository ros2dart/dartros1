# Overview of dartros flutter examples

## Hardware setup
In order to test the example code inside this folder you need to setup your network communication. There are quite a few situations when this can go wrong. It is not an issue with this dart package but most likely with the used hardware. Here is an illustration of an example setup:
![An example hardware setup illustrated](images/HardwareSetup.svg "An example hardware setup illustrated")

In case you face any issues, first try to see if you can learn from the issues by other users and avoid these situations. For example, in issue https://github.com/TimWhiting/dartros/issues/39 it was important to set the `ROS_MASTER_URI` environment variable to the specific ip address of the device where "roscore" is running (e.g. `export ROS_MASTER_URI=http://192.168.2.142:11311/`) instead of using `export ROS_MASTER_URI=http://localhost:11311/`. In general it is recommended to set all three environment variables correctly, namely `ROS_MASTER_URI`, `ROS_HOSTNAME` and `ROS_IP` on all devices that should communicate via ROS (see https://wiki.ros.org/ROS/EnvironmentVariables for more information). And in issue https://github.com/TimWhiting/dartros/issues/46 the communication was blocked when a WIFI hotspot was used but did work with a dedicated WIFI router.


## Example code

### 1.) client.dart
This example demonstrates...
### 2.) dartros_example.dart
This example demonstrates...
### 3.) pub.dart
This example demonstrates how to create a Publisher and publish a string with a custom ROS node from your own app.
### 4.) pub2.dart
This example demonstrates how to create a Publisher which will connect to a ROS Master node on the same device and publishes a string with a custom ROS node.
### 5.) pub_image.dart
This example demonstrates how to create a Publisher and publish an image which is procedurally generated using a generator method of a flutter List object.

MISSING: explanation of how to get the package used for message creation in the third line (`import 'package:sensor_msgs/msgs.dart';`)
### 6.) server.dart
This example demonstrates...
### 7.) service_message_example.dart
This example demonstrates...
### 8.) sub.dart
This example demonstrates how to create a Subscriber which will listen to a chat message (string) within an infinite loop. You can use this in combination with Example 3 which publishes these chat message.

