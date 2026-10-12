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

  @override
  String get homeStartSession => 'Начать сессию (5 мин)';

  @override
  String homeDueLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'знания к повторению',
      many: 'знаний к повторению',
      few: 'знания к повторению',
      one: 'знание к повторению',
    );
    return '$_temp0';
  }

  @override
  String homeNewLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'новых знания',
      many: 'новых знаний',
      few: 'новых знания',
      one: 'новое знание',
    );
    return '$_temp0';
  }

  @override
  String homeStatsSemantics(int due, int fresh) {
    return 'К повторению: $due, новых: $fresh';
  }

  @override
  String get homeNoDecksTitle => 'Пока нет колод';

  @override
  String get homeNoDecksBody =>
      'Скачайте первую колоду, чтобы начать повторять.';

  @override
  String get homeNoDecksAction => 'Скачать колоду';

  @override
  String get homeNothingTitle => 'Здесь пока нечего повторять';

  @override
  String get homeNothingBody =>
      'Загляните в колоды: возможно, в них вышло обновление.';

  @override
  String get homeError => 'Не удалось загрузить данные главного экрана.';

  @override
  String get homeRetry => 'Повторить';

  @override
  String get homeDecksButton => 'Колоды';

  @override
  String deckVersionLine(int version, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count знания',
      many: '$count знаний',
      few: '$count знания',
      one: '$count знание',
    );
    return 'Версия $version · $_temp0';
  }

  @override
  String get deckNoDescription => 'Описание отсутствует.';

  @override
  String get deckProgressTitle => 'Прогресс';

  @override
  String get deckNewLabel => 'Новые';

  @override
  String get deckLearningLabel => 'Изучаемые';

  @override
  String get deckMasteredLabel => 'Выученные';

  @override
  String deckProgressSemantics(int fresh, int learning, int mastered) {
    return 'Прогресс по колоде: новых $fresh, изучаемых $learning, выученных $mastered';
  }

  @override
  String get deckStart => 'Начать по этой колоде';

  @override
  String get deckCheckUpdate => 'Проверить обновление';

  @override
  String get deckUpdating => 'Проверяем…';

  @override
  String deckUpdated(int version) {
    return 'Колода обновлена до версии $version';
  }

  @override
  String get deckUpToDate => 'Установлена последняя версия';

  @override
  String get deckNewPerDay => 'Новых знаний в день';

  @override
  String get deckNewPerDayHint => 'Один лимит на все колоды';

  @override
  String get deckDelete => 'Удалить с устройства';

  @override
  String get deckDeleteTitle => 'Удалить колоду?';

  @override
  String deckDeleteBody(String title) {
    return 'Колода «$title» исчезнет с этого устройства. Ваш прогресс сохранится: если скачать колоду снова, вы продолжите с того же места.';
  }

  @override
  String get deckDeleteCancel => 'Отмена';

  @override
  String get deckDeleteConfirm => 'Удалить';

  @override
  String get deckDeleteError =>
      'Не удалось удалить колоду. Попробуйте ещё раз.';

  @override
  String get deckNotFound => 'Этой колоды нет на устройстве';

  @override
  String get deckLoadError => 'Не удалось загрузить колоду.';

  @override
  String onboardingStep(int current, int total) {
    return 'Шаг $current из $total';
  }

  @override
  String get onboardingWelcomeTitle => 'Помнить, а не зубрить';

  @override
  String get onboardingWelcomeBody =>
      'Приложение показывает знания тогда, когда вы вот-вот их забудете (алгоритм FSRS). Поэтому хватает нескольких минут в день.';

  @override
  String get onboardingSessionTitle => 'Сессия на 5 минут';

  @override
  String get onboardingSessionBody =>
      'Нажмите «Начать сессию»: сначала то, что пора повторить, потом новые знания. После каждого ответа оцените, как хорошо вы помнили, от «Снова» до «Легко». Закрыть приложение можно в любой момент: данные сохраняются.';

  @override
  String get onboardingDeckTitle => 'Выберите колоду';

  @override
  String get onboardingDeckBody =>
      'Скачайте первую колоду. Остальные можно добавить позже в разделе «Колоды».';

  @override
  String get onboardingNext => 'Далее';

  @override
  String get onboardingBack => 'Назад';

  @override
  String get onboardingSkip => 'Пропустить';

  @override
  String get onboardingStartSession => 'Начать первую сессию';

  @override
  String get onboardingLater => 'Выбрать колоду позже';

  @override
  String get settingsSessionSection => 'Сессия';

  @override
  String get settingsNewPerDay => 'Новых знаний в день';

  @override
  String get settingsSessionSize => 'Размер сессии (знаний)';

  @override
  String get settingsSessionSizeHint =>
      'Сессию заканчивает таймер на 5 минут; размер задаёт потолок очереди.';

  @override
  String get settingsDecrease => 'Меньше';

  @override
  String get settingsIncrease => 'Больше';

  @override
  String get settingsSaveError => 'Не удалось сохранить настройку.';

  @override
  String get sessionStart => 'Начать сессию';

  @override
  String get sessionTitle => 'Сессия';

  @override
  String get sessionExit => 'Выйти из сессии';

  @override
  String get sessionExitConfirmTitle => 'Выйти из сессии?';

  @override
  String get sessionExitConfirmBody => 'Уже данные ответы сохранены.';

  @override
  String get sessionExitStay => 'Остаться';

  @override
  String get sessionExitLeave => 'Выйти';

  @override
  String sessionProgress(int current, int total) {
    return 'Вопрос $current из $total';
  }

  @override
  String sessionTimeLeft(String time) {
    return 'Осталось $time';
  }

  @override
  String get sessionTimeUp => 'Время вышло: дайте ответ на этот вопрос';

  @override
  String get sessionLoading => 'Готовим вопросы…';

  @override
  String get sessionStartError =>
      'Не удалось подготовить сессию. Попробуйте ещё раз.';

  @override
  String get sessionRetry => 'Повторить';

  @override
  String get sessionSaveError =>
      'Не удалось сохранить ответ. Нажмите оценку ещё раз.';

  @override
  String get sessionUnsupported =>
      'Этот формат вопроса пока не поддерживается.';

  @override
  String get sessionFinishNow => 'Закончить сессию';

  @override
  String get sessionHome => 'На главную';

  @override
  String get sessionSummaryTitle => 'Сессия завершена';

  @override
  String sessionSummaryReviewed(int count) {
    return 'Повторено: $count';
  }

  @override
  String sessionSummaryCorrect(int count) {
    return 'Верно: $count';
  }

  @override
  String sessionSummaryIncorrect(int count) {
    return 'Неверно: $count';
  }

  @override
  String sessionSummarySelf(int count) {
    return 'По самооценке: $count';
  }

  @override
  String sessionSummaryTime(String time) {
    return 'Время: $time';
  }

  @override
  String get sessionSummaryUpcomingTitle => 'Скоро повторить';

  @override
  String get sessionSummaryUpcomingNow => 'пора сейчас';

  @override
  String sessionSummaryUpcomingItem(String title, String when) {
    return '$title: $when';
  }

  @override
  String sessionSummaryUpcomingMore(int count) {
    return 'и ещё $count';
  }

  @override
  String get sessionMore => 'Ещё 5 минут';

  @override
  String durationSeconds(int n) {
    return '$n с';
  }

  @override
  String durationMinutesOnly(int m) {
    return '$m мин';
  }

  @override
  String durationMinutesSeconds(int m, int s) {
    return '$m мин $s с';
  }

  @override
  String get explanationShortToggle => 'Коротко';

  @override
  String get explanationLongToggle => 'Подробнее';

  @override
  String get explanationEmpty => 'К этому знанию разбора нет.';

  @override
  String get explanationSourcesTitle => 'Источники';

  @override
  String explanationLicense(String license) {
    return 'Лицензия: $license';
  }

  @override
  String explanationQuote(String quote) {
    return '«$quote»';
  }

  @override
  String get explanationOpenSource => 'Открыть источник';

  @override
  String explanationOpenSourceLabel(String title) {
    return 'Открыть источник «$title» в браузере';
  }

  @override
  String get explanationLinkNotHttps =>
      'Ссылка не открывается из приложения: разрешены только адреса https.';

  @override
  String get explanationLinkFailed => 'Не удалось открыть ссылку.';

  @override
  String get explanationLinkBlocked =>
      'Эта ссылка не входит в источники колоды, поэтому не открыта.';

  @override
  String get sessionEmptyTitle => 'Всё повторено 🎉';

  @override
  String sessionEmptyNext(String when) {
    return 'Следующее повторение — $when';
  }

  @override
  String get sessionEmptyNewLimit => 'На сегодня лимит новых знаний исчерпан.';

  @override
  String sessionTakeNew(int count) {
    return 'Взять $count новых';
  }

  @override
  String get sessionNoContentTitle => 'Пока нечего повторять';

  @override
  String get sessionNoContentBody => 'Скачайте колоду, чтобы начать.';

  @override
  String get sessionToDecks => 'К колодам';

  @override
  String get durationLessThanMinute => 'меньше чем через минуту';

  @override
  String durationMinutes(int n) {
    return 'через $n мин';
  }

  @override
  String durationHours(int n) {
    return 'через $n ч';
  }

  @override
  String durationDays(int n) {
    return 'через $n дн.';
  }

  @override
  String get verdictCorrect => 'Верно';

  @override
  String get verdictPartial => 'Почти верно';

  @override
  String get verdictIncorrect => 'Неверно';

  @override
  String get ratingPrompt => 'Как хорошо вы это помнили?';

  @override
  String get ratingAgain => 'Снова';

  @override
  String get ratingHard => 'Трудно';

  @override
  String get ratingGood => 'Хорошо';

  @override
  String get ratingEasy => 'Легко';

  @override
  String get ratingSuggested => 'предложено';

  @override
  String ratingSuggestedHint(String rating) {
    return 'Предложенная оценка: $rating';
  }

  @override
  String get ratingChooseHint => 'Выберите оценку сами';

  @override
  String get ratingNext => 'Дальше';

  @override
  String get mcqHintMultiple => 'Выберите все верные варианты';

  @override
  String get mcqAnswer => 'Ответить';

  @override
  String get mcqOptionCorrect => 'Верно';

  @override
  String get mcqOptionWrong => 'Неверно';

  @override
  String get mcqOptionMissed => 'Верный ответ';

  @override
  String get flipShowAnswer => 'Показать ответ';

  @override
  String get flipAnswerLabel => 'Ответ';

  @override
  String get settingsReminderSection => 'Напоминание';

  @override
  String get reminderSwitchTitle => 'Ежедневное напоминание';

  @override
  String get reminderSwitchSubtitle =>
      'В выбранное время придёт уведомление, но только если есть что повторять. При включении Android может спросить разрешение на уведомления.';

  @override
  String get reminderTimeTitle => 'Время напоминания';

  @override
  String get reminderTimePickerHelp => 'Время напоминания';

  @override
  String get reminderUnsupported =>
      'Напоминания работают только в приложении для Android. В браузере их нет.';

  @override
  String get reminderPermissionDenied =>
      'Уведомления для приложения выключены в настройках Android, поэтому напоминания не приходят. Включите их там, и напоминание заработает само.';

  @override
  String get reminderOpenSettings => 'Открыть настройки уведомлений';

  @override
  String get reminderNotificationTitle => 'Пора повторить';

  @override
  String get reminderNotificationBody =>
      'Пять минут сейчас, и знания останутся надолго.';

  @override
  String get reminderChannelName => 'Напоминания о повторении';

  @override
  String get reminderChannelDescription =>
      'Ежедневное напоминание повторить знания';

  @override
  String get onboardingReminderTitle => 'Напоминание';

  @override
  String get onboardingReminderBody =>
      'Хотите, чтобы приложение напоминало о повторении? Оно напишет в выбранное время и только если есть что повторять. Это можно изменить в настройках.';
}
