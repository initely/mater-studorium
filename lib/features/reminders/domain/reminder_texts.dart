/// Тексты напоминания и канала уведомлений. Домен их не хранит: строки идут
/// из ARB и приходят снаружи (CLAUDE.md, «Соглашения»).
class ReminderTexts {
  const ReminderTexts({
    required this.title,
    required this.body,
    required this.channelName,
    required this.channelDescription,
  });

  final String title;
  final String body;
  final String channelName;
  final String channelDescription;
}
