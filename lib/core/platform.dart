import 'package:flutter/foundation.dart';

/// Le tirage pour actualiser (swipe) n’a de sens que sur mobile tactile.
bool get supportsPullToRefresh {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
