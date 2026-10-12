"""OpenCanvasX plugin: placeholder text (plugin API 1).

Reads the request JSON on stdin and writes {"operations": [...]} on stdout.
"""
import json
import sys

LOREM = (
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod "
    "tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim "
    "veniam, quis nostrud exercitation ullamco laboris."
)
PLAIN = (
    "This is placeholder text. Replace it with your own words to tell people "
    "what this design is about, why it matters and what to do next."
)

request = json.load(sys.stdin)
inputs = request.get("inputs", {})
count = max(1, min(8, int(float(inputs.get("paragraphs", 2)))))
body = PLAIN if inputs.get("style") == "Plain English" else LOREM
page = request["page"]
size = max(page["width"], page["height"]) * 0.018
json.dump({
    "operations": [
        {
            "op": "create_text",
            "text": "\n\n".join([body] * count),
            "x": page["width"] * 0.2,
            "y": page["height"] * 0.25,
            "width": page["width"] * 0.6,
            "size": size,
            "color": "#3A3F4A",
            "name": "Placeholder text",
        },
        {"op": "notify", "message": "Added %d paragraph(s)." % count},
    ]
}, sys.stdout)
