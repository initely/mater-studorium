# Вычитка колоды `infosec-basics` (v1)

Основы информационной безопасности (защита). Знаний: 20. Файл: `content/decks/infosec-basics.json`.

**Состояние (2026-10-14).** 19 знаний одобрены Telman (`approve_items`, все с вердиктом `ok`). `infosec.pw.slow-hash` исправлено без нового круга проверки (убран дублирующий пункт рубрики open, в flip и open добавлена причина про дешёвый перебор на GPU и арендованных серверах, цитата 2), статус `draft`: его осталось вычитать и одобрить. Таблица ниже отражает вердикты независимой проверки (круг 4), а не текущие статусы; команда в конце уже выполнена для 19 знаний.

Статусы в колоде: draft или needs_fix; `approved` ставит только человек командой в конце отчёта. Дословность цитат и код 200 страниц проверяет `tools/check_links.dart` (шаг 3), смысл — независимая сессия по `content/prompts/verify.md` (шаг 4).

| Проверка | Знаний |
|---|---|
| ok | 19 |
| needs_fix | 1 |

## Как вычитывать

1. Для каждого знания откройте страницу источника по ссылке и сверьте цитату и факт.
2. Проверьте вопросы: в `mcq` ровно один верный ответ, в `cloze` учтены естественные варианты, в `find_error` нет ошибок в строках, не помеченных ошибочными.
3. Отметьте чекбокс у знаний, которые одобряете. Правки вносите в колоду, а не в отчёт.
4. Выполните команду из раздела «Одобрение» (оставьте только отмеченные id).

## 1. Пароли хешируют, а не шифруют

- [ ] одобряю `infosec.pw.hash-not-encrypt`
- Вердикт независимой проверки: **✅ ok**; статус в колоде: `approved`

**Факт.** Пароли хранят в виде медленного хеша, а не шифруют: хеш — односторонняя функция, и восстановить по нему пароль нельзя, а шифрование двустороннее.

**Коротко.** Хеширование необратимо: восстановить пароль по хешу нельзя, и это самый подходящий способ проверки паролей. Шифрование двустороннее: из шифртекста можно получить открытый текст.

**Цитаты:**

> Because hashing is a one-way function (i.e., it is impossible to "decrypt" a hash and obtain the original plaintext value), it is the most appropriate approach for password validation.
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> Passwords should never be stored in plain text. Instead, they must be protected using strong, slow hashing algorithms such as Argon2id, bcrypt, or PBKDF2.
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> Since encryption is a two-way function, attackers can retrieve the original plaintext from the encrypted data.
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

**Вопросы:**

- `infosec.pw.hash-not-encrypt.q1` · **mcq** · Почему для хранения паролей, по которым пользователь входит в систему, выбирают хеширование, а не шифрование?
  - ✅ a) Хеш — односторонняя функция: исходный пароль по нему не восстановить
  - ▫ b) Хеш занимает меньше места, чем шифртекст
  - ▫ c) Шифрование не позволяет сравнить введённый пароль с сохранённым
  - ▫ d) Хеш нельзя вычислить без секретного ключа
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.pw.hash-not-encrypt.q2` · **flip** · Почему пароли хранят в виде хеша, а не шифртекста?
  - Оборот: Хеш — односторонняя функция: исходный пароль по нему не восстановить. Шифрование двустороннее, и из шифртекста можно получить открытый текст.
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

- `infosec.pw.hash-not-encrypt.q3` · **open** · Объясните, чем хеширование отличается от шифрования и почему для паролей входа выбирают хеширование.
  - Эталон: Хеширование — односторонняя функция: по хешу нельзя восстановить исходный пароль. Шифрование двустороннее: из шифртекста можно получить открытый текст.
  - Рубрика p1 (вес 3, обязательный): Хеш односторонний: пароль по нему не восстановить
  - Рубрика p2 (вес 2): Шифрование двустороннее: из шифртекста можно получить открытый текст
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`; замечания: Вторая часть prompt («почему для паролей входа выбирают хеширование») не отражена в reference_answer и rubric явно: нет вывода «поэтому хеширование — самый подходящий способ проверки паролей» из цитаты 1

**Заметки генерации (что проверить):** Замечание независимой проверки (раунд 4): q3: Вторая часть prompt («почему для паролей входа выбирают хеширование») не отражена в reference_answer и rubric явно: нет вывода «поэтому хеширование — самый подходящий способ проверки паролей» из цитаты 1

---

## 2. Соль при хешировании паролей

- [ ] одобряю `infosec.pw.salt`
- Вердикт независимой проверки: **✅ ok**; статус в колоде: `approved`

**Факт.** Соль — уникальная случайная строка, которую добавляют к каждому паролю при хешировании: она защищает от заранее посчитанных таблиц (rainbow tables), и, не взломав хеши, нельзя определить, что у двух пользователей одинаковые пароли.

**Коротко.** Соль защищает от rainbow tables и поиска по базам готовых хешей. Из-за разных солей одинаковые пароли дают разные хеши.

**Цитаты:**

> A salt is a unique, randomly generated string that is added to each password as part of the hashing process.
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> Salting also protects against an attacker's pre-computing hashes using rainbow tables or database-based lookups.
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> Finally, salting means that it is impossible to determine whether two users have the same password without cracking the hashes, as the different salts will result in different hashes even if the passwords are the same.
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

**Вопросы:**

- `infosec.pw.salt.q1` · **mcq** · От какой атаки защищает использование соли?
  - ✅ a) От использования заранее вычисленных таблиц хешей (rainbow tables)
  - ▫ b) От перехвата пароля при передаче по сети
  - ▫ c) От подбора пароля через форму входа
  - ▫ d) От кражи cookie сессии
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.pw.salt.q2` · **cloze** · Соль — это {{1}} случайная строка, которую добавляют к {{2}} паролю в процессе хеширования.
  - Пропуск {{1}}: `уникальная`, `индивидуальная`, `неповторяющаяся`, `своя`
  - Пропуск {{2}}: `каждому`, `любому`
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.pw.salt.q3` · **find_error** · Разработчик хеширует пароли при регистрации. Какая строка нарушает требование к соли?
  ```python
     1: def register(user, password):
  >> 2:     salt = SITE_SALT  # одна и та же соль для всех пользователей
     3:     digest = argon2id(password, salt)
     4:     db.save(user, salt, digest)
  ```
  - Строка 2: Соль должна быть уникальной для каждого пароля, а здесь одна и та же соль используется для всех пользователей.
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.pw.salt.q4` · **flip** · Почему у двух пользователей с одинаковым паролем хеши в базе должны различаться?
  - Оборот: К каждому паролю добавляют свою уникальную соль, поэтому разные соли дают разные хеши, даже если пароли одинаковы.
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

---

## 3. Быстрые хеши не подходят для паролей

- [ ] одобряю `infosec.pw.slow-hash`
- Вердикт независимой проверки: **⚠ needs_fix**; статус в колоде: `draft`

**Факт.** Для паролей нужны намеренно медленные алгоритмы (Argon2id, bcrypt, PBKDF2) с настраиваемой стоимостью, а не быстрые хеши вроде MD5 и SHA-1.

**Коротко.** Для паролей нужны сильные медленные алгоритмы, в отличие от MD5 и SHA-1, которые проектировали быстрыми; степень замедления настраивается. Перебор на GPU и арендованных серверах обходится атакующему относительно дёшево, особенно если не следовать лучшим практикам хеширования.

**Цитаты:**

> This means that they should be slow (unlike algorithms such as MD5 and SHA-1, which were designed to be fast), and you can change how slow they are by changing the work factor.
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> While the number of permutations can be enormous, with high speed hardware (such as GPUs) and cloud services with many servers for rent, the cost to an attacker is relatively small to do successful password cracking, especially when best practices for hashing are not followed.
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> Passwords should never be stored in plain text. Instead, they must be protected using strong, slow hashing algorithms such as Argon2id, bcrypt, or PBKDF2.
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

**Вопросы:**

- `infosec.pw.slow-hash.q1` · **mcq** · Чем алгоритмы хеширования паролей (Argon2id, bcrypt) принципиально отличаются от MD5 и SHA-1?
  - ✅ a) Они намеренно медленные, и степень замедления настраивается
  - ▫ b) Они обратимы, если известен ключ
  - ▫ c) Они выдают хеш переменной длины
  - ▫ d) Они шифруют пароль, а не хешируют
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.pw.slow-hash.q2` · **flip** · Почему для хранения паролей берут медленные алгоритмы, а не быстрые MD5 и SHA-1?
  - Оборот: Специальные алгоритмы хеширования паролей медленные по замыслу, а MD5 и SHA-1 проектировали быстрыми. Причина: при быстром хешировании перебор паролей на GPU и арендованных серверах обходится атакующему относительно дёшево.
  - Проверка: цитата подтверждает ответ — `partial`; вторая верная — `n/a`; однозначно — `yes`; замечания: back по-прежнему не связывает медленность алгоритма с ростом стоимости перебора для атакующего: обе фразы верны по цитатам, но ответ на «почему» остаётся выводом читателя

- `infosec.pw.slow-hash.q3` · **open** · Почему для хранения паролей нужны медленные алгоритмы и что такое work factor?
  - Эталон: Пароли защищают сильными медленными алгоритмами вроде Argon2id, bcrypt, PBKDF2, в отличие от MD5 и SHA-1, которые проектировали быстрыми. Причина: на GPU и арендованных серверах перебор паролей обходится атакующему относительно дёшево. Степень замедления настраивают коэффициентом стоимости (work factor).
  - Рубрика p1 (вес 3, обязательный): MD5 и SHA-1 проектировали быстрыми, а для паролей нужны намеренно медленные алгоритмы (Argon2id, bcrypt, PBKDF2)
  - Рубрика p2 (вес 2): Причина: перебор на GPU и арендованных серверах обходится атакующему относительно дёшево
  - Рубрика p3 (вес 2): Замедление настраивается коэффициентом стоимости (work factor)
  - Проверка: цитата подтверждает ответ — `partial`; вторая верная — `n/a`; однозначно — `yes`; замечания: Пункты rubric p1 и p2 по-прежнему дублируют друг друга (оба про намеренно медленные алгоритмы): одна мысль засчитывается дважды / prompt спрашивает «почему», но ни reference_answer, ни rubric не содержат причины (дешёвый перебор на GPU и арендованных серверах из цитаты 2)

**Заметки генерации (что проверить):** Правка без нового круга проверки: убран дублирующий пункт рубрики open, в flip и open добавлена причина (дешёвый перебор на GPU и арендованных серверах, цитата 2). Круг 4 проверки отмечал: q2: back по-прежнему не связывает медленность алгоритма с ростом стоимости перебора для атакующего: обе фразы верны по цитатам, но ответ на «почему» остаётся выводом читателя | q3: Пункты rubric p1 и p2 по-прежнему дублируют друг друга (оба про намеренно медленные алгоритмы): одна мысль засчитывается дважды | q3: prompt спрашивает «почему», но ни reference_answer, ни rubric не содержат причины (дешёвый перебор на GPU и арендованных серверах из цитаты 2)

---

## 4. Argon2id как первый выбор

- [ ] одобряю `infosec.pw.argon2id`
- Вердикт независимой проверки: **✅ ok**; статус в колоде: `approved`

**Факт.** OWASP считает Argon2id лучшим выбором; Argon2 — победитель конкурса Password Hashing Competition 2015; scrypt применяют, если Argon2id недоступен.

**Коротко.** Argon2id даёт сбалансированную защиту от атак по побочным каналам и перебора на GPU. Если его нет, берут scrypt.

**Цитаты:**

> Argon2 was the winner of the 2015 Password Hashing Competition.
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> Out of the three Argon2 versions, use the Argon2id variant since it provides a balanced approach to resisting both side-channel and GPU-based attacks.
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> While Argon2id should be the best choice for password hashing, scrypt should be used when the former is not available.
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

**Вопросы:**

- `infosec.pw.argon2id.q1` · **mcq** · Какой алгоритм хеширования паролей OWASP рекомендует как лучший выбор для нового приложения?
  - ✅ a) Argon2id
  - ▫ b) bcrypt
  - ▫ c) PBKDF2 с HMAC-SHA-1
  - ▫ d) SHA-256 с солью
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`; замечания: В prompt уточнение «для нового приложения», которого в цитатах нет (мелочь)

- `infosec.pw.argon2id.q2` · **cloze** · Победителем конкурса Password Hashing Competition 2015 года стал алгоритм {{1}}.
  - Пропуск {{1}}: `Argon2`
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.pw.argon2id.q3` · **flip** · Что OWASP рекомендует использовать, если Argon2id недоступен?
  - Оборот: scrypt.
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

**Заметки генерации (что проверить):** Проверить актуальность рекомендаций OWASP на дату вычитки; PBKDF2 остаётся вариантом, когда нужна совместимость с FIPS-140 (в вопросах не используется). Замечание независимой проверки (раунд 4): q1: В prompt уточнение «для нового приложения», которого в цитатах нет (мелочь)

---

## 5. Pepper: секрет вне базы данных

- [ ] одобряю `infosec.pw.pepper`
- Вердикт независимой проверки: **✅ ok**; статус в колоде: `approved`

**Факт.** Pepper общий для хранимых паролей (в отличие от уникальной для каждого пароля соли) и должен храниться отдельно от базы паролей.

**Коротко.** Pepper общий для хранимых паролей и лежит отдельно от базы. Сменить pepper можно, лишь заставив всех пользователей, чьи пароли он защищал, сбросить пароли.

**Цитаты:**

> A pepper is shared between stored passwords, rather than being unique to an individual password like a password salt.
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> The pepper should be stored separately from the password database.
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> Therefore changing a pepper will require forcing all users whose passwords were protected by the previous pepper to reset their passwords.
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

**Вопросы:**

- `infosec.pw.pepper.q1` · **mcq** · Чем pepper отличается от соли?
  - ✅ a) Pepper общий для хранимых паролей и хранится отдельно от базы; соль уникальна для каждого пароля
  - ▫ b) Pepper уникален для каждого пользователя и хранится рядом с хешем
  - ▫ c) Pepper заменяет медленный алгоритм хеширования
  - ▫ d) Pepper публикуют, чтобы клиент мог проверить хеш
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.pw.pepper.q2` · **open** · Чем pepper отличается от соли, где его хранить и что потребуется, чтобы его сменить?
  - Эталон: Pepper общий для хранимых паролей, а не уникальный для каждого, как соль. Его хранят отдельно от базы паролей. Чтобы сменить pepper, всем пользователям, чьи пароли он защищал, придётся сбросить пароли.
  - Рубрика p1 (вес 3, обязательный): Pepper общий для хранимых паролей, а не уникальный для каждого пароля, как соль
  - Рубрика p2 (вес 2, обязательный): Хранится отдельно от базы с паролями
  - Рубрика p3 (вес 2): Для смены pepper пользователям нужно сбросить пароли
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

- `infosec.pw.pepper.q3` · **flip** · Что потребуется от пользователей, если сменить pepper?
  - Оборот: Всем пользователям, чьи пароли защищал прежний pepper, придётся сбросить пароли.
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

---

## 6. Коэффициент стоимости (work factor)

- [ ] одобряю `infosec.pw.work-factor`
- Вердикт независимой проверки: **✅ ok**; статус в колоде: `approved`

**Факт.** Work factor — число итераций хеширования для каждого пароля (обычно 2^work); вычисление хеша должно занимать менее секунды, а коэффициент чаще всего повышают при следующем входе пользователя.

**Коротко.** Вычисление хеша должно занимать менее секунды. Коэффициент повышают так: когда пользователь в очередной раз входит, его пароль хешируют заново с новым коэффициентом.

**Цитаты:**

> The work factor is the number of iterations of the hashing algorithm that are performed for each password (usually, it's actually 2^work iterations).
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> As a general rule, calculating a hash should take less than one second.
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> The most common approach to upgrading the work factor is to wait until the user next authenticates, then re-hash their password with the new work factor.
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

**Вопросы:**

- `infosec.pw.work-factor.q1` · **mcq** · Когда чаще всего пересчитывают хеш пароля с новым, более высоким work factor?
  - ✅ a) Когда пользователь в очередной раз входит и подтверждает пароль
  - ▫ b) В фоне, прямо по хешам в базе, без участия пользователей
  - ▫ c) Только при смене пароля по инициативе пользователя
  - ▫ d) При каждом запросе к API
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.pw.work-factor.q2` · **cloze** · Как общее правило, вычисление хеша пароля должно занимать менее {{1}} секунды.
  - Пропуск {{1}}: `1`, `одной`
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.pw.work-factor.q3` · **open** · Что такое work factor и как его повысить для уже сохранённых паролей?
  - Эталон: Work factor — число итераций хеширования для каждого пароля (обычно 2^work). Чаще всего его повышают так: ждут следующего входа пользователя и пересчитывают хеш с новым коэффициентом.
  - Рубрика p1 (вес 3, обязательный): Work factor — число итераций хеширования для каждого пароля
  - Рубрика p2 (вес 3, обязательный): Хеш пересчитывают с новым коэффициентом, когда пользователь в очередной раз входит
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

**Заметки генерации (что проверить):** Проверить cloze: accepted «1», «одной».

---

## 7. bcrypt: ограничение в 72 байта

- [ ] одобряю `infosec.pw.bcrypt-limit`
- Вердикт независимой проверки: **✅ ok**; статус в колоде: `approved`

**Факт.** У большинства реализаций bcrypt максимальная длина входа — 72 байта, поэтому максимальную длину пароля ограничивают 72 байтами (или меньше, если лимит реализации ниже), а не обрезают молча.

**Коротко.** У большинства реализаций bcrypt максимум входа — 72 байта, поэтому длину пароля ограничивают явно; молча обрезать пароли не нужно.

**Цитаты:**

> bcrypt has a maximum length input length of 72 bytes for most implementations, so you should enforce a maximum password length of 72 bytes (or less if the bcrypt implementation in use has smaller limits).
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> The bcrypt password hashing function should only be used for password storage in legacy systems where Argon2 and scrypt are not available. The work factor should be as large as verification server performance will allow, with a minimum of 10.
>
> — [OWASP Cheat Sheet Series: Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> Do not silently truncate passwords.
>
> — [OWASP Cheat Sheet Series: Authentication](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html), CC BY-SA 4.0

**Вопросы:**

- `infosec.pw.bcrypt-limit.q1` · **cloze** · Для большинства реализаций bcrypt максимальная длина входа составляет {{1}} байта.
  - Пропуск {{1}}: `72`, `семьдесят два`
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.pw.bcrypt-limit.q2` · **mcq** · Как правильно поступить с ограничением bcrypt на длину пароля?
  - ✅ a) Явно ограничить максимальную длину пароля 72 байтами
  - ▫ b) Не ограничивать длину: у bcrypt нет предела длины входа
  - ▫ c) Молча обрезать пароль до 72 байт
  - ▫ d) Увеличить work factor до 72
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.pw.bcrypt-limit.q3` · **flip** · Какой минимум work factor рекомендует OWASP для bcrypt?
  - Оборот: 10: work factor bcrypt берут как можно больше, насколько позволяет производительность сервера, но не меньше 10.
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

---

## 8. Многофакторная аутентификация

- [ ] одобряю `infosec.auth.mfa`
- Вердикт независимой проверки: **✅ ok**; статус в колоде: `approved`

**Факт.** Многофакторная аутентификация (MFA) требует подтверждения как минимум из двух разных факторов: что-то знаю, что-то имею, что-то собой представляю (я); несколько экземпляров одного фактора (пароль и PIN) MFA не дают.

**Коротко.** Пароль и PIN — оба «знаю», это не MFA. Пароль плюс токен OTP — два разных фактора.

**Цитаты:**

> Multifactor Authentication (MFA) requires evidence from at least two distinct authentication factors: something you know, something you have, and something you are.
>
> — [OWASP Cheat Sheet Series: Multifactor Authentication](https://cheatsheetseries.owasp.org/cheatsheets/Multifactor_Authentication_Cheat_Sheet.html), CC BY-SA 4.0

> It should be noted that requiring multiple instances of the same authentication factor (such as needing both a password and a PIN) does not constitute MFA and offers minimal additional security.
>
> — [OWASP Cheat Sheet Series: Multifactor Authentication](https://cheatsheetseries.owasp.org/cheatsheets/Multifactor_Authentication_Cheat_Sheet.html), CC BY-SA 4.0

> Something You Know Passwords and PINs Something You Have OTP Tokens, U2F Tokens, Certificates, Smart Cards, SMS and Phone Calls (restricted) Something You Are Fingerprints, Facial Recognition, Iris Scans, Behavioral Biometrics
>
> — [OWASP Cheat Sheet Series: Multifactor Authentication](https://cheatsheetseries.owasp.org/cheatsheets/Multifactor_Authentication_Cheat_Sheet.html), CC BY-SA 4.0

**Вопросы:**

- `infosec.auth.mfa.q1` · **mcq** · Какая комбинация даёт настоящую многофакторную аутентификацию?
  - ✅ a) Пароль и токен OTP
  - ▫ b) Пароль и PIN-код
  - ▫ c) Два разных пароля
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.auth.mfa.q2` · **flip** · Назовите три категории факторов аутентификации.
  - Оборот: Что-то знаю (пароли и PIN), что-то имею (токены OTP, U2F, смарт-карты) и что-то собой представляю (отпечатки пальцев, лицо, радужка).
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

- `infosec.auth.mfa.q3` · **open** · Почему пароль и PIN вместе не считаются многофакторной аутентификацией?
  - Эталон: Оба относятся к одному фактору «знание» (пароли и PIN). MFA требует не менее двух разных факторов, а несколько экземпляров одного фактора дают лишь минимальное усиление защиты.
  - Рубрика p1 (вес 3, обязательный): Пароль и PIN относятся к одному фактору (знание)
  - Рубрика p2 (вес 2): MFA требует как минимум двух разных факторов
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

---

## 9. TOTP: одноразовые коды по времени

- [ ] одобряю `infosec.auth.totp`
- Вердикт независимой проверки: **✅ ok**; статус в колоде: `approved`

**Факт.** TOTP (RFC 6238) — вариант одноразового пароля, где изменяющийся фактор — время, а не счётчик событий, как в HOTP; рекомендуемый шаг по умолчанию — 30 секунд.

**Коротко.** Короткоживущие значения одноразового пароля желательны для безопасности. В TOTP изменяющийся фактор — время, шаг по умолчанию — 30 секунд.

**Цитаты:**

> A time-based variant of the OTP algorithm provides short-lived OTP values, which are desirable for enhanced security.
>
> — [RFC 6238: TOTP: Time-Based One-Time Password Algorithm](https://www.rfc-editor.org/rfc/rfc6238.html), IETF Trust Legal Provisions (BCP 78)

> The HOTP algorithm specifies an event-based OTP algorithm, where the moving factor is an event counter. The present work bases the moving factor on a time value.
>
> — [RFC 6238: TOTP: Time-Based One-Time Password Algorithm](https://www.rfc-editor.org/rfc/rfc6238.html), IETF Trust Legal Provisions (BCP 78)

> We RECOMMEND a default time-step size of 30 seconds.
>
> — [RFC 6238: TOTP: Time-Based One-Time Password Algorithm](https://www.rfc-editor.org/rfc/rfc6238.html), IETF Trust Legal Provisions (BCP 78)

**Вопросы:**

- `infosec.auth.totp.q1` · **mcq** · Чем TOTP отличается от HOTP?
  - ✅ a) В TOTP изменяющийся фактор — время, в HOTP — счётчик событий
  - ▫ b) В TOTP код не зависит от общего секрета
  - ▫ c) В HOTP код действует только 30 секунд
  - ▫ d) TOTP передаёт код по SMS, HOTP — по e-mail
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.auth.totp.q2` · **cloze** · Рекомендуемый по умолчанию шаг времени в TOTP — {{1}} секунд.
  - Пропуск {{1}}: `30`, `тридцать`
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.auth.totp.q3` · **flip** · Что в TOTP служит изменяющимся фактором вместо счётчика событий из HOTP?
  - Оборот: Значение времени.
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

**Заметки генерации (что проверить):** Проверить, что вопросы не выходят за цитаты.

---

## 10. Одинаковые сообщения об ошибках входа

- [ ] одобряю `infosec.auth.generic-errors`
- Вердикт независимой проверки: **✅ ok**; статус в колоде: `approved`

**Факт.** Вход, сброс и восстановление пароля должны отвечать одним общим сообщением независимо от того, неверен ли логин или пароль, есть ли такая учётная запись и заблокирована ли она — иначе атакующий узнает, какие учётные записи существуют.

**Коротко.** Разные сообщения («пользователя нет», «неверный пароль») создают расхождение, по которому можно перебирать имена и узнавать существующие аккаунты. Общее сообщение лишает атакующего этого признака.

**Цитаты:**

> Using any of the authentication mechanisms (login, password reset, or password recovery), an application must respond with a generic error message regardless of whether: The user ID or password was incorrect. The account does not exist. The account is locked or disabled.
>
> — [OWASP Cheat Sheet Series: Authentication](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html), CC BY-SA 4.0

> The objective is to prevent the creation of a discrepancy factor, allowing an attacker to mount a user enumeration action against the application.
>
> — [OWASP Cheat Sheet Series: Authentication](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html), CC BY-SA 4.0

**Вопросы:**

- `infosec.auth.generic-errors.q1` · **mcq** · Какое сообщение безопасно показывать при неудачном входе?
  - ✅ a) Неверный логин или пароль
  - ▫ b) Пользователь с таким логином не найден
  - ▫ c) Пароль неверен, осталось 2 попытки до блокировки учётной записи
  - ▫ d) Учётная запись заблокирована
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.auth.generic-errors.q2` · **flip** · Какую атаку предотвращает единое сообщение об ошибке на входе?
  - Оборот: Перебор существующих пользователей (user enumeration): по разным сообщениям атакующий отличал бы существующие аккаунты от несуществующих.
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

- `infosec.auth.generic-errors.q3` · **open** · Почему вход, сброс и восстановление пароля должны отвечать одинаковым сообщением в любой ситуации?
  - Эталон: Если сообщения различаются (нет аккаунта, неверный пароль, аккаунт заблокирован), атакующий по разнице узнаёт, какие учётные записи существуют, и может перебирать пользователей. Общее сообщение убирает это расхождение.
  - Рубрика p1 (вес 3, обязательный): Разные сообщения раскрывают, существует ли учётная запись
  - Рубрика p2 (вес 2): Атакующий может использовать это для перебора пользователей (user enumeration)
  - Рубрика p3 (вес 1): Общее сообщение применяется ко входу, сбросу и восстановлению пароля
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

---

## 11. Симметричная и асимметричная криптография

- [ ] одобряю `infosec.crypto.sym-vs-asym`
- Вердикт независимой проверки: **✅ ok**; статус в колоде: `approved`

**Факт.** В симметричной криптографии один и тот же ключ служит и для шифрования, и для расшифровки; в асимметричной используются пары ключей — открытый и закрытый, и безопасность держится на секретности закрытого ключа.

**Коротко.** В асимметричной схеме открытый ключ можно свободно раздавать, а закрытый нужно хранить в тайне.

**Цитаты:**

> are algorithms for cryptography that use the same cryptographic keys for both the encryption of plaintext and the decryption of ciphertext.
>
> — [Wikipedia: Symmetric-key algorithm](https://en.wikipedia.org/wiki/Symmetric-key_algorithm), CC BY-SA 4.0

> Each key pair consists of a public key and a corresponding private key.
>
> — [Wikipedia: Public-key cryptography](https://en.wikipedia.org/wiki/Public-key_cryptography), CC BY-SA 4.0

> Security of public-key cryptography depends on keeping the private key secret; the public key can be openly distributed without compromising security.
>
> — [Wikipedia: Public-key cryptography](https://en.wikipedia.org/wiki/Public-key_cryptography), CC BY-SA 4.0

**Вопросы:**

- `infosec.crypto.sym-vs-asym.q1` · **mcq** · Что верно для асимметричной криптографии?
  - ✅ a) Открытый ключ можно свободно распространять, а закрытый нужно хранить в тайне
  - ▫ b) Для шифрования и расшифровки используется один и тот же ключ
  - ▫ c) Закрытый ключ публикуют, открытый хранят в тайне
  - ▫ d) Пара ключей не нужна: достаточно общего пароля
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.crypto.sym-vs-asym.q2` · **cloze** · В {{1}} криптографии для шифрования и расшифровки используется один и тот же ключ.
  - Пропуск {{1}}: `симметричной`
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.crypto.sym-vs-asym.q3` · **flip** · Какой из ключей пары в асимметричной схеме можно свободно распространять, а какой нужно хранить в секрете?
  - Оборот: Открытый ключ можно свободно распространять, закрытый нужно хранить в секрете: безопасность зависит от его сохранности.
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

- `infosec.crypto.sym-vs-asym.q4` · **open** · Сравните симметричное и асимметричное шифрование по ключам.
  - Эталон: В симметричном шифровании один и тот же ключ для шифрования и расшифровки. В асимметричном — пара ключей: открытый можно распространять, закрытый должен оставаться секретным.
  - Рубрика p1 (вес 3, обязательный): Симметричное: один и тот же ключ для шифрования и расшифровки
  - Рубрика p2 (вес 2, обязательный): Асимметричное: пара ключей, открытый и закрытый
  - Рубрика p3 (вес 2): Открытый ключ можно раздавать свободно, закрытый хранят в секрете
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

---

## 12. Гибридные криптосистемы

- [ ] одобряю `infosec.crypto.hybrid`
- Вердикт независимой проверки: **✅ ok**; статус в колоде: `approved`

**Факт.** Гибридные схемы сочетают удобство асимметричного шифрования (не нужен заранее общий секрет) и скорость симметричного: данные шифруют симметричным алгоритмом, а асимметричный служит только для передачи короткого ключа.

**Коротко.** Асимметричное шифрование не требует общего секрета, но неэффективно для длинных сообщений. Гибрид берёт лучшее от обоих.

**Цитаты:**

> Public-key cryptosystems are convenient in that they do not require the sender and receiver to share a common secret in order to communicate securely.
>
> — [Wikipedia: Hybrid cryptosystem](https://en.wikipedia.org/wiki/Hybrid_cryptosystem), CC BY-SA 4.0

> However, they often rely on complicated mathematical computations and are thus generally much more inefficient than comparable symmetric-key cryptosystems.
>
> — [Wikipedia: Hybrid cryptosystem](https://en.wikipedia.org/wiki/Hybrid_cryptosystem), CC BY-SA 4.0

> Note that for very long messages the bulk of the work in encryption/decryption is done by the more efficient symmetric-key scheme, while the inefficient public-key scheme is used only to encrypt/decrypt a short key value.
>
> — [Wikipedia: Hybrid cryptosystem](https://en.wikipedia.org/wiki/Hybrid_cryptosystem), CC BY-SA 4.0

**Вопросы:**

- `infosec.crypto.hybrid.q1` · **mcq** · Зачем на практике сочетают симметричное и асимметричное шифрование?
  - ✅ a) Асимметричное удобно без общего секрета, но неэффективно для больших данных; основную работу делает симметричное
  - ▫ b) Симметричное шифрование безопаснее асимметричного, поэтому асимметричное почти не нужно
  - ▫ c) Асимметричное шифрование быстрее, поэтому им шифруют сами данные
  - ▫ d) Так требует стандарт, технических причин нет
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.crypto.hybrid.q2` · **flip** · Для чего в гибридной схеме используется асимметричный алгоритм?
  - Оборот: Для шифрования или расшифровки короткого значения ключа; сами данные шифрует симметричный алгоритм.
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

- `infosec.crypto.hybrid.q3` · **open** · Объясните, почему длинные сообщения не шифруют напрямую асимметричным алгоритмом, и как устроена гибридная схема.
  - Эталон: Асимметричное шифрование опирается на сложные вычисления и значительно менее эффективно симметричного, поэтому большие данные дорого шифровать им напрямую. В гибридной схеме данные шифрует симметричный алгоритм, а асимметричный применяется лишь для короткого ключа.
  - Рубрика p1 (вес 3, обязательный): Асимметричное шифрование значительно менее эффективно симметричного
  - Рубрика p2 (вес 2, обязательный): Данные шифруются симметричным алгоритмом
  - Рубрика p3 (вес 2): Асимметричный алгоритм защищает только короткий ключ
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

**Заметки генерации (что проверить):** Проверить, что в q1 нет второго верного ответа (вариант b ложен по цитате).

---

## 13. Цифровая подпись

- [ ] одобряю `infosec.crypto.digital-signature`
- Вердикт независимой проверки: **✅ ok**; статус в колоде: `approved`

**Факт.** Цифровая подпись вычисляется из сообщения и закрытого ключа отправителя, а проверяется его открытым ключом; валидная подпись подтверждает, что сообщение пришло от отправителя, известного получателю.

**Коротко.** Подпись вычисляют из сообщения и закрытого ключа отправителя, а проверяют открытым ключом отправителя. Валидная подпись подтверждает, что сообщение пришло от отправителя, известного получателю.

**Цитаты:**

> A digital signature is a mathematical scheme for verifying the authenticity of digital messages or documents.
>
> — [Wikipedia: Digital signature](https://en.wikipedia.org/wiki/Digital_signature), CC BY-SA 4.0

> A valid digital signature on a message gives any recipient confidence that the message came from a sender known to the recipient.
>
> — [Wikipedia: Digital signature](https://en.wikipedia.org/wiki/Digital_signature), CC BY-SA 4.0

> Alice signs a message—"Hello Bob!"—by appending a signature which is computed from the message and her private key. Bob receives both the message and signature. He uses Alice's public key to verify the authenticity of the signed message.
>
> — [Wikipedia: Digital signature](https://en.wikipedia.org/wiki/Digital_signature), CC BY-SA 4.0

**Вопросы:**

- `infosec.crypto.digital-signature.q1` · **mcq** · Каким ключом отправитель подписывает сообщение и каким получатель проверяет подпись?
  - ✅ a) Подписывает своим закрытым ключом, проверяют его открытым ключом
  - ▫ b) Подписывает открытым ключом получателя, проверяют закрытым ключом получателя
  - ▫ c) Подписывает и проверяют одним общим секретным ключом
  - ▫ d) Подписывает открытым ключом отправителя, проверяют закрытым ключом отправителя
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.crypto.digital-signature.q2` · **cloze** · Цифровая подпись вычисляется из сообщения и {{1}} ключа отправителя.
  - Пропуск {{1}}: `закрытого`, `приватного`, `секретного`, `личного`
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.crypto.digital-signature.q3` · **open** · Опишите, как Алиса подписывает сообщение для Боба и как Боб проверяет подпись. Что подтверждает подпись?
  - Эталон: Алиса вычисляет подпись из сообщения и своего закрытого ключа и отправляет её вместе с сообщением. Боб проверяет подпись открытым ключом Алисы. Валидная подпись подтверждает подлинность: сообщение пришло от известного отправителя.
  - Рубрика p1 (вес 3, обязательный): Подпись вычисляется из сообщения и закрытого ключа отправителя
  - Рубрика p2 (вес 2, обязательный): Проверка выполняется открытым ключом отправителя
  - Рубрика p3 (вес 1): Валидная подпись подтверждает подлинность отправителя сообщения
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

---

## 14. Обмен ключами Диффи — Хеллмана

- [ ] одобряю `infosec.crypto.diffie-hellman`
- Вердикт независимой проверки: **✅ ok**; статус в колоде: `approved`

**Факт.** Диффи — Хеллман — математический метод, позволяющий двум сторонам, не знающим друг друга, выработать общий симметричный ключ по открытому каналу без заранее переданного секрета.

**Коротко.** DH позволяет сторонам договориться об общем секретном ключе по небезопасному каналу, а затем шифровать симметричным шифром.

**Цитаты:**

> is a mathematical method of securely generating a symmetric cryptographic key over a public channel.
>
> — [Wikipedia: Diffie–Hellman key exchange](https://en.wikipedia.org/wiki/Diffie%E2%80%93Hellman_key_exchange), CC BY-SA 4.0

> the Diffie–Hellman key exchange method allows two parties that have no prior knowledge of each other to jointly establish a shared secret key over an insecure channel.
>
> — [Wikipedia: Diffie–Hellman key exchange](https://en.wikipedia.org/wiki/Diffie%E2%80%93Hellman_key_exchange), CC BY-SA 4.0

> This key can then be used to encrypt subsequent communications using a symmetric-key cipher.
>
> — [Wikipedia: Diffie–Hellman key exchange](https://en.wikipedia.org/wiki/Diffie%E2%80%93Hellman_key_exchange), CC BY-SA 4.0

**Вопросы:**

- `infosec.crypto.diffie-hellman.q1` · **mcq** · Что решает обмен ключами Диффи — Хеллмана?
  - ✅ a) Позволяет двум сторонам выработать общий секретный ключ по небезопасному каналу без заранее переданного секрета
  - ▫ b) Подписывает сообщения закрытым ключом
  - ▫ c) Хеширует пароли с солью
  - ▫ d) Шифрует большие файлы напрямую открытым ключом
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.crypto.diffie-hellman.q2` · **flip** · Что получают стороны в результате обмена Диффи — Хеллмана и как используют результат?
  - Оборот: Общий секретный (симметричный) ключ; им затем шифруют дальнейшую связь симметричным шифром.
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

- `infosec.crypto.diffie-hellman.q3` · **cloze** · Метод Диффи — Хеллмана позволяет двум сторонам выработать общий {{1}} ключ по {{2}} каналу связи.
  - Пропуск {{1}}: `секретный`, `симметричный`
  - Пропуск {{2}}: `небезопасному`, `незащищённому`, `незащищенному`, `открытому`, `публичному`
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

---

## 15. Принцип Кирхгофа

- [ ] одобряю `infosec.crypto.kerckhoffs`
- Вердикт независимой проверки: **✅ ok**; статус в колоде: `approved`

**Факт.** Криптосистема должна оставаться безопасной, даже если всё о ней, кроме ключа, публично известно.

**Коротко.** Стойкость должна определяться секретностью ключа, а не скрытностью устройства системы.

**Цитаты:**

> The principle holds that a cryptosystem should be secure, even if everything about the system, except the key, is public knowledge.
>
> — [Wikipedia: Kerckhoffs's principle](https://en.wikipedia.org/wiki/Kerckhoffs%27s_principle), CC BY-SA 4.0

> This concept is widely embraced by cryptographers, in contrast to security through obscurity, which is not.
>
> — [Wikipedia: Kerckhoffs's principle](https://en.wikipedia.org/wiki/Kerckhoffs%27s_principle), CC BY-SA 4.0

**Вопросы:**

- `infosec.crypto.kerckhoffs.q1` · **mcq** · Что утверждает принцип Кирхгофа?
  - ✅ a) Система должна быть безопасной, даже если всё о ней, кроме ключа, общеизвестно
  - ▫ b) Алгоритм шифрования нужно держать в секрете, чтобы атакующий не мог его изучить
  - ▫ c) Чем сложнее и закрытее алгоритм, тем он надёжнее
  - ▫ d) Длина ключа не имеет значения, если алгоритм секретный
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.crypto.kerckhoffs.q2` · **flip** · Как криптографы относятся к принципу Кирхгофа и к «безопасности через неясность»?
  - Оборот: Принцип широко поддерживается криптографами, в отличие от безопасности через неясность (security through obscurity).
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

- `infosec.crypto.kerckhoffs.q3` · **open** · Сформулируйте принцип Кирхгофа.
  - Эталон: Криптосистема должна быть безопасной, даже если всё о ней, кроме ключа, является общеизвестным.
  - Рубрика p1 (вес 3, обязательный): Система безопасна, даже если всё, кроме ключа, публично
  - Рубрика p2 (вес 1): Принцип противопоставляют «безопасности через неясность» (security through obscurity)
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`; замечания: rubric p2 (противопоставление «безопасности через неясность») по-прежнему не следует из prompt «Сформулируйте принцип Кирхгофа» и отсутствует в reference_answer

**Заметки генерации (что проверить):** Проверить rubric p2: перифраз той же формулировки. Замечание независимой проверки (раунд 4): q3: rubric p2 (противопоставление «безопасности через неясность») по-прежнему не следует из prompt «Сформулируйте принцип Кирхгофа» и отсутствует в reference_answer

---

## 16. Аутентифицированное шифрование и режим ECB

- [ ] одобряю `infosec.crypto.authenticated-encryption`
- Вердикт независимой проверки: **✅ ok**; статус в колоде: `approved`

**Факт.** Для шифрования данных используют AES (ключ не короче 128 бит, лучше 256) в аутентифицированном режиме, прежде всего GCM или CCM; режим ECB почти никогда не подходит.

**Коротко.** Аутентифицированные режимы дают не только конфиденциальность, но и целостность и подлинность данных. GCM и CCM — первый выбор; ECB использовать нельзя вне очень специфических случаев.

**Цитаты:**

> For symmetric encryption AES with a key that's at least 128 bits (ideally 256 bits) and a secure mode should be used as the preferred algorithm.
>
> — [OWASP Cheat Sheet Series: Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> Where available, authenticated modes should always be used. These provide guarantees of the integrity and authenticity of the data, as well as confidentiality. The most commonly used authenticated modes are GCM and CCM, which should be used as a first preference.
>
> — [OWASP Cheat Sheet Series: Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> ECB should not be used outside of very specific circumstances.
>
> — [OWASP Cheat Sheet Series: Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html), CC BY-SA 4.0

**Вопросы:**

- `infosec.crypto.authenticated-encryption.q1` · **mcq** · Какой вариант OWASP считает предпочтительным для шифрования данных?
  - ✅ a) AES в режиме GCM
  - ▫ b) AES в режиме ECB
  - ▫ c) Собственный шифр на основе XOR
  - ▫ d) RSA без дополнения (padding)
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.crypto.authenticated-encryption.q2` · **find_error** · Разработчик шифрует данные AES. Какая строка содержит ошибку выбора режима?
  ```java
     1: SecretKey key = loadAesKey();
  >> 2: Cipher c = Cipher.getInstance("AES/ECB/PKCS5Padding");
     3: c.init(Cipher.ENCRYPT_MODE, key);
     4: byte[] out = c.doFinal(data);
  ```
  - Строка 2: Режим ECB не следует использовать вне очень специфических случаев. Нужен аутентифицированный режим, например AES/GCM/NoPadding.
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.crypto.authenticated-encryption.q3` · **cloze** · Наиболее часто используемые аутентифицированные режимы — GCM и {{1}}.
  - Пропуск {{1}}: `CCM`
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.crypto.authenticated-encryption.q4` · **flip** · Что дают аутентифицированные режимы шифрования, кроме конфиденциальности?
  - Оборот: Гарантии целостности и подлинности (аутентичности) данных.
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

**Заметки генерации (что проверить):** find_error: в строке 1 ключ загружается (ошибки нет), проверить, что строки 3 и 4 тоже без замечаний; cloze: один пропуск, CCM.

---

## 17. Хранение и защита ключей

- [ ] одобряю `infosec.crypto.key-storage`
- Вердикт независимой проверки: **✅ ok**; статус в колоде: `approved`

**Факт.** Ключи шифрования нельзя зашивать в исходный код и коммитить в систему контроля версий; хранят в системном или облачном хранилище ключей (KMS, HSM) и заранее готовят процесс ротации.

**Коротко.** Ключи нельзя зашивать в исходный код и коммитить в систему контроля версий. Используют механизмы безопасного хранения: HSM, хранилища ключей и секретов.

**Цитаты:**

> Do not hard-code keys into the application source code. Do not check keys into version control systems.
>
> — [OWASP Cheat Sheet Series: Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> Where available, the secure storage mechanisms provided by the operating system, framework or cloud service provider should be used. These include: A physical Hardware Security Module (HSM). A virtual HSM. Key vaults such as Amazon KMS or Azure Key Vault.
>
> — [OWASP Cheat Sheet Series: Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> It is important that the code and processes required to rotate a key are in place before they are required, so that keys can be quickly rotated in the event of a compromise.
>
> — [OWASP Cheat Sheet Series: Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html), CC BY-SA 4.0

**Вопросы:**

- `infosec.crypto.key-storage.q1` · **mcq** · Где правильнее всего хранить ключ шифрования приложения?
  - ✅ a) В хранилище ключей или секретов (KMS, HSM)
  - ▫ b) В константе в исходном коде
  - ▫ c) В файле конфигурации, закоммиченном в репозиторий
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.crypto.key-storage.q2` · **find_error** · Какая строка нарушает правила хранения ключей?
  ```python
     1: from crypto_lib import aes_gcm_encrypt, load_key_from_kms
  >> 2: AES_KEY = bytes.fromhex("00112233445566778899aabbccddeeff")
     3: def protect(data):
     4:     return aes_gcm_encrypt(AES_KEY, data)
  ```
  - Строка 2: Ключ зашит в исходный код (и попадёт в систему контроля версий). Его нужно загружать из хранилища ключей, например load_key_from_kms.
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.crypto.key-storage.q3` · **open** · Что нельзя делать с ключами шифрования и как их следует хранить?
  - Эталон: Ключи нельзя зашивать в исходный код и коммитить в систему контроля версий. Их по возможности хранят в механизмах безопасного хранения ОС, фреймворка или облачного провайдера (например, KMS или HSM), а процесс ротации готовят заранее.
  - Рубрика p1 (вес 3, обязательный): Ключи нельзя зашивать в исходный код и коммитить в систему контроля версий
  - Рубрика p2 (вес 2, обязательный): Ключи хранят в механизмах безопасного хранения (HSM, хранилище ключей вроде KMS)
  - Рубрика p3 (вес 1): Процесс ротации ключей нужно подготовить заранее
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

**Заметки генерации (что проверить):** Проверить однозначность mcq и find_error.

---

## 18. Криптостойкий генератор случайных чисел

- [ ] одобряю `infosec.crypto.csprng`
- Вердикт независимой проверки: **✅ ok**; статус в колоде: `approved`

**Факт.** Для ключей, IV, идентификаторов сессий и токенов нужен криптостойкий генератор (CSPRNG); обычные ГПСЧ быстрее, но предсказуемы и для безопасности не годятся.

**Коротко.** Обычный ГПСЧ для безопасности не годится: его вывод часто можно угадать или предсказать. Для чувствительных функций нужен CSPRNG.

**Цитаты:**

> Random numbers (or strings) are needed for various security critical functionality, such as generating encryption keys, IVs, session IDs, CSRF tokens or password reset tokens.
>
> — [OWASP Cheat Sheet Series: Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> Pseudo-Random Number Generators (PRNG) provide low-quality randomness that are much faster, and can be used for non-security related functionality (such as ordering results on a page, or randomizing UI elements). However, they must not be used for anything security critical, as it is often possible for attackers to guess or predict the output.
>
> — [OWASP Cheat Sheet Series: Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> Cryptographically Secure Pseudo-Random Number Generators (CSPRNG) are designed to produce a much higher quality of randomness (more strictly, a greater amount of entropy), making them safe to use for security-sensitive functionality.
>
> — [OWASP Cheat Sheet Series: Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html), CC BY-SA 4.0

**Вопросы:**

- `infosec.crypto.csprng.q1` · **mcq** · Для какой задачи допустим обычный генератор псевдослучайных чисел (PRNG)?
  - ✅ a) Для перемешивания порядка результатов на странице
  - ▫ b) Для генерации ключей шифрования
  - ▫ c) Для генерации токенов сброса пароля
  - ▫ d) Для генерации идентификаторов сессий
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.crypto.csprng.q2` · **flip** · Почему обычный ГПСЧ нельзя использовать для генерации ключей и токенов?
  - Оборот: Его вывод часто можно угадать или предсказать, а для безопасности нужна непредсказуемость.
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

- `infosec.crypto.csprng.q3` · **cloze** · Для задач безопасности нужны {{1}} генераторы случайных чисел (CSPRNG).
  - Пропуск {{1}}: `криптографически стойкие`, `криптостойкие`, `криптографически безопасные`, `криптографически защищённые`, `криптографически защищенные`
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

---

## 19. RSA: размер ключа и дополнение

- [ ] одобряю `infosec.crypto.rsa-oaep`
- Вердикт независимой проверки: **✅ ok**; статус в колоде: `approved`

**Факт.** Если без RSA не обойтись, ключ должен быть не короче 2048 бит; для шифрования используют RSAES-OAEP из поддерживаемой библиотеки, а RSA без схемы дополнения использовать нельзя.

**Коротко.** RSA без дополнения небезопасен, а «добавить случайные байты вручную» OAEP не заменяет. Размер ключа — не менее 2048 бит.

**Цитаты:**

> If RSA must be used, ensure that the key is at least 2048 bits.
>
> — [OWASP Cheat Sheet Series: Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> For RSA encryption, use a maintained library's RSAES-OAEP (Optimal Asymmetric Encryption Padding) implementation
>
> — [OWASP Cheat Sheet Series: Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html), CC BY-SA 4.0

> OAEP uses randomized encoding and mask generation functions; simply prepending random bytes to the message is not a substitute. Do not use RSA without an encryption padding scheme.
>
> — [OWASP Cheat Sheet Series: Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html), CC BY-SA 4.0

**Вопросы:**

- `infosec.crypto.rsa-oaep.q1` · **cloze** · Если приходится использовать RSA, ключ должен быть не короче {{1}} бит.
  - Пропуск {{1}}: `2048`, `2 048`
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.crypto.rsa-oaep.q2` · **mcq** · Какое дополнение (padding) нужно использовать при шифровании RSA?
  - ✅ a) RSAES-OAEP
  - ▫ b) Дополнение не нужно
  - ▫ c) Несколько случайных байт, дописанных вручную к сообщению
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.crypto.rsa-oaep.q3` · **flip** · Можно ли заменить OAEP дописыванием случайных байт к сообщению?
  - Оборот: Нет: OAEP использует рандомизированное кодирование и функции генерации маски, простое добавление случайных байт его не заменяет.
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

**Заметки генерации (что проверить):** Проверить, что «не короче 2048 бит» актуально на момент вычитки (рекомендации меняются).

---

## 20. Свойства криптографического хеша

- [ ] одобряю `infosec.crypto.hash-properties`
- Вердикт независимой проверки: **✅ ok**; статус в колоде: `approved`

**Факт.** У криптографической хеш-функции практически невозможно найти пару разных сообщений с одинаковым хешем (коллизию), а малое изменение входа резко меняет хеш (лавинный эффект).

**Коротко.** Коллизию — два разных сообщения с одним хешем — найти практически невозможно. При малом изменении входа хеш меняется радикально (лавинный эффект).

**Цитаты:**

> finding any pair of different messages that yield the same hash value (a collision) is also infeasible
>
> — [Wikipedia: Cryptographic hash function](https://en.wikipedia.org/wiki/Cryptographic_hash_function), CC BY-SA 4.0

> A small change in the input (in the word "over") drastically changes the output (digest). This is called the avalanche effect.
>
> — [Wikipedia: Cryptographic hash function](https://en.wikipedia.org/wiki/Cryptographic_hash_function), CC BY-SA 4.0

**Вопросы:**

- `infosec.crypto.hash-properties.q1` · **mcq** · Какое свойство хеш-функции нарушено, если удалось найти два разных сообщения с одинаковым хешем?
  - ✅ a) Стойкость к коллизиям
  - ▫ b) Лавинный эффект
  - ▫ c) Детерминированность
  - ▫ d) Скорость вычисления
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.crypto.hash-properties.q2` · **cloze** · Резкое изменение хеша при малом изменении входа называется {{1}} эффектом.
  - Пропуск {{1}}: `лавинным`
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `no`; однозначно — `yes`

- `infosec.crypto.hash-properties.q3` · **flip** · Что такое коллизия хеш-функции?
  - Оборот: Пара разных сообщений, дающих одинаковое значение хеша; для криптографического хеша найти её должно быть практически невозможно.
  - Проверка: цитата подтверждает ответ — `yes`; вторая верная — `n/a`; однозначно — `yes`

---

## Одобрение

Команда ниже перечисляет знания с вердиктом проверки `ok`; уберите те, что не одобряете, и подставьте своё имя. Знания с `needs_fix` сначала исправьте.

```
dart run tools/approve_items.dart content/decks/infosec-basics.json \
  infosec.pw.hash-not-encrypt \
  infosec.pw.salt \
  infosec.pw.argon2id \
  infosec.pw.pepper \
  infosec.pw.work-factor \
  infosec.pw.bcrypt-limit \
  infosec.auth.mfa \
  infosec.auth.totp \
  infosec.auth.generic-errors \
  infosec.crypto.sym-vs-asym \
  infosec.crypto.hybrid \
  infosec.crypto.digital-signature \
  infosec.crypto.diffie-hellman \
  infosec.crypto.kerckhoffs \
  infosec.crypto.authenticated-encryption \
  infosec.crypto.key-storage \
  infosec.crypto.csprng \
  infosec.crypto.rsa-oaep \
  infosec.crypto.hash-properties \
  --by "<имя>"
```

После этого: `dart run tools/validate_deck.dart content/decks/infosec-basics.json --release` (пройдёт, когда одобрены все знания).
