import 'dart:io';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:dartros/src/utils/tcpros_utils.dart' as tcp;
import 'package:dartros_msgutils/msg_utils.dart';
import 'package:dartx/dartx.dart';

import 'error_utils.dart';

const callerIdPrefix = 'callerid=';
const md5Prefix = 'md5sum=';
const topicPrefix = 'topic=';
const typePrefix = 'type=';
const messageDefinitionPrefix = 'message_definition=';

void serializeStringFields(ByteDataWriter writer, List<String> fields) {
  final totalLength = fields.map((f) => f.lenInBytes + 4).sum();
  writer.writeUint32(totalLength, Endian.little);
  fields.forEach(writer.writeString);
}

// TODO: UDP Services??

List<String> deserializeStringFields(ByteDataReader reader) {
  // final totalLength = reader.readUint32(Endian.little);
  final totalLength = reader.remainingLength;
  // print('Total length of string fields $totalLength');
  final stringList = <String>[];
  var length = 0;
  while (length < totalLength) {
    final string = reader.readString();
    length += string.lenInBytes + 4;
    // print('Read string $string, length $length');
    stringList.add(string);
  }
  return stringList;
}

void createSubHeader(ByteDataWriter writer, String callerId, String md5sum,
        String topic, String type) =>
    serializeStringFields(writer, [
      callerIdPrefix + callerId,
      md5Prefix + md5sum,
      topicPrefix + topic,
      typePrefix + type,
    ]);

void createPubHeader(ByteDataWriter writer, String callerId, String md5sum,
    String type, String messageDefinition) {
  final fields = [
    callerIdPrefix + callerId,
    md5Prefix + md5sum,
    typePrefix + type,
    messageDefinitionPrefix + messageDefinition,
  ];
  serializeStringFields(writer, fields);
}

bool validateSubHeader(ByteDataWriter writer, tcp.TCPRosHeader header,
    String topic, String type, String md5sum) {
  if (header.topic.isNullOrEmpty) {
    writer.writeString('Connection header missing expected field [topic]');
    return false;
  }
  if (header.type.isNullOrEmpty) {
    writer.writeString('Connection header missing expected field [type]');
    return false;
  }
  if (header.md5sum.isNullOrEmpty) {
    writer.writeString('Connection header missing expected field [md5sum]');
    return false;
  }
  if (header.topic != topic) {
    writer
        .writeString('Got incorrect topic [${header.topic}] expected [$topic]');
    return false;
  }
  if (header.type != type && header.type != '*') {
    writer.writeString('Got incorrect type [${header.type}] expected [$type]');
    return false;
  }
  if (header.md5sum != md5sum && header.md5sum != '*') {
    writer.writeString(
        'Got incorrect md5sum [${header.md5sum}] expected [$md5sum]');
    return false;
  }
  return true;
}

bool validatePubHeader(ByteDataWriter writer, tcp.TCPRosHeader header,
    String type, String md5sum) {
  if (header.type.isNullOrEmpty) {
    writer.writeString('Connection header missing expected field [type]');
    return false;
  }
  if (header.md5sum.isNullOrEmpty) {
    writer.writeString('Connection header missing expected field [md5sum]');
    return false;
  }

  if (header.type != type && header.type != '*') {
    writer.writeString('Got incorrect type [${header.type}] expected [$type]');
    return false;
  }
  if (header.md5sum != md5sum && header.md5sum != '*') {
    writer.writeString(
        'Got incorrect md5sum [${header.md5sum}] expected [$md5sum]');
    return false;
  }
  return true;
}

Uint8List serializeMessage(ByteDataWriter writer, RosMessage message,
    {bool prependMessageLength = true}) {
  final msgSize = message.getMessageSize();
  if (prependMessageLength) {
    writer.writeUint32(msgSize);
  }
  message.serialize(writer);
  return writer.toBytes();
}

T deserializeMessage<T extends RosMessage>(
        ByteDataReader reader, T messageClass) =>
    messageClass.deserialize(reader);

void createTcpRosError(ByteDataWriter writer, String str) {
  writer.writeString(str);
}

// TODO: Separate this out from header vs recv header fields
class UDPRosHeader<T> {
  const UDPRosHeader(this.opCode, this.connectionId, this.msgId, this.blkN,
      this.callerId, this.md5, this.topic, this.type, this.messageDefinition);
  factory UDPRosHeader.deserialize(ByteDataReader reader) {
    if (reader.remainingLength < 8) {
      throw HeaderParseException(
          {}, 'Invalid UDPRosHeader remainingLength < 8');
    } else {
      final conId = reader.readUint32();
      final op = reader.readUint8();
      final msg = reader.readUint8();
      final blkN = reader.readUint16();
      return UDPRosHeader(conId, op, msg, blkN, '', '', '', '', '');
    }
  }
  factory UDPRosHeader.parse(String header) {
    final reader = ByteDataReader(endian: Endian.little);
    reader.add(header.toUtf8());
    final Map<String?, String?> info = <String, String?>{};
    final regex = RegExp(r'(\w+)=([\s\S]*)');
    final fields = deserializeStringFields(reader);
    // print(fields);
    for (final field in fields) {
      final hasMatch = regex.hasMatch(field);
      if (!hasMatch) {
        print('Error: Invalid connection header while parsing field $field');
        throw HeaderParseException(info,
            'Error: Invalid connection header while parsing field $field');
      }
      final match = regex.allMatches(field).toList()[0];
      info[match.group(1)] = match.group(2);
    }
    // print(info);
    return UDPRosHeader(
      null,
      null,
      null,
      null,
      info['callerid'],
      info['md5sum'],
      info['topic'],
      info['type'],
      info['message_definition'],
    );
  }
  final String? callerId;
  final String? md5;
  final String? topic;
  final String? type;
  final String? messageDefinition;
  final int? opCode;
  final int? connectionId;
  final int? msgId;
  final int? blkN;

  void serialize(ByteDataWriter writer) {
    writer.writeUint32(connectionId!);
    writer.writeUint8(opCode!);
    writer.writeUint8(msgId!);
    writer.writeUint16(blkN!);
  }
}

class UdpConnection {
  UdpConnection(this.socket)
      : name = '${socket.remoteAddress.address}:${socket.remotePort}';
  final RawSocket socket; // TODO: replace with RawDatagramSocket?
  final String name;
}
