import 'package:cli_table/cli_table.dart';
import 'package:chalkdart/chalk.dart';
import 'security/config.dart';

class Debug {
  Debug(this.enable);

  bool enable;

  bool enabled() {
    enable = true; // ⚠️ Changes state!
    return true;
  }

  bool disabled() {
    enable = false;
    return false;
  }

  bool debugmode() {
    if (enable) {
      return true;
    } else {
      return false;
    }
  }

  void debugMessage(String message) {
    if (!enable) return; // Don't print if debug is disabled

    if (message.isEmpty) {
      print('⚠️ Warning: Empty debug message attempted');
      return;
    }

    final table = Table(header: [chalk.green.bold("DebugMessage:")]);
    table.add([message]);
    print(table);
  }
}

final debug = Debug(config["debugEnable"]);
