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

  /// Главная кнопка запуска сессии (ТЗ §8.2)
  ///
  /// In ru, this message translates to:
  /// **'Начать сессию (5 мин)'**
  String get homeStartSession;

  /// Подпись счётчика «к повторению»; число показано отдельно
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{знание к повторению} few{знания к повторению} many{знаний к повторению} other{знания к повторению}}'**
  String homeDueLabel(int count);

  /// Подпись счётчика новых знаний на сегодня
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{новое знание} few{новых знания} many{новых знаний} other{новых знания}}'**
  String homeNewLabel(int count);

  /// Озвучка блока счётчиков главного экрана
  ///
  /// In ru, this message translates to:
  /// **'К повторению: {due}, новых: {fresh}'**
  String homeStatsSemantics(int due, int fresh);

  /// Главный экран без скачанных колод (ТЗ §8.5)
  ///
  /// In ru, this message translates to:
  /// **'Пока нет колод'**
  String get homeNoDecksTitle;

  /// Подсказка главного экрана без колод
  ///
  /// In ru, this message translates to:
  /// **'Скачайте первую колоду, чтобы начать повторять.'**
  String get homeNoDecksBody;

  /// Кнопка перехода к каталогу с главного экрана без колод
  ///
  /// In ru, this message translates to:
  /// **'Скачать колоду'**
  String get homeNoDecksAction;

  /// В скачанных колодах нет знаний для повторения
  ///
  /// In ru, this message translates to:
  /// **'Здесь пока нечего повторять'**
  String get homeNothingTitle;

  /// Подсказка, если в колодах нет доступных знаний
  ///
  /// In ru, this message translates to:
  /// **'Загляните в колоды: возможно, в них вышло обновление.'**
  String get homeNothingBody;

  /// Ошибка подсчёта статистики
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить данные главного экрана.'**
  String get homeError;

  /// Повтор загрузки главного экрана
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get homeRetry;

  /// Кнопка перехода к колодам на главном экране
  ///
  /// In ru, this message translates to:
  /// **'Колоды'**
  String get homeDecksButton;

  /// Версия колоды и число знаний на экране колоды
  ///
  /// In ru, this message translates to:
  /// **'Версия {version} · {count, plural, one{{count} знание} few{{count} знания} many{{count} знаний} other{{count} знания}}'**
  String deckVersionLine(int version, int count);

  /// Нет описания у колоды (скачана до его хранения)
  ///
  /// In ru, this message translates to:
  /// **'Описание отсутствует.'**
  String get deckNoDescription;

  /// Заголовок блока прогресса колоды
  ///
  /// In ru, this message translates to:
  /// **'Прогресс'**
  String get deckProgressTitle;

  /// Знания, которые ещё не показывали
  ///
  /// In ru, this message translates to:
  /// **'Новые'**
  String get deckNewLabel;

  /// Знания на стадиях обучения и переобучения FSRS
  ///
  /// In ru, this message translates to:
  /// **'Изучаемые'**
  String get deckLearningLabel;

  /// Знания на стадии повторения FSRS
  ///
  /// In ru, this message translates to:
  /// **'Выученные'**
  String get deckMasteredLabel;

  /// Озвучка полосы прогресса колоды
  ///
  /// In ru, this message translates to:
  /// **'Прогресс по колоде: новых {fresh}, изучаемых {learning}, выученных {mastered}'**
  String deckProgressSemantics(int fresh, int learning, int mastered);

  /// Запуск сессии по одной колоде
  ///
  /// In ru, this message translates to:
  /// **'Начать по этой колоде'**
  String get deckStart;

  /// Кнопка обновления колоды на экране колоды
  ///
  /// In ru, this message translates to:
  /// **'Проверить обновление'**
  String get deckCheckUpdate;

  /// Идёт проверка обновления колоды
  ///
  /// In ru, this message translates to:
  /// **'Проверяем…'**
  String get deckUpdating;

  /// Колода обновилась
  ///
  /// In ru, this message translates to:
  /// **'Колода обновлена до версии {version}'**
  String deckUpdated(int version);

  /// Обновлений колоды нет
  ///
  /// In ru, this message translates to:
  /// **'Установлена последняя версия'**
  String get deckUpToDate;

  /// Подпись настройки лимита новых на экране колоды
  ///
  /// In ru, this message translates to:
  /// **'Новых знаний в день'**
  String get deckNewPerDay;

  /// Пояснение к лимиту новых на экране колоды
  ///
  /// In ru, this message translates to:
  /// **'Один лимит на все колоды'**
  String get deckNewPerDayHint;

  /// Кнопка удаления локальной колоды
  ///
  /// In ru, this message translates to:
  /// **'Удалить с устройства'**
  String get deckDelete;

  /// Заголовок диалога удаления колоды
  ///
  /// In ru, this message translates to:
  /// **'Удалить колоду?'**
  String get deckDeleteTitle;

  /// Текст подтверждения удаления колоды (ADR-27)
  ///
  /// In ru, this message translates to:
  /// **'Колода «{title}» исчезнет с этого устройства. Ваш прогресс сохранится: если скачать колоду снова, вы продолжите с того же места.'**
  String deckDeleteBody(String title);

  /// Отмена удаления колоды
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get deckDeleteCancel;

  /// Подтверждение удаления колоды
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get deckDeleteConfirm;

  /// Ошибка удаления колоды
  ///
  /// In ru, this message translates to:
  /// **'Не удалось удалить колоду. Попробуйте ещё раз.'**
  String get deckDeleteError;

  /// Экран колоды открыт для колоды, которой нет локально
  ///
  /// In ru, this message translates to:
  /// **'Этой колоды нет на устройстве'**
  String get deckNotFound;

  /// Ошибка чтения колоды
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить колоду.'**
  String get deckLoadError;

  /// Номер шага онбординга (озвучка и подпись)
  ///
  /// In ru, this message translates to:
  /// **'Шаг {current} из {total}'**
  String onboardingStep(int current, int total);

  /// Заголовок первого экрана онбординга
  ///
  /// In ru, this message translates to:
  /// **'Помнить, а не зубрить'**
  String get onboardingWelcomeTitle;

  /// Первый экран онбординга: что это
  ///
  /// In ru, this message translates to:
  /// **'Приложение показывает знания тогда, когда вы вот-вот их забудете (алгоритм FSRS). Поэтому хватает нескольких минут в день.'**
  String get onboardingWelcomeBody;

  /// Заголовок второго экрана онбординга
  ///
  /// In ru, this message translates to:
  /// **'Сессия на 5 минут'**
  String get onboardingSessionTitle;

  /// Второй экран онбординга: как устроены сессии
  ///
  /// In ru, this message translates to:
  /// **'Нажмите «Начать сессию»: сначала то, что пора повторить, потом новые знания. После каждого ответа оцените, как хорошо вы помнили, от «Снова» до «Легко». Закрыть приложение можно в любой момент: данные сохраняются.'**
  String get onboardingSessionBody;

  /// Заголовок третьего экрана онбординга
  ///
  /// In ru, this message translates to:
  /// **'Выберите колоду'**
  String get onboardingDeckTitle;

  /// Третий экран онбординга: выбор колоды
  ///
  /// In ru, this message translates to:
  /// **'Скачайте первую колоду. Остальные можно добавить позже в разделе «Колоды».'**
  String get onboardingDeckBody;

  /// Следующий шаг онбординга
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get onboardingNext;

  /// Предыдущий шаг онбординга
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get onboardingBack;

  /// Пропуск онбординга
  ///
  /// In ru, this message translates to:
  /// **'Пропустить'**
  String get onboardingSkip;

  /// Завершить онбординг и начать сессию
  ///
  /// In ru, this message translates to:
  /// **'Начать первую сессию'**
  String get onboardingStartSession;

  /// Завершить онбординг без колоды
  ///
  /// In ru, this message translates to:
  /// **'Выбрать колоду позже'**
  String get onboardingLater;

  /// Заголовок раздела настроек сессии
  ///
  /// In ru, this message translates to:
  /// **'Сессия'**
  String get settingsSessionSection;

  /// Настройка дневного лимита новых
  ///
  /// In ru, this message translates to:
  /// **'Новых знаний в день'**
  String get settingsNewPerDay;

  /// Настройка максимальной длины очереди
  ///
  /// In ru, this message translates to:
  /// **'Размер сессии (знаний)'**
  String get settingsSessionSize;

  /// Пояснение к размеру сессии
  ///
  /// In ru, this message translates to:
  /// **'Сессию заканчивает таймер на 5 минут; размер задаёт потолок очереди.'**
  String get settingsSessionSizeHint;

  /// Подсказка кнопки «−» у настройки
  ///
  /// In ru, this message translates to:
  /// **'Меньше'**
  String get settingsDecrease;

  /// Подсказка кнопки «+» у настройки
  ///
  /// In ru, this message translates to:
  /// **'Больше'**
  String get settingsIncrease;

  /// Ошибка записи настройки
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить настройку.'**
  String get settingsSaveError;

  /// Кнопка запуска сессии повторения на главном экране
  ///
  /// In ru, this message translates to:
  /// **'Начать сессию'**
  String get sessionStart;

  /// Заголовок экрана сессии
  ///
  /// In ru, this message translates to:
  /// **'Сессия'**
  String get sessionTitle;

  /// Подсказка кнопки-крестика на экране сессии
  ///
  /// In ru, this message translates to:
  /// **'Выйти из сессии'**
  String get sessionExit;

  /// Заголовок диалога подтверждения выхода
  ///
  /// In ru, this message translates to:
  /// **'Выйти из сессии?'**
  String get sessionExitConfirmTitle;

  /// Текст диалога выхода: прогресс не теряется (AC3.2)
  ///
  /// In ru, this message translates to:
  /// **'Уже данные ответы сохранены.'**
  String get sessionExitConfirmBody;

  /// Кнопка диалога выхода: продолжить сессию
  ///
  /// In ru, this message translates to:
  /// **'Остаться'**
  String get sessionExitStay;

  /// Кнопка диалога выхода: покинуть сессию
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get sessionExitLeave;

  /// Прогресс сессии
  ///
  /// In ru, this message translates to:
  /// **'Вопрос {current} из {total}'**
  String sessionProgress(int current, int total);

  /// Подпись таймера сессии (время в формате м:сс)
  ///
  /// In ru, this message translates to:
  /// **'Осталось {time}'**
  String sessionTimeLeft(String time);

  /// Таймер дошёл до нуля, начатый вопрос можно дописать (ТЗ M3)
  ///
  /// In ru, this message translates to:
  /// **'Время вышло: дайте ответ на этот вопрос'**
  String get sessionTimeUp;

  /// Подпись под индикатором, пока строится очередь
  ///
  /// In ru, this message translates to:
  /// **'Готовим вопросы…'**
  String get sessionLoading;

  /// Очередь не построилась (ошибка локальной БД)
  ///
  /// In ru, this message translates to:
  /// **'Не удалось подготовить сессию. Попробуйте ещё раз.'**
  String get sessionStartError;

  /// Кнопка повтора запуска сессии
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get sessionRetry;

  /// Запись ответа в локальную БД не удалась; вопрос остался текущим
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить ответ. Нажмите оценку ещё раз.'**
  String get sessionSaveError;

  /// Модуля формата нет в реестре (защитный запасной экран)
  ///
  /// In ru, this message translates to:
  /// **'Этот формат вопроса пока не поддерживается.'**
  String get sessionUnsupported;

  /// Кнопка на запасном экране неподдерживаемого формата
  ///
  /// In ru, this message translates to:
  /// **'Закончить сессию'**
  String get sessionFinishNow;

  /// Кнопка возврата на главный экран с итогов и пустых состояний
  ///
  /// In ru, this message translates to:
  /// **'На главную'**
  String get sessionHome;

  /// Заголовок итогов сессии
  ///
  /// In ru, this message translates to:
  /// **'Сессия завершена'**
  String get sessionSummaryTitle;

  /// Сколько вопросов отвечено за сессию
  ///
  /// In ru, this message translates to:
  /// **'Повторено: {count}'**
  String sessionSummaryReviewed(int count);

  /// Итоги: ответов с оценкой выше «Снова» при автопроверке или оценке модели
  ///
  /// In ru, this message translates to:
  /// **'Верно: {count}'**
  String sessionSummaryCorrect(int count);

  /// Итоги: ответов с оценкой «Снова» при автопроверке или оценке модели
  ///
  /// In ru, this message translates to:
  /// **'Неверно: {count}'**
  String sessionSummaryIncorrect(int count);

  /// Итоги: ответов, которые пользователь оценил сам (без вердикта)
  ///
  /// In ru, this message translates to:
  /// **'По самооценке: {count}'**
  String sessionSummarySelf(int count);

  /// Итоги: сколько длилась сессия
  ///
  /// In ru, this message translates to:
  /// **'Время: {time}'**
  String sessionSummaryTime(String time);

  /// Итоги: заголовок списка ближайших повторений
  ///
  /// In ru, this message translates to:
  /// **'Скоро повторить'**
  String get sessionSummaryUpcomingTitle;

  /// Итоги: знание уже пора повторять
  ///
  /// In ru, this message translates to:
  /// **'пора сейчас'**
  String get sessionSummaryUpcomingNow;

  /// Итоги: строка списка ближайших повторений («Название: через 3 ч»)
  ///
  /// In ru, this message translates to:
  /// **'{title}: {when}'**
  String sessionSummaryUpcomingItem(String title, String when);

  /// Итоги: сколько ближайших повторений не поместилось в список
  ///
  /// In ru, this message translates to:
  /// **'и ещё {count}'**
  String sessionSummaryUpcomingMore(int count);

  /// Итоги: кнопка новой сессии (длительность сессии — kSessionDuration, 5 минут)
  ///
  /// In ru, this message translates to:
  /// **'Ещё 5 минут'**
  String get sessionMore;

  /// Длительность: секунды
  ///
  /// In ru, this message translates to:
  /// **'{n} с'**
  String durationSeconds(int n);

  /// Длительность: целые минуты
  ///
  /// In ru, this message translates to:
  /// **'{m} мин'**
  String durationMinutesOnly(int m);

  /// Длительность: минуты и секунды
  ///
  /// In ru, this message translates to:
  /// **'{m} мин {s} с'**
  String durationMinutesSeconds(int m, int s);

  /// Кнопка разбора: короткий разбор (explanation_short)
  ///
  /// In ru, this message translates to:
  /// **'Коротко'**
  String get explanationShortToggle;

  /// Кнопка разбора: развёрнутый разбор и источники (explanation_long)
  ///
  /// In ru, this message translates to:
  /// **'Подробнее'**
  String get explanationLongToggle;

  /// Пустое состояние: у знания нет заранее написанного разбора
  ///
  /// In ru, this message translates to:
  /// **'К этому знанию разбора нет.'**
  String get explanationEmpty;

  /// Заголовок списка источников под развёрнутым разбором
  ///
  /// In ru, this message translates to:
  /// **'Источники'**
  String get explanationSourcesTitle;

  /// Лицензия источника
  ///
  /// In ru, this message translates to:
  /// **'Лицензия: {license}'**
  String explanationLicense(String license);

  /// Цитата из источника, подтверждающая факт
  ///
  /// In ru, this message translates to:
  /// **'«{quote}»'**
  String explanationQuote(String quote);

  /// Кнопка открытия ссылки на источник во внешнем браузере
  ///
  /// In ru, this message translates to:
  /// **'Открыть источник'**
  String get explanationOpenSource;

  /// Подпись кнопки открытия источника для скринридера
  ///
  /// In ru, this message translates to:
  /// **'Открыть источник «{title}» в браузере'**
  String explanationOpenSourceLabel(String title);

  /// Ссылка источника не https: показывается текстом
  ///
  /// In ru, this message translates to:
  /// **'Ссылка не открывается из приложения: разрешены только адреса https.'**
  String get explanationLinkNotHttps;

  /// Внешнее приложение или браузер не открылись
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть ссылку.'**
  String get explanationLinkFailed;

  /// Ссылка внутри текста разбора, которой нет среди источников колоды
  ///
  /// In ru, this message translates to:
  /// **'Эта ссылка не входит в источники колоды, поэтому не открыта.'**
  String get explanationLinkBlocked;

  /// Нечего повторять (ТЗ §8.5)
  ///
  /// In ru, this message translates to:
  /// **'Всё повторено 🎉'**
  String get sessionEmptyTitle;

  /// Когда следующее повторение
  ///
  /// In ru, this message translates to:
  /// **'Следующее повторение — {when}'**
  String sessionEmptyNext(String when);

  /// Новые есть, но дневной лимит выбран (AC3.3)
  ///
  /// In ru, this message translates to:
  /// **'На сегодня лимит новых знаний исчерпан.'**
  String get sessionEmptyNewLimit;

  /// Кнопка «Взять новые» на пустом состоянии (AC3.3)
  ///
  /// In ru, this message translates to:
  /// **'Взять {count} новых'**
  String sessionTakeNew(int count);

  /// Нет скачанных знаний
  ///
  /// In ru, this message translates to:
  /// **'Пока нечего повторять'**
  String get sessionNoContentTitle;

  /// Подсказка при отсутствии скачанных колод (ТЗ §8.5)
  ///
  /// In ru, this message translates to:
  /// **'Скачайте колоду, чтобы начать.'**
  String get sessionNoContentBody;

  /// Кнопка перехода к каталогу колод с пустого состояния сессии
  ///
  /// In ru, this message translates to:
  /// **'К колодам'**
  String get sessionToDecks;

  /// Следующее повторение совсем скоро
  ///
  /// In ru, this message translates to:
  /// **'меньше чем через минуту'**
  String get durationLessThanMinute;

  /// Следующее повторение через n минут
  ///
  /// In ru, this message translates to:
  /// **'через {n} мин'**
  String durationMinutes(int n);

  /// Следующее повторение через n часов
  ///
  /// In ru, this message translates to:
  /// **'через {n} ч'**
  String durationHours(int n);

  /// Следующее повторение через n дней
  ///
  /// In ru, this message translates to:
  /// **'через {n} дн.'**
  String durationDays(int n);

  /// Вердикт автопроверки: ответ верный
  ///
  /// In ru, this message translates to:
  /// **'Верно'**
  String get verdictCorrect;

  /// Вердикт: частично верно (опечатка, перестановка соседних шагов)
  ///
  /// In ru, this message translates to:
  /// **'Почти верно'**
  String get verdictPartial;

  /// Вердикт автопроверки: ответ неверный
  ///
  /// In ru, this message translates to:
  /// **'Неверно'**
  String get verdictIncorrect;

  /// Заголовок панели оценки
  ///
  /// In ru, this message translates to:
  /// **'Как хорошо вы это помнили?'**
  String get ratingPrompt;

  /// Оценка Again (1)
  ///
  /// In ru, this message translates to:
  /// **'Снова'**
  String get ratingAgain;

  /// Оценка Hard (2)
  ///
  /// In ru, this message translates to:
  /// **'Трудно'**
  String get ratingHard;

  /// Оценка Good (3)
  ///
  /// In ru, this message translates to:
  /// **'Хорошо'**
  String get ratingGood;

  /// Оценка Easy (4)
  ///
  /// In ru, this message translates to:
  /// **'Легко'**
  String get ratingEasy;

  /// Пометка предложенной оценки (текст и семантика, не только цвет)
  ///
  /// In ru, this message translates to:
  /// **'предложено'**
  String get ratingSuggested;

  /// Подсказка над кнопкой «Дальше»
  ///
  /// In ru, this message translates to:
  /// **'Предложенная оценка: {rating}'**
  String ratingSuggestedHint(String rating);

  /// Подсказка, когда оценку не предлагаем (flip, самооценка)
  ///
  /// In ru, this message translates to:
  /// **'Выберите оценку сами'**
  String get ratingChooseHint;

  /// Кнопка «Дальше» принимает предложенную оценку
  ///
  /// In ru, this message translates to:
  /// **'Дальше'**
  String get ratingNext;

  /// Подсказка над вариантами, когда верных ответов несколько
  ///
  /// In ru, this message translates to:
  /// **'Выберите все верные варианты'**
  String get mcqHintMultiple;

  /// Кнопка подтверждения выбора в mcq с несколькими ответами
  ///
  /// In ru, this message translates to:
  /// **'Ответить'**
  String get mcqAnswer;

  /// Подпись выбранного верного варианта
  ///
  /// In ru, this message translates to:
  /// **'Верно'**
  String get mcqOptionCorrect;

  /// Подпись выбранного неверного варианта
  ///
  /// In ru, this message translates to:
  /// **'Неверно'**
  String get mcqOptionWrong;

  /// Подпись верного варианта, который не выбрали
  ///
  /// In ru, this message translates to:
  /// **'Верный ответ'**
  String get mcqOptionMissed;

  /// Кнопка отправки ответа в cloze
  ///
  /// In ru, this message translates to:
  /// **'Проверить'**
  String get clozeAnswer;

  /// Подпись поля ввода пропуска cloze для скринридера
  ///
  /// In ru, this message translates to:
  /// **'Пропуск {number}'**
  String clozeBlankLabel(int number);

  /// Подпись верно заполненного пропуска cloze
  ///
  /// In ru, this message translates to:
  /// **'Верно'**
  String get clozeBlankCorrect;

  /// Подпись пропуска cloze, принятого с опечаткой
  ///
  /// In ru, this message translates to:
  /// **'Принято с опечаткой. Верно: {expected}'**
  String clozeBlankTypo(String expected);

  /// Подпись неверно заполненного пропуска cloze
  ///
  /// In ru, this message translates to:
  /// **'Неверно. Верно: {expected}'**
  String clozeBlankWrong(String expected);

  /// Подсказка над шагами формата order
  ///
  /// In ru, this message translates to:
  /// **'Расставьте шаги по порядку: перетащите или нажимайте стрелки'**
  String get orderHint;

  /// Кнопка проверки порядка в order
  ///
  /// In ru, this message translates to:
  /// **'Проверить'**
  String get orderCheck;

  /// Подсказка кнопки перемещения шага вверх
  ///
  /// In ru, this message translates to:
  /// **'Выше: {step}'**
  String orderMoveUp(String step);

  /// Подсказка кнопки перемещения шага вниз
  ///
  /// In ru, this message translates to:
  /// **'Ниже: {step}'**
  String orderMoveDown(String step);

  /// Семантика шага order: место и текст
  ///
  /// In ru, this message translates to:
  /// **'Шаг {position} из {total}: {step}'**
  String orderStepPosition(int position, int total, String step);

  /// Подпись шага order на верном месте
  ///
  /// In ru, this message translates to:
  /// **'Верно'**
  String get orderStepCorrect;

  /// Подпись шага order не на своём месте
  ///
  /// In ru, this message translates to:
  /// **'Неверно, верное место: {position}'**
  String orderStepWrong(int position);

  /// Подсказка над кодом в find_error
  ///
  /// In ru, this message translates to:
  /// **'Нажмите на строку с ошибкой (не больше двух)'**
  String get findErrorHintCode;

  /// Подсказка над утверждениями в find_error
  ///
  /// In ru, this message translates to:
  /// **'Нажмите на утверждение с ошибкой (не больше двух)'**
  String get findErrorHintText;

  /// Кнопка проверки выбора в find_error
  ///
  /// In ru, this message translates to:
  /// **'Проверить'**
  String get findErrorCheck;

  /// Семантика строки find_error
  ///
  /// In ru, this message translates to:
  /// **'Строка {number}: {text}'**
  String findErrorLine(int number, String text);

  /// Семантика выбранной строки find_error
  ///
  /// In ru, this message translates to:
  /// **'Строка {number}: {text}, выбрана'**
  String findErrorLineSelected(int number, String text);

  /// Подпись выбранной ошибочной строки
  ///
  /// In ru, this message translates to:
  /// **'Ошибка найдена'**
  String get findErrorFound;

  /// Подпись выбранной строки без ошибки
  ///
  /// In ru, this message translates to:
  /// **'Здесь ошибки нет'**
  String get findErrorWrong;

  /// Подпись ошибочной строки, которую не выбрали
  ///
  /// In ru, this message translates to:
  /// **'Пропущенная ошибка'**
  String get findErrorMissed;

  /// Пояснение к ошибочной строке после ответа
  ///
  /// In ru, this message translates to:
  /// **'Строка {number}: {text}'**
  String findErrorExplanation(int number, String text);

  /// Кнопка формата flip
  ///
  /// In ru, this message translates to:
  /// **'Показать ответ'**
  String get flipShowAnswer;

  /// Заголовок обратной стороны карточки
  ///
  /// In ru, this message translates to:
  /// **'Ответ'**
  String get flipAnswerLabel;

  /// Заголовок раздела настроек с напоминанием
  ///
  /// In ru, this message translates to:
  /// **'Напоминание'**
  String get settingsReminderSection;

  /// Тумблер напоминания
  ///
  /// In ru, this message translates to:
  /// **'Ежедневное напоминание'**
  String get reminderSwitchTitle;

  /// Пояснение к тумблеру напоминания: когда приходит и зачем разрешение
  ///
  /// In ru, this message translates to:
  /// **'В выбранное время придёт уведомление, но только если есть что повторять. При включении Android может спросить разрешение на уведомления.'**
  String get reminderSwitchSubtitle;

  /// Строка выбора времени напоминания
  ///
  /// In ru, this message translates to:
  /// **'Время напоминания'**
  String get reminderTimeTitle;

  /// Заголовок диалога выбора времени
  ///
  /// In ru, this message translates to:
  /// **'Время напоминания'**
  String get reminderTimePickerHelp;

  /// Почему тумблер напоминания недоступен (web)
  ///
  /// In ru, this message translates to:
  /// **'Напоминания работают только в приложении для Android. В браузере их нет.'**
  String get reminderUnsupported;

  /// Напоминание включено, но системное разрешение не дано
  ///
  /// In ru, this message translates to:
  /// **'Уведомления для приложения выключены в настройках Android, поэтому напоминания не приходят. Включите их там, и напоминание заработает само.'**
  String get reminderPermissionDenied;

  /// Кнопка перехода в системные настройки уведомлений
  ///
  /// In ru, this message translates to:
  /// **'Открыть настройки уведомлений'**
  String get reminderOpenSettings;

  /// Заголовок уведомления-напоминания
  ///
  /// In ru, this message translates to:
  /// **'Пора повторить'**
  String get reminderNotificationTitle;

  /// Текст уведомления-напоминания
  ///
  /// In ru, this message translates to:
  /// **'Пять минут сейчас, и знания останутся надолго.'**
  String get reminderNotificationBody;

  /// Название канала уведомлений Android
  ///
  /// In ru, this message translates to:
  /// **'Напоминания о повторении'**
  String get reminderChannelName;

  /// Описание канала уведомлений Android
  ///
  /// In ru, this message translates to:
  /// **'Ежедневное напоминание повторить знания'**
  String get reminderChannelDescription;

  /// Заголовок шага онбординга с напоминанием
  ///
  /// In ru, this message translates to:
  /// **'Напоминание'**
  String get onboardingReminderTitle;

  /// Шаг онбординга: напоминание
  ///
  /// In ru, this message translates to:
  /// **'Хотите, чтобы приложение напоминало о повторении? Оно напишет в выбранное время и только если есть что повторять. Это можно изменить в настройках.'**
  String get onboardingReminderBody;

  /// Подпись поля ввода открытого ответа
  ///
  /// In ru, this message translates to:
  /// **'Ваш ответ'**
  String get openAnswerLabel;

  /// Подсказка в пустом поле открытого ответа
  ///
  /// In ru, this message translates to:
  /// **'Своими словами, в одном-трёх предложениях'**
  String get openAnswerHint;

  /// Счётчик символов открытого ответа
  ///
  /// In ru, this message translates to:
  /// **'{count} из {max}'**
  String openCounter(int count, int max);

  /// Кнопка проверки открытого ответа
  ///
  /// In ru, this message translates to:
  /// **'Проверить'**
  String get openCheck;

  /// Индикатор проверки ответа моделью
  ///
  /// In ru, this message translates to:
  /// **'Проверяю…'**
  String get openChecking;

  /// Кнопка: не помню ответ, сразу к эталону и самооценке
  ///
  /// In ru, this message translates to:
  /// **'Не помню'**
  String get openDontRemember;

  /// Повтор проверки после сбоя сети или сервера
  ///
  /// In ru, this message translates to:
  /// **'Проверить ещё раз'**
  String get openCheckAgain;

  /// Кнопка: отказаться от повтора и оценить себя по эталону
  ///
  /// In ru, this message translates to:
  /// **'Оценить самому'**
  String get openSelfAssess;

  /// Заголовок блока с эталонным ответом
  ///
  /// In ru, this message translates to:
  /// **'Эталонный ответ'**
  String get openReferenceTitle;

  /// Заголовок списка пунктов рубрики с отметками
  ///
  /// In ru, this message translates to:
  /// **'Разбор по пунктам'**
  String get openRubricTitle;

  /// Статус пункта рубрики: раскрыт (для озвучки)
  ///
  /// In ru, this message translates to:
  /// **'раскрыт'**
  String get openPointHit;

  /// Статус пункта рубрики: частично (для озвучки)
  ///
  /// In ru, this message translates to:
  /// **'раскрыт частично'**
  String get openPointPartial;

  /// Статус пункта рубрики: не раскрыт (для озвучки)
  ///
  /// In ru, this message translates to:
  /// **'не раскрыт'**
  String get openPointMiss;

  /// Пометка обязательного пункта рубрики
  ///
  /// In ru, this message translates to:
  /// **'обязательный пункт'**
  String get openPointRequired;

  /// Заголовок краткого комментария модели
  ///
  /// In ru, this message translates to:
  /// **'Комментарий проверки'**
  String get openFeedbackTitle;

  /// Сколько проверок осталось на сегодня
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Осталась {count} проверка на сегодня} few{Осталось {count} проверки на сегодня} many{Осталось {count} проверок на сегодня} other{Осталось {count} проверки на сегодня}}'**
  String openQuotaRemaining(int count);

  /// Нет сети или сервер не ответил (ТЗ §8.5)
  ///
  /// In ru, this message translates to:
  /// **'Проверка недоступна. Сравните свой ответ с эталоном и оцените себя сами.'**
  String get openFallbackUnavailable;

  /// Исчерпан дневной лимит проверок
  ///
  /// In ru, this message translates to:
  /// **'На сегодня проверки закончились. Сравните свой ответ с эталоном и оцените себя сами.'**
  String get openFallbackQuota;

  /// Лимит исчерпан, известно время сброса
  ///
  /// In ru, this message translates to:
  /// **'На сегодня проверки закончились, они обновятся в {time}. Сравните свой ответ с эталоном и оцените себя сами.'**
  String openFallbackQuotaReset(String time);

  /// Нет сессии пользователя
  ///
  /// In ru, this message translates to:
  /// **'Чтобы проверять ответы, нужно войти в приложение. Сравните свой ответ с эталоном и оцените себя сами.'**
  String get openFallbackSignedOut;

  /// Модель не уверена (unsure)
  ///
  /// In ru, this message translates to:
  /// **'Не удалось уверенно оценить ответ. Сравните его с эталоном и оцените себя сами.'**
  String get openFallbackUnsure;

  /// Пользователь отказался от проверки внешней моделью
  ///
  /// In ru, this message translates to:
  /// **'Проверка моделью выключена. Сравните свой ответ с эталоном и оцените себя сами.'**
  String get openFallbackDisabled;

  /// Пользователь нажал «Не помню»
  ///
  /// In ru, this message translates to:
  /// **'Сравните ответ с эталоном и оцените себя сами.'**
  String get openFallbackSkipped;

  /// Кнопка микрофона (подсказка и семантика)
  ///
  /// In ru, this message translates to:
  /// **'Диктовать ответ'**
  String get openMicStart;

  /// Кнопка микрофона во время диктовки
  ///
  /// In ru, this message translates to:
  /// **'Закончить диктовку'**
  String get openMicStop;

  /// Отмена диктовки: возвращает текст, который был до неё
  ///
  /// In ru, this message translates to:
  /// **'Отменить диктовку'**
  String get openMicCancel;

  /// Состояние диктовки: идёт запись речи
  ///
  /// In ru, this message translates to:
  /// **'Слушаю… говорите'**
  String get openMicListening;

  /// Подсказка после диктовки
  ///
  /// In ru, this message translates to:
  /// **'Распознанный текст можно поправить перед проверкой.'**
  String get openMicEditHint;

  /// Нет распознавания речи
  ///
  /// In ru, this message translates to:
  /// **'Диктовка в этом браузере или на этом устройстве недоступна. Введите ответ текстом.'**
  String get openMicUnsupported;

  /// Отказ в разрешении на микрофон (Android)
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к микрофону. Разрешите его в настройках приложения или введите ответ текстом.'**
  String get openMicPermissionDenied;

  /// Отказ в разрешении на микрофон (web)
  ///
  /// In ru, this message translates to:
  /// **'Браузер не дал доступ к микрофону. Разрешите его для этого сайта или введите ответ текстом.'**
  String get openMicPermissionDeniedWeb;

  /// Кнопка перехода в системные настройки приложения
  ///
  /// In ru, this message translates to:
  /// **'Открыть настройки приложения'**
  String get openMicOpenSettings;

  /// Таймаут тишины или нет совпадения
  ///
  /// In ru, this message translates to:
  /// **'Речь не расслышали. Нажмите на микрофон и повторите или введите ответ текстом.'**
  String get openMicNoSpeech;

  /// Сервису распознавания нужна сеть
  ///
  /// In ru, this message translates to:
  /// **'Для распознавания речи нужна сеть. Введите ответ текстом.'**
  String get openMicNetwork;

  /// Язык колоды не поддерживается распознаванием
  ///
  /// In ru, this message translates to:
  /// **'Для языка колоды на устройстве нет распознавания речи. Введите ответ текстом.'**
  String get openMicLanguage;

  /// Прочий сбой диктовки
  ///
  /// In ru, this message translates to:
  /// **'Диктовка не сработала. Попробуйте ещё раз или введите ответ текстом.'**
  String get openMicError;

  /// Заголовок диалога согласия перед первым open
  ///
  /// In ru, this message translates to:
  /// **'Проверка ответов моделью'**
  String get openConsentTitle;

  /// Текст диалога согласия
  ///
  /// In ru, this message translates to:
  /// **'Открытые ответы отправляются на проверку внешней языковой модели через наш сервер. Уходит только текст ответа, без имени и контактов. Если отказаться, вы будете оценивать себя сами по эталонному ответу; передумать можно в настройках.'**
  String get openConsentBody;

  /// Согласие на проверку моделью
  ///
  /// In ru, this message translates to:
  /// **'Разрешить'**
  String get openConsentAllow;

  /// Отказ от проверки моделью
  ///
  /// In ru, this message translates to:
  /// **'Без ИИ'**
  String get openConsentDecline;

  /// Заголовок раздела настроек про проверку открытых ответов
  ///
  /// In ru, this message translates to:
  /// **'Проверка ответов'**
  String get settingsGradingSection;

  /// Переключатель согласия на проверку внешней моделью
  ///
  /// In ru, this message translates to:
  /// **'Проверять открытые ответы моделью'**
  String get settingsLlmConsentTitle;

  /// Пояснение переключателя
  ///
  /// In ru, this message translates to:
  /// **'Текст ответа отправляется внешней модели. Если выключить, вы оцениваете себя сами по эталону.'**
  String get settingsLlmConsentSubtitle;

  /// Кнопка под разбором: пожаловаться на вопрос (⚑, ТЗ M11)
  ///
  /// In ru, this message translates to:
  /// **'Пожаловаться'**
  String get reportButton;

  /// Кнопка после жалобы на этот вопрос: недоступна
  ///
  /// In ru, this message translates to:
  /// **'Жалоба отправлена'**
  String get reportButtonSent;

  /// Заголовок шторки жалобы
  ///
  /// In ru, this message translates to:
  /// **'На что пожаловаться?'**
  String get reportSheetTitle;

  /// Пояснение в шторке жалобы: вопрос скрывается у автора жалобы
  ///
  /// In ru, this message translates to:
  /// **'Вопрос перестанет показываться вам сразу. Куратор проверит его.'**
  String get reportSheetHint;

  /// Причина жалобы: в вопросе или ответе фактическая ошибка
  ///
  /// In ru, this message translates to:
  /// **'Неверный ответ'**
  String get reportReasonWrongAnswer;

  /// Причина жалобы: вопрос или разбор непонятны
  ///
  /// In ru, this message translates to:
  /// **'Непонятно'**
  String get reportReasonUnclear;

  /// Причина жалобы: опечатка в тексте
  ///
  /// In ru, this message translates to:
  /// **'Опечатка'**
  String get reportReasonTypo;

  /// Причина жалобы: ссылка не подтверждает ответ или не открывается
  ///
  /// In ru, this message translates to:
  /// **'Плохой источник'**
  String get reportReasonBadSource;

  /// Причина жалобы: другое
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get reportReasonOther;

  /// Подпись поля комментария к жалобе или к «не согласен»
  ///
  /// In ru, this message translates to:
  /// **'Комментарий (необязательно)'**
  String get reportCommentLabel;

  /// Кнопка отправки жалобы
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get reportSend;

  /// Закрыть шторку жалобы без отправки
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get reportCancel;

  /// Подтверждение после жалобы на вопрос
  ///
  /// In ru, this message translates to:
  /// **'Спасибо! Вопрос скрыт у вас, куратор его проверит.'**
  String get reportThanks;

  /// Запись жалобы в локальную БД не удалась
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить жалобу. Попробуйте ещё раз.'**
  String get reportError;

  /// Кнопка после вердикта ИИ: оспорить оценку (ТЗ M11)
  ///
  /// In ru, this message translates to:
  /// **'Не согласен с оценкой'**
  String get disagreeButton;

  /// Заголовок шторки «не согласен»
  ///
  /// In ru, this message translates to:
  /// **'Не согласен с оценкой ИИ'**
  String get disagreeSheetTitle;

  /// Что произойдёт в «не согласен»; куратор получает ответ пользователя
  ///
  /// In ru, this message translates to:
  /// **'ИИ оценил ответ: «{verdict}». Выберите оценку, которую считаете верной. Куратор увидит ваш ответ, вердикт ИИ и вашу оценку.'**
  String disagreeSheetBody(String verdict);

  /// Заголовок выбора своей оценки в «не согласен»
  ///
  /// In ru, this message translates to:
  /// **'Моя оценка'**
  String get disagreeRatingLabel;

  /// Кнопка «не согласен»: записать свою оценку и отправить report
  ///
  /// In ru, this message translates to:
  /// **'Отправить и продолжить'**
  String get disagreeSend;

  /// Подсказка после «не согласен»
  ///
  /// In ru, this message translates to:
  /// **'Спасибо! Куратор посмотрит оценку.'**
  String get disagreeThanks;

  /// Заголовок раздела настроек про аккаунт и привязку Google (T21)
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт'**
  String get settingsAccountSection;

  /// Статус аккаунта, пока анонимный вход ещё не завершён
  ///
  /// In ru, this message translates to:
  /// **'Выполняется вход…'**
  String get accountSigningIn;

  /// Статус аккаунта без привязки
  ///
  /// In ru, this message translates to:
  /// **'Анонимный аккаунт'**
  String get accountAnonymousTitle;

  /// Пояснение к анонимному аккаунту
  ///
  /// In ru, this message translates to:
  /// **'Прогресс хранится на этом устройстве и в облаке без входа. Привяжите Google, чтобы не потерять его и открыть на другом устройстве.'**
  String get accountAnonymousSubtitle;

  /// Статус привязанного аккаунта с почтой
  ///
  /// In ru, this message translates to:
  /// **'Google: {email}'**
  String accountLinkedTitle(String email);

  /// Статус привязанного аккаунта, если почта неизвестна
  ///
  /// In ru, this message translates to:
  /// **'Google привязан'**
  String get accountLinkedNoEmailTitle;

  /// Пояснение к привязанному аккаунту
  ///
  /// In ru, this message translates to:
  /// **'Прогресс сохраняется в облаке. Войдите в этот аккаунт Google на другом устройстве, и прогресс будет там же.'**
  String get accountLinkedSubtitle;

  /// Кнопка привязки Google к анонимному аккаунту
  ///
  /// In ru, this message translates to:
  /// **'Привязать Google'**
  String get accountLinkButton;

  /// Кнопка привязки, пока открывается браузер
  ///
  /// In ru, this message translates to:
  /// **'Открываем браузер…'**
  String get accountLinkOpening;

  /// Блок аккаунта в сборке без Supabase
  ///
  /// In ru, this message translates to:
  /// **'Вход недоступен: приложение собрано без подключения к серверу.'**
  String get accountNoBackend;

  /// Сообщение после успешной привязки
  ///
  /// In ru, this message translates to:
  /// **'Google привязан. Прогресс сохранён.'**
  String get accountNoticeLinked;

  /// Сообщение после входа в существующий аккаунт с объединением
  ///
  /// In ru, this message translates to:
  /// **'Вы вошли в существующий аккаунт Google. Прогресс этого устройства объединён с ним и уйдёт на сервер при синхронизации.'**
  String get accountNoticeSignedInExisting;

  /// Сообщение, если пользователь отказался на стороне Google
  ///
  /// In ru, this message translates to:
  /// **'Вход отменён. Ничего не изменилось.'**
  String get accountNoticeCancelled;

  /// Сообщение, если провайдер Google не включён на сервере
  ///
  /// In ru, this message translates to:
  /// **'Привязка Google не настроена в этой сборке.'**
  String get accountNoticeUnavailable;

  /// Сообщение о недоступном сервере при привязке
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с сервером. Проверьте сеть и попробуйте ещё раз.'**
  String get accountNoticeNetwork;

  /// Общее сообщение об ошибке привязки
  ///
  /// In ru, this message translates to:
  /// **'Не удалось привязать Google. Ничего не изменилось, можно попробовать ещё раз.'**
  String get accountNoticeFailed;

  /// Заголовок диалога: Google-аккаунт уже привязан к другому профилю
  ///
  /// In ru, this message translates to:
  /// **'Этот Google уже используется'**
  String get accountConflictTitle;

  /// Текст диалога конфликта: предупреждение об объединении через синхронизацию (LWW)
  ///
  /// In ru, this message translates to:
  /// **'Этот аккаунт Google уже привязан к другому профилю приложения. Можно войти в него: тогда прогресс на этом устройстве объединится с прогрессом того аккаунта. По каждому знанию останется более поздний результат повторения, остальное сохранится. Если не хотите, откажитесь: всё останется как сейчас.'**
  String get accountConflictBody;

  /// Кнопка диалога конфликта: войти в существующий аккаунт и объединить прогресс
  ///
  /// In ru, this message translates to:
  /// **'Войти и объединить'**
  String get accountConflictConfirm;

  /// Кнопка диалога конфликта: ничего не менять
  ///
  /// In ru, this message translates to:
  /// **'Отказаться'**
  String get accountConflictDecline;

  /// Сообщение после входа в существующий аккаунт, если подтверждение объединения устарело или его не было
  ///
  /// In ru, this message translates to:
  /// **'Подтверждение устарело, поэтому прогресс этого устройства не перенесён. Он сохранён на устройстве: нажмите «Перенести прогресс», чтобы объединить его с этим аккаунтом.'**
  String get accountNoticeMergeNotConfirmed;

  /// Сообщение, если перенос прогресса не удался
  ///
  /// In ru, this message translates to:
  /// **'Не удалось перенести прогресс. Ничего не потеряно, он сохранён на устройстве. Попробуйте ещё раз.'**
  String get accountNoticeMergeFailed;

  /// Кнопка повтора переноса прогресса анонимного аккаунта в Google-аккаунт
  ///
  /// In ru, this message translates to:
  /// **'Перенести прогресс'**
  String get accountRetryMerge;

  /// Кнопка на главном экране: переход к дуэлям
  ///
  /// In ru, this message translates to:
  /// **'Дуэли'**
  String get homeDuelsButton;

  /// Заголовок экрана дуэлей (ТЗ M10)
  ///
  /// In ru, this message translates to:
  /// **'Дуэли'**
  String get duelsTitle;

  /// Кнопка: создать дуэль
  ///
  /// In ru, this message translates to:
  /// **'Создать дуэль'**
  String get duelsCreate;

  /// Кнопка: войти в дуэль друга по коду
  ///
  /// In ru, this message translates to:
  /// **'Войти по коду'**
  String get duelsJoin;

  /// Заголовок списка дуэлей пользователя
  ///
  /// In ru, this message translates to:
  /// **'Твои дуэли'**
  String get duelsListTitle;

  /// Пустой список дуэлей
  ///
  /// In ru, this message translates to:
  /// **'Дуэлей пока нет. Создай свою или войди по коду друга.'**
  String get duelsEmpty;

  /// Список дуэлей не загрузился
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить дуэли.'**
  String get duelsLoadError;

  /// Кнопка повтора загрузки дуэлей
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get duelsRetry;

  /// Поле имени: его увидит соперник по дуэли
  ///
  /// In ru, this message translates to:
  /// **'Твоё имя для соперника'**
  String get duelNameLabel;

  /// Подсказка в поле имени
  ///
  /// In ru, this message translates to:
  /// **'Можно оставить пустым'**
  String get duelNameHint;

  /// Кнопка сохранения имени
  ///
  /// In ru, this message translates to:
  /// **'Сохранить имя'**
  String get duelNameSave;

  /// Сообщение после сохранения имени
  ///
  /// In ru, this message translates to:
  /// **'Имя сохранено'**
  String get duelNameSaved;

  /// Ошибка сохранения имени
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить имя. Проверь сеть и попробуй ещё раз.'**
  String get duelNameError;

  /// Заголовок экрана создания дуэли
  ///
  /// In ru, this message translates to:
  /// **'Новая дуэль'**
  String get duelCreateTitle;

  /// Подсказка выбора колоды для дуэли
  ///
  /// In ru, this message translates to:
  /// **'Выбери колоду: 5 случайных вопросов возьмём из неё'**
  String get duelCreateChooseDeck;

  /// Нет скачанных колод
  ///
  /// In ru, this message translates to:
  /// **'Сначала скачай колоду: вопросы для дуэли берутся из неё.'**
  String get duelCreateNoDecks;

  /// Кнопка перехода к каталогу колод
  ///
  /// In ru, this message translates to:
  /// **'К колодам'**
  String get duelCreateNoDecksAction;

  /// Кнопка создания дуэли на экране выбора колоды
  ///
  /// In ru, this message translates to:
  /// **'Создать дуэль'**
  String get duelCreateAction;

  /// Подпись кнопки во время создания
  ///
  /// In ru, this message translates to:
  /// **'Создаём…'**
  String get duelCreateCreating;

  /// В колоде меньше пяти автопроверяемых вопросов
  ///
  /// In ru, this message translates to:
  /// **'В этой колоде мало подходящих вопросов: {count}, нужно 5. Выбери другую колоду.'**
  String duelCreateNotEnough(int count);

  /// Заголовок после создания дуэли
  ///
  /// In ru, this message translates to:
  /// **'Дуэль создана'**
  String get duelCreatedTitle;

  /// Пояснение после создания дуэли
  ///
  /// In ru, this message translates to:
  /// **'Отправь код другу: он введёт его в приложении.'**
  String get duelCreatedBody;

  /// Подпись кода приглашения
  ///
  /// In ru, this message translates to:
  /// **'Код приглашения'**
  String get duelCodeLabel;

  /// Озвучка кода приглашения знаками через пробел
  ///
  /// In ru, this message translates to:
  /// **'Код: {code}'**
  String duelCodeSemantics(String code);

  /// Кнопка копирования кода
  ///
  /// In ru, this message translates to:
  /// **'Скопировать код'**
  String get duelCopyCode;

  /// Кнопка копирования текста приглашения
  ///
  /// In ru, this message translates to:
  /// **'Скопировать приглашение'**
  String get duelCopyInvite;

  /// Сообщение после копирования
  ///
  /// In ru, this message translates to:
  /// **'Скопировано'**
  String get duelCopied;

  /// Текст приглашения для друга
  ///
  /// In ru, this message translates to:
  /// **'Сыграем дуэль в Mater Studorium? Код: {code}'**
  String duelInviteText(String code);

  /// Кнопка перехода к экрану дуэли
  ///
  /// In ru, this message translates to:
  /// **'К дуэли'**
  String get duelOpenDuel;

  /// Заголовок экрана входа по коду
  ///
  /// In ru, this message translates to:
  /// **'Вход по коду'**
  String get duelJoinTitle;

  /// Подпись поля кода
  ///
  /// In ru, this message translates to:
  /// **'Код дуэли'**
  String get duelJoinCodeLabel;

  /// Подсказка в поле кода
  ///
  /// In ru, this message translates to:
  /// **'6 знаков, например K7Q 2MX'**
  String get duelJoinCodeHint;

  /// Кнопка входа по коду
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get duelJoinAction;

  /// Подпись кнопки во время входа
  ///
  /// In ru, this message translates to:
  /// **'Входим…'**
  String get duelJoinJoining;

  /// Неверный или просроченный код (ТЗ §8.5, AC10.2)
  ///
  /// In ru, this message translates to:
  /// **'Код не найден или дуэль истекла'**
  String get duelErrorNotFound;

  /// Код верный, но места нет
  ///
  /// In ru, this message translates to:
  /// **'В этой дуэли уже есть соперник'**
  String get duelErrorFull;

  /// Лимит активных дуэлей
  ///
  /// In ru, this message translates to:
  /// **'Слишком много активных дуэлей. Дождись окончания прежних.'**
  String get duelErrorLimitActive;

  /// Лимит создания дуэлей в сутки
  ///
  /// In ru, this message translates to:
  /// **'Сегодня создано слишком много дуэлей. Попробуй завтра.'**
  String get duelErrorLimitDaily;

  /// Лимит неудачных попыток входа по коду
  ///
  /// In ru, this message translates to:
  /// **'Слишком много неверных кодов. Подожди час и попробуй снова.'**
  String get duelErrorLimitJoin;

  /// Нет сети при действии с дуэлью
  ///
  /// In ru, this message translates to:
  /// **'Нужна сеть. Проверь подключение и повтори.'**
  String get duelErrorNetwork;

  /// Нет сессии при действии с дуэлью
  ///
  /// In ru, this message translates to:
  /// **'Нет входа в аккаунт. Перезапусти приложение.'**
  String get duelErrorAuth;

  /// Колоду нельзя использовать в дуэли
  ///
  /// In ru, this message translates to:
  /// **'Эта колода недоступна для дуэли.'**
  String get duelErrorDeck;

  /// Прочая ошибка дуэли
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выполнить действие. Попробуй ещё раз.'**
  String get duelErrorGeneric;

  /// Заголовок экрана дуэли
  ///
  /// In ru, this message translates to:
  /// **'Дуэль'**
  String get duelScreenTitle;

  /// Дуэли нет или пользователь не её участник
  ///
  /// In ru, this message translates to:
  /// **'Дуэль не найдена'**
  String get duelNotFound;

  /// Статус: соперник ещё не вошёл
  ///
  /// In ru, this message translates to:
  /// **'Ждём соперника'**
  String get duelStatusOpen;

  /// Пояснение к статусу «ждём соперника»
  ///
  /// In ru, this message translates to:
  /// **'Отправь ему код: он введёт его в приложении.'**
  String get duelStatusOpenBody;

  /// Статус: соперник вошёл
  ///
  /// In ru, this message translates to:
  /// **'Соперник в дуэли'**
  String get duelStatusActive;

  /// Статус: соперник с именем вошёл
  ///
  /// In ru, this message translates to:
  /// **'{name} в дуэли'**
  String duelStatusActiveNamed(String name);

  /// Статус: оба ответили
  ///
  /// In ru, this message translates to:
  /// **'Результат готов'**
  String get duelStatusFinished;

  /// Статус: срок вышел
  ///
  /// In ru, this message translates to:
  /// **'Дуэль истекла'**
  String get duelStatusExpired;

  /// Сколько осталось до конца срока дуэли
  ///
  /// In ru, this message translates to:
  /// **'осталось {left}'**
  String duelRemaining(String left);

  /// Остаток срока в днях
  ///
  /// In ru, this message translates to:
  /// **'{n} д'**
  String duelLeftDays(int n);

  /// Остаток срока в часах
  ///
  /// In ru, this message translates to:
  /// **'{n} ч'**
  String duelLeftHours(int n);

  /// Остаток срока в минутах
  ///
  /// In ru, this message translates to:
  /// **'{n} мин'**
  String duelLeftMinutes(int n);

  /// Остаток срока меньше минуты
  ///
  /// In ru, this message translates to:
  /// **'меньше минуты'**
  String get duelLeftLessThanMinute;

  /// Название дуэли в списке, когда соперник известен
  ///
  /// In ru, this message translates to:
  /// **'Дуэль с {name}'**
  String duelWithName(String name);

  /// Название дуэли в списке, пока соперника нет
  ///
  /// In ru, this message translates to:
  /// **'Дуэль, ждём соперника'**
  String get duelWaitingTitle;

  /// Колоды дуэли нет локально
  ///
  /// In ru, this message translates to:
  /// **'Колода этой дуэли не скачана на устройство. Без неё играть нельзя.'**
  String get duelDeckMissing;

  /// Кнопка скачивания колоды дуэли
  ///
  /// In ru, this message translates to:
  /// **'Скачать колоду'**
  String get duelDeckDownload;

  /// Подпись кнопки скачивания колоды
  ///
  /// In ru, this message translates to:
  /// **'Скачиваем…'**
  String get duelDeckDownloading;

  /// Ошибка скачивания колоды дуэли
  ///
  /// In ru, this message translates to:
  /// **'Не удалось скачать колоду. Нужна сеть.'**
  String get duelDeckDownloadError;

  /// Соперник не задал имя
  ///
  /// In ru, this message translates to:
  /// **'Соперник без имени'**
  String get duelOpponentUnnamed;

  /// Создатель дуэли не задал имя
  ///
  /// In ru, this message translates to:
  /// **'Создатель без имени'**
  String get duelCreatorUnnamed;

  /// Кнопка обновления состояния дуэли
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get duelRefresh;

  /// Статус дуэли: нужно ответить на вопросы
  ///
  /// In ru, this message translates to:
  /// **'Твой ход'**
  String get duelStatusYourTurn;

  /// Статус: я ответил, ждём соперника с именем
  ///
  /// In ru, this message translates to:
  /// **'Ждём {name}'**
  String duelStatusWaitingNamed(String name);

  /// Кнопка: начать или продолжить дуэль
  ///
  /// In ru, this message translates to:
  /// **'Играть'**
  String get duelPlayButton;

  /// Пояснение к статусу «твой ход»
  ///
  /// In ru, this message translates to:
  /// **'Пять вопросов, у каждого свой секундомер. Лимита по времени нет.'**
  String get duelYourTurnBody;

  /// Я закончил, соперник нет
  ///
  /// In ru, this message translates to:
  /// **'Ты ответил на все вопросы. Результат появится, когда соперник тоже закончит.'**
  String get duelWaitingBody;

  /// Я закончил, соперник с именем нет
  ///
  /// In ru, this message translates to:
  /// **'Ты ответил на все вопросы. Результат появится, когда {name} тоже закончит.'**
  String duelWaitingBodyNamed(String name);

  /// Ответы лежат в очереди отправки
  ///
  /// In ru, this message translates to:
  /// **'Ответы ещё отправляются. Для этого нужна сеть.'**
  String get duelSendingAnswers;

  /// Заголовок экрана прохождения дуэли
  ///
  /// In ru, this message translates to:
  /// **'Дуэль'**
  String get duelPlayTitle;

  /// Номер вопроса в дуэли
  ///
  /// In ru, this message translates to:
  /// **'Вопрос {n} из {total}'**
  String duelPlayProgress(int n, int total);

  /// Секундомер вопроса (для скринридера)
  ///
  /// In ru, this message translates to:
  /// **'Время на вопрос: {time}'**
  String duelPlayTimerLabel(String time);

  /// Кнопка перехода к следующему вопросу дуэли
  ///
  /// In ru, this message translates to:
  /// **'Дальше'**
  String get duelPlayNext;

  /// Кнопка после последнего вопроса дуэли
  ///
  /// In ru, this message translates to:
  /// **'Закончить'**
  String get duelPlayFinish;

  /// Ошибка локального сохранения ответа
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить ответ. Попробуй ещё раз.'**
  String get duelPlaySaveError;

  /// Кнопка повторного сохранения ответа
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get duelPlaySaveRetry;

  /// Заголовок после последнего ответа
  ///
  /// In ru, this message translates to:
  /// **'Ты ответил на все вопросы'**
  String get duelPlayDoneTitle;

  /// Пояснение после последнего ответа
  ///
  /// In ru, this message translates to:
  /// **'Ответы уходят на сервер сами, сеть нужна только для этого. Результат появится, когда соперник тоже закончит.'**
  String get duelPlayDoneBody;

  /// Кнопка возврата к экрану дуэли
  ///
  /// In ru, this message translates to:
  /// **'К дуэли'**
  String get duelPlayBackToDuel;

  /// Дуэль закрыта для ответов
  ///
  /// In ru, this message translates to:
  /// **'Эта дуэль уже закончилась или истекла.'**
  String get duelPlayClosed;

  /// Часть вопросов недоступна на устройстве
  ///
  /// In ru, this message translates to:
  /// **'Дуэль нельзя сыграть как есть'**
  String get duelPlayBlockedTitle;

  /// Часть вопросов набора недоступна
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} вопрос этой дуэли недоступен} few{{count} вопроса этой дуэли недоступны} many{{count} вопросов этой дуэли недоступны} other{{count} вопроса этой дуэли недоступны}} в твоей версии колоды: колода обновилась или вопрос скрыт. Обнови колоду или сыграй без них.'**
  String duelPlayBlockedBody(int count);

  /// Кнопка: докачать актуальную версию колоды
  ///
  /// In ru, this message translates to:
  /// **'Обновить колоду'**
  String get duelPlayUpdateDeck;

  /// Подпись кнопки во время обновления колоды
  ///
  /// In ru, this message translates to:
  /// **'Обновляем…'**
  String get duelPlayUpdating;

  /// Ошибка обновления колоды
  ///
  /// In ru, this message translates to:
  /// **'Не удалось обновить колоду. Нужна сеть.'**
  String get duelPlayUpdateError;

  /// Кнопка: недоступные вопросы засчитать неверными
  ///
  /// In ru, this message translates to:
  /// **'Сыграть без них'**
  String get duelPlaySkip;

  /// Пояснение к кнопке «Сыграть без них»
  ///
  /// In ru, this message translates to:
  /// **'Недоступные вопросы засчитаются как неверные, остальные сыграешь как обычно.'**
  String get duelPlaySkipHint;

  /// Итог дуэли: победа
  ///
  /// In ru, this message translates to:
  /// **'Ты победил'**
  String get duelResultWon;

  /// Итог дуэли: поражение
  ///
  /// In ru, this message translates to:
  /// **'Победил соперник'**
  String get duelResultLost;

  /// Итог дуэли: поражение, соперник с именем
  ///
  /// In ru, this message translates to:
  /// **'Победил {name}'**
  String duelResultLostNamed(String name);

  /// Итог дуэли: ничья
  ///
  /// In ru, this message translates to:
  /// **'Ничья'**
  String get duelResultDraw;

  /// Подпись твоего счёта
  ///
  /// In ru, this message translates to:
  /// **'Ты'**
  String get duelResultYou;

  /// Подпись счёта соперника без имени
  ///
  /// In ru, this message translates to:
  /// **'Соперник'**
  String get duelResultOpponent;

  /// Счёт: верных из всех
  ///
  /// In ru, this message translates to:
  /// **'{correct} из {total}'**
  String duelResultScore(int correct, int total);

  /// Суммарное время ответов
  ///
  /// In ru, this message translates to:
  /// **'время {time}'**
  String duelResultTime(String time);

  /// Счёт участника для скринридера
  ///
  /// In ru, this message translates to:
  /// **'{who}: верных {correct} из {total}, время {time}'**
  String duelResultScoreSemantics(
    String who,
    int correct,
    int total,
    String time,
  );

  /// Правило подсчёта
  ///
  /// In ru, this message translates to:
  /// **'Побеждает больше верных ответов, при равенстве меньшее время.'**
  String get duelResultRule;

  /// Заголовок разбора вопроса
  ///
  /// In ru, this message translates to:
  /// **'Вопрос {n}'**
  String duelResultQuestionTitle(int n);

  /// Подпись твоего ответа
  ///
  /// In ru, this message translates to:
  /// **'Твой ответ'**
  String get duelResultYourAnswer;

  /// Подпись ответа соперника без имени
  ///
  /// In ru, this message translates to:
  /// **'Ответ соперника'**
  String get duelResultTheirAnswer;

  /// Подпись ответа соперника с именем
  ///
  /// In ru, this message translates to:
  /// **'Ответ: {name}'**
  String duelResultTheirAnswerNamed(String name);

  /// Подпись верного ответа
  ///
  /// In ru, this message translates to:
  /// **'Верный ответ'**
  String get duelResultCorrectAnswer;

  /// Ответ верный
  ///
  /// In ru, this message translates to:
  /// **'верно'**
  String get duelResultRight;

  /// Ответ неверный
  ///
  /// In ru, this message translates to:
  /// **'неверно'**
  String get duelResultWrong;

  /// Ответа нет
  ///
  /// In ru, this message translates to:
  /// **'нет ответа'**
  String get duelResultNoAnswer;

  /// Вопрос пропущен как недоступный
  ///
  /// In ru, this message translates to:
  /// **'вопрос был недоступен, засчитан неверным'**
  String get duelResultSkipped;

  /// Не удалось показать выбранные варианты
  ///
  /// In ru, this message translates to:
  /// **'ответ в неизвестном виде'**
  String get duelResultUnknownAnswer;

  /// Время ответа на вопрос
  ///
  /// In ru, this message translates to:
  /// **'время {time}'**
  String duelResultTimeOfAnswer(String time);

  /// Тексты вопроса не показать
  ///
  /// In ru, this message translates to:
  /// **'Вопрос недоступен на этом устройстве: его нет в твоей версии колоды или он скрыт.'**
  String get duelResultQuestionUnavailable;

  /// Нет колоды для экрана результата
  ///
  /// In ru, this message translates to:
  /// **'Колоды нет на устройстве: тексты вопросов и разбор недоступны.'**
  String get duelResultDeckMissing;

  /// Заголовок разбора вопроса
  ///
  /// In ru, this message translates to:
  /// **'Разбор'**
  String get duelResultExplanation;

  /// Ошибка загрузки результата
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить результат.'**
  String get duelResultError;

  /// Заголовок блока карточек дуэлей на главном
  ///
  /// In ru, this message translates to:
  /// **'Дуэли'**
  String get homeDuelsSection;

  /// Карточка на главном: пора отвечать
  ///
  /// In ru, this message translates to:
  /// **'Дуэль: твой ход'**
  String get homeDuelYourTurn;

  /// Карточка на главном: пора отвечать, с именем
  ///
  /// In ru, this message translates to:
  /// **'{name}: твой ход'**
  String homeDuelYourTurnNamed(String name);

  /// Карточка на главном: ждём
  ///
  /// In ru, this message translates to:
  /// **'Дуэль: ждём соперника'**
  String get homeDuelWaiting;

  /// Карточка на главном: ждём, с именем
  ///
  /// In ru, this message translates to:
  /// **'{name}: ждём ответа'**
  String homeDuelWaitingNamed(String name);

  /// Карточка на главном: результат готов
  ///
  /// In ru, this message translates to:
  /// **'Дуэль: посмотри результат'**
  String get homeDuelResult;

  /// Карточка на главном: результат готов, с именем
  ///
  /// In ru, this message translates to:
  /// **'{name} ответил: посмотри результат'**
  String homeDuelResultNamed(String name);
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
