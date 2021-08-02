import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/rpc.dart';
import 'package:universal_io/io.dart' as io;

import 'package:logging/logging.dart';

//connection in chia show -c
class Connection {
  //type of connection
  ConnectionType _type;
  ConnectionType get type => _type;

  //ip from connection e.g. 127.0.0.1
  String _ip;
  String get ip => _ip;

  //ports associated with connection e.g. 8444/8444
  List<int> ports = [];

  Connection(this._type, this._ip, this.ports);

  Map toJson() => {"type": type, "ip": ip, "ports": ports};
}

//Maybe there are more???
enum ConnectionType { FullNode, Farmer, Wallet, Introducer, ERROR }

final log = Logger('FarmerWallet');

class Connections {
  List<Connection> connections;

  Connections(this.connections);

  static Future<Connections> generateConnections(Blockchain blockchain) async {
    List<Connection> connections = [];

    final bool? isFullNodeRunning = ((await blockchain.rpcPorts
            ?.isServiceRunning([RPCService.Full_Node])) ??
        {})[RPCService.Full_Node];

    //checks if full node rpc ports are defined
    if (isFullNodeRunning ?? false) {
      RPCConfiguration configuration = RPCConfiguration(
          blockchain: blockchain,
          service: RPCService.Full_Node,
          endpoint: "get_connections");

      print(await RPCConnection.getEndpoint(configuration));
      io.stdin.readLineSync(); //debug
    }
    //if not parses connections in legacy mode
    else {
      var connectionsOutput = io.Process.runSync(
              blockchain.config.cache!.binPath, const ["show", "-c"])
          .stdout
          .toString();

      try {
        RegExp connectionsRegex = RegExp(
            "([\\S_]+) ([\\S\\.]+)[\\s]+([0-9]+)/([0-9]+)",
            multiLine: true);

        var matches = connectionsRegex.allMatches(connectionsOutput);

        for (var match in matches) {
          try {
            var typeString = match.group(1);
            final ConnectionType type;

            if (typeString == "FULL_NODE")
              type = ConnectionType.FullNode;
            else if (typeString == "INTRODUCER")
              type = ConnectionType.Introducer;
            else if (typeString == "WALLET")
              type = ConnectionType.Wallet;
            else if (typeString == "FARMER")
              type = ConnectionType.Farmer;
            else
              type = ConnectionType.ERROR;

            String ip = match.group(2) ?? 'N/A';
            int port1 = int.parse(match.group(3) ?? '-1');
            int port2 = int.parse(match.group(4) ?? '-1');

            Connection connection = new Connection(type, ip, [port1, port2]);

            connections.add(connection);
          } catch (e) {
            log.warning("Failed to parse connection");
          }
        }
      } catch (e) {
        log.warning("Failed to parse connections");
      }
    }

    return Connections(connections);
  }
}
