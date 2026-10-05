from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Final


ROOT: Final[Path] = Path(__file__).resolve().parents[1]
MOD_ID: Final[str] = "apasz_sided_signals"
ADVANCED_PARAM_KEY: Final[str] = "apasz_sided_signals_advanced_adjustments"
ADVANCED_DEFAULT_NAME_KEY: Final[str] = "APASZ_SIDED_SIGNALS_ADVANCED_DEFAULT"
SUPPORTED_LOCALES: Final[tuple[str, ...]] = (
    "en",
    "de",
    "ru",
    "zh_CN",
    "fr",
    "es",
    "it",
    "nl",
    "cs",
    "sv",
    "ro",
    "fi",
    "da",
    "tr",
    "et",
    "ja",
    "hu",
    "pl",
    "id",
    "ko",
    "pt_BR",
    "zh_TW",
)
LOCALIZATION_KEY: Final[re.Pattern[str]] = re.compile(
    r'"(APASZ_SIDED_SIGNALS_[A-Z_]+)"'
)
KNOWN_MOD_ENTRY: Final[re.Pattern[str]] = re.compile(
    r"^[1-9][0-9]* \| [A-Za-z0-9_]+$"
)
METADATA_FIELDS: Final[frozenset[str]] = frozenset({"name", "summary", "description"})


def unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate object key {key!r}")
        result[key] = value
    return result


def load_object(path: Path) -> dict[str, object]:
    try:
        value: object = json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=unique_object,
        )
    except ValueError as error:
        raise AssertionError(f"{path.relative_to(ROOT)}: {error}") from error
    if not isinstance(value, dict):
        raise AssertionError(f"{path.relative_to(ROOT)} must contain a JSON object")
    return value


def string_map(value: object, location: str) -> dict[str, str]:
    if not isinstance(value, dict):
        raise AssertionError(f"{location} must be an object")

    result: dict[str, str] = {}
    for key, text in value.items():
        if not isinstance(key, str) or not isinstance(text, str) or not text.strip():
            raise AssertionError(f"{location} contains an invalid or empty entry: {key!r}")
        result[key] = text
    return result


def referenced_ui_keys() -> set[str]:
    paths = [ROOT / "mod.json", *sorted((ROOT / "src").rglob("*.tl"))]
    return {
        match.group(1)
        for path in paths
        for match in LOCALIZATION_KEY.finditer(path.read_text(encoding="utf-8"))
    }


def validate_ui_strings() -> int:
    translations = load_object(ROOT / "strings.json")
    actual_locales = tuple(translations)
    if actual_locales != SUPPORTED_LOCALES:
        raise AssertionError(
            f"strings.json locales differ: expected {SUPPORTED_LOCALES}, got {actual_locales}"
        )

    english = string_map(translations["en"], "strings.json:en")
    english_keys = set(english)
    referenced_keys = referenced_ui_keys()
    if english_keys != referenced_keys:
        missing = sorted(referenced_keys - english_keys)
        unused = sorted(english_keys - referenced_keys)
        raise AssertionError(
            f"English localization mismatch: missing={missing}, unused={unused}"
        )

    for locale in SUPPORTED_LOCALES[1:]:
        localized = string_map(translations[locale], f"strings.json:{locale}")
        localized_keys = set(localized)
        if localized_keys != english_keys:
            missing = sorted(english_keys - localized_keys)
            extra = sorted(localized_keys - english_keys)
            raise AssertionError(f"{locale} key mismatch: missing={missing}, extra={extra}")

    return len(english_keys)


def script_reference(manifest: dict[str, object], field: str) -> str:
    reference = manifest.get(field)
    if not isinstance(reference, dict) or set(reference) != {"fileName"}:
        raise AssertionError(f"mod.json:{field} must contain only fileName")
    file_name = reference["fileName"]
    if not isinstance(file_name, str):
        raise AssertionError(f"mod.json:{field}.fileName must be a string")
    return file_name


def validate_manifest() -> None:
    manifest = load_object(ROOT / "mod.json")
    if manifest.get("modId") != MOD_ID:
        raise AssertionError(f"mod.json:modId must be {MOD_ID!r}")
    if manifest.get("cosmetic") is not True:
        raise AssertionError("mod.json:cosmetic must be true")

    revision = manifest.get("revision")
    if isinstance(revision, bool) or not isinstance(revision, int) or revision < 1:
        raise AssertionError("mod.json:revision must be a positive integer")

    expected_scripts = {
        "preRunScript": "",
        "runScript": f"{MOD_ID}::/mod.script@runFn",
        "postRunScript": f"{MOD_ID}::/mod.script@postRunFn",
    }
    for field, expected in expected_scripts.items():
        actual = script_reference(manifest, field)
        if actual != expected:
            raise AssertionError(
                f"mod.json:{field}.fileName must be {expected!r}, got {actual!r}"
            )

    params = manifest.get("params")
    if not isinstance(params, list) or len(params) != 1:
        raise AssertionError("mod.json:params must contain exactly one setting")
    advanced = params[0]
    if not isinstance(advanced, dict) or advanced.get("key") != ADVANCED_PARAM_KEY:
        raise AssertionError("mod.json:params must declare the advanced setting")
    if advanced.get("name") != ADVANCED_DEFAULT_NAME_KEY:
        raise AssertionError("the advanced setting must use its default-visibility name")
    if advanced.get("uiType") != "CheckBox":
        raise AssertionError("the advanced setting must use a checkbox")
    default_index = advanced.get("defaultIndex")
    if isinstance(default_index, bool) or default_index != 1:
        raise AssertionError("the advanced setting must default to Off")
    if advanced.get("values") != [
        "APASZ_SIDED_SIGNALS_OFF",
        "APASZ_SIDED_SIGNALS_ON",
    ]:
        raise AssertionError("the advanced setting must contain Off and On")

    for field in ("known_signal_mods", "known_broken_mods"):
        entries = manifest.get(field)
        if not isinstance(entries, list):
            raise AssertionError(f"mod.json:{field} must be a list")
        if field == "known_signal_mods" and not entries:
            raise AssertionError("mod.json:known_signal_mods must be non-empty")
        for entry in entries:
            if not isinstance(entry, str) or KNOWN_MOD_ENTRY.fullmatch(entry) is None:
                raise AssertionError(
                    f"mod.json:{field} entry must be '<mod.io ID> | <modId>': {entry!r}"
                )


def validate_metadata() -> None:
    metadata = load_object(ROOT / "_metadata" / "modinfo.json")
    for field in METADATA_FIELDS:
        value = metadata.get(field)
        if not isinstance(value, str) or not value.strip():
            raise AssertionError(f"modinfo.json:{field} must be a non-empty string")

    localization = metadata.get("localization")
    if not isinstance(localization, dict):
        raise AssertionError("modinfo.json:localization must be an object")

    expected_locales = set(SUPPORTED_LOCALES[1:])
    actual_locales = set(localization)
    if actual_locales != expected_locales:
        missing = sorted(expected_locales - actual_locales)
        extra = sorted(actual_locales - expected_locales)
        raise AssertionError(f"metadata locale mismatch: missing={missing}, extra={extra}")

    entries: dict[str, object] = {
        "en": {field: metadata[field] for field in METADATA_FIELDS}
    }
    entries.update(localization)
    for locale in SUPPORTED_LOCALES:
        entry = string_map(entries[locale], f"modinfo.json:{locale}")
        if set(entry) != METADATA_FIELDS:
            raise AssertionError(
                f"modinfo.json:{locale} must contain exactly {sorted(METADATA_FIELDS)}"
            )
        if len(entry["name"]) > 32 or "\n" in entry["name"]:
            raise AssertionError(f"modinfo.json:{locale}:name exceeds the game limit")
        if len(entry["summary"]) > 100 or "\n" in entry["summary"]:
            raise AssertionError(f"modinfo.json:{locale}:summary exceeds the game limit")


def main() -> None:
    validate_manifest()
    string_count = validate_ui_strings()
    validate_metadata()
    print(
        "localization_check: ok "
        f"({len(SUPPORTED_LOCALES)} locales, {string_count} UI strings each)"
    )


if __name__ == "__main__":
    main()
