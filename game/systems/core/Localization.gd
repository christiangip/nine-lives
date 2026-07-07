extends RefCounted
class_name Localization
## Language scaffold (task 21, FR-21-1). Registers in-code Translation objects for the shipped locales and
## applies a locale from the gameplay/language setting. This is the PLUMBING plus a small sample string set
## (menu + a few pause keys) — not a full localization pass. The authoring source is
## game/assets/i18n/strings.csv; the CSV→.translation import route is the production path (see
## docs/RELEASE_CHECKLIST.md / AUTHORING). Keeps the 10-autoload spine: a static helper SettingsManager calls,
## never an 11th singleton. Godot's Control auto-translation re-renders keyed text on locale change, so the
## Main Menu / Pause flip live. See docs/tasks/21_release_polish.md and GDD §15.2.

const LOCALES := ["en", "es", "fr", "de"]

## Translation key -> per-locale strings, ordered by LOCALES. English is the source; the rest are the sample
## scaffold. Set a Control's text to the KEY (auto-translate on) and it displays + live-updates the locale.
const STRINGS := {
	"MENU_NEW_GAME": ["New Game", "Nuevo Juego", "Nouvelle Partie", "Neues Spiel"],
	"MENU_CONTINUE": ["Continue", "Continuar", "Continuer", "Fortsetzen"],
	"MENU_OPTIONS": ["Options", "Opciones", "Options", "Optionen"],
	"MENU_EXIT": ["Exit", "Salir", "Quitter", "Beenden"],
	"MENU_EXIT_CONFIRM": ["Exit Nine Lives?", "¿Salir de Nine Lives?", "Quitter Nine Lives ?", "Nine Lives beenden?"],
	"PAUSE_TITLE": ["Paused", "Pausa", "En Pause", "Pausiert"],
	"PAUSE_RESUME": ["Resume", "Reanudar", "Reprendre", "Fortsetzen"],
	"PAUSE_OPTIONS": ["Options", "Opciones", "Options", "Optionen"],
	"PAUSE_ABORT": ["Abort Mission", "Abortar Misión", "Abandonner la Mission", "Mission abbrechen"],
}

static var _registered: bool = false

## Register one Translation per locale from STRINGS (idempotent), then switch to `code` (falls back to "en").
static func apply_locale(code: String) -> void:
	ensure_registered()
	TranslationServer.set_locale(code if code in LOCALES else "en")

## Idempotently register the in-code sample translations with the TranslationServer.
static func ensure_registered() -> void:
	if _registered:
		return
	_registered = true
	for i in LOCALES.size():
		var t := Translation.new()
		t.locale = LOCALES[i]
		for key in STRINGS:
			t.add_message(key, StringName(STRINGS[key][i]))
		TranslationServer.add_translation(t)
