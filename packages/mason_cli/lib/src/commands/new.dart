import 'package:args/command_runner.dart';
import 'package:mason/mason.dart';
import 'package:mason_cli/src/command.dart';
import 'package:path/path.dart' as p;
import 'package:recase/recase.dart';
import 'package:universal_io/io.dart';

/// {@template new_command}
/// `mason new` command which creates a new brick.
/// {@endtemplate}
class NewCommand extends MasonCommand {
  /// {@macro new_command}
  NewCommand({Logger? logger}) : super(logger: logger) {
    argParser.addOption(
      'desc',
      abbr: 'd',
      help: 'Description of the new brick template',
      defaultsTo: 'A new brick created with the Mason CLI.',
    );
  }

  @override
  final String description = 'Creates a new brick template.';

  @override
  final String name = 'new';

  @override
  Future<int> run() async {
    if (results.rest.isEmpty) {
      throw UsageException('Name of the new brick is required.', usage);
    }
    final bricksJson = localBricksJson;
    if (bricksJson == null) throw const MasonYamlNotFoundException();
    final name = results.rest.first.snakeCase;
    final description = results['desc'] as String;
    final directory = Directory(p.join(entryPoint.path, 'bricks'));
    final brickYaml = File(p.join(directory.path, name, BrickYaml.file));

    if (brickYaml.existsSync()) {
      logger.err('Existing brick: $name at ${brickYaml.path}');
      return ExitCode.usage.code;
    }

    final done = logger.progress('Creating new brick: $name.');
    final target = DirectoryGeneratorTarget(directory);
    final generator = _BrickGenerator(name, description);
    final newBrick = Brick.path(
      p
          .normalize(
            p.relative(
              brickYaml.parent.path,
              from: entryPoint.path,
            ),
          )
          .replaceAll(r'\', '/'),
    );
    final bricks = Map.of(masonYaml.bricks)..addAll({name: newBrick.location});

    try {
      await Future.wait([
        generator.generate(
          target,
          vars: <String, dynamic>{'name': '{{name}}'},
          logger: logger,
        ),
        if (!masonYaml.bricks.containsKey(name))
          masonYamlFile.writeAsString(Yaml.encode(MasonYaml(bricks).toJson())),
      ]);
      await bricksJson.add(newBrick);
      await bricksJson.flush();

      done('Created new brick: $name');
      logger
        ..info(
          '''${lightGreen.wrap('✓')} Generated ${generator.files.length} file(s):''',
        )
        ..flush(logger.detail);
      return ExitCode.success.code;
    } catch (_) {
      done();
      rethrow;
    }
  }
}

class _BrickGenerator extends MasonGenerator {
  _BrickGenerator(this.brickName, this.brickDescription)
      : super(
          '__new_brick__',
          'Creates a new brick.',
          files: [
            TemplateFile(
              p.join(brickName, BrickYaml.file),
              _brickYamlContent(brickName, brickDescription),
            ),
            TemplateFile(
              p.join(brickName, 'README.md'),
              _brickReadmeContent(brickName, brickDescription),
            ),
            TemplateFile(
              p.join(brickName, 'CHANGELOG.md'),
              _brickChangelogContent,
            ),
            TemplateFile(
              p.join(brickName, 'LICENSE'),
              _brickLicenseContent,
            ),
            TemplateFile(
              p.join(brickName, BrickYaml.dir, 'hello.md'),
              'Hello {{name}}!',
            ),
          ],
        );

  static String _brickYamlContent(String name, String description) => '''
name: $name
description: $description

# The following defines the version and build number for your brick.
# A version number is three numbers separated by dots, like 1.2.34
# followed by an optional build number (separated by a +).
version: 0.1.0+1

# The following defines the environment for the current brick.
# It includes the version of mason that the brick requires.
environment:
  mason: ">=0.1.0-dev <0.1.0"

# Variables specify dynamic values that your brick depends on.
# Zero or more variables can be specified for a given brick.
# Each variable has:
#  * a type (string, number, or boolean)
#  * an optional short description
#  * an optional default value
#  * an optional prompt phrase used when asking for the variable.
vars:
  name:
    type: string
    description: Your name
    default: Dash
    prompt: What is your name?
''';

  static String _brickReadmeContent(String name, String description) => '''
# $name

$description

_Generated by [mason][1] 🧱_

## Getting Started 🚀

This is a starting point for a new brick.
A few resources to get you started if this is your first brick template:

- [Official Mason Documentation][2]
- [Code generation with Mason Blog][3]
- [Very Good Livestream: Felix Angelov Demos Mason][4]

[1]: https://github.com/felangel/mason
[2]: https://github.com/felangel/mason/tree/master/packages/mason_cli#readme
[3]: https://verygood.ventures/blog/code-generation-with-mason
[4]: https://youtu.be/G4PTjA6tpTU
''';

  static const _brickChangelogContent = '''
# 0.1.0+1

- TODO: Describe initial release.
''';

  static const _brickLicenseContent = '''
TODO: Add your license here.
''';

  final String brickName;
  final String brickDescription;
}
