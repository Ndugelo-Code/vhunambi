/// Barrel export for the Vhunambi Cross-Cutting Design System.
///
/// Provides a single import point for all design system public APIs:
/// tokens, theme extension, services, and generation state models.
///
/// ```dart
/// import 'package:vhunambi_client/core/design_system/design_system.dart';
/// ```
library;

// Tokens
export 'tokens/app_icons.dart';
export 'tokens/color_token.dart';
export 'tokens/contrast_utils.dart';
export 'tokens/design_enums.dart';
export 'tokens/design_token_registry.dart';
export 'tokens/token_exceptions.dart';
export 'tokens/token_registration.dart';

// Theme
export 'theme/vhunambi_theme_extension.dart';

// Services
export 'services/accessibility_service.dart';
export 'services/analytics_service.dart';
export 'services/haptics_service.dart';

// Models
export 'models/generation_request_model.dart';
export 'models/generation_request_notifier.dart';
