"""OpenCanvasX plugin: palette generator (plugin API 1)."""
import colorsys
import json
import sys

HARMONIES = {
    "Analogous": [(-0.08, 0), (-0.04, 0), (0, 0), (0.04, 0), (0.08, 0)],
    "Complementary": [(0, -0.2), (0, 0), (0, 0.2), (0.5, 0), (0.5, 0.2)],
    "Triadic": [(0, 0), (1 / 3, 0), (2 / 3, 0), (0, 0.25), (0, -0.2)],
    "Monochrome": [(0, -0.3), (0, -0.15), (0, 0), (0, 0.15), (0, 0.3)],
}

request = json.load(sys.stdin)
inputs = request.get("inputs", {})
base = str(inputs.get("base", "#3256F0")).lstrip("#")[:6].ljust(6, "0")
r, g, b = (int(base[i:i + 2], 16) / 255 for i in (0, 2, 4))
h, l, s = colorsys.rgb_to_hls(r, g, b)
harmony = inputs.get("harmony", "Analogous")
offsets = HARMONIES.get(harmony, HARMONIES["Analogous"])


def hexcolor(hh, ll):
    rr, gg, bb = colorsys.hls_to_rgb(hh % 1, min(0.95, max(0.08, ll)), s)
    return "#%02X%02X%02X" % (round(rr * 255), round(gg * 255), round(bb * 255))


page = request["page"]
unit = min(page["width"], page["height"]) / 8
x0 = page["width"] / 2 - unit * 2.75
y0 = page["height"] / 2 - unit
ops = []
for i, (dh, dl) in enumerate(offsets):
    colour = hexcolor(h + dh, l + dl)
    x = x0 + i * unit * 1.15
    ops.append({"op": "create_shape", "shape": "rounded_rect", "x": x, "y": y0,
                "width": unit, "height": unit * 1.4, "fill": colour,
                "radius": unit * 0.12, "name": colour})
    ops.append({"op": "create_text", "text": colour, "x": x,
                "y": y0 + unit * 1.5, "size": unit * 0.16, "weight": 600,
                "color": "#3A3F4A"})
ops.append({"op": "notify",
            "message": "%s palette from #%s." % (harmony, base.upper())})
json.dump({"operations": ops}, sys.stdout)
