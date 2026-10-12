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
}
