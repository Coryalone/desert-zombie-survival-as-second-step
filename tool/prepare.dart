import 'dart:io';

Future<void> main() async {
  final root = Directory.current;
  if (!File('pubspec.yaml').existsSync() ||
      !File('tool/android/AndroidManifest.xml').existsSync()) {
    throw StateError('Run from the project folder.');
  }
  final required = [
    'android/app/build.gradle.kts',
    'android/settings.gradle.kts',
    'android/gradlew',
    'web/index.html',
    '.metadata',
  ];
  if (required.any((path) => !File(path).existsSync())) {
    final stage = Directory.systemTemp.createTempSync('desert-highway-');
    try {
      final result = await Process.run('flutter', [
        'create', '--platforms=android,web', '--org=com.coryalone',
        '--project-name=desert_zombie_survival', '--no-pub', stage.path,
      ], runInShell: Platform.isWindows);
      stdout.write(result.stdout);
      stderr.write(result.stderr);
      if (result.exitCode != 0) {
        throw StateError('Flutter platform generation failed.');
      }
      for (final platform in ['android', 'web']) {
        copyMissing(Directory('${stage.path}/$platform'),
            Directory('${root.path}/$platform'));
      }
      final metadata = File('.metadata');
      if (!metadata.existsSync()) {
        File('${stage.path}/.metadata').copySync(metadata.path);
      }
    } finally {
      // Only the unique directory returned by createTempSync is removed.
      if (stage.existsSync()) stage.deleteSync(recursive: true);
    }
  }
  for (final path in required) {
    if (!File(path).existsSync()) throw StateError('Missing platform file: $path');
  }
  File('tool/android/AndroidManifest.xml')
      .copySync('android/app/src/main/AndroidManifest.xml');
  final xml = Directory('android/app/src/main/res/xml')..createSync(recursive: true);
  File('tool/android/data_extraction_rules.xml')
      .copySync('${xml.path}/data_extraction_rules.xml');
  for (final mode in ['debug', 'profile']) {
    Directory('android/app/src/$mode').createSync(recursive: true);
    File('android/app/src/$mode/AndroidManifest.xml').writeAsStringSync(
      '<manifest xmlns:android="http://schemas.android.com/apk/res/android"/>\n',
    );
  }
  stdout.writeln('Android and Web ready. App manifests contain no INTERNET permission.');
}

void copyMissing(Directory source, Directory destination) {
  destination.createSync(recursive: true);
  for (final entry in source.listSync()) {
    final name = entry.uri.pathSegments.where((part) => part.isNotEmpty).last;
    final target = '${destination.path}/$name';
    if (entry is Directory) {
      copyMissing(entry, Directory(target));
    } else if (entry is File && !File(target).existsSync()) {
      entry.copySync(target);
    }
  }
}
