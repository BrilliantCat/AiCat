"""Bake one portable animation sheet per lesson from the shipped room and rig."""
from PIL import Image
from preview_room import render_room, ROOT
from preview_kitten import model

output = ROOT / "Assets/LivingRoom/Lessons"
output.mkdir(exist_ok=True)
for name in ("pushUp", "squat", "walk", "breath", "plank", "yoga", "curl", "shoulders", "stretch"):
    clip = model["clips"][name]
    sheet = Image.new("RGB", (360 * 5, 416 * 4))
    for i in range(20):
        t = clip.get("entry", {}).get("seconds", 0) + clip["seconds"] * i / 20
        frame = render_room(False, size=(360,416), heading=-.94, clip=name, t=t, lesson=True)
        sheet.paste(frame, (i % 5 * 360, i // 5 * 416))
    sheet.save(output / (name + ".jpg"), quality=90)
