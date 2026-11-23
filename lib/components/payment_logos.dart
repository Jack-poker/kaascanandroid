import 'package:flutter/material.dart';

/// Payment providers with their official logos (assets/payment, sourced from
/// Wikimedia Commons). MTN's logo is black and belongs on MTN yellow.
enum PaymentBrand {
  mtn('assets/payment/mtn.png', 'MTN Mobile Money', Color(0xFFFFCC00)),
  airtel('assets/payment/airtel.png', 'Airtel Money', Colors.white),
  visa('assets/payment/visa.png', 'Visa', Colors.white),
  mastercard('assets/payment/mastercard.png', 'Mastercard', Colors.white);

  const PaymentBrand(this.asset, this.label, this.tile);

  final String asset;
  final String label;
  final Color tile;
}

/// A provider logo on a small rounded chip, like the badges on checkout pages.
class PaymentLogo extends StatelessWidget {
  const PaymentLogo(this.brand, {super.key, this.height = 24});

  final PaymentBrand brand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final vPad = height * 0.2;
    return Semantics(
      label: brand.label,
      image: true,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: height * 0.3, vertical: vPad),
        decoration: BoxDecoration(
          color: brand.tile,
          borderRadius: BorderRadius.circular(height * 0.25),
          border: brand.tile == Colors.white
              ? Border.all(color: const Color(0xFFE5E7EB))
              : null,
        ),
        child: Image.asset(
          brand.asset,
          height: height - vPad * 2,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => Text(
            brand.label,
            style: TextStyle(fontSize: height * 0.4, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// A row of provider chips.
class PaymentLogoRow extends StatelessWidget {
  const PaymentLogoRow(this.brands, {super.key, this.height = 24});

  final List<PaymentBrand> brands;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final b in brands) PaymentLogo(b, height: height)],
    );
  }
}
