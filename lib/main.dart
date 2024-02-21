// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert' show json;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'src/sign_in_button.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
//import 'package:mini_server/mini_server.dart';
import 'package:network_info_plus/network_info_plus.dart';

bool isSwitched = false; // Global variable to store switch state
List<Alarm>alarms = [];
/// The scopes required by this application.
// #docregion Initialize
const List<String> scopes = <String>[
  'https://www.googleapis.com/auth/calendar',
];

GoogleSignIn _googleSignIn = GoogleSignIn(
  // Optional clientId
  //clientId: '797159991956-a7i2e730ec0ih9bk1n4t69h0d1co3sgk.apps.googleusercontent.com',
  scopes: scopes,
);
// #enddocregion Initialize

void main() {

  runApp(
    const MaterialApp(
      title: 'Google Sign In',
      home: SignInDemo(),
    ),
  );
}

/// The SignInDemo app.
class SignInDemo extends StatefulWidget {
  ///
  const SignInDemo({super.key});

  @override
  State createState() => _SignInDemoState();
}

class _SignInDemoState extends State<SignInDemo> {
  GoogleSignInAccount? _currentUser;
  bool _isAuthorized = false; // has granted permissions?

  @override
  void initState() {
    super.initState();

    _googleSignIn.onCurrentUserChanged
        .listen((GoogleSignInAccount? account) async {
//
      // In mobile, being authenticated means being authorized...
      bool isAuthorized = account != null;
      // However, on web...
      if (kIsWeb && account != null) {
        isAuthorized = await _googleSignIn.canAccessScopes(scopes);
      }
//

      setState(() {
        _currentUser = account;
        _isAuthorized = isAuthorized;
      });

      // Now that we know that the user can access the required scopes, the app
      // can call the REST API.
      if (isAuthorized) {
        unawaited(_handleGetCalendars(account!));
      }
    });

    // In the web, _googleSignIn.signInSilently() triggers the One Tap UX.
    //
    // It is recommended by Google Identity Services to render both the One Tap UX
    // and the Google Sign In button together to "reduce friction and improve
    // sign-in rates" ([docs](https://developers.google.com/identity/gsi/web/guides/display-button#html)).
    _googleSignIn.signInSilently();
  }


  Future<void> _handleSignIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (error) {
      print(error);
    }
  }

  // #enddocregion SignIn

  // Prompts the user to authorize `scopes`.
  //
  // This action is **required** in platforms that don't perform Authentication
  // and Authorization at the same time (like the web).
  //
  // On the web, this must be called from an user interaction (button click).
  // #docregion RequestScopes
  Future<void> _handleAuthorizeScopes() async {
    final bool isAuthorized = await _googleSignIn.requestScopes(scopes);
    // #enddocregion RequestScopes
    setState(() {
      _isAuthorized = isAuthorized;
    });
    // #docregion RequestScopes
    if (isAuthorized) {

    }
    // #enddocregion RequestScopes
  }

  Future<void> _handleGetCalendars(GoogleSignInAccount user) async {
    DateTime now = DateTime.now();
    DateTime startTime = DateTime(now.year, now.month, now.day, 4, 0, 0);
    DateTime endTime = now.add(const Duration(days: 30));
    endTime = DateTime(endTime.year, endTime.month, endTime.day, 10, 0, 0);
    String formattedStartTime = startTime.toUtc().toIso8601String();
    String formattedEndTime = endTime.toUtc().toIso8601String();

    final http.Response response = await http.get(
      Uri.parse('https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=$formattedStartTime&timeMax=$formattedEndTime&singleEvents=true'),
      headers: await user.authHeaders,
    );

    if (response.statusCode == 200) {
      Map<String, dynamic> jsonResponse = jsonDecode(response.body);
      List<dynamic> events = jsonResponse['items'];
      Map<String, dynamic> firstEvents = {};
      for (var event in events) {
        String eventDate = event['start']['date'] ?? event['start']['dateTime'];
        String date = eventDate.substring(0, 10);

        if (!firstEvents.containsKey(date)) {
          firstEvents[date] = event;
        }
      }
      alarms = [];
      alarms.add(Alarm(0,0,0,0));
      for (var date in firstEvents.keys) {
        var event = firstEvents[date];

        // Extract start time of the event
        String eventStartTimeStr = event['start']['dateTime'] ?? event['start']['date'];
        DateTime eventStartTime = DateTime.parse(eventStartTimeStr);

        // Calculate alarm time (1 hour before the event)
        DateTime alarmTime = eventStartTime.subtract(Duration(hours: 0));
        alarms.add(Alarm(alarmTime.day,alarmTime.month,alarmTime.hour, alarmTime.minute));
      }
      for (var alarm in alarms) {
        print(alarm);
      }
      startServer();
      return;
    }else
    {
      print('calendars API Error ${response.statusCode} response: ${response.body}');
    }
  }
  startServer()async{
    //InternetAddress.loopbackIPv4
    final ipv4 = "0.0.0.0"; //await NetworkInfo().getWifiIP();
    print("Address: $ipv4");
    var server = await HttpServer.bind(ipv4, 4040);
    print("Server running on IP : "+server.address.toString()+" On Port : "+server.port.toString());
    await for (var request in server) {
      DateTime now = DateTime.now();
      String currentDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      Map<String, dynamic> jsonResponse = {
        'chargingTime': 1,
        'dateTime': currentDateTime,
        'alarms': alarms.map((alarm) => {'hour': alarm.hour, 'minute': alarm.minute, 'day':alarm.day, 'month':alarm.month}).toList(),
      };
      String jsonString = jsonEncode(jsonResponse);
      print("route solicited");
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonString)
        ..close();
    }
  }



    Future<void> _handleSignOut() => _googleSignIn.disconnect();


    Widget _buildBody() {
      final GoogleSignInAccount? user = _currentUser;
      if (user != null) {
        // The user is Authenticated
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            ListTile(
              leading: GoogleUserCircleAvatar(
                identity: user,
              ),
              title: Text(user.displayName ?? ''),
              subtitle: Text(user.email),
            ),
            const Text('Signed in successfully.'),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children:<Widget> [
              Text('2 Hours charging time (default is 1 hour)'),
              Switch(
                  value: isSwitched,
                  onChanged: (newValue) {
                    setState(() {
                      isSwitched = newValue;
                    });
                  })
            ])
            ,
            if (_isAuthorized) ...<Widget>[
              // The user has Authorized all required scopes
              ElevatedButton(
                child: const Text('Set up Alarmy'),
                onPressed: () => _handleGetCalendars(user),
              ),
            ],
            if (!_isAuthorized) ...<Widget>[
              // The user has NOT Authorized all required scopes.
              // (Mobile users may never see this button!)
              const Text(
                  'Additional permissions needed to read your contacts.'),
              ElevatedButton(
                onPressed: _handleAuthorizeScopes,
                child: const Text('REQUEST PERMISSIONS'),
              ),
            ],
            ElevatedButton(
              onPressed: _handleSignOut,
              child: const Text('SIGN OUT'),
            ),
          ],
        );
      } else {
        // The user is NOT Authenticated
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            const Text('You are not currently signed in.'),
            // This method is used to separate mobile from web code with conditional exports.
            // See: src/sign_in_button.dart
            buildSignInButton(
              onPressed: _handleSignIn,
            ),
          ],
        );
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
          appBar: AppBar(
            title: const Text('Google Sign In'),
          ),
          body: ConstrainedBox(
            constraints: const BoxConstraints.expand(),
            child: _buildBody(),
          ));
    }
  }


class Alarm {
  int day;
  int month;
  int hour;
  int minute;
  Alarm(this.day,this.month, this.hour, this.minute);

  @override
  String toString() {
    return 'Alarm time: $day-$month-$hour:$minute';
  }
}
