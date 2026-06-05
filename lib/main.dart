import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/router.dart';
import 'data/services/db_change_service.dart';
import 'data/services/sync_service.dart';
import 'presentation/widgets/offline_banner.dart';

void main() {
  // Zona guardada: captura cualquier error no manejado (sync y async) que de
  // otro modo sería invisible. ensureInitialized va dentro para que el binding
  // y runApp compartan la misma zona.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Errores del framework (build/layout/paint) y errores async de la plataforma.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _reportError(details.exception, details.stack);
    };
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      _reportError(error, stack);
      return true;
    };

    // Inicializar sqflite para desktop (Windows/Linux/macOS)
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Cargar variables de entorno. Si falta el .env (p.ej. build sin el asset
    // empaquetado), no abortamos el arranque: SupabaseConfig.isConfigured maneja
    // la ausencia de credenciales y la app corre en modo local.
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      debugPrint('No se pudo cargar .env, se continúa sin config remota: $e');
    }

    // Inicializar locale para fechas en español
    await initializeDateFormatting('es', null);

    // Inicializar Supabase (solo si está configurado)
    if (SupabaseConfig.isConfigured) {
      try {
        await SupabaseConfig.initialize();
      } catch (e) {
        debugPrint('Error inicializando Supabase: $e');
      }
    }

    // Configurar barra de estado transparente
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppTheme.surface,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    runApp(
      const ProviderScope(
        child: GestorVehiculosApp(),
      ),
    );
  }, (error, stack) => _reportError(error, stack));
}

/// Punto único de reporte de errores no manejados. Hoy va a debugPrint; este es
/// el lugar para enganchar un logger persistente o Sentry/Crashlytics y tener
/// visibilidad de crashes en release.
void _reportError(Object error, StackTrace? stack) {
  debugPrint('❌ [ERROR no manejado] $error');
  if (stack != null) debugPrint(stack.toString());
}

class GestorVehiculosApp extends ConsumerStatefulWidget {
  const GestorVehiculosApp({super.key});

  @override
  ConsumerState<GestorVehiculosApp> createState() => _GestorVehiculosAppState();
}

class _GestorVehiculosAppState extends ConsumerState<GestorVehiculosApp> {
  @override
  void initState() {
    super.initState();
    // Sincronizar datos y suscribirse a cambios en tiempo real
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (SupabaseConfig.isConfigured) {
        ref.read(syncServiceProvider.notifier).fullSync();
        DbChangeService.instance.onRemoteChange = () {
          final notifier = ref.read(syncServiceProvider.notifier);
          // Ignorar el eco de realtime de nuestras propias escrituras recientes.
          if (!notifier.shouldSuppressRealtimeEcho) notifier.fullSync();
        };
        DbChangeService.instance.startRealtimeSubscription();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Gestor de Vehículos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      locale: const Locale('es', 'ES'),
      supportedLocales: const [
        Locale('es', 'ES'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return MediaQuery(
          // Asegurar que el texto no se escale demasiado
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: OfflineBanner(child: child!),
        );
      },
    );
  }
}
