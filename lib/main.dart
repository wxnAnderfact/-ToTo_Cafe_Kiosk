import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'providers/cart_provider.dart';
import 'services/menu_service.dart';
import 'screens/standby_screen.dart';
import 'screens/cashier_pos_screen.dart';

void main() async {
  debugPrint('--- [DEBUG] main() started ---');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('--- [DEBUG] WidgetsFlutterBinding initialized ---');
  try {
    debugPrint('--- [DEBUG] Calling Firebase.initializeApp() ---');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('--- [DEBUG] Firebase.initializeApp() completed ---');

    // Seed Firestore with initial menu data if empty.
    // Change to menuService.reseed() to force-refresh all menu data.
    final menuService = MenuService();
    debugPrint('--- [DEBUG] Firing menuService.seedIfEmpty() in background ---');
    menuService.seedIfEmpty().then((_) {
      debugPrint('--- [DEBUG] menuService.seedIfEmpty() completed ---');
    }).catchError((e) {
      debugPrint('--- [DEBUG] menuService.seedIfEmpty() failed: $e ---');
    });

    debugPrint('--- [DEBUG] Calling runApp(TotoCafeApp) ---');
    runApp(TotoCafeApp(menuService: menuService));
  } catch (e) {
    debugPrint('--- [DEBUG] Exception caught: $e ---');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Firebase Init Error:\n$e',
                style: const TextStyle(color: Colors.red, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TotoCafeApp extends StatelessWidget {
  const TotoCafeApp({super.key, required this.menuService});

  final MenuService menuService;

  @override
  Widget build(BuildContext context) {
    debugPrint('--- [DEBUG] TotoCafeApp.build() started ---');
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        Provider.value(value: menuService),
      ],
      child: MaterialApp(
        title: 'ToTo Cafe Kiosk',
        debugShowCheckedModeBanner: false,
        theme: totoCafeTheme,
        // Use /cashier route for POS iPad, default is Kiosk standby
        routes: {
          '/': (_) {
            debugPrint('--- [DEBUG] Building StandbyScreen (route /) ---');
            return const StandbyScreen();
          },
          '/cashier': (_) => const CashierPosScreen(),
          '/firebase-test': (_) => const FirebaseTestScreen(),
        },
      ),
    );
  }
}

/// Temporary screen to verify Firebase + Firestore connectivity.
/// Replace this with the actual Kiosk standby screen later.
class FirebaseTestScreen extends StatelessWidget {
  const FirebaseTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ToTo Cafe — Firebase Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 80),
            const SizedBox(height: kSpace24),
            Text(
              'Firebase initialized successfully!',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: kSpace8),
            Text(
              'Project: ${Firebase.app().options.projectId}',
              style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: kSpace32),
            ElevatedButton.icon(
              onPressed: () => _testFirestoreWrite(context),
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Test Firestore Write'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testFirestoreWrite(BuildContext context) async {
    try {
      final docRef =
          FirebaseFirestore.instance.collection('connection_tests').doc();
      await docRef.set({
        'message': 'Hello from ToTo Cafe Kiosk!',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Firestore write succeeded! Doc ID: ${docRef.id}'),
            backgroundColor: kColorPrimary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Firestore error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
