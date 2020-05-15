class SPECIAL_KEYS {
  static const name = '__name';
  static const log = '__log';
  static const ip = '__ip';
  static const hostname = '__hostname';
  static const master = '__master';
  static const ns = '__ns';
}

Map<String, String> processRemapping(List<String> args) {
  final len = args.length;

  final remapping = <String, String>{};

  for (var i = 0; i < len; ++i) {
    final arg = args[i];
    final p = arg.indexOf(':=');
    if (p >= 0) {
      final local = arg.substring(0, p);
      final ext = arg.substring(p + 2);
      remapping[local] = ext;
    }
  }
  return remapping;
}
