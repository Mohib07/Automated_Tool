import 'dart:io';

import 'package:automated_tool/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class IntegrationTool extends StatefulWidget {
  const IntegrationTool({super.key});

  @override
  _IntegrationToolState createState() => _IntegrationToolState();
}

class _IntegrationToolState extends State<IntegrationTool> {
  String? selectedDirectory;

  Future<void> selectDirectory() async {
    String? directory = await FilePicker.platform.getDirectoryPath();
    if (directory != null) {
      File pubspec = File('$directory/pubspec.yaml');
      if (pubspec.existsSync()) {
        setState(() {
          selectedDirectory = directory;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Not a valid Flutter project: pubspec.yaml not found')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Integration Tool')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: selectDirectory,
              child: const Text('Select Flutter Project'),
            ),
            const SizedBox(height: 20),
            if (selectedDirectory != null) Text('Selected: $selectedDirectory'),
            //
            const SizedBox(height: 20),
            if (selectedDirectory != null)
              ElevatedButton(
                onPressed: () async {
                  final apiKey = await promptForApiKey(context);
                  await addPackage(selectedDirectory!, context);
                  await configureAndroid(selectedDirectory!, apiKey);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Integration completed')),
                  );
                },
                child: const Text('Integrate Google Maps'),
              ),
            const SizedBox(height: 40),

            // Navigate to Map Screen
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MapScreen(),
                    ));
              },
              child: const Text('Navigate to Map Screen'),
            ),

            // ElevatedButton(
            //   onPressed: () => promptForApiKey(context),
            //   child: const Text('Add API Key'),
            // ),
          ],
        ),
      ),
    );
  }
}

//

Future<void> addPackage(String projectDir, BuildContext context) async {
  final pubspecFile = File('$projectDir/pubspec.yaml');
  String content = await pubspecFile.readAsString();

  if (content.contains('google_maps_flutter')) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('google_maps_flutter already exists.')),
    );
    print('google_maps_flutter already exists.');
    return;
  }

  final lines = content.split('\n');
  final buffer = StringBuffer();
  bool added = false;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    buffer.writeln(line);

    if (!added && line.trim() == 'dependencies:') {
      // Get indentation from the next line or default to 2 spaces
      final nextLine = i + 1 < lines.length ? lines[i + 1] : '';
      final indent = RegExp(r'^(\s*)').firstMatch(nextLine)?.group(1) ?? '  ';
      buffer.writeln('${indent}google_maps_flutter: ^2.6.0');
      added = true;
    }
  }

  await pubspecFile.writeAsString(buffer.toString());

  final result = await Process.run('flutter', ['pub', 'get'],
      workingDirectory: projectDir);
  print(result.stdout);
  if (result.exitCode != 0) print(result.stderr);
}

//

Future<String?> promptForApiKey(BuildContext context) async {
  TextEditingController controller = TextEditingController();
  return await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Enter Google Maps API Key'),
      content: TextField(controller: controller),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Skip')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Submit')),
      ],
    ),
  );
}

//

Future<void> configureAndroid(String projectDir, String? apiKey) async {
  final manifestPath = '$projectDir/android/app/src/main/AndroidManifest.xml';
  final manifestFile = File(manifestPath);
  String content = await manifestFile.readAsString();

  // Add required permissions if missing
  if (!content.contains('ACCESS_FINE_LOCATION')) {
    content = content.replaceFirst('</manifest>', '''
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-permission android:name="android.permission.INTERNET"/>
  </manifest>
''');
  }

  // Handle API key update or insert
  if (apiKey != null) {
    final apiKeyPattern = RegExp(
      r'<meta-data\s+android:name="com\.google\.android\.geo\.API_KEY"\s+android:value=".*?"\s*/>',
    );

    final metaTag = '''<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="$apiKey"/>''';

    if (apiKeyPattern.hasMatch(content)) {
      // Replace existing API key tag
      content = content.replaceAll(apiKeyPattern, metaTag);
    } else {
      // Insert new API key tag under <application>
      content =
          content.replaceFirst('<application', '$metaTag\n  <application');
    }
  }

  await manifestFile.writeAsString(content);
}
