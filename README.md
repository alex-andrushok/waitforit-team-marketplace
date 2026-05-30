# waitforit-team-marketplace

Внутрішній marketplace плагінів [Claude Code](https://code.claude.com) для команди WaitForIt.

## Що це

Це репозиторій-marketplace, який збирає в одному місці плагіни Claude Code, що
використовує команда WaitForIt: slash-команди, агентів, скіли, хуки та MCP-сервери.
Замість того щоб кожен встановлював інструменти вручну, ви один раз додаєте цей
marketplace — і отримуєте доступ до всіх командних плагінів та їхніх оновлень.

Маніфест marketplace лежить у [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json),
а самі плагіни — у теці [`plugins/`](plugins/).

## Як додати у Claude Code

1. Додайте marketplace (одноразово):

   ```
   /plugin marketplace add alex-andrushok/waitforit-team-marketplace
   ```

   Або з локальної копії репозиторію:

   ```
   /plugin marketplace add /шлях/до/waitforit-team-marketplace
   ```

2. Встановіть потрібний плагін:

   ```
   /plugin install hello@waitforit-team-marketplace
   ```

3. Перегляньте, що доступно, та керуйте плагінами:

   ```
   /plugin
   ```

Оновлення підтягуються командою `/plugin marketplace update waitforit-team-marketplace`.

## Список плагінів

| Плагін  | Опис                                                              | Команди / можливості |
| ------- | ----------------------------------------------------------------- | -------------------- |
| `hello` | Демо-плагін і шаблон для копіювання при створенні нових плагінів. | `/hello`             |

> Додаючи новий плагін, не забудьте дописати рядок у цю таблицю та запис у
> масив `plugins` файлу `.claude-plugin/marketplace.json`.

## Супровідники

| Ім'я         | Роль                  | Контакт                                            |
| ------------ | --------------------- | -------------------------------------------------- |
| o.andrushok  | Власник / супровідник | [andrushoka@gmail.com](mailto:andrushoka@gmail.com) |

## Як контриб'ютити

1. Створіть гілку від `main`.
2. Скопіюйте теку [`plugins/hello/`](plugins/hello/) як шаблон і перейменуйте під свій плагін.
3. Оновіть `.claude-plugin/plugin.json` нового плагіна (`name`, `description`, `version`).
4. Додайте компоненти плагіна — `commands/`, `agents/`, `skills/`, `hooks/` тощо.
5. Зареєструйте плагін у масиві `plugins` файлу `.claude-plugin/marketplace.json`
   та допишіть рядок у таблицю [Список плагінів](#список-плагінів).
6. Перевірте валідність JSON і встановіть плагін локально, щоб переконатися, що він працює:

   ```
   python3 -m json.tool .claude-plugin/marketplace.json
   /plugin marketplace add .
   /plugin install <ваш-плагін>@waitforit-team-marketplace
   ```

7. Відкрийте Pull Request з коротким описом, що робить плагін.

**Конвенції:** імена плагінів — `kebab-case`; кожен локальний плагін має власний
`.claude-plugin/plugin.json`; дотримуйтесь [семантичного версіонування](https://semver.org/lang/uk/).

## Контакти

- **Питання та пропозиції:** [andrushoka@gmail.com](mailto:andrushoka@gmail.com)
- **Issues та Pull Requests:** <https://github.com/alex-andrushok/waitforit-team-marketplace>
- **Вразливості безпеки:** див. [SECURITY.md](SECURITY.md) — **не** повідомляйте через публічні issues.
