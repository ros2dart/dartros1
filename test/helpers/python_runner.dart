import 'dart:io';

Future<Process> startRosCore() async =>
    Process.start('roscore', [], runInShell: true);

Future<Process> startRosCore2() async => Process.start('roscore -p 6001', [],
    runInShell: true, environment: {'ROS_MASTER_URI': 'http://localhost:6001'});

Future<Process> startPythonNode(String name) async =>
    Process.start('python', ['test/helpers/python_nodes/$name.py'],
        runInShell: true);
