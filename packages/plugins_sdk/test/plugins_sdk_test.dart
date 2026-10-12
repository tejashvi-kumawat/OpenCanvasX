import 'dart:convert';
import 'dart:io';

import 'package:document_model/document_model.dart';
import 'package:plugins_sdk/plugins_sdk.dart';
import 'package:test/test.dart';

const pageId = PageId('p');

DesignDocument doc() {
  final rect = DesignObject(
    id: const ObjectId('r'),
    type: ObjectType.rect,
    pageId: pageId,
    transform: ObjectTransform(x: 10, y: 20, width: 100, height: 50),
    style: ObjectStyle(fill: SolidFill(ArgbColor(0xFF3256F0))),
  );
  return DesignDocument(
    id: const DocumentId('d'),
    metadata: const DocumentMetadata(title: 'Doc'),
    pages: [
      DesignPage(
        id: pageId,
        width: 1000,
        height: 800,
        objectIds: const [ObjectId('r')],
      ),
    ],
    objects: {rect.id: rect},
  );
}

String manifest({
  List<String> permissions = const ['write_document'],
  List<String> command = const ['python', 'main.py'],
  int api = 1,
}) => jsonEncode({
  'id': 'org.example.test',
  'name': 'Test',
  'version': '1.0.0',
  'api': api,
  'permissions': permissions,
  'entry': {'command': command},
  'commands': [
    {
      'id': 'go',
      'title': 'Go',
      'inputs': [
        {'id': 'n', 'label': 'N', 'type': 'number', 'default': 2},
      ],
    },
  ],
});

Point2D measure(TextPayload t) =>
    Point2D(t.text.length * t.fontSize * 0.5, t.fontSize * 1.2);

ObjectId Function() ids() {
  var n = 0;
  return () => ObjectId('new${n++}');
}

void main() {
  group('manifest', () {
    test('parses permissions, commands and inputs', () {
      final m = PluginManifest.parse(
        manifest(permissions: ['read_selection', 'write_document', 'teleport']),
      );
      expect(m.permissions, {
        PluginPermission.readSelection,
        PluginPermission.writeDocument,
      });
      expect(m.unknownPermissions, ['teleport']);
      expect(m.commands.single.inputs.single.defaultValue, 2);
      expect(m.hash, hasLength(64));
    });

    test('rejects broken or unsafe manifests', () {
      expect(() => PluginManifest.parse('nope'), throwsFormatException);
      expect(
        () => PluginManifest.parse(manifest(api: 99)),
        throwsFormatException,
      );
      expect(
        () => PluginManifest.parse(manifest(command: ['../../evil.exe'])),
        throwsFormatException,
      );
      expect(
        () => PluginManifest.parse(manifest(command: [])),
        throwsFormatException,
      );
      final badId = (jsonDecode(manifest()) as Map)..['id'] = 'Bad Id!';
      expect(
        () => PluginManifest.parse(jsonEncode(badId)),
        throwsFormatException,
      );
    });
  });

  group('request', () {
    test('only includes what permissions allow', () {
      final writeOnly = PluginManifest.parse(manifest());
      final r1 = buildPluginRequest(
        manifest: writeOnly,
        command: 'go',
        inputs: const {'n': 2},
        document: doc(),
        pageId: pageId,
        selection: {const ObjectId('r')},
      );
      expect(r1.containsKey('selection'), isFalse);
      expect(r1.containsKey('document'), isFalse);
      expect((r1['page']! as Map)['width'], 1000);

      final reader = PluginManifest.parse(
        manifest(permissions: ['read_selection']),
      );
      final r2 = buildPluginRequest(
        manifest: reader,
        command: 'go',
        inputs: const {},
        document: doc(),
        pageId: pageId,
        selection: {const ObjectId('r')},
      );
      final sel = (r2['selection']! as List).single as Map;
      expect(sel['id'], 'r');
      expect(sel['fill'], '#3256f0');
      expect(r2.containsKey('document'), isFalse);
    });
  });

  group('operations', () {
    PluginEffect run(Object? response, {Set<PluginPermission>? perms}) =>
        applyPluginResponse(
          doc(),
          pageId,
          response,
          permissions: perms ?? {PluginPermission.writeDocument},
          measure: measure,
          newId: ids(),
        );

    test('create, update and delete become one change', () {
      final effect = run({
        'operations': [
          {
            'op': 'create_shape',
            'shape': 'ellipse',
            'x': 0,
            'y': 0,
            'width': 50,
            'height': 50,
            'fill': '#FF000080',
          },
          {'op': 'create_text', 'text': 'Hi', 'x': 5, 'y': 5, 'size': 20},
          {'op': 'update', 'id': 'r', 'name': 'Card', 'x': 300},
          {'op': 'notify', 'message': 'Done'},
        ],
      });
      final (after, undo) = effect.change.applyTo(doc());
      expect(after.pages.single.objectIds, hasLength(3));
      expect(
        after.objects[const ObjectId('new0')]!.style!.fill,
        SolidFill(ArgbColor(0x80FF0000)),
      );
      expect(after.objects[const ObjectId('r')]!.name, 'Card');
      expect(after.objects[const ObjectId('r')]!.transform.x, 300);
      expect(effect.messages, ['Done']);
      expect(effect.created, hasLength(2));
      expect(undo.applyTo(after).$1, doc());

      final deleted = run({
        'operations': [
          {'op': 'delete', 'id': 'r'},
        ],
      });
      expect(deleted.change.applyTo(doc()).$1.objects, isEmpty);
    });

    test('writes need the write permission', () {
      expect(
        () => run(
          {
            'operations': [
              {'op': 'delete', 'id': 'r'},
            ],
          },
          perms: {PluginPermission.readSelection},
        ),
        throwsFormatException,
      );
      // Notifications are always allowed.
      expect(
        run({
          'operations': [
            {'op': 'notify', 'message': 'hi'},
          ],
        }, perms: const {}).messages,
        ['hi'],
      );
    });

    test('hostile operations are refused as a whole', () {
      for (final bad in [
        'not a map',
        {'operations': 'x'},
        {
          'operations': [
            {'op': 'format_disk'},
          ],
        },
        {
          'operations': [
            {
              'op': 'create_shape',
              'shape': 'rect',
              'x': double.nan,
              'y': 0,
              'width': 1,
              'height': 1,
            },
          ],
        },
        {
          'operations': [
            {
              'op': 'create_shape',
              'shape': 'rect',
              'x': 1e12,
              'y': 0,
              'width': 1,
              'height': 1,
            },
          ],
        },
        {
          'operations': [
            {'op': 'update', 'id': 'nope'},
          ],
        },
        {
          'operations': [
            {
              'op': 'create_svg',
              'svg': '<svg><script>alert(1)</script></svg>',
              'x': 0,
              'y': 0,
              'width': 10,
              'height': 10,
            },
          ],
        },
        {
          'operations': [
            {
              'op': 'create_shape',
              'shape': 'rect',
              'x': 0,
              'y': 0,
              'width': 1,
              'height': 1,
              'fill': 'red',
            },
          ],
        },
        {
          'operations': [
            for (var i = 0; i <= maxPluginOperations; i++)
              {'op': 'notify', 'message': 'x'},
          ],
        },
      ]) {
        expect(() => run(bad), throwsFormatException, reason: '$bad');
      }
    });

    test('safe SVG becomes an image with its asset', () {
      final effect = run({
        'operations': [
          {
            'op': 'create_svg',
            'svg':
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10"/></svg>',
            'x': 0,
            'y': 0,
            'width': 40,
            'height': 40,
          },
        ],
      });
      final after = effect.change.applyTo(doc()).$1;
      expect(after.assets, hasLength(1));
      expect(effect.assets.keys, after.assets.keys);
    });
  });

  group('runner', () {
    late Directory dir;
    final hasPython = () {
      try {
        return Process.runSync('python', ['--version']).exitCode == 0;
      } on ProcessException {
        return false;
      }
    }();

    setUp(() => dir = Directory.systemTemp.createTempSync('ocx_plugin'));
    tearDown(() => dir.deleteSync(recursive: true));

    PluginBundle plugin(String script) {
      File('${dir.path}/plugin.json').writeAsStringSync(manifest());
      File('${dir.path}/main.py').writeAsStringSync(script);
      return loadPlugin(dir.path);
    }

    test('runs a plugin with a minimal environment', () async {
      final result = await runPlugin(
        plugin(
          'import json, os, sys\n'
          'req = json.load(sys.stdin)\n'
          'json.dump({"operations": [{"op": "notify", "message": ",".join(sorted(os.environ))}], "echo": req["command"]}, sys.stdout)\n',
        ),
        {'command': 'go'},
      );
      final map = result! as Map;
      expect(map['echo'], 'go');
      final env =
          ((map['operations'] as List).single as Map)['message'] as String;
      for (final secret in ['USERPROFILE', 'HOME', 'APPDATA', 'USERNAME']) {
        expect(env.split(','), isNot(contains(secret)));
      }
    }, skip: hasPython ? false : 'python is not installed');

    test('timeouts, failures, junk and floods are reported', () async {
      await expectLater(
        runPlugin(
          plugin('import time\ntime.sleep(10)\n'),
          const {},
          timeout: const Duration(seconds: 1),
        ),
        throwsA(isA<PluginException>()),
      );
      await expectLater(
        runPlugin(plugin('import sys\nsys.exit(3)\n'), const {}),
        throwsA(isA<PluginException>()),
      );
      await expectLater(
        runPlugin(plugin('print("not json")\n'), const {}),
        throwsA(isA<PluginException>()),
      );
      await expectLater(
        runPlugin(
          plugin('import sys\nwhile True: sys.stdout.write("x" * 65536)\n'),
          const {},
        ),
        throwsA(isA<PluginException>()),
      );
    }, skip: hasPython ? false : 'python is not installed');

    test('the sample plugins produce valid operations', () async {
      for (final folder
          in Directory('../../plugins').listSync().whereType<Directory>()) {
        final bundle = loadPlugin(folder.path);
        final command = bundle.manifest.commands.first;
        final request = buildPluginRequest(
          manifest: bundle.manifest,
          command: command.id,
          inputs: {for (final i in command.inputs) i.id: i.defaultValue},
          document: doc(),
          pageId: pageId,
          selection: {const ObjectId('r')},
        );
        final effect = applyPluginResponse(
          doc(),
          pageId,
          await runPlugin(bundle, request),
          permissions: bundle.manifest.permissions,
          measure: measure,
        );
        expect(effect.messages, isNotEmpty, reason: bundle.manifest.id);
        expect(effect.change.applyTo(doc()).$1.objects, isNotEmpty);
      }
    }, skip: hasPython ? false : 'python is not installed');
  });
}
