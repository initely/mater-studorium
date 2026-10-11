import '../../../core/errors/app_error.dart';
import '../domain/local_deck.dart';
import '../domain/remote_deck.dart';

/// Что можно сделать с колодой в списке.
enum DeckStatus {
  /// На устройстве нет: «Скачать».
  notDownloaded,

  /// Скачана, версия на сервере не новее (или сервер недоступен).
  downloaded,

  /// На сервере версия новее скачанной: «Обновить».
  updateAvailable,
}

/// Строка списка «Колоды»: серверные данные, если они есть, иначе локальные.
class DeckEntry {
  const DeckEntry({
    required this.id,
    required this.title,
    required this.topic,
    required this.version,
    required this.status,
    this.itemCount,
    this.downloading = false,
    this.error,
  });

  final String id;
  final String title;
  final String topic;

  /// Версия на сервере (для `notDownloaded` и `updateAvailable`) или скачанная.
  final int version;
  final DeckStatus status;

  /// Число знаний известно только из каталога сервера.
  final int? itemCount;
  final bool downloading;

  /// Последняя неудачная попытка скачать эту колоду.
  final AppError? error;
}

/// Состояние экрана «Колоды».
class CatalogState {
  const CatalogState({
    this.loading = false,
    this.listError,
    this.remote,
    this.local = const [],
    this.downloading = const {},
    this.deckErrors = const {},
  });

  /// Идёт загрузка списка с сервера.
  final bool loading;

  /// Список с сервера не получен (нет сети и т. п.); скачанные колоды при
  /// этом всё равно показываются.
  final AppError? listError;

  /// Последний полученный каталог сервера; null, пока не получен.
  final List<RemoteDeck>? remote;
  final List<LocalDeck> local;
  final Set<String> downloading;
  final Map<String, AppError> deckErrors;

  /// Каталог сервера плюс скачанные колоды, которых в нём нет (сервер
  /// недоступен или колоду сняли с публикации). Порядок: по названию.
  List<DeckEntry> get entries {
    final localById = {for (final d in local) d.id: d};
    final entries = <DeckEntry>[];
    for (final r in remote ?? const <RemoteDeck>[]) {
      final l = localById.remove(r.id);
      entries.add(
        DeckEntry(
          id: r.id,
          title: r.title,
          topic: r.topic,
          version: r.version,
          itemCount: r.itemCount,
          status: l == null
              ? DeckStatus.notDownloaded
              : l.version < r.version
              ? DeckStatus.updateAvailable
              : DeckStatus.downloaded,
          downloading: downloading.contains(r.id),
          error: deckErrors[r.id],
        ),
      );
    }
    for (final l in localById.values) {
      entries.add(
        DeckEntry(
          id: l.id,
          title: l.title,
          topic: l.topic,
          version: l.version,
          status: DeckStatus.downloaded,
        ),
      );
    }
    entries.sort((a, b) => a.title.compareTo(b.title));
    return entries;
  }

  CatalogState copyWith({
    bool? loading,
    AppError? Function()? listError,
    List<RemoteDeck>? remote,
    List<LocalDeck>? local,
    Set<String>? downloading,
    Map<String, AppError>? deckErrors,
  }) => CatalogState(
    loading: loading ?? this.loading,
    listError: listError != null ? listError() : this.listError,
    remote: remote ?? this.remote,
    local: local ?? this.local,
    downloading: downloading ?? this.downloading,
    deckErrors: deckErrors ?? this.deckErrors,
  );
}
