From rosnodejs:

src/ros_msg_utils/ -- done

src/utils/
* xmlrpc_utils.js -- done
* time_utils.js -- done
* tcpros_utils.js -- done
* remapping_utils.js -- done
* message_utils.js -- ignore (not dynamically requiring packages)
* event_utils.js -- ignore (simple rebroadcast)
* xmlrpcclient.js -- later (don't need incremental backoff and multiple attempts for rpc call yet)
* client_states.js -- done
??
* serialization_utils.js -- tcp stream stuff??
  
src/utils/messageGeneration -- ignore (don't do message generation this way)
src/utils/log -- later (logging could use some work, but this will be later)
src/utils/spinner -- ignore (using dart async streams is probably better, but might lose predictability or become overloaded)

tools -- ignore (no need for msg_flattening (done in gendart))

src/lib
* ActionClientInterface.js -- future
* ActionServerInterface.js -- future
* Logging.js -- future
* MasterApiClient.js -- done (I think, maybe some work with making classes for API results)
* Names.js -- done
* NodeHandle.js -- TODO
* ParamServerApiClient.js -- done (Except subscribe and unsubscribe to params)
* Publisher.js -- done
* RosNode.js -- TODO
* ServiceClient.js -- TODO
* ServiceServer.js -- TODO
* SlaveApiClient.js -- TODO
* Subscriber.js -- done
* ThisNode.js -- TODO
* Time.js -- started (need node done first)

src/lib/impl
* PublisherImpl.js -- TODO
* SubscriberImpl.js -- TODO