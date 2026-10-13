/// Время в миллисекундах как `м:сс`: «0:07», «1:05», «12:30». Больше часа —
/// `ч:мм:сс`. Отрицательное — как нуль.
String formatDuelTime(int milliseconds) {
  final total = (milliseconds < 0 ? 0 : milliseconds) ~/ 1000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}
