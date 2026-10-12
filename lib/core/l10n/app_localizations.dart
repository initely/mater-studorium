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

  /// Текст подтверждения удаления колоды (ADR-26)
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

  /// Заглушка итогов (полные итоги — T14)
  ///
  /// In ru, this message translates to:
  /// **'Сессия завершена'**
  String get sessionSummaryTitle;

  /// Сколько вопросов отвечено за сессию
  ///
  /// In ru, this message translates to:
  /// **'Повторено: {count}'**
  String sessionSummaryReviewed(int count);

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
