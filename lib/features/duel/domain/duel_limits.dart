/// Максимальный размер ответа в дуэли: JSON не больше 512 байт (CHECK
/// `duel_answers.answer`, 0007_duels.sql; для `mcq` с запасом хватает).
/// Клиент не отправляет больше (`isValidDuelAnswerPayload`, T23).
const kDuelAnswerMaxBytes = 512;
