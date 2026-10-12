"""OpenCanvasX plugin: bar chart (plugin API 1).

Bars are ordinary rectangles and labels ordinary text, so the chart stays
fully editable.
"""
import json
import sys

request = json.load(sys.stdin)
inputs = request.get("inputs", {})
labels = [s.strip() for s in str(inputs.get("labels", "")).split(",") if s.strip()]
values = []
for part in str(inputs.get("values", "")).split(","):
    try:
        values.append(float(part))
    except ValueError:
        pass
n = min(len(labels), len(values), 40)
if n == 0:
    json.dump({"operations": [{"op": "notify",
                               "message": "Enter matching labels and numbers."}]},
              sys.stdout)
    sys.exit(0)

page = request["page"]
w, h = page["width"] * 0.6, page["height"] * 0.4
x0, y0 = page["width"] * 0.2, page["height"] * 0.3
top = max(max(values[:n]), 1e-9)
slot = w / n
size = max(page["width"], page["height"]) * 0.014
colour = inputs.get("colour", "#3256F0")
ops = [{"op": "create_shape", "shape": "line", "x": x0, "y": y0 + h,
        "width": w, "stroke": "#C9CDD6", "stroke_width": size * 0.12,
        "name": "Axis"}]
for i in range(n):
    bar_h = max(0.0, values[i]) / top * h
    x = x0 + i * slot + slot * 0.15
    ops.append({"op": "create_shape", "shape": "rounded_rect", "x": x,
                "y": y0 + h - bar_h, "width": slot * 0.7, "height": bar_h,
                "fill": colour, "radius": slot * 0.06,
                "name": "Bar %s" % labels[i]})
    ops.append({"op": "create_text", "text": labels[i], "x": x,
                "y": y0 + h + size * 0.6, "width": slot * 0.7, "size": size,
                "align": "center", "color": "#5B616E"})
    ops.append({"op": "create_text", "text": "%g" % values[i], "x": x,
                "y": y0 + h - bar_h - size * 1.6, "width": slot * 0.7,
                "size": size, "weight": 700, "align": "center",
                "color": "#16181D"})
ops.append({"op": "notify", "message": "Drew %d bars." % n})
json.dump({"operations": ops}, sys.stdout)
