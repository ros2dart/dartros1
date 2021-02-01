// Auto-generated. Do not edit!

// (in-package common_msgs.srv)

import 'dart:convert';
import 'package:buffer/buffer.dart';
import 'package:dartros/msg_utils.dart';

//-----------------------------------------------------------

//-----------------------------------------------------------

class MoveBlockRequest extends RosMessage<MoveBlockRequest> {
  int color;

  int shape;

  static MoveBlockRequest empty$ = MoveBlockRequest();
  MoveBlockRequest({
    int? color,
    int? shape,
  })  : this.color = color ?? 0,
        this.shape = shape ?? 0;

  MoveBlockRequest call({
    int? color,
    int? shape,
  }) =>
      MoveBlockRequest(
        color: color,
        shape: shape,
      );

  void serialize(ByteDataWriter writer) {
    // Serializes a message object of type MoveBlockRequest
    // Serialize message field [color]
    writer.writeUint8(color);
    // Serialize message field [shape]
    writer.writeUint8(shape);
  }

  @override
  MoveBlockRequest deserialize(ByteDataReader reader) {
    //deserializes a message object of type MoveBlockRequest
    final data = MoveBlockRequest();
    // Deserialize message field [color]
    data.color = reader.readUint8();
    // Deserialize message field [shape]
    data.shape = reader.readUint8();
    return data;
  }

  int getMessageSize() {
    return 2;
  }

  @override
  String get fullType {
    // Returns string type for a service object
    return 'common_msgs/MoveBlockRequest';
  }

  @override
  String get md5sum {
    //Returns md5sum for a message object
    return '1d682ebcbca7dac8445c0278f8ac56d2';
  }

  @override
  String get messageDefinition {
    // Returns full string definition for message
    return '''uint8 color
uint8 shape
string RED = "r"
string BLUE = "b"
string PURPLE = "p"
string square = "s"
string triangle = "t"
string circle = "c"

''';
  }

// Constants for message
  static const String RED = '"r"';
  static const String BLUE = '"b"';
  static const String PURPLE = '"p"';
  static const String SQUARE = '"s"';
  static const String TRIANGLE = '"t"';
  static const String CIRCLE = '"c"';
}

class MoveBlockResponse extends RosMessage<MoveBlockResponse> {
  bool wasSuccessful;

  bool outOfReach;

  static MoveBlockResponse empty$ = MoveBlockResponse();
  MoveBlockResponse({
    bool? wasSuccessful,
    bool? outOfReach,
  })  : this.wasSuccessful = wasSuccessful ?? false,
        this.outOfReach = outOfReach ?? false;

  MoveBlockResponse call({
    bool? wasSuccessful,
    bool? outOfReach,
  }) =>
      MoveBlockResponse(
        wasSuccessful: wasSuccessful,
        outOfReach: outOfReach,
      );

  void serialize(ByteDataWriter writer) {
    // Serializes a message object of type MoveBlockResponse
    // Serialize message field [wasSuccessful]
    writer.writeUint8(wasSuccessful == false ? 0 : 1);
    // Serialize message field [outOfReach]
    writer.writeUint8(outOfReach == false ? 0 : 1);
  }

  @override
  MoveBlockResponse deserialize(ByteDataReader reader) {
    //deserializes a message object of type MoveBlockResponse
    final data = MoveBlockResponse();
    // Deserialize message field [wasSuccessful]
    data.wasSuccessful = reader.readUint8() != 0;
    // Deserialize message field [outOfReach]
    data.outOfReach = reader.readUint8() != 0;
    return data;
  }

  int getMessageSize() {
    return 2;
  }

  @override
  String get fullType {
    // Returns string type for a service object
    return 'common_msgs/MoveBlockResponse';
  }

  @override
  String get md5sum {
    //Returns md5sum for a message object
    return '65c3f42cd1561b9544e1716a7f538b30';
  }

  @override
  String get messageDefinition {
    // Returns full string definition for message
    return '''bool wasSuccessful
bool outOfReach

''';
  }
}

class MoveBlock extends RosServiceMessage<MoveBlockRequest, MoveBlockResponse> {
  static final empty$ = MoveBlock();
  @override
  MoveBlockRequest get request => MoveBlockRequest.empty$;
  @override
  MoveBlockResponse get response => MoveBlockResponse.empty$;
  @override
  String get md5sum => '5674452fd9a3e6471d92b38af266a35b';
  @override
  String get fullType => 'common_msgs/MoveBlock';
}
