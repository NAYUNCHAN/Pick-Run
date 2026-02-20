extends Control

@onready var summary_label: Label = $MarginContainer/VBox/SummaryLabel
@onready var horse_stats_label: Label = $MarginContainer/VBox/HorseStatsLabel
@onready var recent_list_label: Label = $MarginContainer/VBox/RecentLabel
@onready var reset_button: Button = $MarginContainer/VBox/ButtonRow/ResetButton
@onready var back_button: Button = $MarginContainer/VBox/ButtonRow/BackButton
@onready var confirm_dialog: ConfirmationDialog = $ConfirmDialog

func _ready() -> void:
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)
	confirm_dialog.confirmed.connect(_on_confirm_reset)
	refresh_ui()

func refresh_ui() -> void:
	var total_races := int(GameState.stats.get("total_races", 0))
	var wins := int(GameState.stats.get("wins", 0))
	var losses := int(GameState.stats.get("losses", 0))
	var win_rate := 0.0 if total_races == 0 else (float(wins) / float(total_races)) * 100.0
	var best_profit := int(GameState.stats.get("best_profit", 0))

	summary_label.text = "총 %d전 %d승 %d패 | 승률 %.1f%%\n누적 손익 %+d | 최고 수익 %+d | 현재 코인 %d" % [
		total_races, wins, losses, win_rate, GameState.total_profit, best_profit, GameState.coins
	]

	var horse_lines: Array[String] = []
	for horse in HorseData.get_all_horses():
		var name := str(horse["name"])
		var hstat := GameState.horse_stats.get(name, {"selected": 0, "wins": 0})
		var selected := int(hstat.get("selected", 0))
		var hwins := int(hstat.get("wins", 0))
		var hwin_rate := 0.0 if selected == 0 else (float(hwins) / float(selected)) * 100.0
		horse_lines.append("- %s: 선택 %d / 우승 %d / 승률 %.1f%%" % [name, selected, hwins, hwin_rate])
	horse_stats_label.text = "말별 통계\n" + "\n".join(horse_lines)

	var recent_lines: Array[String] = []
	for entry in GameState.recent_results:
		recent_lines.append("- 우승 %s | 선택 %s | 배팅 %d | 손익 %+d" % [
			entry.get("winner", "-"),
			entry.get("selected", "-"),
			int(entry.get("bet", 0)),
			int(entry.get("profit", 0))
		])
	if recent_lines.is_empty():
		recent_lines.append("- 최근 경기 없음")
	recent_list_label.text = "최근 5경기\n" + "\n".join(recent_lines)

func _on_reset_pressed() -> void:
	confirm_dialog.dialog_text = "정말 통계를 초기화할까요?\n코인/통계가 기본값으로 돌아갑니다."
	confirm_dialog.popup_centered()

func _on_confirm_reset() -> void:
	GameState.reset_stats()
	refresh_ui()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
