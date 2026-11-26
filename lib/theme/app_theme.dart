import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  const AppColors._();

  static const Color accent = Color(0xFF8B7BFF);
  static const Color accentSoft = Color(0xFFB3A8FF);
  static const Color accentDeep = Color(0xFF5B4BD6);

  static const Color modeAction = Color(0xFFFF7A4D);
  static const Color modeActionAlt = Color(0xFFFFB35C);
  static const Color modeJamais = Color(0xFF8B7BFF);
  static const Color modeJamaisAlt = Color(0xFFC77DFF);
  static const Color modePrefere = Color(0xFF2DD4BF);
  static const Color modePrefereAlt = Color(0xFF38BDF8);

  static const Color intensitySoft = Color(0xFF4ADE80);
  static const Color intensityNormal = Color(0xFF8B7BFF);
  static const Color intensityHardcore = Color(0xFFFF9838);
  static const Color intensityAdulte = Color(0xFFFF4D6D);

  static const Color success = Color(0xFF4ADE80);
  static const Color danger = Color(0xFFFF5D6C);
  static const Color warning = Color(0xFFFFC043);

  static const List<Color> playerPalette = <Color>[
    Color(0xFF8B7BFF),
    Color(0xFF38BDF8),
    Color(0xFF2DD4BF),
    Color(0xFF86C440),
    Color(0xFFFFC043),
    Color(0xFFFF8A4D),
    Color(0xFFFF6B8A),
    Color(0xFFC77DFF),
  ];
}

@immutable
class CulSecColors extends ThemeExtension<CulSecColors> {
  const CulSecColors({
    required this.ink,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceTop,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textOnAccent, // <-- NOUVEAU
    required this.fill,
    required this.fillStrong,
    required this.border,
    required this.borderSoft,
    required this.gradientBackground,
    required this.gradientSurface,
  });

  final Color ink;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceTop;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textOnAccent;
  final Color fill;
  final Color fillStrong;
  final Color border;
  final Color borderSoft;
  final LinearGradient gradientBackground;
  final LinearGradient gradientSurface;

  // --- THÈME CLASSIQUE SOMBRE ---
  static const CulSecColors classicDark = CulSecColors(
    ink: Color(0xFF0B0A12),
    surface: Color(0xFF15131F),
    surfaceHigh: Color(0xFF1D1A2B),
    surfaceTop: Color(0xFF262236),
    textPrimary: Color(0xFFF7F6FB),
    textSecondary: Color(0xFFA9A3C0),
    textMuted: Color(0xFF746D92),
    textOnAccent: Colors.white,
    fill: Color(0x12FFFFFF),
    fillStrong: Color(0x1FFFFFFF),
    border: Color(0x26FFFFFF),
    borderSoft: Color(0x17FFFFFF),
    gradientBackground: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF12101C), Color(0xFF09080F)],
    ),
    gradientSurface: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF1E1B2D), Color(0xFF16131F)],
    ),
  );

  // --- THÈME CLASSIQUE CLAIR ---
  static const CulSecColors classicLight = CulSecColors(
    ink: Color(0xFFFCF9F5),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF2EFF6),
    surfaceTop: Color(0xFFE8E4F0),
    textPrimary: Color(0xFF1A162B),
    textSecondary: Color(0xFF5E5775),
    textMuted: Color(0xFF9E99AD),
    textOnAccent: Colors.white,
    fill: Color(0x08000000),
    fillStrong: Color(0x14000000),
    border: Color(0x1A000000),
    borderSoft: Color(0x0D000000),
    gradientBackground: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFFFCF9F5), Color(0xFFF0EAF3)],
    ),
    gradientSurface: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFFFFFFF), Color(0xFFFCF9F5)],
    ),
  );

  @override
  CulSecColors copyWith({
    Color? ink,
    Color? surface,
    Color? surfaceHigh,
    Color? surfaceTop,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textOnAccent,
    Color? fill,
    Color? fillStrong,
    Color? border,
    Color? borderSoft,
    LinearGradient? gradientBackground,
    LinearGradient? gradientSurface,
  }) {
    return CulSecColors(
      ink: ink ?? this.ink,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceTop: surfaceTop ?? this.surfaceTop,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textOnAccent: textOnAccent ?? this.textOnAccent,
      fill: fill ?? this.fill,
      fillStrong: fillStrong ?? this.fillStrong,
      border: border ?? this.border,
      borderSoft: borderSoft ?? this.borderSoft,
      gradientBackground: gradientBackground ?? this.gradientBackground,
      gradientSurface: gradientSurface ?? this.gradientSurface,
    );
  }

  @override
  CulSecColors lerp(ThemeExtension<CulSecColors>? other, double t) {
    if (other is! CulSecColors) return this;
    return CulSecColors(
      ink: Color.lerp(ink, other.ink, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceTop: Color.lerp(surfaceTop, other.surfaceTop, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textOnAccent: Color.lerp(textOnAccent, other.textOnAccent, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      fillStrong: Color.lerp(fillStrong, other.fillStrong, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t)!,
      gradientBackground: LinearGradient.lerp(gradientBackground, other.gradientBackground, t)!,
      gradientSurface: LinearGradient.lerp(gradientSurface, other.gradientSurface, t)!,
    );
  }
}

class AppGradients {
  const AppGradients._();
  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF9B8CFF), Color(0xFF6A57E0)],
  );
  static LinearGradient pair(Color a, Color b) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[a, b],
      );
}

class AppSpacing {
  const AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: 20);
}

class AppRadii {
  const AppRadii._();
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;
  static final BorderRadius card = BorderRadius.circular(lg);
  static final BorderRadius bigCard = BorderRadius.circular(xl);
  static final BorderRadius button = BorderRadius.circular(md);
  static const BorderRadius sheet = BorderRadius.vertical(top: Radius.circular(26));
}

class AppMotion {
  const AppMotion._();
  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration base = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 520);
  static const Duration stagger = Duration(milliseconds: 60);
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve spring = Curves.elasticOut;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve overshoot = Curves.easeOutBack;
}

class AppShadows {
  const AppShadows._();
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x55000000), blurRadius: 20, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> raised = <BoxShadow>[
    BoxShadow(color: Color(0x70000000), blurRadius: 32, offset: Offset(0, 16)),
  ];
  static List<BoxShadow> glow(Color color, {double opacity = 0.34}) => <BoxShadow>[
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 26,
          spreadRadius: -6,
          offset: const Offset(0, 8),
        ),
      ];
}

class AppTheme {
  const AppTheme._();

  static const SystemUiOverlayStyle systemOverlayDark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF0B0A12),
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static const SystemUiOverlayStyle systemOverlayLight = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFFFCF9F5),
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static TextTheme _buildTextTheme(Color textColor, Color textMuted) {
    const TextTheme base = Typography.whiteMountainView;
    final TextTheme display = GoogleFonts.outfitTextTheme(base);
    final TextTheme body = GoogleFonts.interTextTheme(base);

    return TextTheme(
      displayLarge: display.displayLarge!.copyWith(fontSize: 54, fontWeight: FontWeight.w700, height: 1.05, letterSpacing: -1.6, color: textColor),
      displayMedium: display.displayMedium!.copyWith(fontSize: 42, fontWeight: FontWeight.w700, height: 1.1, letterSpacing: -1, color: textColor),
      displaySmall: display.displaySmall!.copyWith(fontSize: 31, fontWeight: FontWeight.w600, height: 1.18, letterSpacing: -0.5, color: textColor),
      headlineLarge: display.headlineLarge!.copyWith(fontSize: 26, fontWeight: FontWeight.w600, height: 1.25, color: textColor),
      headlineMedium: display.headlineMedium!.copyWith(fontSize: 21, fontWeight: FontWeight.w600, color: textColor),
      titleLarge: display.titleLarge!.copyWith(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
      titleMedium: display.titleMedium!.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
      bodyLarge: body.bodyLarge!.copyWith(fontSize: 16, height: 1.5, color: textColor),
      bodyMedium: body.bodyMedium!.copyWith(fontSize: 14, height: 1.5, color: textColor),
      bodySmall: body.bodySmall!.copyWith(fontSize: 12.5, height: 1.45, color: textMuted),
      labelLarge: display.labelLarge!.copyWith(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2, color: textColor),
      labelMedium: body.labelMedium!.copyWith(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: textMuted),
    );
  }

  static ThemeData _buildTheme(Brightness brightness, CulSecColors colors) {
    final bool isDark = brightness == Brightness.dark;
    final TextTheme textTheme = _buildTextTheme(colors.textPrimary, colors.textMuted);

    final ColorScheme colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.accent,
      onPrimary: colors.textOnAccent,
      secondary: AppColors.accentSoft,
      onSecondary: isDark ? colors.ink : Colors.white,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      surfaceContainerHighest: colors.surfaceTop,
      error: AppColors.danger,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.ink,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      highlightColor: colors.fill,
      extensions: <ThemeExtension<dynamic>>[colors],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: isDark ? systemOverlayDark : systemOverlayLight,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: colors.textOnAccent,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.button),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentSoft,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          minimumSize: const Size.fromHeight(56),
          side: BorderSide(color: colors.border),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.button),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.fill,
        hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md), borderSide: BorderSide(color: colors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md), borderSide: BorderSide(color: colors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md), borderSide: const BorderSide(color: AppColors.accent, width: 1.8)),
      ),
      dividerTheme: DividerThemeData(color: colors.borderSoft, thickness: 1, space: AppSpacing.lg),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceTop,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceTop,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceTop,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
      ),
    );
  }

  static ThemeData dark() => _buildTheme(Brightness.dark, CulSecColors.classicDark);
  static ThemeData light() => _buildTheme(Brightness.light, CulSecColors.classicLight);
}

extension AppThemeX on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
  CulSecColors get culColors => Theme.of(this).extension<CulSecColors>()!;
  Size get screenSize => MediaQuery.sizeOf(this);
}