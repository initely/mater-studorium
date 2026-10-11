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
  String get decksTitle => 'Колоды';

  @override
  String get decksEmpty => 'Колод пока нет';

  @override
  String get decksRetry => 'Повторить';

  @override
  String get decksDownload => 'Скачать';

  @override
  String get decksUpdate => 'Обновить';

  @override
  String get decksDownloaded => 'Скачано';

  @override
  String get decksDownloading => 'Загрузка…';

  @override
  String decksSubtitle(String topic, int version, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count знания',
      many: '$count знаний',
      few: '$count знания',
      one: '$count знание',
    );
    return '$topic · версия $version · $_temp0';
  }

  @override
  String decksSubtitleLocal(String topic, int version) {
    return '$topic · версия $version';
  }

  @override
  String get decksListErrorNetwork =>
      'Не удалось загрузить каталог: нужна сеть. Скачанные колоды доступны.';

  @override
  String get decksListErrorGeneric =>
      'Не удалось загрузить каталог. Попробуйте позже.';

  @override
  String get decksErrorNetwork => 'Нужна сеть, чтобы скачать колоду';

  @override
  String get decksErrorCorrupt => 'Файл колоды повреждён, колода не изменена';

  @override
  String get decksErrorSchemaTooNew =>
      'Колоде нужна более новая версия приложения. Обновите приложение.';

  @override
  String get decksErrorCollision =>
      'Колода конфликтует с уже скачанной: одно и то же знание есть в обеих';

  @override
  String get decksErrorNotFound => 'Колода не найдена на сервере';

  @override
  String get decksErrorGeneric =>
      'Не удалось скачать колоду. Попробуйте ещё раз.';
}
