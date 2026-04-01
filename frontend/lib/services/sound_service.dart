import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import '../services/logger_service.dart';

// mciSendStringW signature from winmm.dll
typedef _MciSendStringNative = Uint32 Function(
  Pointer<Utf16> lpszCommand,
  Pointer<Utf16> lpszReturnString,
  Uint32 cchReturn,
  IntPtr hwndCallback,
);
typedef _MciSendStringDart = int Function(
  Pointer<Utf16> lpszCommand,
  Pointer<Utf16> lpszReturnString,
  int cchReturn,
  int hwndCallback,
);
typedef _MciGetErrorStringNative = Int32 Function(
  Uint32 fdwError,
  Pointer<Utf16> lpszErrorText,
  Uint32 cchErrorText,
);
typedef _MciGetErrorStringDart = int Function(
  int fdwError,
  Pointer<Utf16> lpszErrorText,
  int cchErrorText,
);

/// Servicio para reproducir sonidos NG/OK usando la API MCI de Windows (winmm.dll).
/// No requiere paquetes de audio externos.
class SoundService {
  static final _log = LoggerService();
  static _MciSendStringDart? _mciSendString;
  static _MciGetErrorStringDart? _mciGetErrorString;
  static String? _ngSoundPath;
  static String? _okSoundPath;

  static void _init() {
    if (_mciSendString != null) return;

    try {
      final winmm = DynamicLibrary.open('winmm.dll');
      _mciSendString =
          winmm.lookupFunction<_MciSendStringNative, _MciSendStringDart>(
        'mciSendStringW',
      );
      _mciGetErrorString = winmm.lookupFunction<_MciGetErrorStringNative,
          _MciGetErrorStringDart>('mciGetErrorStringW');

      // Los assets de Flutter se ubican en data/flutter_assets/ relativo al ejecutable
      final exeDir = p.dirname(Platform.resolvedExecutable);
      _ngSoundPath = p.join(
        exeDir,
        'data',
        'flutter_assets',
        'assets',
        'sounds',
        'NG_Sound.mpeg',
      );
      _okSoundPath = p.join(
        exeDir,
        'data',
        'flutter_assets',
        'assets',
        'sounds',
        'OK_Sound.mpeg',
      );

      _log.info('Sound', 'SoundService inicializado',
          'NG: $_ngSoundPath\nOK: $_okSoundPath');

      if (_ngSoundPath != null && !File(_ngSoundPath!).existsSync()) {
        _log.error('Sound', 'Archivo NG no encontrado', _ngSoundPath!);
      }
      if (_okSoundPath != null && !File(_okSoundPath!).existsSync()) {
        _log.error('Sound', 'Archivo OK no encontrado', _okSoundPath!);
      }
    } catch (e) {
      _log.error('Sound', 'Error al inicializar SoundService', e.toString());
    }
  }

  /// Envía un comando MCI a Windows.
  static int _sendMci(String command) {
    final cmdPtr = command.toNativeUtf16();
    try {
      return _mciSendString!(cmdPtr, Pointer<Utf16>.fromAddress(0), 0, 0);
    } finally {
      malloc.free(cmdPtr);
    }
  }

  static String _getMciErrorText(int errorCode) {
    if (_mciGetErrorString == null) return 'Código MCI: $errorCode';

    final buffer = calloc<Uint16>(256);
    final utf16Buffer = buffer.cast<Utf16>();
    try {
      final result = _mciGetErrorString!(errorCode, utf16Buffer, 256);
      if (result == 0) return 'Código MCI: $errorCode';
      return utf16Buffer.toDartString();
    } finally {
      calloc.free(buffer);
    }
  }

  static bool _playSound(String alias, String path, String soundName) {
    final file = File(path);
    if (!file.existsSync()) {
      _log.error('Sound', 'Archivo de sonido no encontrado', path);
      return false;
    }

    final closeResult = _sendMci('close $alias');
    if (closeResult != 0) {
      _log.debug('Sound', 'close $alias devolvió $closeResult');
    }

    final openResult = _sendMci('open "$path" type mpegvideo alias $alias');
    if (openResult != 0) {
      _log.error(
        'Sound',
        'Error al abrir sonido $soundName',
        _getMciErrorText(openResult),
      );
      return false;
    }

    final playResult = _sendMci('play $alias from 0');
    if (playResult != 0) {
      _log.error(
        'Sound',
        'Error al reproducir sonido $soundName',
        _getMciErrorText(playResult),
      );
      return false;
    }

    return true;
  }

  /// Reproduce el sonido de error (NG_Sound.mpeg).
  static void playError() {
    _init();
    if (_mciSendString == null || _ngSoundPath == null) return;
    try {
      _playSound('ngSound', _ngSoundPath!, 'NG');
    } catch (e) {
      _log.error('Sound', 'Error al reproducir sonido NG', e.toString());
    }
  }

  /// Reproduce el sonido de éxito (OK_Sound.mpeg).
  static void playSuccess() {
    _init();
    if (_mciSendString == null || _okSoundPath == null) return;
    try {
      _playSound('okSound', _okSoundPath!, 'OK');
    } catch (e) {
      _log.error('Sound', 'Error al reproducir sonido OK', e.toString());
    }
  }

  /// Libera recursos MCI.
  static void dispose() {
    try {
      if (_mciSendString != null) {
        _sendMci('close ngSound');
        _sendMci('close okSound');
      }
    } catch (_) {}
  }
}
