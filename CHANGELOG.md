## 0.1.0
- Stable null-safe release

## 0.1.0-nullsafety.1
- Fix nullable type in simple action server

## 0.1.0-nullsafety.0
- Update to nullsafety

## 0.0.5+4
- Adjust ROS_MASTER_URI logic slightly and add tests

## 0.0.5+3
- Try making web compatible (as a package in dependencies - not actually run on web)

## 0.0.5+1
- Fix an issue with home directory on Android and an issue with dependencies
  
## 0.0.5
- Update Actions and Services to not require as many type parameters especially when creating them

## 0.0.4+7
- Update dependencies

## 0.0.4+6
- Fix SimpleActionClient and Server thanks to @knuesel

## 0.0.4+5
- Update README.md and link to external documentation website
  
## 0.0.4+4
- Fix for several issues with shutdown thanks to @knuesel
  
## 0.0.4+3
- Fix for parameters thanks to @knuesel
  
## 0.0.4+2
- Update to latest message generation
  
## 0.0.4+1
- Fix an issue with rosservice servers
  
## 0.0.4
- Fix an issue with added UDP support with subscribers
- Added type parameter to return value of subscriber
- Add some tests

## 0.0.3+10
- Add preliminary UDP support, and use IP address to enable working on local network
  
## 0.0.3+9
- Fix service server issue with deserializing request
  
## 0.0.3+8
- Finish fixing bus info from node via rqt_graph
  
## 0.0.3+7
- Fix exception when getting bus info from node via rqt_graph
  
## 0.0.3+6
- Export NodeHandle class. Still need work on generating action messages

## 0.0.3+5
- Try to fix a logging problem when used with flutter

## 0.0.3+4
- Attempt to publish with documentation as well as updated dependencies

## 0.0.3+3
- Added documentation

## 0.0.3+2
- Fixed actionlib messages

## 0.0.3+1
- Fixed actionlib interface
 
## 0.0.3
- Added type for actionlib msgs, required for development of them
- v0.0.4 should contain a basic implementation of actions

## 0.0.2+1
- Better logging and some cleanup of print statements

## 0.0.2

- Publisher, subscriber, service client, and service server working in limited tests
- Getting / setting parameters working in limited tests
 
## 0.0.1

- Initial version, starting to expose it publicly to enable pub dependency, still a work in progress

