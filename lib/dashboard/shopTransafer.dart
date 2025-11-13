import 'package:flutter/material.dart';
import 'package:kaascan/components/transferScan.dart';
import 'package:kaascan/dashboard/home.dart';
import 'package:kaascan/dashboard/transactions.dart';
import 'package:kaascan/onBoradingScreen.dart';


class Transfer extends StatefulWidget {
  const Transfer({super.key});

  @override
  State<Transfer> createState() => _TransferState();
}

class _TransferState extends State<Transfer> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: myWhite,
      body: scanTransfer()
    );
  }
}