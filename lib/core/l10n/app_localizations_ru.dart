// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Mater Studorium';

  @override
  String get homeTitle => 'Главная';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get backToHome => 'На главную';

  @override
  String get spikeAddNote => 'Добавить запись (spike)';

  @override
  String spikeNoteText(int number) {
    return 'Запись $number';
  }

  @override
  String get spikeNoNotes => 'Записей пока нет';

  @override
  String spikeStorage(String impl) {
    return 'Хранилище на web: $impl';
  }

  @override
  String spikeNoteLine(String text, String time) {
    return '$text — $time';
  }
}
