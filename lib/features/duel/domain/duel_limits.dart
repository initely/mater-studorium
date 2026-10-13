/// Максимальный размер ответа в дуэли: JSON не больше 512 байт (CHECK
/// `duel_answers.answer`, 0007_duels.sql; для `mcq` с запасом хватает). T23
/// обязан укладываться и не отправлять больше.
const kDuelAnswerMaxBytes = 512;
