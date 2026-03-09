bool isProduction = true;
String get Base_Url => isProduction
    ? "https://api.v2.kaascan.com"
    : "http://192.168.1.149:8000";

String get Ws_Url => "wss://api.v2.kaascan.com";

// N8N Webhook URLs for withdrawals
var N8n_Parent_Withdraw_Url = isProduction
    ? "https://automation.kaascan.com/webhook/parent-withdraw"
    : "https://automation.kaascan.com/webhook/parent-withdraw";

var N8n_Merchant_Withdraw_Url = isProduction
    ? "https://automation.kaascan.com/webhook/merchant-withdraw"
    : "https://automation.kaascan.com/webhook/merchant-withdraw";



