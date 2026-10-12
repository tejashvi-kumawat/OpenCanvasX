"""OpenCanvasX plugin: rename selected layers (plugin API 1)."""
import json
import sys

request = json.load(sys.stdin)
inputs = request.get("inputs", {})
selection = list(request.get("selection", []))
prefix = (str(inputs.get("prefix") or "Item")).strip()[:80] or "Item"
order = inputs.get("order", "Left to right")
if order == "Left to right":
    selection.sort(key=lambda o: (o.get("x", 0), o.get("y", 0)))
elif order == "Top to bottom":
    selection.sort(key=lambda o: (o.get("y", 0), o.get("x", 0)))
ops = [{"op": "update", "id": o["id"], "name": "%s %d" % (prefix, i + 1)}
       for i, o in enumerate(selection)]
ops.append({"op": "notify",
            "message": ("Renamed %d layer(s)." % len(selection))
            if selection else "Select some layers first."})
json.dump({"operations": ops}, sys.stdout)
