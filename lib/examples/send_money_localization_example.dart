import 'package:flutter/material.dart';
import '../services/language_service.dart';

/// Example showing how to convert send_money_ui.dart to use server-driven translations
/// This is a reference file - copy patterns from here to actual implementation

class SendMoneyUILocalizationExample extends StatelessWidget {
  final Map<String, dynamic> student;

  const SendMoneyUILocalizationExample({Key? key, required this.student}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header Title
        Text(
          languageService.t('deposit.title', 
            fallback: 'Deposit using Mobile Money'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: "gilroy-light",
          ),
        ),

        const SizedBox(height: 10),

        // Description with student name
        Text(
          languageService.t('deposit.description',
            params: {'studentName': student['student_name'] ?? 'Student'},
            fallback: "Easily deposit money on ${student['student_name']}'s account using Mobile Money. Simply enter the amount to deposit below."),
          style: const TextStyle(
            fontSize: 12,
            fontFamily: "gilroy-light",
            height: 1.3,
          ),
        ),

        const SizedBox(height: 8),

        // PS Message
        Text(
          languageService.t('deposit.ps_message',
            fallback: 'PS! Make sure you have sufficient funds to deposit.'),
          style: const TextStyle(
            fontSize: 11,
            fontFamily: "gilroy-light",
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 16),

        // Amount Section
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    languageService.t('deposit.amount', fallback: 'Amount'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    languageService.t('deposit.telco_fees_apply',
                      fallback: 'Telco fees apply'),
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Min/Max text
              Text(
                languageService.t('deposit.min_max',
                  fallback: 'Min: 100, Max: 5,000,000'),
                style: const TextStyle(fontSize: 10),
              ),

              const SizedBox(height: 16),

              // Breakdown
              _buildBreakdownRow(
                languageService.t('deposit.deposit_amount', 
                  fallback: 'Deposit Amount:'),
                "500 RWF",
              ),

              const SizedBox(height: 6),

              _buildBreakdownRow(
                languageService.t('deposit.telco_fee',
                  fallback: 'Telco Fee (Est 5%):'),
                "25 RWF",
              ),

              const SizedBox(height: 6),

              _buildBreakdownRow(
                languageService.t('deposit.total', fallback: 'Total:'),
                "500 RWF",
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // What happens next
        Text(
          languageService.t('deposit.what_happens_next',
            fallback: 'What happens next?'),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          languageService.t('deposit.confirm_on_phone',
            fallback: 'Confirm the deposit request on your phone.'),
          style: const TextStyle(
            fontSize: 11,
            height: 1.2,
          ),
        ),

        const SizedBox(height: 20),

        // Confirm Button
        ElevatedButton(
          onPressed: () {},
          child: Text(
            languageService.t('deposit.confirm_deposit',
              fallback: 'Confirm Deposit'),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value),
      ],
    );
  }
}

/* 
  === CONVERSION CHECKLIST ===
  
  1. Replace all hardcoded text with languageService.t() calls
  2. Use consistent key naming (e.g., 'deposit.title', 'deposit.description')
  3. Always provide fallback text that matches original English
  4. Use params for dynamic content (student names, amounts, etc.)
  5. Import language_service.dart at the top of the file
  
  === COMMON PATTERNS ===
  
  Simple text:
    "Send Money" → languageService.t('common.send_money', fallback: 'Send Money')
  
  Text with variables:
    "Hello $name" → languageService.t('greeting', params: {'name': name}, fallback: 'Hello $name')
  
  Button text:
    "Confirm" → languageService.t('common.confirm', fallback: 'Confirm')
  
  Error messages:
    "Failed to load" → languageService.t('errors.load_failed', fallback: 'Failed to load')
*/
