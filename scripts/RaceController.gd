extends Control

const TRACK_DISTANCE_M: float = 1600.0
const ODDS_SIM_TOTAL: int = 500
const ODDS_SIM_BATCH: int = 25
const START_X: float = 100.0
const LANE_Y: Array[float] = [70.0, 190.0, 310.0, 430.0]

@onready var coin_label: Label = $RootMargin/MainVBox/TopBar/CoinLabel
@onready var forecast_button: Button = $RootMargin/MainVBox/TopBar/ForecastButton
@onready var bet_label: Label = $RootMargin/MainVBox/BetPanel/BetLabel
@onready var minus_button: Button = $RootMargin/MainVBox/BetPanel/MinusButton
@onready var plus_button: Button = $RootMargin/MainVBox/BetPanel/PlusButton
@onready var confirm_button: Button = $RootMargin/MainVBox/BetPanel/ConfirmBetButton
@onready var race_again_button: Button = $RootMargin/MainVBox/BottomButtons/RaceAgainButton
@onready var back_button: Button = $RootMargin/MainVBox/BottomButtons/BackButton
@onready var report_button: Button = $RootMargin/MainVBox/BottomButtons/ReportButton

@onready var horses_container: Node2D = %HorsesLayer
@onready var finish_line: ColorRect = %FinishLine
@onready var track_bg: ColorRect = %TrackBg
@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_label: Label = $ResultPanel/MarginContainer/ResultVBox/ResultLabel
@onready var settlement_label: Label = $ResultPanel/MarginContainer/ResultVBox/SettlementLabel
@onready var horse_info_popup: HorseInfoPopup = $HorseInfoPopup
@onready var forecast_popup: ForecastPopup = $ForecastPopup

var horse_cards_container: HBoxContainer = null
var horse_card_names: Array[Label] = []
var horse_card_odds: Array[Label] = []
var horse_card_mult: Array[Label] = []
var horse_card_select_buttons: Array[Button] = []
var horse_card_info_buttons: Array[Button] = []

var horse_nodes: Array[Horse] = []
var horses_data: Array[Dictionary] = []
var selected_horse_idx: int = 0
var bet_amount: int = 100
var is_racing: bool = false
var is_odds_calculating: bool = false
var race_elapsed: float = 0.0

var race_seed: int = 0
var race_conditions: Dictionary = {}
var odds_probabilities: Array[float] = []
var odds_multipliers: Array[float] = []
var stamina_current: Array[float] = []
var stamina_max: Array[float] = []
var race_distance_m: Array[float] = []
var skill_used: Array[bool] = []
var finish_order_indices: Array[int] = []

var rng_race: RandomNumberGenerator = RandomNumberGenerator.new()
var rng_odds: RandomNumberGenerator = RandomNumberGenerator.new()
var odds_worker: Node = null

func _ready() -> void:
	horses_data = HorseData.get_all_horses()
	_ensure_horse_cards_container()
	_setup_horses()
	_setup_ui()
	_start_new_round()
	result_panel.visible = false
	race_again_button.visible = false
	_update_coin_label()

func _process(delta: float) -> void:
	if not is_racing:
		return
	race_elapsed += delta

	for i in horse_nodes.size():
		if finish_order_indices.has(i):
			continue
		var node: Horse = horse_nodes[i]
		var data: Dictionary = horses_data[i]
		var move_delta_m: float = _calculate_distance_delta_m(i, data, delta)
		race_distance_m[i] = clampf(race_distance_m[i] + move_delta_m, 0.0, TRACK_DISTANCE_M)
		stamina_current[i] = clampf(stamina_current[i] - move_delta_m, 0.0, 1800.0)
		node.race_distance_m = race_distance_m[i]
		node.position = _horse_position_for_lane(i, race_distance_m[i])
		if race_distance_m[i] >= TRACK_DISTANCE_M:
			finish_order_indices.append(i)

	if finish_order_indices.size() >= horses_data.size():
		finish_race(finish_order_indices[0])

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		return

	if event.is_action_pressed("race_again"):
		if not is_racing and race_again_button.visible:
			reset_for_new_race()
		return

	if is_racing or is_odds_calculating:
		return

	if event.is_action_pressed("select_horse_1"):
		select_horse(0)
	elif event.is_action_pressed("select_horse_2"):
		select_horse(1)
	elif event.is_action_pressed("select_horse_3"):
		select_horse(2)
	elif event.is_action_pressed("select_horse_4"):
		select_horse(3)
	elif event.is_action_pressed("confirm_bet"):
		start_race()

func _setup_horses() -> void:
	for child in horses_container.get_children():
		child.queue_free()
	horse_nodes.clear()

	var horse_scene: PackedScene = preload("res://scenes/entities/Horse.tscn")
	for i in horses_data.size():
		var horse: Horse = horse_scene.instantiate()
		horses_container.add_child(horse)
		horse.setup(horses_data[i])
		horse.position = _horse_position_for_lane(i, 0.0)
		horse.z_index = 20 + i
		horse_nodes.append(horse)

func _horse_position_for_lane(index: int, distance_m: float) -> Vector2:
	var lane_index: int = clampi(index, 0, LANE_Y.size() - 1)
	var x_end: float = finish_line.position.x - 44.0
	var progress: float = clampf(distance_m / TRACK_DISTANCE_M, 0.0, 1.0)
	var x_pos: float = lerpf(START_X, x_end, progress)
	return Vector2(x_pos, LANE_Y[lane_index])

func _setup_ui() -> void:
	minus_button.pressed.connect(_on_minus_pressed)
	plus_button.pressed.connect(_on_plus_pressed)
	confirm_button.pressed.connect(start_race)
	forecast_button.pressed.connect(_on_forecast_pressed)
	race_again_button.pressed.connect(reset_for_new_race)
	back_button.pressed.connect(_on_back_pressed)
	report_button.pressed.connect(_on_report_pressed)
	for i in horse_card_select_buttons.size():
		horse_card_select_buttons[i].pressed.connect(_on_horse_card_select_pressed.bind(i))
		horse_card_info_buttons[i].pressed.connect(_on_horse_card_info_pressed.bind(i))

func _ensure_horse_cards_container() -> void:
	horse_cards_container = %HorseCards
	for child in horse_cards_container.get_children():
		child.queue_free()
	horse_card_names.clear()
	horse_card_odds.clear()
	horse_card_mult.clear()
	horse_card_select_buttons.clear()
	horse_card_info_buttons.clear()

	for i in horses_data.size():
		var card_panel: PanelContainer = PanelContainer.new()
		card_panel.custom_minimum_size = Vector2(0.0, 126.0)
		card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		horse_cards_container.add_child(card_panel)

		var vb: VBoxContainer = VBoxContainer.new()
		vb.add_theme_constant_override("separation", 3)
		card_panel.add_child(vb)

		var name_label: Label = Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.text = str(horses_data[i].get("name", "마필"))
		vb.add_child(name_label)

		var odds_label: Label = Label.new()
		odds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		odds_label.text = "승률 계산중..."
		vb.add_child(odds_label)

		var mult_label: Label = Label.new()
		mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mult_label.text = "배당 계산중..."
		vb.add_child(mult_label)

		var button_row: HBoxContainer = HBoxContainer.new()
		button_row.add_theme_constant_override("separation", 4)
		vb.add_child(button_row)

		var select_button: Button = Button.new()
		select_button.text = "선택"
		select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button_row.add_child(select_button)

		var info_button: Button = Button.new()
		info_button.text = "정보"
		info_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button_row.add_child(info_button)

		horse_card_names.append(name_label)
		horse_card_odds.append(odds_label)
		horse_card_mult.append(mult_label)
		horse_card_select_buttons.append(select_button)
		horse_card_info_buttons.append(info_button)

func _start_new_round() -> void:
	is_racing = false
	race_elapsed = 0.0
	race_seed = int(Time.get_ticks_usec()) ^ int(Time.get_unix_time_from_system()) ^ randi()
	rng_race.seed = race_seed
	rng_odds.seed = race_seed ^ int(0x9E3779B9)

	race_conditions = _make_race_conditions(horses_data.size(), rng_race)
	_prepare_race_arrays()
	for i in horse_nodes.size():
		horse_nodes[i].reset_for_race(_horse_position_for_lane(i, 0.0))
	_update_coin_label()
	update_bet_ui()
	_start_odds_calculation()

func _make_race_conditions(count: int, rng: RandomNumberGenerator) -> Dictionary:
	var form_speed: Array[float] = []
	var form_stamina: Array[float] = []
	for _i in count:
		form_speed.append(rng.randf_range(0.97, 1.03))
		form_stamina.append(rng.randf_range(0.98, 1.04))
	return {
		"track_speed_bias": rng.randf_range(0.98, 1.02),
		"track_variance_scale": rng.randf_range(0.9, 1.15),
		"horse_form_speed": form_speed,
		"horse_form_stamina": form_stamina
	}

func _prepare_race_arrays() -> void:
	stamina_current.clear()
	stamina_max.clear()
	race_distance_m.clear()
	skill_used.clear()
	finish_order_indices.clear()
	for i in horses_data.size():
		var horse: Dictionary = horses_data[i]
		var stamina_value: float = float(horse.get("stamina_max", 1600.0))
		stamina_value *= _condition_array_value("horse_form_stamina", i, 1.0)
		stamina_value = clampf(stamina_value, 1600.0, 1800.0)
		stamina_max.append(stamina_value)
		stamina_current.append(stamina_value)
		race_distance_m.append(0.0)
		skill_used.append(false)

func _calculate_distance_delta_m(index: int, horse: Dictionary, delta: float) -> float:
	var fatigue_multiplier: float = clampf(0.35 + (stamina_current[index] / maxf(stamina_max[index], 1.0)) * 0.85, 0.35, 1.2)
	var form_speed: float = _condition_array_value("horse_form_speed", index, 1.0)
	var base_pace_mps: float = float(horse.get("base_pace_mps", 16.0))
	base_pace_mps *= float(race_conditions.get("track_speed_bias", 1.0))
	base_pace_mps *= form_speed
	var consistency: float = float(horse.get("consistency", 0.6))
	var variance: float = rng_race.randf_range(-0.9, 0.9) * (1.2 - consistency) * float(race_conditions.get("track_variance_scale", 1.0))
	var delta_m: float = maxf((base_pace_mps * fatigue_multiplier + variance) * delta, 0.0)

	var skill_bonus_m: float = HorseData.skill_trigger_bonus_m(horse, race_distance_m[index], stamina_current[index], stamina_max[index], delta, skill_used[index], rng_race)
	if skill_bonus_m > 0.0:
		skill_used[index] = true
	delta_m += skill_bonus_m
	return minf(delta_m, TRACK_DISTANCE_M - race_distance_m[index])

func _condition_array_value(key: String, index: int, fallback: float) -> float:
	var arr_any: Variant = race_conditions.get(key, [])
	if arr_any is Array:
		var arr: Array = arr_any
		if index >= 0 and index < arr.size():
			return float(arr[index])
	return fallback

func _start_odds_calculation() -> void:
	is_odds_calculating = true
	for i in horse_card_odds.size():
		horse_card_odds[i].text = "승률 계산중..."
		horse_card_mult[i].text = "배당 계산중..."
	confirm_button.disabled = true

	if odds_worker != null and is_instance_valid(odds_worker):
		odds_worker.queue_free()

	var odds_script: Script = preload("res://scripts/MonteCarloOdds.gd")
	odds_worker = odds_script.new()
	add_child(odds_worker)
	odds_worker.progress_changed.connect(_on_odds_progress_changed)
	odds_worker.completed.connect(_on_odds_completed)
	odds_worker.start(horses_data, race_conditions, rng_odds.seed, ODDS_SIM_TOTAL, ODDS_SIM_BATCH)

func _on_odds_progress_changed(ratio: float) -> void:
	for label in horse_card_odds:
		label.text = "승률 계산중... %d%%" % int(round(ratio * 100.0))

func _on_odds_completed(prob: Array[float], mult: Array[float]) -> void:
	odds_probabilities = prob
	odds_multipliers = mult
	is_odds_calculating = false
	_update_horse_cards_info()
	update_bet_ui()

func _update_horse_cards_info() -> void:
	for i in horse_card_names.size():
		horse_card_names[i].text = str(horses_data[i].get("name", "마필"))
		if i < odds_probabilities.size() and i < odds_multipliers.size():
			var p: float = odds_probabilities[i]
			var m: float = odds_multipliers[i]
			horse_card_odds[i].text = "승률 %.0f%%" % round(p * 100.0)
			horse_card_mult[i].text = "배당 x%.2f" % m
		else:
			horse_card_odds[i].text = "승률 계산중..."
			horse_card_mult[i].text = "배당 계산중..."

func _on_horse_card_select_pressed(index: int) -> void:
	select_horse(index)

func _on_horse_card_info_pressed(index: int) -> void:
	if index < 0 or index >= horses_data.size():
		return
	horse_info_popup.show_horse_info(horses_data[index])

func select_horse(index: int) -> void:
	if is_racing:
		return
	selected_horse_idx = clampi(index, 0, horses_data.size() - 1)
	for button in horse_card_select_buttons:
		button.modulate = Color(1, 1, 1, 1)
	if selected_horse_idx < horse_card_select_buttons.size():
		horse_card_select_buttons[selected_horse_idx].modulate = Color(1.0, 1.0, 0.65, 1.0)

func _on_minus_pressed() -> void:
	if is_racing or is_odds_calculating:
		return
	bet_amount = max(50, bet_amount - 50)
	update_bet_ui()

func _on_plus_pressed() -> void:
	if is_racing or is_odds_calculating:
		return
	bet_amount = min(GameState.coins, bet_amount + 50)
	bet_amount = max(50, bet_amount)
	update_bet_ui()

func update_bet_ui() -> void:
	if GameState.coins < 50:
		bet_amount = GameState.coins
	else:
		bet_amount = clampi(bet_amount, 50, GameState.coins)
	bet_label.text = "배팅 코인: %d" % bet_amount
	confirm_button.disabled = is_racing or is_odds_calculating or GameState.coins < 50

func start_race() -> void:
	if is_racing or is_odds_calculating:
		return
	if not GameState.can_bet(bet_amount):
		return

	result_panel.visible = false
	race_again_button.visible = false
	is_racing = true
	race_elapsed = 0.0
	_set_controls_locked(true)
	_prepare_race_arrays()
	for i in horse_nodes.size():
		horse_nodes[i].reset_for_race(_horse_position_for_lane(i, 0.0))

func finish_race(winner_idx: int) -> void:
	is_racing = false
	_set_controls_locked(false)

	var result: Dictionary = GameState.apply_race_result(selected_horse_idx, winner_idx, bet_amount, GameState.TEMP_MULTIPLIER, finish_order_indices)
	_update_coin_label()
	update_bet_ui()

	result_label.text = "우승: %s / 내 선택: %s (%s)" % [
		result["winner"],
		result["selected"],
		("적중" if result["hit"] else "미적중")
	]
	settlement_label.text = "정산: %+d 코인 | 현재 코인: %d" % [int(result["profit"]), int(result["coins_after"])]
	result_panel.visible = true
	race_again_button.visible = true

func reset_for_new_race() -> void:
	result_panel.visible = false
	race_again_button.visible = false
	_start_new_round()
	select_horse(0)

func _set_controls_locked(locked: bool) -> void:
	for button in horse_card_select_buttons:
		button.disabled = locked
	for button in horse_card_info_buttons:
		button.disabled = locked
	forecast_button.disabled = locked
	minus_button.disabled = locked
	plus_button.disabled = locked
	confirm_button.disabled = locked or is_odds_calculating or GameState.coins < 50

func _update_coin_label() -> void:
	coin_label.text = "보유 코인: %d" % GameState.coins

func _on_forecast_pressed() -> void:
	var ranking_rows: Array[Dictionary] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = race_seed ^ int(0xABCDEF)
	for i in horses_data.size():
		var horse: Dictionary = horses_data[i]
		var horse_name: String = str(horse.get("name", "마필"))
		var form_score: float = GameState.get_recent_form_score(horse_name)
		var score: float = HorseData.get_forecast_score(horse, form_score, rng)
		ranking_rows.append({"index": i, "score": score})
	ranking_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)

	var ranking_lines: Array[String] = []
	for i in ranking_rows.size():
		var horse_index: int = int(ranking_rows[i].get("index", 0))
		var horse_name: String = str(horses_data[horse_index].get("name", "마필"))
		ranking_lines.append("예상 %d위 - %s" % [i + 1, horse_name])

	var featured_index: int = int(ranking_rows[0].get("index", 0))
	var featured_horse: Dictionary = horses_data[featured_index]
	var featured_skill_any: Variant = featured_horse.get("skill", {})
	var featured_skill: Dictionary = featured_skill_any if featured_skill_any is Dictionary else {}
	var featured_skill_desc: String = str(featured_skill.get("description", "직선 주로에서 주목할 만합니다."))
	var featured_lines: Array[String] = [
		"%s는 이번 편성에서 가장 안정적인 전개가 기대됩니다." % str(featured_horse.get("name", "마필")),
		"%s" % featured_skill_desc,
		"지난 경주 흐름도 나쁘지 않아 다시 한 번 눈여겨볼 필요가 있습니다."
	]

	var record_lines: Array[String] = []
	for horse in horses_data:
		var horse_name: String = str(horse.get("name", "마필"))
		record_lines.append("%s - %s" % [horse_name, GameState.get_recent_form_text(horse_name, 5)])

	forecast_popup.show_forecast(ranking_lines, featured_lines, record_lines)

func _on_back_pressed() -> void:
	if is_racing:
		return
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_report_pressed() -> void:
	print("TODO: Report 기능")
