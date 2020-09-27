import 'dart:io';

Future<Process> startRosCore() async {
  return Process.start('roscore', [], runInShell: true);
}

Future<Process> startPythonNode(String name) async {
  return Process.start('python', ['test/helpers/python_nodes/$name.py'],
      runInShell: true);
}
