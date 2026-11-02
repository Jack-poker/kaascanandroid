bool isProduction = true; // be carefully or you waste time !
String get Base_Url => isProduction
    ? "https://api.v3.kaascan.com" // this is set for production ready
    : "http://localhost:8000"; // for development and testing purposes only


String get Ws_Url => "wss://api.v3.kaascan.com";

var N8n_Parent_Withdraw_Url = isProduction
    ? "https://automation.kaascan.com/webhook/parent-withdraw"
    : "https://automation.kaascan.com/webhook/parent-withdraw";

var N8n_Merchant_Withdraw_Url = isProduction
    ? "https://automation.kaascan.com/webhook/merchant-withdraw"
    : "https://automation.kaascan.com/webhook/merchant-withdraw";
