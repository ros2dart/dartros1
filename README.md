A ROS Client Library implementation in Dart

Heavily inspired by the cpp and especially [nodejs](https://github.com/RethinkRobotics-opensource/rosnodejs) implementations (see footnote)

See the examples folder for examples, until I have time to create a better Readme and documentation.

I will be starting to add some more documentation on [this website](https://timwhiting.github.io/dartros/) as I have time.

## Message Generation
Message generation is implemented for dartros. You will need to clone [this ROS package](https://github.com/TimWhiting/gendart)
into your catkin workspace for messages to be generated. I'm not quite sure how to get this into the default ROS message generation pipeline, and not sure if it is stable or efficient enough yet to warrant that.

Essentially the basics are to clone the gendart repository into your catkin workspace, and then run catkin_make. As long as some catkin package depends on message generation it should generate messages. I'm trying to remember if there was anything else I needed to make it work.

The generated messages will be in the devel folder of your workspace more specifically: `devel/share/gendart/ros/{name_of_msg_package}`.

You can depend on this in your dart node via a path dependency.
Assuming your dart node is in the src folder this would look like this:
```yaml
# pubspec.yaml
dependencies:
  sensor_msgs:
    path: ../../devel/share/gendart/ros/sensor_msgs
```

Then to use it to publish an image you might do something like this:
```dart
import 'package:dartros/dartros.dart';
import 'package:dartx/dartx.dart';
import 'package:sensor_msgs/msgs.dart';

Future<void> main(List<String> args) async {
  final node = await initNode('test_node', args);
  final img_msg = Image(
      header: null,
      height: 600,
      width: 1024,
      encoding: 'rgba8',
      is_bigendian: 0,
      step: 1024 * 4,
      data: List.generate(600 * 1024 * 4, (_) => 255));
  final pub = node.advertise<Image>('/robot/head_display', Image.$prototype);
  await Future.delayed(2.seconds);
  while (true) {
    pub.publish(img_msg, 1);
    await Future.delayed(2.seconds);
  }
}
```

However, the following message packages are published to `pub.dev` for a better experience creating libraries around them, or they are part of the dartros implementation and therefore needed to be published to `pub.dev`:
* std_msgs
* sensor_msgs
* rosgraph_msgs
* geometry_msgs
* actionlib_msgs

Depend on them through a regular pub dependency to ensure no conflicts with the message versions.


## Feature Status
At a high level the things that have been tested are:
* Publish and Subscribe (TCP)
* Services
* Message Generation for messages and services
* Connecting to a ROS master that is not localhost

Not tested:
* Publish and Subscribe (UDP)

Still in the works:
* Actions and ActionServers, needs action message generation work, and then some updates to the action server implementation.


### Notes

Heavily inspired by the cpp and especially [nodejs](https://github.com/RethinkRobotics-opensource/rosnodejs) implementation


* I did not directly use any of the nodejs source code since this is an implementation in a different language using different libraries.
However, I want to make sure I attribute them properly, since a large portion of the code is structured similarly, and I used their
implementation as a reference. You can find their license included in the source code of this library.
