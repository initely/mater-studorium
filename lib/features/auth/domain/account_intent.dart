/// Что человек сейчас делает с аккаунтом (T21, ADR-34). Хранится на
/// устройстве, потому что на web возврат из Google перезагружает страницу, а
/// на Android приложение могут закрыть, пока открыт браузер: без записи
/// приложение не знало бы, чем закончилась попытка, и не отличило бы свою
/// попытку от чужого или старого события.
enum AccountIntentKind {
  /// Привязать Google к текущему анонимному аккаунту (`linkIdentity`).
  link,

  /// Пользователь явно подтвердил: войти в существующий аккаунт Google и
  /// объединить с ним прогресс этого устройства (ADR-34). Только такая запись
  /// разрешает перенос данных «аноним → Google».
  merge,

  /// Приложение само повторно входит анонимно, потому что сессия потеряна
  /// (отозван или просрочен refresh token, очищено хранилище сессии). Только
  /// при такой записи прогресс прежнего анонимного пользователя переносится на
  /// нового анонимного (ADR-30). Без неё смена анонимного пользователя на
  /// анонимного ничего не переносит: иначе подмена сессии извне забрала бы
  /// прогресс и очередь отправки (ревью T21, B2). Срока жизни нет: повторный
  /// вход может ждать сети сколько угодно; запись закрывает любой вход.
  relogin,
}

/// Намерение: что, из какого пользователя и когда началось.
class AccountIntent {
  const AccountIntent({
    required this.kind,
    required this.fromUserId,
    required this.createdAt,
  });

  final AccountIntentKind kind;

  /// Анонимный пользователь, чей локальный прогресс затрагивается.
  final String fromUserId;

  /// UTC.
  final DateTime createdAt;

  /// Срок жизни записи. Хватает на вход в Google с двухфакторной проверкой;
  /// просроченная запись не разрешает ничего (общее устройство: чужой вход
  /// через час не должен получить прогресс прежнего владельца).
  static const ttl = Duration(minutes: 15);

  /// Запись ещё действует в момент [now] (для `link` и `merge`; `relogin` без
  /// срока). Время «из будущего» (часы переведены назад) недействительно.
  bool isFresh(DateTime now) {
    final age = now.difference(createdAt);
    return !age.isNegative && age <= ttl;
  }

  @override
  bool operator ==(Object other) =>
      other is AccountIntent &&
      other.kind == kind &&
      other.fromUserId == fromUserId &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(kind, fromUserId, createdAt);

  @override
  String toString() => 'AccountIntent($kind, $fromUserId, $createdAt)';
}

/// Хранилище одного намерения (в локальной БД, `app_settings`).
abstract interface class AccountIntentStore {
  /// Текущая запись или `null`. Битое значение читается как `null`.
  Future<AccountIntent?> readIntent();

  Future<void> writeIntent(AccountIntent intent);

  Future<void> clearIntent();
}
