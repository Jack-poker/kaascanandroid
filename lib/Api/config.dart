bool isProduction = true; // be carefully or you waste time !
// ignore: non_constant_identifier_names
String get Base_Url => isProduction
    ? "http://ssh.kaascan.com:8788" // this is set for production ready
    : "http://192.168.1.134:8002"; // for development and testing purposes only


// ignore: non_constant_identifier_names
String get Ws_Url => "wss://api.v3.kaascan.com";

// Default for "Floating Soma" (parents can switch it in Personalise Soma).
// How the Soma robot tab behaves while another tab (Students, History) is open:
//   true  → the robot floats above the bottom bar; tapping it pops Soma's chat
//           up as a sheet over the current screen.
//   false → the robot stays inside its tab circle; tapping it opens the AI tab.
bool floatingSomaRobot = false;

// Low-balance reminder (Android): while the parent's phone charges, the app
// checks the children's cards and reminds the parent, at most twice a day,
// when any card is below this many RWF.
int lowBalanceReminderRwf = 1000;

// ignore: non_constant_identifier_names
var N8n_Parent_Withdraw_Url = isProduction
    ? "https://automation.kaascan.com/webhook/parent-withdraw"
    : "https://automation.kaascan.com/webhook/parent-withdraw";


// ignore: non_constant_identifier_names
var N8n_Merchant_Withdraw_Url = isProduction
    ? "https://automation.kaascan.com/webhook/merchant-withdraw"
    : "https://automation.kaascan.com/webhook/merchant-withdraw";

