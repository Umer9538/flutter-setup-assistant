import 'package:flutter_setup_assistant/core/shell_env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final spec = EnvSpec(variables: {'ANDROID_HOME': '/Users/me/Library/Android/sdk'}, pathEntries: ['/Users/me/development/flutter/bin']);

  test('renders a delimited block', () {
    final block = ShellEnvironment.renderBlock(spec);
    expect(block, startsWith(kManagedBlockStart));
    expect(block.trim(), endsWith(kManagedBlockEnd));
    expect(block, contains('export ANDROID_HOME="/Users/me/Library/Android/sdk"'));
    expect(block, contains('export PATH="\$PATH:/Users/me/development/flutter/bin"'));
  });

  test('appends to a profile without a block', () {
    final out = ShellEnvironment.applyBlock('export FOO=1\n', ShellEnvironment.renderBlock(spec));
    expect(out, startsWith('export FOO=1\n\n$kManagedBlockStart'));
  });

  test('replaces an existing block idempotently', () {
    final first = ShellEnvironment.applyBlock('# mine\n', ShellEnvironment.renderBlock(spec));
    final updated = EnvSpec(variables: {'ANDROID_HOME': '/new'}, pathEntries: ['/new/bin']);
    final second = ShellEnvironment.applyBlock(first, ShellEnvironment.renderBlock(updated));
    expect(kManagedBlockStart.allMatches(second).length, 1);
    expect(second, contains('/new/bin'));
    expect(second, isNot(contains('/Users/me/development/flutter/bin')));
    expect(second, startsWith('# mine\n'));
  });
}
