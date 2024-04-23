// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' as convert;

import 'package:engine_build_configs/engine_build_configs.dart';
import 'package:engine_tool/src/build_utils.dart';
import 'package:engine_tool/src/commands/command_runner.dart';
import 'package:engine_tool/src/environment.dart';
import 'package:litetest/litetest.dart';
import 'package:path/path.dart' as path;
import 'package:platform/platform.dart';

import 'fixtures.dart' as fixtures;
import 'utils.dart';

void main() {
  final BuilderConfig linuxTestConfig = BuilderConfig.fromJson(
    path: 'ci/builders/linux_test_config.json',
    map: convert.jsonDecode(fixtures.testConfig('Linux', Platform.linux))
        as Map<String, Object?>,
  );

  final BuilderConfig macTestConfig = BuilderConfig.fromJson(
    path: 'ci/builders/mac_test_config.json',
    map: convert.jsonDecode(fixtures.testConfig('Mac-12', Platform.macOS))
        as Map<String, Object?>,
  );

  final BuilderConfig winTestConfig = BuilderConfig.fromJson(
    path: 'ci/builders/win_test_config.json',
    map: convert.jsonDecode(fixtures.testConfig('Windows-11', Platform.windows))
        as Map<String, Object?>,
  );

  final Map<String, BuilderConfig> configs = <String, BuilderConfig>{
    'linux_test_config': linuxTestConfig,
    'linux_test_config2': linuxTestConfig,
    'mac_test_config': macTestConfig,
    'win_test_config': winTestConfig,
  };

  final List<CannedProcess> cannedProcesses = <CannedProcess>[
    CannedProcess((List<String> command) => command.contains('desc'),
        stdout: fixtures.gnDescOutput()),
  ];

  test('can find host runnable build', () async {
    final TestEnvironment testEnv = TestEnvironment.withTestEngine(
      cannedProcesses: cannedProcesses,
    );
    try {
      final List<Build> result = runnableBuilds(testEnv.environment, configs, true);
      expect(result.length, equals(8));
      expect(result[0].name, equals('ci/build_name'));
    } finally {
      testEnv.cleanup();
    }
  });

  test('build command invokes gn', () async {
    final TestEnvironment testEnv = TestEnvironment.withTestEngine(
      cannedProcesses: cannedProcesses,
    );
    try {
      final ToolCommandRunner runner = ToolCommandRunner(
        environment: testEnv.environment,
        configs: configs,
        verbose: true,
      );
      final int result = await runner.run(<String>[
        'build',
        '--config',
        'ci/build_name',
      ]);
      expect(result, equals(0));
      expect(testEnv.processHistory.length, greaterThanOrEqualTo(1));
      expect(testEnv.processHistory[0].command[0], contains('gn'));
    } finally {
      testEnv.cleanup();
    }
  });

  test('build command invokes ninja', () async {
    final TestEnvironment testEnv = TestEnvironment.withTestEngine(
      cannedProcesses: cannedProcesses,
    );
    try {
      final ToolCommandRunner runner = ToolCommandRunner(
        environment: testEnv.environment,
        configs: configs,
        verbose: true,
      );
      final int result = await runner.run(<String>[
        'build',
        '--config',
        'ci/build_name',
      ]);
      expect(result, equals(0));
      expect(testEnv.processHistory.length, greaterThanOrEqualTo(2));
      expect(testEnv.processHistory[1].command[0], contains('ninja'));
    } finally {
      testEnv.cleanup();
    }
  });

  test('build command invokes generator', () async {
    final TestEnvironment testEnv = TestEnvironment.withTestEngine(
      cannedProcesses: cannedProcesses,
    );
    try {
      final ToolCommandRunner runner = ToolCommandRunner(
        environment: testEnv.environment,
        configs: configs,
        verbose: true,
      );
      final int result = await runner.run(<String>[
        'build',
        '--config',
        'ci/build_name',
      ]);
      expect(result, equals(0));
      expect(testEnv.processHistory.length, greaterThanOrEqualTo(3));
      expect(
        testEnv.processHistory[2].command,
        containsStringsInOrder(<String>['python3', 'gen/script.py']),
      );
    } finally {
      testEnv.cleanup();
    }
  });

  test('build command does not invoke tests', () async {
    final TestEnvironment testEnv = TestEnvironment.withTestEngine(
      cannedProcesses: cannedProcesses,
    );
    try {
      final ToolCommandRunner runner = ToolCommandRunner(
        environment: testEnv.environment,
        configs: configs,
        verbose: true,
      );
      final int result = await runner.run(<String>[
        'build',
        '--config',
        'ci/build_name',
      ]);
      expect(result, equals(0));
      expect(testEnv.processHistory.length, lessThanOrEqualTo(4));
    } finally {
      testEnv.cleanup();
    }
  });

  test('build command runs rbe on an rbe build', () async {
    final TestEnvironment testEnv = TestEnvironment.withTestEngine(
      withRbe: true,
      cannedProcesses: cannedProcesses,
    );
    try {
      final ToolCommandRunner runner = ToolCommandRunner(
        environment: testEnv.environment,
        configs: configs,
        verbose: true,
      );
      final int result = await runner.run(<String>[
        'build',
        '--config',
        'ci/android_debug_rbe_arm64',
      ]);
      expect(result, equals(0));
      expect(testEnv.processHistory[0].command[0],
          contains(path.join('tools', 'gn')));
      expect(testEnv.processHistory[0].command[3], equals('--rbe'));
      expect(testEnv.processHistory[1].command[0],
          contains(path.join('reclient', 'bootstrap')));
    } finally {
      testEnv.cleanup();
    }
  });

  test('build command does not run rbe when disabled', () async {
    final TestEnvironment testEnv = TestEnvironment.withTestEngine(
      withRbe: true,
      cannedProcesses: cannedProcesses,
    );
    try {
      final ToolCommandRunner runner = ToolCommandRunner(
        environment: testEnv.environment,
        configs: configs,
        verbose: true,
      );
      final int result = await runner.run(<String>[
        'build',
        '--config',
        'ci/android_debug_rbe_arm64',
        '--no-rbe',
      ]);
      expect(result, equals(0));
      expect(testEnv.processHistory[0].command[0],
          contains(path.join('tools', 'gn')));
      expect(testEnv.processHistory[0].command,
          doesNotContainAny(<String>['--rbe']));
      expect(testEnv.processHistory[1].command[0],
          contains(path.join('ninja', 'ninja')));
    } finally {
      testEnv.cleanup();
    }
  });

  test('build command does not run rbe when rbe configs do not exist',
      () async {
    final TestEnvironment testEnv = TestEnvironment.withTestEngine(
      cannedProcesses: cannedProcesses,
    );
    try {
      final ToolCommandRunner runner = ToolCommandRunner(
        environment: testEnv.environment,
        configs: configs,
        verbose: true,
      );
      final int result = await runner.run(<String>[
        'build',
        '--config',
        'ci/android_debug_rbe_arm64',
      ]);
      expect(result, equals(0));
      expect(testEnv.processHistory[0].command[0],
          contains(path.join('tools', 'gn')));
      expect(testEnv.processHistory[0].command,
          doesNotContainAny(<String>['--rbe']));
      expect(testEnv.processHistory[1].command[0],
          contains(path.join('ninja', 'ninja')));
    } finally {
      testEnv.cleanup();
    }
  });

  test('mangleConfigName removes the OS and adds ci/ as needed', () {
    final TestEnvironment testEnv = TestEnvironment.withTestEngine(
      cannedProcesses: cannedProcesses,
    );
    try {
      final Environment env = testEnv.environment;
      expect(mangleConfigName(env, 'linux/build'), equals('build'));
      expect(mangleConfigName(env, 'ci/build'), equals('ci/build'));
    } finally {
      testEnv.cleanup();
    }
  });

  test('mangleConfigName throws when the input config name is malformed', () {
    final TestEnvironment testEnv = TestEnvironment.withTestEngine(
      cannedProcesses: cannedProcesses,
    );
    try {
      final Environment env = testEnv.environment;
      expectArgumentError(() => mangleConfigName(env, 'build'));
    } finally {
      testEnv.cleanup();
    }
  });

  test('demangleConfigName adds the OS and removes ci/ as needed', () {
    final TestEnvironment testEnv = TestEnvironment.withTestEngine(
      cannedProcesses: cannedProcesses,
    );
    try {
        final Environment env = testEnv.environment;
        expect(demangleConfigName(env, 'build'), equals('linux/build'));
        expect(demangleConfigName(env, 'ci/build'), equals('ci/build'));
    } finally {
      testEnv.cleanup();
    }
  });

  test('local config name on the command line is correctly translated',
      () async {
    final BuilderConfig namespaceTestConfigs = BuilderConfig.fromJson(
      path: 'ci/builders/namespace_test_config.json',
      map: convert.jsonDecode(fixtures.configsToTestNamespacing)
          as Map<String, Object?>,
    );
    final Map<String, BuilderConfig> configs = <String, BuilderConfig>{
      'namespace_test_config': namespaceTestConfigs,
    };
    final TestEnvironment testEnv = TestEnvironment.withTestEngine(
      cannedProcesses: cannedProcesses,
    );
    try {
      final ToolCommandRunner runner = ToolCommandRunner(
        environment: testEnv.environment,
        configs: configs,
        verbose: true,
      );
      final int result = await runner.run(<String>[
        'build',
        '--config',
        'host_debug',
      ]);
      expect(result, equals(0));
      expect(testEnv.processHistory[1].command[0],
          contains(path.join('ninja', 'ninja')));
      expect(
          testEnv.processHistory[1].command[2], contains('local_host_debug'));
    } finally {
      testEnv.cleanup();
    }
  });

  test('ci config name on the command line is correctly translated', () async {
    final BuilderConfig namespaceTestConfigs = BuilderConfig.fromJson(
      path: 'ci/builders/namespace_test_config.json',
      map: convert.jsonDecode(fixtures.configsToTestNamespacing)
          as Map<String, Object?>,
    );
    final Map<String, BuilderConfig> configs = <String, BuilderConfig>{
      'namespace_test_config': namespaceTestConfigs,
    };
    final TestEnvironment testEnv = TestEnvironment.withTestEngine(
      cannedProcesses: cannedProcesses,
    );
    final Environment env = testEnv.environment;
    try {
      final ToolCommandRunner runner = ToolCommandRunner(
        environment: env,
        configs: configs,
        verbose: true,
      );
      final int result = await runner.run(<String>[
        'build',
        '--config',
        'ci/host_debug',
      ]);
      expect(result, equals(0));
      expect(testEnv.processHistory[1].command[0],
          contains(path.join('ninja', 'ninja')));
      expect(testEnv.processHistory[1].command[2], contains('ci/host_debug'));
    } finally {
      testEnv.cleanup();
    }
  });

  test('build command invokes ninja with the specified target', () async {
    final TestEnvironment testEnv = TestEnvironment.withTestEngine(
      cannedProcesses: cannedProcesses,
    );
    try {
      final ToolCommandRunner runner = ToolCommandRunner(
        environment: testEnv.environment,
        configs: configs,
        verbose: true,
      );
      final int result = await runner.run(<String>[
        'build',
        '--config',
        'host_debug',
        '//flutter/fml:fml_arc_unittests',
      ]);
      expect(result, equals(0));
      expect(testEnv.processHistory.length, greaterThan(6));
      expect(testEnv.processHistory[6].command[0], contains('ninja'));
      expect(testEnv.processHistory[6].command[2], endsWith('/host_debug'));
      expect(
        testEnv.processHistory[6].command[5],
        equals('flutter/fml:fml_arc_unittests'),
      );
    } finally {
      testEnv.cleanup();
    }
  });

  test('build command invokes ninja with all matched targets', () async {
    final TestEnvironment testEnv = TestEnvironment.withTestEngine(
      cannedProcesses: cannedProcesses,
    );
    try {
      final ToolCommandRunner runner = ToolCommandRunner(
        environment: testEnv.environment,
        configs: configs,
        verbose: true,
      );
      final int result = await runner.run(<String>[
        'build',
        '--config',
        'host_debug',
        '//flutter/...',
      ]);
      expect(result, equals(0));
      expect(testEnv.processHistory.length, greaterThan(6));
      expect(testEnv.processHistory[6].command[0], contains('ninja'));
      expect(testEnv.processHistory[6].command[2], endsWith('/host_debug'));
      expect(
        testEnv.processHistory[6].command[5],
        equals('flutter/display_list:display_list_unittests'),
      );
      expect(
        testEnv.processHistory[6].command[6],
        equals('flutter/flow:flow_unittests'),
      );
      expect(
        testEnv.processHistory[6].command[7],
        equals('flutter/fml:fml_arc_unittests'),
      );
    } finally {
      testEnv.cleanup();
    }
  });

  test('et help build line length is not too big', () async {
    final List<String> prints = <String>[];
    await runZoned(
      () async {
        final TestEnvironment testEnv = TestEnvironment.withTestEngine(
          cannedProcesses: cannedProcesses,
        );
        try {
          final ToolCommandRunner runner = ToolCommandRunner(
            environment: testEnv.environment,
            configs: configs,
            verbose: true,
          );
          final int result = await runner.run(<String>[
            'help', 'build',
          ]);
          expect(result, equals(0));
        } finally {
          testEnv.cleanup();
        }
      },
      zoneSpecification: ZoneSpecification(
        print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
          prints.addAll(line.split('\n'));
        },
      ),
    );
    for (final String line in prints) {
      expect(line.length, lessThanOrEqualTo(100));
    }
  });
}
