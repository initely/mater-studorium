import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ru')];

  /// Название приложения
  ///
  /// In ru, this message translates to:
  /// **'Mater Studorium'**
  String get appTitle;

  /// Заголовок главного экрана-заглушки
  ///
  /// In ru, this message translates to:
  /// **'Главная'**
  String get homeTitle;

  /// Заголовок экрана настроек и подпись кнопки перехода
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settingsTitle;

  /// Кнопка возврата с экрана настроек на главный
  ///
  /// In ru, this message translates to:
  /// **'На главную'**
  String get backToHome;

  /// Заголовок экрана каталога колод и подпись кнопки перехода на него
  ///
  /// In ru, this message translates to:
  /// **'Колоды'**
  String get decksTitle;

  /// Пустой каталог: на сервере нет доступных колод
  ///
  /// In ru, this message translates to:
  /// **'Колод пока нет'**
  String get decksEmpty;

  /// Кнопка повтора загрузки каталога
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get decksRetry;

  /// Кнопка скачивания колоды, которой нет на устройстве
  ///
  /// In ru, this message translates to:
  /// **'Скачать'**
  String get decksDownload;

  /// Кнопка обновления скачанной колоды до новой версии
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get decksUpdate;

  /// Метка скачанной колоды без новой версии
  ///
  /// In ru, this message translates to:
  /// **'Скачано'**
  String get decksDownloaded;

  /// Подпись кнопки во время скачивания колоды
  ///
  /// In ru, this message translates to:
  /// **'Загрузка…'**
  String get decksDownloading;

  /// Подпись колоды в каталоге: тема, версия, число знаний
  ///
  /// In ru, this message translates to:
  /// **'{topic} · версия {version} · {count, plural, one{{count} знание} few{{count} знания} many{{count} знаний} other{{count} знания}}'**
  String decksSubtitle(String topic, int version, int count);

  /// Подпись скачанной колоды, которой нет в каталоге (число знаний неизвестно)
  ///
  /// In ru, this message translates to:
  /// **'{topic} · версия {version}'**
  String decksSubtitleLocal(String topic, int version);

  /// Каталог не загрузился из-за сети
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить каталог: нужна сеть. Скачанные колоды доступны.'**
  String get decksListErrorNetwork;

  /// Каталог не загрузился по другой причине
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить каталог. Попробуйте позже.'**
  String get decksListErrorGeneric;

  /// Скачивание колоды не удалось: нет сети (ТЗ §8.5)
  ///
  /// In ru, this message translates to:
  /// **'Нужна сеть, чтобы скачать колоду'**
  String get decksErrorNetwork;

  /// Файл колоды не прошёл проверку; прежняя версия осталась (AC2.3)
  ///
  /// In ru, this message translates to:
  /// **'Файл колоды повреждён, колода не изменена'**
  String get decksErrorCorrupt;

  /// Формат колоды новее, чем понимает приложение
  ///
  /// In ru, this message translates to:
  /// **'Колоде нужна более новая версия приложения. Обновите приложение.'**
  String get decksErrorSchemaTooNew;

  /// Совпал id знания с другой колодой
  ///
  /// In ru, this message translates to:
  /// **'Колода конфликтует с уже скачанной: одно и то же знание есть в обеих'**
  String get decksErrorCollision;

  /// Колоду сняли с публикации или она недоступна
  ///
  /// In ru, this message translates to:
  /// **'Колода не найдена на сервере'**
  String get decksErrorNotFound;

  /// Скачивание колоды не удалось по неизвестной причине
  ///
  /// In ru, this message translates to:
  /// **'Не удалось скачать колоду. Попробуйте ещё раз.'**
  String get decksErrorGeneric;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
