import 'package:flutter/material.dart';
import 'package:kaascan/Api/client.dart';
import 'package:kaascan/Auth/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

class MerchantKYCScreen extends StatefulWidget {
  const MerchantKYCScreen({super.key});

  @override
  State<MerchantKYCScreen> createState() => _MerchantKYCScreenState();
}

class _MerchantKYCScreenState extends State<MerchantKYCScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  String _verificationStatus = "none";
  Map<String, dynamic>? _existingDetails;

  final TextEditingController _businessName = TextEditingController();
  final TextEditingController _businessAddress = TextEditingController();
  final TextEditingController _ownerName = TextEditingController();
  final TextEditingController _nationalId = TextEditingController();
  final TextEditingController _phoneNumber = TextEditingController();
  final TextEditingController _momoNumber = TextEditingController();
  final TextEditingController _bankAccount = TextEditingController();
  final TextEditingController _bankName = TextEditingController();

  String _businessType = "Individual";
  String _businessCategory = "Retail";
  double? _latitude;
  double? _longitude;

  static const Color brandBlue = myColor;
  static const Color deepNavy = Color(0xFF11142D);
  static const Color softGray = Color(0xFF808191);
  static const Color cloudWhite = Color(0xFFF4F7FF);

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('login_token');
      if (token == null) throw "Session expired";

      final res = await backendClient().getKYCStatus(token);
      if (res.data['status'] == "success") {
        setState(() {
          _verificationStatus = res.data['verification_status'];
          _existingDetails = res.data['details'];

          if (_existingDetails != null) {
            _businessName.text = _existingDetails!['business_name'] ?? "";
            _businessAddress.text = _existingDetails!['business_address'] ?? "";
            _ownerName.text = _existingDetails!['owner_name'] ?? "";
            _nationalId.text = _existingDetails!['national_id'] ?? "";
            _phoneNumber.text = _existingDetails!['phone_number'] ?? "";
            _momoNumber.text = _existingDetails!['mobile_money_number'] ?? "";
            _bankAccount.text = _existingDetails!['bank_account'] ?? "";
            _bankName.text = _existingDetails!['bank_name'] ?? "";
            _businessType = _existingDetails!['business_type'] ?? "Individual";
            _businessCategory =
                _existingDetails!['business_category'] ?? "Retail";
            _latitude = _existingDetails!['latitude'];
            _longitude = _existingDetails!['longitude'];
          }
          _isLoading = false;
        });
        _fetchLocation(); // Refresh location even if existing
      } else {
        setState(() {
          _verificationStatus = "not_submitted";
          _isLoading = false;
        });
        _fetchLocation();
      }
    } catch (e) {
      debugPrint("KYC Status Fetch Error: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      debugPrint("Location Fetch Error: $e");
    }
  }

  Future<void> _submitKyc() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('login_token');
      final csrfRes = await backendClient().csrfToken();
      final xtoken = csrfRes.data['csrf_token'];

      final data = {
        "business_name": _businessName.text,
        "business_type": _businessType,
        "business_category": _businessCategory,
        "business_address": _businessAddress.text,
        "owner_name": _ownerName.text,
        "national_id": _nationalId.text,
        "phone_number": _phoneNumber.text,
        "mobile_money_number": _momoNumber.text,
        "bank_account": _bankAccount.text,
        "bank_name": _bankName.text,
        "latitude": _latitude,
        "longitude": _longitude,
      };

      final res = await backendClient().submitKYC(
        xtoken: xtoken,
        token: token!,
        kycData: data,
      );

      if (res.data['status'] == "success") {
        if (mounted) {
          _showSuccessSheet();
          _fetchStatus();
        }
      } else {
        throw res.data['message'] ?? "Submission failed";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cloudWhite,
      appBar: AppBar(
        title: const Text(
          "Business KYC",
          style: TextStyle(
            fontFamily: 'gilroy-light',
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: brandBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: brandBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusBanner(),
                  const SizedBox(height: 24),
                  if (_verificationStatus == "pending" ||
                      _verificationStatus == "verified")
                    _buildSummaryView()
                  else
                    _buildKycForm(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusBanner() {
    Color bannerColor;
    IconData icon;
    String text;
    String subtext;

    switch (_verificationStatus) {
      case "verified":
        bannerColor = Colors.green;
        icon = Icons.verified_rounded;
        text = "Account Verified";
        subtext = "Your business details have been approved.";
        break;
      case "pending":
        bannerColor = Colors.orange;
        icon = Icons.pending_actions_rounded;
        text = "Verification Pending";
        subtext =
            "We are reviewing your submission. This usually takes 24-48h.";
        break;
      case "rejected":
        bannerColor = Colors.red;
        icon = Icons.error_outline_rounded;
        text = "Action Required";
        subtext = "Your KYC was rejected. Please review and resubmit.";
        break;
      default:
        bannerColor = brandBlue;
        icon = Icons.business_center_rounded;
        text = "KYC Not Started";
        subtext =
            "Please provide your business details to enable full features.";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bannerColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bannerColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontFamily: 'gilroy-light',
                    fontWeight: FontWeight.w900,
                    color: bannerColor,
                    fontSize: 18,
                  ),
                ),
                Text(
                  subtext,
                  style: TextStyle(
                    fontFamily: 'gilroy-light',
                    color: softGray,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryView() {
    return Column(
      children: [
        _buildInfoCard("Business Identity", {
          "Name": _businessName.text,
          "Type": _businessType,
          "Category": _businessCategory,
          "Location": _latitude != null
              ? "${_latitude?.toStringAsFixed(4)}, ${_longitude?.toStringAsFixed(4)}"
              : "Unknown",
        }),
        const SizedBox(height: 16),
        _buildInfoCard("Owner & Banking", {
          "Full Name": _ownerName.text,
          "National ID": _nationalId.text,
          "Contact Phone": _phoneNumber.text,
          "MoMo Number": _momoNumber.text,
          "Bank Name": _bankName.text.isEmpty ? "Not Provided" : _bankName.text,
          "Bank Account": _bankAccount.text.isEmpty
              ? "Not Provided"
              : _bankAccount.text,
        }),
        const SizedBox(height: 32),
        if (_verificationStatus == "verified")
          const Text(
            "✅ All set! Your business is officially verified.",
            style: TextStyle(
              fontFamily: 'gilroy-light',
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() => _verificationStatus = "none"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: brandBlue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "EDIT DETAILS",
                style: TextStyle(
                  fontFamily: 'gilroy-light',
                  fontWeight: FontWeight.w800,
                  color: brandBlue,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoCard(String title, Map<String, String> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'gilroy-light',
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: softGray,
            ),
          ),
          const SizedBox(height: 16),
          ...data.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.key,
                    style: const TextStyle(
                      fontFamily: 'gilroy-light',
                      color: softGray,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    e.value,
                    style: const TextStyle(
                      fontFamily: 'gilroy-light',
                      fontWeight: FontWeight.w800,
                      color: deepNavy,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKycForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "BUSINESS IDENTITY",
            style: TextStyle(
              fontFamily: 'gilroy-light',
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: softGray,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _buildField(
            _businessName,
            "Registered Business Name",
            Icons.business_rounded,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  "Business Type",
                  ["Individual", "Company", "NGO", "School"],
                  _businessType,
                  (v) => setState(() => _businessType = v!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdown(
                  "Category",
                  ["Retail", "Restaurant", "Education", "Services"],
                  _businessCategory,
                  (v) => setState(() => _businessCategory = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // _buildField(_businessAddress, "Physical Address", Icons.location_on_rounded),
          if (_latitude != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: brandBlue, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    "Location Captured: ${_latitude?.toStringAsFixed(4)}, ${_longitude?.toStringAsFixed(4)}",
                    style: const TextStyle(
                      fontFamily: 'gilroy-light',
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 32),
          const Text(
            "OWNER DETAILS",
            style: TextStyle(
              fontFamily: 'gilroy-light',
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: softGray,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _buildField(
            _ownerName,
            "Owner Full Name",
            Icons.person_rounded,
            hint: "As it appears on your ID",
          ),
          const SizedBox(height: 16),
          _buildField(
            _nationalId,
            "National ID (NID)",
            Icons.badge_rounded,
            hint: "16-digit National ID number",
          ),
          const SizedBox(height: 16),
          _buildField(
            _phoneNumber,
            "Contact Phone Number",
            Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
            hint: "For verification calls & security alerts",
          ),
          const SizedBox(height: 32),
          const Text(
            "FINANCIAL ACCOUNTS",
            style: TextStyle(
              fontFamily: 'gilroy-light',
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: softGray,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _buildField(
            _momoNumber,
            "Mobile Money Number",
            Icons.account_balance_wallet_rounded,
            keyboardType: TextInputType.phone,
            hint: "Where your payouts will be sent",
          ),
          const SizedBox(height: 16),
          _buildField(
            _bankName,
            "Bank Name (Optional)",
            Icons.account_balance_rounded,
            isRequired: false,
            hint: "Your commercial bank name",
          ),
          const SizedBox(height: 16),
          _buildField(
            _bankAccount,
            "Bank Account Number (Optional)",
            Icons.numbers_rounded,
            isRequired: false,
            hint: "Account for large settlement transfers",
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitKyc,
              style: ElevatedButton.styleFrom(
                backgroundColor: brandBlue,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                "SUBMIT FOR VERIFICATION",
                style: TextStyle(
                  fontFamily: 'gilroy-light',
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = true,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (v) {
        if (!isRequired) return null;
        return (v == null || v.isEmpty) ? "Required" : null;
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: 'gilroy-light',
          color: softGray.withOpacity(0.5),
          fontSize: 12,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'gilroy-light',
          color: softGray,
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: brandBlue, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brandBlue, width: 1.5),
        ),
      ),
      style: const TextStyle(
        fontFamily: 'gilroy-light',
        fontWeight: FontWeight.w700,
        color: deepNavy,
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String value,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'gilroy-light',
            color: softGray,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: brandBlue,
              ),
              style: const TextStyle(
                fontFamily: 'gilroy-light',
                fontWeight: FontWeight.w700,
                color: deepNavy,
              ),
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 450,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 80,
            ),
            const SizedBox(height: 24),
            const Text(
              "KYC SUBMITTED",
              style: TextStyle(
                fontFamily: 'gilroy-light',
                fontWeight: FontWeight.w900,
                color: deepNavy,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Your details have been sent successfully. We will review them and notify you soon.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'gilroy-light',
                color: softGray,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandBlue,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "GREAT",
                  style: TextStyle(
                    fontFamily: 'gilroy-light',
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
