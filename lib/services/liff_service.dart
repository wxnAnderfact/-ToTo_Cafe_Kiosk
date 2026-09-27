// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, camel_case_types, non_constant_identifier_names
import 'dart:async';
import 'dart:js' as dart_js;
import 'package:flutter/foundation.dart';

/// JS Interop helper providing `js.context`, `js.JsObject`, and `js.allowInterop`.
class js {
  static dart_js.JsObject get context => dart_js.context;
  static F allowInterop<F extends Function>(F f) => f;
  static final JsObjectFactory JsObject = JsObjectFactory();
}

class JsObjectFactory {
  dart_js.JsObject jsify(dynamic obj) => dart_js.JsObject.jsify(obj);
}

class LiffService {
  static final LiffService _instance = LiffService._internal();
  factory LiffService() => _instance;
  LiffService._internal();

  static const String liffId = '2011572383-l29PIrit';
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    final completer = Completer<void>();

    try {
      if (!kIsWeb) {
        debugPrint('LiffService: Not running on web.');
        completer.complete();
        return;
      }

      if (!js.context.hasProperty('liff') || js.context['liff'] == null) {
        debugPrint('LiffService: window.liff is not defined.');
        completer.complete();
        return;
      }

      final liff = js.context['liff'] as dart_js.JsObject;
      final initObj = js.JsObject.jsify({
        'liffId': liffId,
        'withLoginOnExternalBrowser': true,
      });

      // In LIFF v2, init takes only the config object and returns a Promise
      final res = liff.callMethod('init', [initObj]);

      if (res is dart_js.JsObject && res.hasProperty('then')) {
        res.callMethod('then', [
          js.allowInterop((_) {
            _isInitialized = true;
            debugPrint('LiffService: LIFF initialized successfully.');
            if (!completer.isCompleted) {
              completer.complete();
            }
          }),
        ]);
        if (res.hasProperty('catch')) {
          res.callMethod('catch', [
            js.allowInterop((e) {
              debugPrint('LiffService: LIFF init rejected: $e');
              if (!completer.isCompleted) {
                completer.completeError(e ?? 'LIFF init promise rejected');
              }
            }),
          ]);
        }
      } else {
        _isInitialized = true;
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    } catch (e) {
      debugPrint('LiffService.initialize catch: $e');
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }

    await completer.future;
  }

  bool isLoggedIn() {
    try {
      if (!kIsWeb) return false;
      if (js.context.hasProperty('liff') && js.context['liff'] != null) {
        final result = js.context['liff'].callMethod('isLoggedIn', []);
        return result == true;
      }
    } catch (e) {
      debugPrint('LiffService.isLoggedIn error: $e');
    }
    return false;
  }

  bool isInClient() {
    try {
      if (!kIsWeb) return false;
      if (js.context.hasProperty('liff') && js.context['liff'] != null) {
        final result = js.context['liff'].callMethod('isInClient', []);
        return result == true;
      }
    } catch (e) {
      debugPrint('LiffService.isInClient error: $e');
    }
    return false;
  }

  void login() {
    try {
      if (!kIsWeb) return;
      if (js.context.hasProperty('liff') && js.context['liff'] != null) {
        js.context['liff'].callMethod('login', []);
      }
    } catch (e) {
      debugPrint('LiffService.login error: $e');
    }
  }

  Future<Map<String, String>> getProfile() async {
    final completer = Completer<Map<String, String>>();
    try {
      if (!kIsWeb) {
        return {'userId': '', 'displayName': '', 'pictureUrl': ''};
      }

      if (js.context.hasProperty('liff') && js.context['liff'] != null) {
        final liff = js.context['liff'] as dart_js.JsObject;
        final profilePromise = liff.callMethod('getProfile', []);

        if (profilePromise is dart_js.JsObject && profilePromise.hasProperty('then')) {
          profilePromise.callMethod('then', [
            js.allowInterop((dynamic profile) {
              String uid = '';
              String name = '';
              String pic = '';
              try {
                if (profile != null) {
                  uid = (profile['userId'] ?? '').toString();
                  name = (profile['displayName'] ?? '').toString();
                  pic = (profile['pictureUrl'] ?? '').toString();
                }
              } catch (e) {
                debugPrint('LiffService.getProfile read error: $e');
              }
              debugPrint('LiffService.getProfile success: userId=$uid, name=$name');
              if (!completer.isCompleted) {
                completer.complete({
                  'userId': uid,
                  'displayName': name,
                  'pictureUrl': pic,
                });
              }
            }),
          ]);
          if (profilePromise.hasProperty('catch')) {
            profilePromise.callMethod('catch', [
              js.allowInterop((error) {
                debugPrint('LiffService.getProfile error: $error');
                if (!completer.isCompleted) {
                  completer.complete({
                    'userId': '',
                    'displayName': '',
                    'pictureUrl': '',
                  });
                }
              }),
            ]);
          }
          return await completer.future;
        }
      }
    } catch (e) {
      debugPrint('LiffService.getProfile catch: $e');
    }
    return {
      'userId': '',
      'displayName': '',
      'pictureUrl': '',
    };
  }
}
