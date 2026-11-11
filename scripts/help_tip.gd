extends Label
# Garage "?" badge: its explanation pops up wrapped onto a few short lines, not one screen-wide line

const LINE_CHARS: int = 60

func _make_custom_tooltip(for_text: String) -> Object:
	var lines: PackedStringArray = []
	var cur: String = ""
	for w in tr(for_text).split(" ", false):
		if cur != "" and cur.length() + 1 + w.length() > LINE_CHARS:
			lines.append(cur)
			cur = w
		else:
			cur = w if cur == "" else cur + " " + w
	lines.append(cur)
	var l := Label.new()
	l.text = "\n".join(lines)
	return l
