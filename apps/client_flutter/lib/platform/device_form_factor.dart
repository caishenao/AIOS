import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DeviceFormFactor {
  mobile,
  desktop,
  tv,
  car,
  xr,
}

class FormFactorNotifier extends StateNotifier<DeviceFormFactor> {
  static const String _key = 'device_form_factor_override';

  FormFactorNotifier() : super(DeviceFormFactor.mobile) {
    _loadOverride();
  }

  Future<void> _loadOverride() async {
    final prefs = await SharedPreferences.getInstance();
    final overrideStr = prefs.getString(_key);
    if (overrideStr != null) {
      try {
        state = DeviceFormFactor.values.firstWhere((e) => e.name == overrideStr);
      } catch (_) {
        state = DeviceFormFactor.mobile;
      }
    }
  }

  Future<void> setFormFactor(DeviceFormFactor formFactor) async {
    state = formFactor;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, formFactor.name);
  }
}

final formFactorProvider = StateNotifierProvider<FormFactorNotifier, DeviceFormFactor>((ref) {
  return FormFactorNotifier();
});
