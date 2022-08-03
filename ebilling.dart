import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../main.dart';


/*
--------------------------------------------------
                    FLUBILLING
---------------------------------------------------

Intégration Ebilling sur Flutter
version: 1.0.0


Informations supplémentaires
----------------------------

payment_system_name = airtelmoney (pour Airtel Money)
payment_system_name = moovmoney4 (pour Mobicash)


*/


class EbillingModel{

  // Identifiants d'authentification
  var username = ""; // username
  var sharedkey = ""; //sharedKey

  // En env prod
  //A utiliser lorsque vous êtes en environnement Prod
  var domain = "https://stg.billing-easy.com"; 

  // En env dev
  //A utiliser lorsque vous êtes en environnement Dev
  var domain = "https://lab.billing-easy.net" 

  var  basicAuth;

  EbillingModel(){

    // init
    var credentials = "$username:$sharedkey";
    var encodedCredentials = base64.encode(utf8.encode(credentials));
    this.basicAuth = 'Basic '+ encodedCredentials;
  }


  // Appelez cette fonction lorsque l'utilisateur clique sur le bouton"Payer" dans votre app mobile
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

  // Récupère l'état de la facture
  void getInvoiceStateFunc(invoiceId, requestHeaders, paymentMethod) async {

    var getInvoiceUrl = "$domain/api/v1/merchant/e_bills/$invoiceId";
    var getInvoiceRes = await http.get(Uri.parse(getInvoiceUrl),
        headers: requestHeaders
    );

    Map<String, dynamic> jsonData = jsonDecode(getInvoiceRes.body);
    var invoiceState = jsonData['state'];


    if (invoiceState == "processed"){
      print("Paiement réussi")

    /* 
      Une fois le paiement réussi, vous pouvez enregister les informations de la transaction dans votre base de données.
      Pour cela :
          - Ecrivez une fonction qui enregistre les infos dans la BD (dans un autre fichier)
          - Appeler cette fonction ici 
      */
      
    
    }
    else{
      print("Paiement échoué")
    }
  }


  // Ouvre la fenêtre ussd sur le téléphone. L'utilisateur n'aura qu'à rentrer son mot de passe pour valider le paiement
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

      // Vérifie l'état de la transaction après 30 secondes
      Timer(
          Duration(seconds: 30), () => getInvoiceStateFunc(invoiceId, requestHeaders, paymentMethod)
      );
    }
  }

  // Crée la facture
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
      throw Exception('Impossible de charger la réponse');
    }
  }
}
