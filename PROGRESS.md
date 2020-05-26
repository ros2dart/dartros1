From rosnodejs:

src/ros_msg_utils/ -- done

src/utils/
* xmlrpc_utils.js -- done
* time_utils.js -- done
* tcpros_utils.js -- done
* remapping_utils.js -- done
* message_utils.js -- ignore (not dynamically requiring packages)
* event_utils.js -- ignore (not using event emitters in dart)
* xmlrpcclient.js -- later (don't need incremental backoff and multiple attempts for rpc call yet)
* client_states.js -- done
* serialization_utils.js -- done
  
src/utils/messageGeneration -- ignore (don't do message generation this way, dart is not that dynamic)
src/utils/log -- later (logging could use some work, but this will be later)
src/utils/spinner -- ignore for now (using dart async streams is probably better, but might lose predictability or become overloaded)

tools -- ignore (no need for msg_flattening (done in gendart))

src/lib
* ActionClientInterface.js -- in progress
* ActionServerInterface.js -- done I think
* Logging.js -- mostly done
* MasterApiClient.js -- done (I think, maybe some work with making classes for API results)
* Names.js -- done
* NodeHandle.js -- done, except ActionServer / Client
* ParamServerApiClient.js -- done (Except subscribe and unsubscribe to params)
* Publisher.js -- done
* RosNode.js -- done
* ServiceClient.js -- done
* ServiceServer.js -- done
* SlaveApiClient.js -- done
* Subscriber.js -- done
* ThisNode.js -- done
* Time.js -- done

src/lib/impl
* PublisherImpl.js -- done
* SubscriberImpl.js -- done, except some debug log statements

src/actions/
* ActionClient.js -- TODO
* ActionServer.js -- TODO
* ClientGoalHandle.js -- TODO
* ClientStates.js -- TODO
* GoalHandle.js -- TODO
* GoalIdGenerator -- done
* SimpleActionClient -- TODO
* SimpleActionServer -- TODO