# Tick

*[Русская версия ниже](#tick-russian)*

Sometimes you don't need automation — you just need to not miss a step.
Tick is a checklist and reference-card app for macOS, styled after aviation
checklists: short, itemized, no clutter.

Two kinds of lists for different jobs. A **checklist** is for procedures
where you want to mark off what's done — cutting a release, running a backup,
anything you repeat. A **reference card** is a list of terms with commands
or values at hand ("FLAPS ........ 15"), so you don't have to keep it in
your head or dig through shell history.

Tick normally sits as a compact card that floats above every window on any
desktop — out of the way, always visible, draggable from anywhere. Click any
item to copy its value and keep moving; an item can carry several values. Lists are grouped into folders, with
search. When you need to change something, there's a dedicated editing mode,
fully keyboard-driven; the full shortcut list lives right inside the app, as
a built-in "Tick Hotkeys" card.

Theme: light, dark, or match the system.

## Install

```bash
brew tap white-currant/tap
brew trust white-currant/tap
brew install --cask tick
```

Or grab the DMG by hand from the [Releases](https://github.com/white-currant/Tick/releases) page.

Updates happen automatically via [Sparkle](https://sparkle-project.org), or
manually from the "Check for Updates…" menu.

## Uninstall and reinstall

Your checklists live in `~/Library/Application Support/Tick`. Copy that folder
first if you want to keep them.

Remove the app, keep your data:

```bash
brew uninstall --cask tick
```

Reinstall from scratch:

```bash
brew uninstall --cask tick
brew install --cask tick
```

Remove everything — app, checklists, settings, caches (can't be undone):

```bash
brew uninstall --zap --cask tick
```

**Deleted the app by dragging it to the Trash, and Homebrew now says it is
"already installed"?** Homebrew keeps its own record. Clear it, then install again:

```bash
brew uninstall --cask tick
brew install --cask tick
```

**Installed from the DMG, without Homebrew?** Quit Tick, then:

```bash
rm -rf /Applications/Tick.app
rm -rf ~/Library/Application\ Support/Tick ~/Library/Preferences/com.yulion.tick.plist \
       ~/Library/Caches/com.yulion.tick ~/Library/HTTPStorages/com.yulion.tick \
       ~/Library/Containers/com.yulion.tick
```

Skip the second line if you want to keep your checklists.

---

<a id="tick-russian"></a>
# Tick (русский)

*[English version above](#tick)*

Иногда не нужно ничего автоматизировать — нужно просто не забыть ни одного
шага. Tick — чеклисты и памятки для macOS в духе авиационных карточек:
коротко, по пунктам, без лишнего.

Два типа листов под разные задачи. **Чеклист** — для процедур, где важно
отмечать пройденное: сборка релиза, бэкап, что угодно повторяющееся.
**Памятка** — список тезисов с командами и значениями под рукой
(«ЗАКРЫЛКИ ........ 15»), чтобы не держать в голове и не рыться в истории
терминала.

Обычно Tick просто висит компактной карточкой поверх всех окон на любом
рабочем столе — не мешает, но всегда на виду, и таскается за любое место.
Клик по пункту копирует его значение, и можно работать дальше; у пункта может быть несколько значений. Листы
группируются по папкам, есть поиск. Когда нужно что-то поправить — отдельный
режим редактирования, полностью с клавиатуры; полный список горячих клавиш —
прямо в приложении, встроенным листом «Горячие клавиши Tick».

Тема — светлая, тёмная или как в системе.

## Установка

```bash
brew tap white-currant/tap
brew trust white-currant/tap
brew install --cask tick
```

Или скачать вручную — DMG со страницы [Releases](https://github.com/white-currant/Tick/releases).

Обновления — автоматически через [Sparkle](https://sparkle-project.org), либо
вручную через меню «Проверить обновления…».

## Удаление и переустановка

Твои листы лежат в `~/Library/Application Support/Tick`. Если хочешь их
сохранить, сначала скопируй эту папку.

Удалить приложение, оставив данные:

```bash
brew uninstall --cask tick
```

Переустановить с нуля:

```bash
brew uninstall --cask tick
brew install --cask tick
```

Удалить всё — приложение, листы, настройки, кэши (необратимо):

```bash
brew uninstall --zap --cask tick
```

**Удалил приложение перетаскиванием в корзину, а Homebrew пишет, что оно «уже
установлено»?** Homebrew ведёт собственный учёт. Сбрось запись и установи заново:

```bash
brew uninstall --cask tick
brew install --cask tick
```

**Ставил из DMG, без Homebrew?** Закрой Tick и выполни:

```bash
rm -rf /Applications/Tick.app
rm -rf ~/Library/Application\ Support/Tick ~/Library/Preferences/com.yulion.tick.plist \
       ~/Library/Caches/com.yulion.tick ~/Library/HTTPStorages/com.yulion.tick \
       ~/Library/Containers/com.yulion.tick
```

Вторую строку пропусти, если листы нужно оставить.
