import 'package:string_validator/string_validator.dart';

class NameUtils {
  static String clean(String name) {
    final n = name.replaceAll('//', '/');
    if (n.endsWith('/')) {
      return n.substring(0, n.length - 1);
    }
    return n;
  }

  static String append(String left, String right) => clean('$left/$right');
  static bool _isValidCharInName(String char) =>
      isAlphanumeric(char) || char == '/' || char == '_';

  static bool validate(String name, {bool throwError = false}) {
    if (name.isEmpty) {
      return true;
    }
    final c = name[0];
    if (!isAlpha(c) && c != '/' && c != '~') {
      if (throwError) {
        throw Exception(
            'Character [$c] is not valid as the first character in Graph Resource Name [$name].  Valid characters are a-z, A-Z, / and in some cases ~.');
      }
      return false;
    }
    for (var i = 1; i < name.length; ++i) {
      if (!_isValidCharInName(name[i])) {
        if (throwError) {
          throw Exception(
              'Character [$c] at element [$i] is not valid in Graph Resource Name [$name].  Valid characters are a-z, A-Z, 0-9, / and _.');
        }
        return false;
      }
    }
    return true;
  }

  static List<Object> _parseResolveArgs(String namespace, List<Object> args) {
    var name = namespace;
    var ns = namespace;
    var remap = true;
    switch (args.length) {
      case 0:
        name = '';
        break;
      case 1:
        name = args[0] as String;
        break;
      case 2:
        if (args[1] is String) {
          ns = args[0] as String;
          name = args[1] as String;
        } else {
          name = args[0] as String;
          remap = args[1] as bool;
        }
        break;
      default:
        return args;
    }

    return [ns, name, remap];
  }

  static String remap(Map<String, String> remappings, String name) =>
      remappings[name] ?? name;

  static String parentNamespace(String name) {
    NameUtils.validate(name, throwError: true);

    if (name.isEmpty) {
      return '';
    } else if (name == '/') {
      return '/';
    }

    var p = name.lastIndexOf('/');
    if (p == name.length - 1) {
      p = name.lastIndexOf('/', p - 1);
    }

    if (p < 0) {
      return '';
    } else if (p == 0) {
      return '/';
    }
    return name.substring(0, p);
  }

  static String resolve(
      List<Object> args, Map<String, String> remappings, String namespace) {
    final a = _parseResolveArgs(namespace, args);
    final ns = a[0] as String;
    var name = a[1] as String;
    final remap = a[2] as bool;

    validate(name, throwError: true);

    if (name.isEmpty) {
      if (ns.isEmpty) {
        return '/';
      } else if (ns[0] == '/') {
        return ns;
      }
      return '/$namespace';
    }

    if (name.startsWith('~')) {
      name = name.replaceAll('~', '$namespace/');
    }

    if (!name.startsWith('/')) {
      name = '$namespace/$name';
    }

    name = clean(name);

    if (remap) {
      name = NameUtils.remap(remappings, name);
    }

    return name;
  }
}

class NameRemapping {
  NameRemapping(Map<String, String> remaps, this.namespace) {
    for (final left in remaps.keys) {
      if (!left.startsWith('_')) {
        final right = remaps[left];
        final resolvedLeft = resolve([left, false]);
        final resolvedRight = resolve([right!, false]);
        remappings[resolvedLeft] = resolvedRight;
      }
    }
  }
  Map<String, String> remappings = {};
  final String namespace;

  String remap(String name) => resolve([name, true]);
  String resolve(List<Object> args) =>
      NameUtils.resolve(args, remappings, namespace);
}
