from pathlib import Path

root = Path(r"c:\flutter_apps\petnest_saas")
files = []
files += list((root / "lib/features/booking").rglob("*.dart"))
files += list((root / "lib/features/member").rglob("*.dart"))
files += [
    root / "lib/features/shop/pages/shop_pre_arrival_guide_setting_page.dart",
]

colors = [
    "background",
    "card",
    "border",
    "primary",
    "text",
    "muted",
    "success",
    "successSoft",
    "warning",
    "warningSoft",
    "danger",
    "dangerSoft",
    "iconSoft",
]
member_colors = colors + ["iconSoft"]

for path in files:
    if not path.exists():
        continue
    text = path.read_text(encoding="utf-8")
    orig = text
    text = text.replace(
        "BookingDetailUi.cardDecoration()",
        "BookingDetailUi.cardDecoration(context)",
    )
    for name in colors:
        text = text.replace(
            f"BookingDetailUi.{name}",
            f"BookingDetailUi.of(context).{name}",
        )
        # undo accidental double wrap
        text = text.replace(
            "BookingDetailUi.of(context).of(context).",
            "BookingDetailUi.of(context).",
        )
    text = text.replace(
        "MemberUi.cardDecoration()",
        "MemberUi.cardDecoration(context)",
    )
    for name in [
        "background",
        "card",
        "border",
        "primary",
        "text",
        "muted",
        "success",
        "successSoft",
        "danger",
        "dangerSoft",
        "warning",
        "warningSoft",
        "iconSoft",
    ]:
        text = text.replace(f"MemberUi.{name}", f"MemberUi.of(context).{name}")
        text = text.replace(
            "MemberUi.of(context).of(context).",
            "MemberUi.of(context).",
        )
    if text != orig:
        path.write_text(text, encoding="utf-8")
        print("updated", path.relative_to(root))
