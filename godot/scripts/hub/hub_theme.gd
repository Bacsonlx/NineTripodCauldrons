extends RefCounted

const PAPER: Color = Color("f3e4c3")
const GOLD: Color = Color("c9ac73")
const INK: Color = Color("111a17")
const MUTED: Color = Color("aaa48c")

static func box(color: Color,border: Color = GOLD,padding: int = 16) -> StyleBoxFlat:
	var result: StyleBoxFlat = StyleBoxFlat.new()
	result.bg_color=color; result.border_color=border; result.set_border_width_all(1)
	result.set_content_margin_all(padding)
	return result

static func make() -> Theme:
	var result: Theme = Theme.new()
	result.default_font=preload("res://assets/fonts/NineTripodsHudSong.ttf")
	result.default_font_size=17
	result.set_color("font_color","Label",PAPER)
	result.set_color("font_color","Button",PAPER)
	result.set_color("font_hover_color","Button",Color("fff2d4"))
	result.set_color("font_disabled_color","Button",Color("807c6e"))
	result.set_stylebox("panel","PanelContainer",box(Color("111a17fa")))
	for state in ["normal","hover","pressed","focus","disabled"]:
		result.set_stylebox(state,"Button",box(Color("25382b") if state in ["hover","pressed"] else Color("17241e"),GOLD if state!="disabled" else Color("4d5145"),12))
	return result

static func label(text: String,size: int = 17,color: Color = PAPER,wrap: bool = false) -> Label:
	var result: Label = Label.new()
	result.text=text; result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",color)
	if wrap: result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return result

static func button(parent: Node,text: String,action: Callable) -> Button:
	var result: Button = Button.new()
	result.text=text; result.custom_minimum_size.y=44
	result.pressed.connect(action); parent.add_child(result)
	return result
