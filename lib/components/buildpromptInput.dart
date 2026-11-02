import 'package:flutter/material.dart';
import 'package:kaascan/provider/values_provider.dart';
import 'package:provider/provider.dart';

Widget _buildTextInput(ValuesProvider valuesProvider,String _enteredText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              // controller: ,
              maxLines: 3,
              minLines: 1,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Andika ibyo ukeneye...',
                hintStyle: TextStyle(
                  color: const Color.fromRGBO(213, 187, 255, 1),
                  fontSize: 14,
                  fontFamily: "minigap",
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (value) {
                // setState(() => _enteredText = value);
              },
              // onSubmitted: _enteredText.isNotEmpty
              //     ? (_) => _handleSendMessage(valuesProvider)
              //     : null,
            ),
          ),
          // if (!amountController.text.isNotEmpty)
          Row(
            children: [
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  // if (_enteredText.isEmpty) return;
                  // _handleSendMessage(valuesProvider);
                },
                child: Consumer<ValuesProvider>(
                  builder: (context, Wvalue, child) {
                    return Container(
                      width: 50,
                      height: 50,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _enteredText.isNotEmpty
                            ? const Color.fromARGB(255, 196, 179, 255)
                            : const Color.fromARGB(
                                255,
                                196,
                                179,
                                255,
                              ).withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Wvalue.waiting_ask
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.deepPurpleAccent,
                                ),
                              )
                            : Icon(
                                Icons.send_rounded,
                                color: _enteredText.isNotEmpty
                                    ? Colors.deepPurpleAccent
                                    : Colors.deepPurpleAccent.withValues(
                                        alpha: 0.4,
                                      ),
                                size: 30,
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }