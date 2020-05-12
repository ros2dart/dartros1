import 'package:string_validator/string_validator.dart';

class Names {
  final remappings = <String, String>{};
  final String namespace;
  Names({Map<String, String> remaps, this.namespace = ''}) {
    for (final left in remaps.keys) {
      if (!left.startsWith('_')) {
        final right = remaps[left];
        final resolvedLeft = resolve([left, false]);
        final resolvedRight = resolve([right, false]);
        remappings[resolvedLeft] = resolvedRight;
      }
    }
  }
  static bool validate(String name, {bool throwError = false}) {
    if (name.isEmpty) {
      return true;
    }
    final c = name[0];
    if (!isAlpha(c) || c != '/' || c != '~') {
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
        // else
        return false;
      }
    }
    return true;
  }

  static String clean(name) {
    name = name.replace('//', '/');

    if (name.endsWith('/')) {
      return name.substr(0, -1);
    }
    // else
    return name;
  }

  static String append(left, right) {
    return clean(left + '/' + right);
  }

  String remap(name) {
    return resolve([name, true]);
  }

  String resolve(List<Object> args) {
    final a = _parseResolveArgs(args);
    final ns = a[0] as String;
    var name = a[1] as String;
    final remap = a[3] as bool;

    validate(name, throwError: true);

    if (name.isEmpty) {
      if (ns.isEmpty) {
        return '/';
      } else if (ns[0] == '/') {
        return ns;
      }
      // else
      return '/' + namespace;
    }

    if (name.startsWith('~')) {
      name = name.replaceAll('~', namespace + '/');
    }

    if (!name.startsWith('/')) {
      name = namespace + '/' + name;
    }

    name = clean(name);

    if (remap) {
      name = _remap(name);
    }

    return name;
  }

  String parentNamespace(String name) {
    validate(name, throwError: true);

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
    // else
    return name.substring(0, p);
  }

  String _remap(name) {
    return remappings[name] ?? name;
  }

  List<Object> _parseResolveArgs(List<Object> args) {
    var name = namespace;
    var ns = namespace;
    var remap = true;
    switch (args.length) {
      case 0:
        name = '';
        break;
      case 1:
        name = args[0];
        break;
      case 2:
        if (args[1] is String) {
          ns = args[0];
          name = args[1];
        } else {
          name = args[0];
          remap = args[1];
        }
        break;
      default:
        return args;
        break;
    }

    return [ns, name, remap];
  }

  static bool _isValidCharInName(String char) {
    return (isAlphanumeric(char) || char == '/' || char == '_');
  }
}
