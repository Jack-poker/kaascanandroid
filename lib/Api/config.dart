bool isProduction = false; // be carefully or you waste time !
// ignore: non_constant_identifier_names
String get Base_Url => isProduction
    ? "http://ssh.kaascan.com:8788" // this is set for production ready
    : "http://192.168.1.134:8002"; // for development and testing purposes only


// ignore: non_constant_identifier_names
String get Ws_Url => "wss://api.v3.kaascan.com";

// ignore: non_constant_identifier_names
var N8n_Parent_Withdraw_Url = isProduction
    ? "https://automation.kaascan.com/webhook/parent-withdraw"
    : "https://automation.kaascan.com/webhook/parent-withdraw";


// ignore: non_constant_identifier_names
var N8n_Merchant_Withdraw_Url = isProduction
    ? "https://automation.kaascan.com/webhook/merchant-withdraw"
    : "https://automation.kaascan.com/webhook/merchant-withdraw";

