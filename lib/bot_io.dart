library bot_io;

import 'dart:async';
import 'dart:crypto' as crypto;
import 'dart:math' as math;
import 'dart:io';
import 'dart:utf' as utf;

import 'package:args/args.dart';
import 'package:logging/logging.dart' as logging;
import 'package:meta/meta.dart';
import 'package:pathos/path.dart' as pathos;

import 'package:bot/bot.dart';

part 'src/bot_io/ansi_color.dart';
part 'src/bot_io/completion.dart';
part 'src/bot_io/console.dart';
part 'src/bot_io/directory_populater.dart';
part 'src/bot_io/entity_populater.dart';
part 'src/bot_io/entity_validator.dart';
part 'src/bot_io/io_helpers.dart';
part 'src/bot_io/sha_and_comparison.dart';
part 'src/bot_io/shell_string.dart';
part 'src/bot_io/temp_dir.dart';

/**
 * When called, a listener is added to the root [Logger] and all output is
 * appended to a log file named "`new Options().script`.log".
 *
 * The format: [LogRecord.time] 'tab' [LogRecord.level] 'tab' [LogRecord.loggerName] 'tab' [LogRecord.message]
 */
void enableScriptLogListener() {
  if(_scriptLogListenerPath == null) {
    final options = new Options();

    final script = options.script;
    _scriptLogListenerPath = new Path(script).toNativePath() + '.log';

    final rootLogger = logging.Logger.root;
    rootLogger.level = logging.Level.ALL;

    rootLogger.onRecord.listen(_doLog);

    final logger = logging.Logger.root;

    logger.info('Starting log for $script at $_scriptLogListenerPath');
  }
}

String _scriptLogListenerPath;

void _doLog(logging.LogRecord record) {

  final msg = '${record.time}\t${record.level}\t${record.loggerName}\t${record.message}';

  final logFile = new File(_scriptLogListenerPath);

  logFile.writeAsStringSync('$msg\n', mode: FileMode.APPEND);
}
