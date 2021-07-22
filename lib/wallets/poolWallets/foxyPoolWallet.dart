import 'package:farmr_client/blockchain.dart';
import 'package:farmr_client/wallets/poolWallets/genericPoolWallet.dart';

import 'dart:async';

import 'package:farmr_client/server/netspace.dart';
import 'package:logging/logging.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

Logger log = Logger("FoxyPool API");

class FoxyPoolWallet extends GenericPoolWallet {
  IO.Socket? _socket;

  bool _queryComplete = false;

  int _shares = 0;
  int get shares => _shares;

  int _effectiveCapacity = 0;
  int get effectiveCapacity => _effectiveCapacity;

  FoxyPoolWallet(
      {int pendingBalance = -1,
      int collateralBalance = -1,
      required Blockchain blockchain,
      String name = "FoxyPool Wallet"})
      : super(
            pendingBalance: pendingBalance,
            collateralBalance: collateralBalance,
            blockchain: blockchain,
            name: name);

  Future<void> init() async {
    for (var publicKey in blockchain.config.foxyPoolPublicKeys) {
      if (publicKey != "") {
        Stopwatch stopwatch = Stopwatch();

        stopwatch.start();

        try {
          _getBalance(publicKey, blockchain);
        } catch (e) {
          log.warning(
              "Failed to get FoxyPool Info, make sure your pool public key is correct.");
        }

        //maximum of 5 seconds
        while (!_queryComplete && stopwatch.elapsedMilliseconds < 5000) {
          await Future.delayed(Duration(seconds: 1));
        }

        //print("finished");
        stopwatch.stop();
        //print(stopwatch.elapsedMilliseconds);

        //print(this.collateralBalance);
        //print(this.pendingBalance);
        //print(this.effectiveCapacity);
        //print(this.shares);
      }
    }
  }

  void _getBalance(String poolPublicKey, Blockchain blockchain) {
    // Dart client
    _socket = IO.io(
      'https://api.${blockchain.binaryName}-og.foxypool.io/stats',
      <String, dynamic>{
        'transports': ['websocket'],
      },
    );
    _socket?.onConnect((_) {
      _socket?.emitWithAck('account:fetch', {
        '${blockchain.binaryName}-og',
        {'poolPublicKey': poolPublicKey}
      }, ack: (data) {
        //print('ack $data');
        if (data != null) {
          //print(data);
          try {
            pendingBalance = (double.parse(data['pending'].toString()) *
                    blockchain.majorToMinorMultiplier)
                .round();
            collateralBalance = (double.parse(data['collateral'].toString()) *
                    blockchain.majorToMinorMultiplier)
                .round();
            _shares = double.parse(data['shares'].toString()).round();
            _effectiveCapacity =
                NetSpace.sizeStringToInt("${data['ec']} GiB").round();
          } catch (error) {
            log.warning("Error parsing FoxyPool info!");
            log.info(error.toString());
          }
        } else {
          log.warning(
              "Failed to get FoxyPool Info, make sure your pool public key is correct.");
        }
        _queryComplete = true;

        _socket?.dispose();
      });
    });
  }
}
