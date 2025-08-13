import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/clubs.dart';
import 'package:my_app/dashboard.dart';
import 'package:my_app/events.dart';
import 'package:my_app/homepage.dart';
import 'package:my_app/login.dart';
import 'package:my_app/notices.dart';
import 'package:my_app/register.dart'; // 🔹 Add this
import 'package:my_app/workshops.dart';
import 'options.dart';  // import your options page


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // 🔥 This is important
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RUET Smart Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/register': (context) => const RegisterPage(),
        '/login': (context) => const LoginPage(),
        // '/options': (context) => const OptionsPage(userRoll: roll), // remove this
        '/events': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?; // nullable
          final userRoll = args?['userRoll'] ?? 'guest'; // default value
          return EventsPage(currentUserRoll: userRoll);
        },

        '/workshops': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final userRoll = args?['userRoll'] ?? 'guest'; // fallback if null
          return WorkshopsPage(currentUserRoll: userRoll);
        },

        '/notices': (context) => const NoticesPage(),
        '/clubs': (context) => const ClubsPage(),
        // add others as needed
      },
    );
  }
}