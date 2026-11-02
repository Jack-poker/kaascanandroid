import 'package:flutter/material.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/components/deposit.dart';
import 'package:kaascan/dashboard/home.dart';
import 'package:kaascan/main.dart';
import 'package:get/get.dart';


final depositController = Get.find<DepositController>();
// print(depositController.currentValue.value); // Access current deposit amount
// print(depositController.transactionStatus.value); // Access transaction status

class Depositprocess extends StatelessWidget {
  final amount;
  final bool status;

  const Depositprocess({super.key, required this.amount, required this.status});

  Future<void> _checkTransactionStatus(BuildContext context) async {
    try {
      final response = await api_Call.post(
        'https://automation.kaascan.com/webhook/checkpaymentstatus',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Status: ${response.data}"),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ntibikunze, ongera ugerageze."),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;

    return    Center(
      child: Obx(()=>Container(
        width: screen.width * 0.9,
        height: screen.height * 0.22,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
                txStatus.value == "pending"
                  ? const Color.fromARGB(255, 255, 145, 0)
                  : txStatus.value != "success"
                    ? Colors.red
                    : Colors.green,
                txStatus.value == "pending"
                  ?const Color.fromARGB(255, 255, 145, 0)
                   : txStatus.value != "success"
                    ? Colors.redAccent
                    : Colors.green,
              // myColor,
              // myOpblue,
              const Color.fromARGB(193, 255, 255, 255),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color.fromARGB(60, 255, 255, 255),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                   Obx(()=>Text(
                      "+ ${transaction_amount.value} RWF",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        fontFamily: "gilroy",
                        color: const Color.fromARGB(255, 255, 255, 255),
                      ),
                    )),
                    SizedBox(height: 4),
                    Text(
                      'Mutegereze gato, igikorwa\n cyo kohereza amafaranga kirimo gukorwa...',
                      style: TextStyle(
                        fontFamily: 'gilroy-semibold',
                        fontSize: 10.0,
                        color: Color.fromARGB(255, 255, 255, 255),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              Container(
                width: 60,
                height: 60,
                child: ElevatedButton(
                  onPressed: () => {
                    transaction_processing.value=false,
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (context) =>   DashboardNav()))
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  
                  child: Obx(()=>Icon(
                    txStatus.value == "pending" ? Icons.timelapse_sharp : Icons.check_circle,
                      color:  txStatus.value == "pending"  ? Colors.red : Colors.green,
                    size: 24,
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}
