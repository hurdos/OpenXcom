# macOS: профили качества графики

Готовые профили видео-настроек для macOS-сборки OpenXcom. Профили проверены
на **MacBook Air M4, 24 ГБ, macOS 26** со встроенным Retina-дисплеем
**2560×1664** (логически 1470×956) и внешним **3440×1440**.

Профили меняют только графические ключи в пользовательском
`~/Library/Application Support/OpenXcom/options.cfg`; управление, язык,
сохранения и моды не затрагиваются.

## Профили

| Профиль | Режим | Разрешение | Фильтр | Для чего |
|---|---|---|---|---|
| `balanced-fullscreen` | Fullscreen | 1280×800 | OpenGL + `Openxcom` | Повседневный: полный экран, аккуратное сглаживание |
| `sharp-windowed` | Windowed | 1280×800 | OpenGL + `Openxcom` | Максимальная резкость: 1:1 к Retina-панели |
| `smooth-sabr` | Fullscreen | 1280×800 | OpenGL + `SABR-XCOMified` | Максимальное сглаживание, более «современная» картинка |
| `pixel-raw` | Windowed | 1280×800 | OpenGL + `Raw` | Чистые пиксели без сглаживания |
| `external-uwqhd-windowed` | Windowed | 1920×1200 | OpenGL + `Openxcom` | Внешний 3440×1440: резкие 3× от 320×200 |
| `external-uwqhd-fullscreen` | Fullscreen | 3440×1440 | OpenGL + `SABR-XCOMified` | Внешний 3440×1440: заполняет весь экран |

Во всех профилях:

- **VSync** включён;
- **Letterbox / keep aspect ratio** включён;
- **Geoscape/Battlescape scale = Original** (при 2× интерфейс главного меню
  становится крошечным — проверено);
- программные фильтры Scale/HQX/xBRZ выключены;
- `nonSquarePixelRatio = false`.

## Применение и запуск

Игра должна быть **закрыта** — при выходе она сохраняет `options.cfg` и может
перезаписать настройки.

```sh
# посмотреть список
./scripts/apply-graphics-profile.sh --list

# применить профиль
./scripts/apply-graphics-profile.sh balanced-fullscreen

# применить и сразу запустить установленную игру
./scripts/apply-graphics-profile.sh balanced-fullscreen --launch
```

Скрипт сам делает резервную копию:

```text
options.cfg.bak-YYYYMMDD-HHMMSS
options.cfg.bak-YYYYMMDD-HHMMSS-1   # если два профиля применены в одну секунду
```

Показать содержимое профиля без применения:

```sh
./scripts/apply-graphics-profile.sh --show smooth-sabr
```

Если `OpenXcom.app` установлен в `/Applications`, `--launch` запустит его;
иначе попробует `dist/OpenXcom.app`.

Запуск вручную:

```sh
open /Applications/OpenXcom.app
# или, если игра не установлена:
open dist/OpenXcom.app
```

## Как это соотносится с меню игры

В игре: **Настройки → Видео**.

- **Разрешение** — `1280×800`;
- **Режим** — `Fullscreen` или `Windowed`;
- **Фильтр** — `Openxcom *`, `SABR-XCOMified *` или `Raw *`;
  выбор OpenGL-шейдера автоматически включает OpenGL;
- **Geoscape/Battlescape scale** — `Original`;
- **Letterboxed** — включён.

Быстрое переключение fullscreen/windowed — **Alt+Enter**.

## Почему 1280×800

Базовое разрешение игры — 320×200 (16:10). 1280×800 — ровно **4×**:

- пиксели остаются ровными, без «дробного» масштабирования;
- на Retina это 2560×1600 физических пикселей — почти родное разрешение
  панели 2560×1664;
- окно 1280×800 комфортно помещается на логическом рабочем столе 1470×956.

В режиме **Fullscreen** macOS растягивает 1280×800 на весь экран (1470×956);
это немного мягче, но шейдер сглаживает масштаб. В режиме **Windowed**
картинка идёт 1:1 и выглядит максимально резко.

## Шейдеры

- **`Openxcom`** — сглаживает грубые края, сохраняя полу-пиксельный стиль.
  Рекомендуется как баланс.
- **`SABR-XCOMified`** — самое мягкое сглаживание, меньше «лесенок», но
  картинка менее пиксельная.
- **`Raw`** — без сглаживания, максимально близко к оригинальному пиксель-арту.
- **CRT/scanline** шейдеры тоже доступны в списке фильтров, но это отдельный
  ретро-стиль, а не «улучшение качества».

## Внешний монитор 3440×1440

Для внешнего UWQHD-монитора используйте:

- `external-uwqhd-windowed` — окно 1920×1200 (3× от 320×200), резко;
- `external-uwqhd-fullscreen` — полный экран 3440×1440, SABR; картинка
  заполняет экран, но масштаб нецелый (7.2×), поэтому сглаживание обязательно.

Профили `balanced-fullscreen` и другие с 1280×800 рассчитаны на встроенный
Retina-дисплей; на внешнем 3440×1440 они дадут большие поля.

## Откат

- применить другой профиль;
- или в игре: **Настройки → Видео → Восстановить настройки по умолчанию**;
- или восстановить нужный `options.cfg.bak-*`.

## Файлы

```text
docs/macos-graphics/
  README.md
  profiles/
    balanced-fullscreen.yml
    sharp-windowed.yml
    smooth-sabr.yml
    pixel-raw.yml
    external-uwqhd-windowed.yml
    external-uwqhd-fullscreen.yml
scripts/apply-graphics-profile.sh
```

Профили — это фрагменты `options.cfg`, а не полные файлы настроек. Скрипт
обновляет только перечисленные в них ключи.
