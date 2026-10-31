import 'package:flutter/material.dart';

/// Global navigator key allowing persistent overlays (such as [MiniPlayerHost]
/// in `MaterialApp.builder`) to safely launch modals and general dialogs.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
