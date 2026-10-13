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

  @override
  String get openAnswerLabel => 'Ваш ответ';

  @override
  String get openAnswerHint => 'Своими словами, в одном-трёх предложениях';

  @override
  String openCounter(int count, int max) {
    return '$count из $max';
  }

  @override
  String get openCheck => 'Проверить';

  @override
  String get openChecking => 'Проверяю…';

  @override
  String get openDontRemember => 'Не помню';

  @override
  String get openCheckAgain => 'Проверить ещё раз';

  @override
  String get openSelfAssess => 'Оценить самому';

  @override
  String get openReferenceTitle => 'Эталонный ответ';

  @override
  String get openRubricTitle => 'Разбор по пунктам';

  @override
  String get openPointHit => 'раскрыт';

  @override
  String get openPointPartial => 'раскрыт частично';

  @override
  String get openPointMiss => 'не раскрыт';

  @override
  String get openPointRequired => 'обязательный пункт';

  @override
  String get openFeedbackTitle => 'Комментарий проверки';

  @override
  String openQuotaRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Осталось $count проверки на сегодня',
      many: 'Осталось $count проверок на сегодня',
      few: 'Осталось $count проверки на сегодня',
      one: 'Осталась $count проверка на сегодня',
    );
    return '$_temp0';
  }

  @override
  String get openFallbackUnavailable =>
      'Проверка недоступна. Сравните свой ответ с эталоном и оцените себя сами.';

  @override
  String get openFallbackQuota =>
      'На сегодня проверки закончились. Сравните свой ответ с эталоном и оцените себя сами.';

  @override
  String openFallbackQuotaReset(String time) {
    return 'На сегодня проверки закончились, они обновятся в $time. Сравните свой ответ с эталоном и оцените себя сами.';
  }

  @override
  String get openFallbackSignedOut =>
      'Чтобы проверять ответы, нужно войти в приложение. Сравните свой ответ с эталоном и оцените себя сами.';

  @override
  String get openFallbackUnsure =>
      'Не удалось уверенно оценить ответ. Сравните его с эталоном и оцените себя сами.';

  @override
  String get openFallbackDisabled =>
      'Проверка моделью выключена. Сравните свой ответ с эталоном и оцените себя сами.';

  @override
  String get openFallbackSkipped =>
      'Сравните ответ с эталоном и оцените себя сами.';

  @override
  String get openMicStart => 'Диктовать ответ';

  @override
  String get openMicStop => 'Закончить диктовку';

  @override
  String get openMicCancel => 'Отменить диктовку';

  @override
  String get openMicListening => 'Слушаю… говорите';

  @override
  String get openMicEditHint =>
      'Распознанный текст можно поправить перед проверкой.';

  @override
  String get openMicUnsupported =>
      'Диктовка в этом браузере или на этом устройстве недоступна. Введите ответ текстом.';

  @override
  String get openMicPermissionDenied =>
      'Нет доступа к микрофону. Разрешите его в настройках приложения или введите ответ текстом.';

  @override
  String get openMicPermissionDeniedWeb =>
      'Браузер не дал доступ к микрофону. Разрешите его для этого сайта или введите ответ текстом.';

  @override
  String get openMicOpenSettings => 'Открыть настройки приложения';

  @override
  String get openMicNoSpeech =>
      'Речь не расслышали. Нажмите на микрофон и повторите или введите ответ текстом.';

  @override
  String get openMicNetwork =>
      'Для распознавания речи нужна сеть. Введите ответ текстом.';

  @override
  String get openMicLanguage =>
      'Для языка колоды на устройстве нет распознавания речи. Введите ответ текстом.';

  @override
  String get openMicError =>
      'Диктовка не сработала. Попробуйте ещё раз или введите ответ текстом.';

  @override
  String get openConsentTitle => 'Проверка ответов моделью';

  @override
  String get openConsentBody =>
      'Открытые ответы отправляются на проверку внешней языковой модели через наш сервер. Уходит только текст ответа, без имени и контактов. Если отказаться, вы будете оценивать себя сами по эталонному ответу; передумать можно в настройках.';

  @override
  String get openConsentAllow => 'Разрешить';

  @override
  String get openConsentDecline => 'Без ИИ';

  @override
  String get settingsGradingSection => 'Проверка ответов';

  @override
  String get settingsLlmConsentTitle => 'Проверять открытые ответы моделью';

  @override
  String get settingsLlmConsentSubtitle =>
      'Текст ответа отправляется внешней модели. Если выключить, вы оцениваете себя сами по эталону.';

  @override
  String get reportButton => 'Пожаловаться';

  @override
  String get reportButtonSent => 'Жалоба отправлена';

  @override
  String get reportSheetTitle => 'На что пожаловаться?';

  @override
  String get reportSheetHint =>
      'Вопрос перестанет показываться вам сразу. Куратор проверит его.';

  @override
  String get reportReasonWrongAnswer => 'Неверный ответ';

  @override
  String get reportReasonUnclear => 'Непонятно';

  @override
  String get reportReasonTypo => 'Опечатка';

  @override
  String get reportReasonBadSource => 'Плохой источник';

  @override
  String get reportReasonOther => 'Другое';

  @override
  String get reportCommentLabel => 'Комментарий (необязательно)';

  @override
  String get reportSend => 'Отправить';

  @override
  String get reportCancel => 'Отмена';

  @override
  String get reportThanks =>
      'Спасибо! Вопрос скрыт у вас, куратор его проверит.';

  @override
  String get reportError => 'Не удалось сохранить жалобу. Попробуйте ещё раз.';

  @override
  String get disagreeButton => 'Не согласен с оценкой';

  @override
  String get disagreeSheetTitle => 'Не согласен с оценкой ИИ';

  @override
  String disagreeSheetBody(String verdict) {
    return 'ИИ оценил ответ: «$verdict». Выберите оценку, которую считаете верной. Куратор увидит ваш ответ, вердикт ИИ и вашу оценку.';
  }

  @override
  String get disagreeRatingLabel => 'Моя оценка';

  @override
  String get disagreeSend => 'Отправить и продолжить';

  @override
  String get disagreeThanks => 'Спасибо! Куратор посмотрит оценку.';

  @override
  String get settingsAccountSection => 'Аккаунт';

  @override
  String get accountSigningIn => 'Выполняется вход…';

  @override
  String get accountAnonymousTitle => 'Анонимный аккаунт';

  @override
  String get accountAnonymousSubtitle =>
      'Прогресс хранится на этом устройстве и в облаке без входа. Привяжите Google, чтобы не потерять его и открыть на другом устройстве.';

  @override
  String accountLinkedTitle(String email) {
    return 'Google: $email';
  }

  @override
  String get accountLinkedNoEmailTitle => 'Google привязан';

  @override
  String get accountLinkedSubtitle =>
      'Прогресс сохраняется в облаке. Войдите в этот аккаунт Google на другом устройстве, и прогресс будет там же.';

  @override
  String get accountLinkButton => 'Привязать Google';

  @override
  String get accountLinkOpening => 'Открываем браузер…';

  @override
  String get accountNoBackend =>
      'Вход недоступен: приложение собрано без подключения к серверу.';

  @override
  String get accountNoticeLinked => 'Google привязан. Прогресс сохранён.';

  @override
  String get accountNoticeSignedInExisting =>
      'Вы вошли в существующий аккаунт Google. Прогресс этого устройства объединён с ним и уйдёт на сервер при синхронизации.';

  @override
  String get accountNoticeCancelled => 'Вход отменён. Ничего не изменилось.';

  @override
  String get accountNoticeUnavailable =>
      'Привязка Google не настроена в этой сборке.';

  @override
  String get accountNoticeNetwork =>
      'Нет связи с сервером. Проверьте сеть и попробуйте ещё раз.';

  @override
  String get accountNoticeFailed =>
      'Не удалось привязать Google. Ничего не изменилось, можно попробовать ещё раз.';

  @override
  String get accountConflictTitle => 'Этот Google уже используется';

  @override
  String get accountConflictBody =>
      'Этот аккаунт Google уже привязан к другому профилю приложения. Можно войти в него: тогда прогресс на этом устройстве объединится с прогрессом того аккаунта. По каждому знанию останется более поздний результат повторения, остальное сохранится. Если не хотите, откажитесь: всё останется как сейчас.';

  @override
  String get accountConflictConfirm => 'Войти и объединить';

  @override
  String get accountConflictDecline => 'Отказаться';

  @override
  String get accountNoticeMergeNotConfirmed =>
      'Подтверждение устарело, поэтому прогресс этого устройства не перенесён. Он сохранён на устройстве: нажмите «Перенести прогресс», чтобы объединить его с этим аккаунтом.';

  @override
  String get accountNoticeMergeFailed =>
      'Не удалось перенести прогресс. Ничего не потеряно, он сохранён на устройстве. Попробуйте ещё раз.';

  @override
  String get accountRetryMerge => 'Перенести прогресс';

  @override
  String get homeDuelsButton => 'Дуэли';

  @override
  String get duelsTitle => 'Дуэли';

  @override
  String get duelsCreate => 'Создать дуэль';

  @override
  String get duelsJoin => 'Войти по коду';

  @override
  String get duelsListTitle => 'Твои дуэли';

  @override
  String get duelsEmpty =>
      'Дуэлей пока нет. Создай свою или войди по коду друга.';

  @override
  String get duelsLoadError => 'Не удалось загрузить дуэли.';

  @override
  String get duelsRetry => 'Повторить';

  @override
  String get duelNameLabel => 'Твоё имя для соперника';

  @override
  String get duelNameHint => 'Можно оставить пустым';

  @override
  String get duelNameSave => 'Сохранить имя';

  @override
  String get duelNameSaved => 'Имя сохранено';

  @override
  String get duelNameError =>
      'Не удалось сохранить имя. Проверь сеть и попробуй ещё раз.';

  @override
  String get duelCreateTitle => 'Новая дуэль';

  @override
  String get duelCreateChooseDeck =>
      'Выбери колоду: 5 случайных вопросов возьмём из неё';

  @override
  String get duelCreateNoDecks =>
      'Сначала скачай колоду: вопросы для дуэли берутся из неё.';

  @override
  String get duelCreateNoDecksAction => 'К колодам';

  @override
  String get duelCreateAction => 'Создать дуэль';

  @override
  String get duelCreateCreating => 'Создаём…';

  @override
  String duelCreateNotEnough(int count) {
    return 'В этой колоде мало подходящих вопросов: $count, нужно 5. Выбери другую колоду.';
  }

  @override
  String get duelCreatedTitle => 'Дуэль создана';

  @override
  String get duelCreatedBody =>
      'Отправь код другу: он введёт его в приложении.';

  @override
  String get duelCodeLabel => 'Код приглашения';

  @override
  String duelCodeSemantics(String code) {
    return 'Код: $code';
  }

  @override
  String get duelCopyCode => 'Скопировать код';

  @override
  String get duelCopyInvite => 'Скопировать приглашение';

  @override
  String get duelCopied => 'Скопировано';

  @override
  String duelInviteText(String code) {
    return 'Сыграем дуэль в Mater Studorium? Код: $code';
  }

  @override
  String get duelOpenDuel => 'К дуэли';

  @override
  String get duelJoinTitle => 'Вход по коду';

  @override
  String get duelJoinCodeLabel => 'Код дуэли';

  @override
  String get duelJoinCodeHint => '6 знаков, например K7Q 2MX';

  @override
  String get duelJoinAction => 'Войти';

  @override
  String get duelJoinJoining => 'Входим…';

  @override
  String get duelErrorNotFound => 'Код не найден или дуэль истекла';

  @override
  String get duelErrorFull => 'В этой дуэли уже есть соперник';

  @override
  String get duelErrorLimitActive =>
      'Слишком много активных дуэлей. Дождись окончания прежних.';

  @override
  String get duelErrorLimitDaily =>
      'Сегодня создано слишком много дуэлей. Попробуй завтра.';

  @override
  String get duelErrorLimitJoin =>
      'Слишком много неверных кодов. Подожди час и попробуй снова.';

  @override
  String get duelErrorNetwork => 'Нужна сеть. Проверь подключение и повтори.';

  @override
  String get duelErrorAuth => 'Нет входа в аккаунт. Перезапусти приложение.';

  @override
  String get duelErrorDeck => 'Эта колода недоступна для дуэли.';

  @override
  String get duelErrorGeneric =>
      'Не удалось выполнить действие. Попробуй ещё раз.';

  @override
  String get duelScreenTitle => 'Дуэль';

  @override
  String get duelNotFound => 'Дуэль не найдена';

  @override
  String get duelStatusOpen => 'Ждём соперника';

  @override
  String get duelStatusOpenBody =>
      'Отправь ему код: он введёт его в приложении.';

  @override
  String get duelStatusActive => 'Соперник в дуэли';

  @override
  String duelStatusActiveNamed(String name) {
    return '$name в дуэли';
  }

  @override
  String get duelStatusFinished => 'Результат готов';

  @override
  String get duelStatusExpired => 'Дуэль истекла';

  @override
  String duelRemaining(String left) {
    return 'осталось $left';
  }

  @override
  String duelLeftDays(int n) {
    return '$n д';
  }

  @override
  String duelLeftHours(int n) {
    return '$n ч';
  }

  @override
  String duelLeftMinutes(int n) {
    return '$n мин';
  }

  @override
  String get duelLeftLessThanMinute => 'меньше минуты';

  @override
  String duelWithName(String name) {
    return 'Дуэль с $name';
  }

  @override
  String get duelWaitingTitle => 'Дуэль, ждём соперника';

  @override
  String get duelDeckMissing =>
      'Колода этой дуэли не скачана на устройство. Без неё играть нельзя.';

  @override
  String get duelDeckDownload => 'Скачать колоду';

  @override
  String get duelDeckDownloading => 'Скачиваем…';

  @override
  String get duelDeckDownloadError => 'Не удалось скачать колоду. Нужна сеть.';

  @override
  String get duelOpponentUnnamed => 'Соперник без имени';

  @override
  String get duelCreatorUnnamed => 'Создатель без имени';

  @override
  String get duelRefresh => 'Обновить';

  @override
  String get duelStatusYourTurn => 'Твой ход';

  @override
  String duelStatusWaitingNamed(String name) {
    return 'Ждём $name';
  }

  @override
  String get duelPlayButton => 'Играть';

  @override
  String get duelYourTurnBody =>
      'Пять вопросов, у каждого свой секундомер. Лимита по времени нет.';

  @override
  String get duelWaitingBody =>
      'Ты ответил на все вопросы. Результат появится, когда соперник тоже закончит.';

  @override
  String duelWaitingBodyNamed(String name) {
    return 'Ты ответил на все вопросы. Результат появится, когда $name тоже закончит.';
  }

  @override
  String get duelSendingAnswers =>
      'Ответы ещё отправляются. Для этого нужна сеть.';

  @override
  String get duelPlayTitle => 'Дуэль';

  @override
  String duelPlayProgress(int n, int total) {
    return 'Вопрос $n из $total';
  }

  @override
  String duelPlayTimerLabel(String time) {
    return 'Время на вопрос: $time';
  }

  @override
  String get duelPlayNext => 'Дальше';

  @override
  String get duelPlayFinish => 'Закончить';

  @override
  String get duelPlaySaveError =>
      'Не удалось сохранить ответ. Попробуй ещё раз.';

  @override
  String get duelPlaySaveRetry => 'Повторить';

  @override
  String get duelPlayDoneTitle => 'Ты ответил на все вопросы';

  @override
  String get duelPlayDoneBody =>
      'Ответы уходят на сервер сами, сеть нужна только для этого. Результат появится, когда соперник тоже закончит.';

  @override
  String get duelPlayBackToDuel => 'К дуэли';

  @override
  String get duelPlayClosed => 'Эта дуэль уже закончилась или истекла.';

  @override
  String get duelPlayBlockedTitle => 'Дуэль нельзя сыграть как есть';

  @override
  String duelPlayBlockedBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вопроса этой дуэли недоступны',
      many: '$count вопросов этой дуэли недоступны',
      few: '$count вопроса этой дуэли недоступны',
      one: '$count вопрос этой дуэли недоступен',
    );
    return '$_temp0 в твоей версии колоды: колода обновилась или вопрос скрыт. Обнови колоду или сыграй без них.';
  }

  @override
  String get duelPlayUpdateDeck => 'Обновить колоду';

  @override
  String get duelPlayUpdating => 'Обновляем…';

  @override
  String get duelPlayUpdateError => 'Не удалось обновить колоду. Нужна сеть.';

  @override
  String get duelPlaySkip => 'Сыграть без них';

  @override
  String get duelPlaySkipHint =>
      'Недоступные вопросы засчитаются как неверные, остальные сыграешь как обычно.';

  @override
  String get duelResultWon => 'Ты победил';

  @override
  String get duelResultLost => 'Победил соперник';

  @override
  String duelResultLostNamed(String name) {
    return 'Победил $name';
  }

  @override
  String get duelResultDraw => 'Ничья';

  @override
  String get duelResultYou => 'Ты';

  @override
  String get duelResultOpponent => 'Соперник';

  @override
  String duelResultScore(int correct, int total) {
    return '$correct из $total';
  }

  @override
  String duelResultTime(String time) {
    return 'время $time';
  }

  @override
  String duelResultScoreSemantics(
    String who,
    int correct,
    int total,
    String time,
  ) {
    return '$who: верных $correct из $total, время $time';
  }

  @override
  String get duelResultRule =>
      'Побеждает больше верных ответов, при равенстве меньшее время.';

  @override
  String duelResultQuestionTitle(int n) {
    return 'Вопрос $n';
  }

  @override
  String get duelResultYourAnswer => 'Твой ответ';

  @override
  String get duelResultTheirAnswer => 'Ответ соперника';

  @override
  String duelResultTheirAnswerNamed(String name) {
    return 'Ответ: $name';
  }

  @override
  String get duelResultCorrectAnswer => 'Верный ответ';

  @override
  String get duelResultRight => 'верно';

  @override
  String get duelResultWrong => 'неверно';

  @override
  String get duelResultNoAnswer => 'нет ответа';

  @override
  String get duelResultSkipped => 'вопрос был недоступен, засчитан неверным';

  @override
  String get duelResultUnknownAnswer => 'ответ в неизвестном виде';

  @override
  String duelResultTimeOfAnswer(String time) {
    return 'время $time';
  }

  @override
  String get duelResultQuestionUnavailable =>
      'Вопрос недоступен на этом устройстве: его нет в твоей версии колоды или он скрыт.';

  @override
  String get duelResultDeckMissing =>
      'Колоды нет на устройстве: тексты вопросов и разбор недоступны.';

  @override
  String get duelResultExplanation => 'Разбор';

  @override
  String get duelResultError => 'Не удалось загрузить результат.';

  @override
  String get homeDuelsSection => 'Дуэли';

  @override
  String get homeDuelYourTurn => 'Дуэль: твой ход';

  @override
  String homeDuelYourTurnNamed(String name) {
    return '$name: твой ход';
  }

  @override
  String get homeDuelWaiting => 'Дуэль: ждём соперника';

  @override
  String homeDuelWaitingNamed(String name) {
    return '$name: ждём ответа';
  }

  @override
  String get homeDuelResult => 'Дуэль: посмотри результат';

  @override
  String homeDuelResultNamed(String name) {
    return '$name ответил: посмотри результат';
  }
}
