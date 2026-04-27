String formatDateTime(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String formatRelativePast(DateTime date, {DateTime? now}) {
  final reference = (now ?? DateTime.now()).toUtc();
  final elapsed = reference.difference(date.toUtc());
  if (elapsed.isNegative) {
    return 'agora';
  }
  if (elapsed.inDays >= 1) {
    return 'há ${elapsed.inDays} ${elapsed.inDays == 1 ? 'dia' : 'dias'}';
  }
  if (elapsed.inHours >= 1) {
    return 'há ${elapsed.inHours} ${elapsed.inHours == 1 ? 'hora' : 'horas'}';
  }
  if (elapsed.inMinutes >= 1) {
    return 'há ${elapsed.inMinutes} ${elapsed.inMinutes == 1 ? 'minuto' : 'minutos'}';
  }
  return 'agora';
}

String formatRemaining(DateTime future, {DateTime? now}) {
  final reference = (now ?? DateTime.now()).toUtc();
  final remaining = future.toUtc().difference(reference);
  if (remaining.isNegative || remaining.inSeconds == 0) {
    return 'expirado';
  }
  if (remaining.inDays >= 1) {
    return '${remaining.inDays} ${remaining.inDays == 1 ? 'dia' : 'dias'}';
  }
  if (remaining.inHours >= 1) {
    return '${remaining.inHours} ${remaining.inHours == 1 ? 'hora' : 'horas'}';
  }
  if (remaining.inMinutes >= 1) {
    return '${remaining.inMinutes} ${remaining.inMinutes == 1 ? 'minuto' : 'minutos'}';
  }
  return 'menos de 1 minuto';
}
