import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../main.dart';



class EbillingModel{

  // Auth credentials
  var username = ""; // username
  var sharedkey = ""; //sharedKey

  //A utiliser lorsque vous êtes en environnement Prod
  var domain = "https://stg.billing-easy.com"; // Url prod

   //A utiliser lorsque vous êtes en environnement test
  var domain = "https://test.billing-easy.com" // Url test

  var  basicAuth;

  EbillingModel(){

    // init
    var credentials = "$username:$sharedkey";
    var encodedCredentials = base64.encode(utf8.encode(credentials));
    this.basicAuth = 'Basic '+ encodedCredentials;
  }


  // Appeler cette fonction lorsque l'utilisateur clique sur le bouton"Payer" dans votre app mobile
  void procedePayment(double amount, String desc, String clientPhone,
      String clientEmail, clientTransId, String paymentMethod) async {

      // Request Header
      Map<String, String> requestHeaders = {
        "Content-type": "application/json",
        "Accept": "application/json",
        "Authorization": basicAuth
      };

   createBillFunc(clientTransId, clientEmail,
       clientPhone, amount, desc, requestHeaders,
       paymentMethod);

  }

  // Get the state of the invoice
  void getInvoiceStateFunc(invoiceId, requestHeaders, paymentMethod) async {

    var getInvoiceUrl = "$domain/api/v1/merchant/e_bills/$invoiceId";
    var getInvoiceRes = await http.get(Uri.parse(getInvoiceUrl),
        headers: requestHeaders
    );

    Map<String, dynamic> jsonData = jsonDecode(getInvoiceRes.body);
    var invoiceState = jsonData['state'];


    if (invoiceState == "processed"){
      print("Paiement réussi")
    }
    else{
      print("Paiement échoué")
    }
  }

  // Run ussd push prompt
  // Ouvrir la fenêtre ussd sur votre téléphone, l'utilisateur n'aura qu'à rentrer son mot de passe pour valider le paiement
  void ussdPushFunc(invoiceId, requestHeaders, paymentMethod, clientPhone) async {

    var ussdPushUrl = "$domain/api/v1/merchant/e_bills/$invoiceId/ussd_push";

    var ussdPushBody = {
      "payment_system_name": paymentMethod,
      "payer_msisdn": clientPhone
    };


    final ussdPushResponse = await http.post(Uri.parse(ussdPushUrl),
        body: jsonEncode(ussdPushBody),
        headers: requestHeaders
    );


    if (ussdPushResponse.statusCode == 202){

      // Vérifier l'état de la transaction après 30 secondes
      Timer(
          Duration(seconds: 30), () => getInvoiceStateFunc(invoiceId, requestHeaders, paymentMethod)
      );
    }
  }

  // Create the invoice
  void createBillFunc(clientTransId, clientEmail, clientPhone, amount, desc, requestHeaders, paymentMethod) async {

    var apiUrl = "$domain/api/v1/merchant/e_bills";

    const expPeriod = 60;

    // Request body
    final body = {
      "client_transaction_id": clientTransId,
      "payer_email": clientEmail,
      'payer_msisdn': clientPhone,
      'amount': amount,
      'short_description': desc,
      'expiry_period': expPeriod,
    };

    final response = await http.post(Uri.parse(apiUrl),
        body: jsonEncode(body),
        headers: requestHeaders
    );

    if (response.statusCode == 201) {

      Map<String, dynamic> jsonData = jsonDecode(response.body);

      var invoiceId = jsonData['e_bill']['bill_id'];

      ussdPushFunc(invoiceId, requestHeaders, paymentMethod, clientPhone);
    }
    else {
      throw Exception('Failed to load response');
    }
  }
}
