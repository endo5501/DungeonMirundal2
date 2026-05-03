class_name TitledView
extends RefCounted

const HEADER_CHILD_COUNT: int = 2  # title + spacer


static func build(title_text: String, separation: int = 6) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", separation)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	vbox.add_child(spacer)
	return vbox


static func clear_extras(container: VBoxContainer) -> void:
	while container.get_child_count() > HEADER_CHILD_COUNT:
		var child := container.get_child(container.get_child_count() - 1)
		container.remove_child(child)
		child.queue_free()
