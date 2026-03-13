extends Control

const TRACK_DISTANCE_M: float = 1600.0
const ODDS_SIM_TOTAL: int = 500
const ODDS_SIM_BATCH: int = 25
const START_X: float = 100.0
const LANE_Y: Array[float] = [70.0, 190.0, 310.0, 430.0]
const RACE_TIME_SCALE: float = 3.7
const MAX_RACE_SECONDS: float = 26.0

@onready var coin_label: Label = $RootMargin/MainVBox/TopBar/CoinLabel
@onready var forecast_button: Button = $RootMargin/MainVBox/TopBar/ForecastButton
@onready var bet_label: Label = $RootMargin/MainVBox/BetPanel/BetLabel
@onready var minus_button: Button = $RootMargin/MainVBox/BetPanel/MinusButton
@onready var plus_button: Button = $RootMargin/MainVBox/BetPanel/PlusButton
@onready var confirm_button: Button = $RootMargin/MainVBox/BetPanel/ConfirmBetButton
@onready var race_again_button: Button = $RootMargin/MainVBox/BottomButtons/RaceAgainButton
@onready var back_button: Button = $RootMargin/MainVBox/BottomButtons/BackButton
@onready var report_button: Button = $RootMargin/MainVBox/BottomButtons/ReportButton

@onready var horses_container: Node2D = get_node_or_null("%HorsesLayer") as Node2D
@onready var finish_line: ColorRect = get_node_or_null("%FinishLine") as ColorRect
@onready var result_panel: PanelContainer = get_node_or_null("ResultPanel") as PanelContainer
@onready var result_label: Label = get_node_or_null("ResultPanel/MarginContainer/ResultVBox/ResultLabel") as Label
@onready var rank_label: Label = get_node_or_null("ResultPanel/MarginContainer/ResultVBox/RankLabel") as Label
@onready var settlement_label: Label = get_node_or_null("ResultPanel/MarginContainer/ResultVBox/SettlementLabel") as Label
@onready var horse_info_popup: HorseInfoPopup = get_node_or_null("HorseInfoPopup") as HorseInfoPopup
@onready var forecast_popup: ForecastPopup = get_node_or_null("ForecastPopup") as ForecastPopup

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
var skill_logs: Array[String] = []
var finish_order_indices: Array[int] = []

var rng_race: RandomNumberGenerator = RandomNumberGenerator.new()
var rng_odds: RandomNumberGenerator = RandomNumberGenerator.new()
var odds_worker: Node = null

func _ready() -> void:
	_resolve_fallback_nodes()
	horses_data = HorseData.get_all_horses()
	_ensure_horse_cards_container()
	_setup_horses()
	_setup_ui()
	_ensure_rank_label_exists()
	_ensure_info_popup_exists()
	_ensure_forecast_popup_exists()
	_start_new_round()
	if result_panel != null:
		result_panel.visible = false
	race_again_button.visible = false
	_update_coin_label()

func _resolve_fallback_nodes() -> void:
	if horses_container == null:
		horses_container = find_child("HorsesLayer", true, false) as Node2D
	if finish_line == null:
		finish_line = find_child("FinishLine", true, false) as ColorRect
	if horse_cards_container == null:
		horse_cards_container = find_child("HorseCards", true, false) as HBoxContainer
	if result_panel == null:
		result_panel = find_child("ResultPanel", true, false) as PanelContainer
	if result_label == null:
		result_label = find_child("ResultLabel", true, false) as Label
	if rank_label == null:
		rank_label = find_child("RankLabel", true, false) as Label
	if settlement_label == null:
		settlement_label = find_child("SettlementLabel", true, false) as Label
	if horse_info_popup == null:
		horse_info_popup = find_child("HorseInfoPopup", true, false) as HorseInfoPopup
	if forecast_popup == null:
		forecast_popup = find_child("ForecastPopup", true, false) as ForecastPopup

func _process(delta: float) -> void:
	if not is_racing:
		return
	race_elapsed += delta

	for i in horse_nodes.size():
		if finish_order_indices.has(i):
			continue
		var data: Dictionary = horses_data[i]
		var move_delta_m: float = _calculate_distance_delta_m(i, data, delta)
		race_distance_m[i] = clampf(race_distance_m[i] + move_delta_m, 0.0, TRACK_DISTANCE_M)
		stamina_current[i] = clampf(stamina_current[i] - move_delta_m, 0.0, 1800.0)
		horse_nodes[i].race_distance_m = race_distance_m[i]
		horse_nodes[i].position = _horse_position_for_lane(i, race_distance_m[i])
		if race_distance_m[i] >= TRACK_DISTANCE_M and not finish_order_indices.has(i):
			finish_order_indices.append(i)
			print("[Race] 결승 통과: %s (%d착 확정)" % [str(data.get("name", "마필")), finish_order_indices.size()])

	if race_elapsed >= MAX_RACE_SECONDS and finish_order_indices.size() < horses_data.size():
		_finalize_unfinished_horses()

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
	if horses_container == null:
		push_error("RaceController: HorsesLayer not found")
		return
	for child in horses_container.get_children():
		child.queue_free()
	horse_nodes.clear()

	var horse_scene: PackedScene = preload("res://scenes/entities/Horse.tscn")
	for i in horses_data.size():
		var horse: Horse = horse_scene.instantiate() as Horse
		horses_container.add_child(horse)
		horse.setup(horses_data[i])
		horse.position = _horse_position_for_lane(i, 0.0)
		horse.z_index = 20 + i
		horse_nodes.append(horse)

func _horse_position_for_lane(index: int, distance_m: float) -> Vector2:
	var lane_index: int = clampi(index, 0, LANE_Y.size() - 1)
	var x_end: float = 1060.0
	if finish_line != null:
		x_end = finish_line.position.x - 44.0
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
	if horse_cards_container == null:
		horse_cards_container = get_node_or_null("%HorseCards") as HBoxContainer
	if horse_cards_container == null:
		horse_cards_container = find_child("HorseCards", true, false) as HBoxContainer
	if horse_cards_container == null:
		push_error("RaceController: HorseCards not found")
		return

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
		info_button.text = "마필 정보"
		info_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button_row.add_child(info_button)

		horse_card_names.append(name_label)
		horse_card_odds.append(odds_label)
		horse_card_mult.append(mult_label)
		horse_card_select_buttons.append(select_button)
		horse_card_info_buttons.append(info_button)

func _prepare_race_arrays() -> void:
	stamina_current.clear()
	stamina_max.clear()
	race_distance_m.clear()
	skill_used.clear()
	skill_logs.clear()
	finish_order_indices.clear()
	for i in horses_data.size():
		var horse: Dictionary = horses_data[i]
		var stamina_value: float = float(horse.get("stamina", 1600.0))
		stamina_value *= _condition_array_value("horse_form_stamina", i, 1.0)
		stamina_value = clampf(stamina_value, 1600.0, 1800.0)
		stamina_max.append(stamina_value)
		stamina_current.append(stamina_value)
		race_distance_m.append(0.0)
		skill_used.append(false)

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
	var form_skill: Array[float] = []
	for _i in count:
		form_speed.append(rng.randf_range(0.96, 1.04))
		form_stamina.append(rng.randf_range(0.95, 1.05))
		form_skill.append(rng.randf_range(0.9, 1.1))
	return {
		"track_speed_bias": rng.randf_range(0.98, 1.03),
		"track_variance_scale": rng.randf_range(0.95, 1.35),
		"horse_form_speed": form_speed,
		"horse_form_stamina": form_stamina,
		"horse_form_skill": form_skill
	}

func _calculate_distance_delta_m(index: int, horse: Dictionary, delta: float) -> float:
	var time_delta_scaled: float = delta * RACE_TIME_SCALE
	var stamina_ratio: float = stamina_current[index] / maxf(stamina_max[index], 1.0)
	var fatigue_multiplier: float = clampf(0.5 + stamina_ratio * 0.8, 0.5, 1.25)
	var form_speed: float = _condition_array_value("horse_form_speed", index, 1.0)
	var base_pace_mps: float = float(horse.get("base_speed", 17.8))
	base_pace_mps *= float(race_conditions.get("track_speed_bias", 1.0))
	base_pace_mps *= form_speed

	var luck_value: float = float(int(horse.get("luck", 58)))
	var consistency: float = clampf(0.45 + (luck_value / 100.0) * 0.7, 0.45, 0.9)
	var progress_ratio: float = clampf(race_distance_m[index] / TRACK_DISTANCE_M, 0.0, 1.0)
	var phase_bonus: float = 0.0
	if progress_ratio < 0.25:
		phase_bonus = rng_race.randf_range(-0.6, 0.8)
	elif progress_ratio < 0.75:
		phase_bonus = rng_race.randf_range(-0.7, 0.9)
	else:
		phase_bonus = rng_race.randf_range(-0.9, 1.2)

	var variance: float = rng_race.randf_range(-1.3, 1.3) * (1.28 - consistency) * float(race_conditions.get("track_variance_scale", 1.0))
	var delta_m: float = maxf((base_pace_mps * fatigue_multiplier + variance + phase_bonus) * time_delta_scaled, 0.0)

	var skill_form: float = _condition_array_value("horse_form_skill", index, 1.0)
	var skill_bonus_m: float = HorseData.skill_trigger_bonus_m(horse, race_distance_m[index], stamina_current[index], stamina_max[index], time_delta_scaled, skill_used[index], rng_race, skill_form)
	if skill_bonus_m > 0.0:
		skill_used[index] = true
		var skill_name: String = str(horse.get("skill_name", "스킬"))
		var horse_name: String = str(horse.get("name", "마필"))
		var log_line: String = "%s 발동: %s (+%.2fm)" % [skill_name, horse_name, skill_bonus_m]
		skill_logs.append(log_line)
		print("[Skill] %s" % log_line)
	delta_m += skill_bonus_m

	return minf(delta_m, TRACK_DISTANCE_M - race_distance_m[index])

func _condition_array_value(key: String, index: int, fallback: float) -> float:
	var arr_any: Variant = race_conditions.get(key, [])
	if arr_any is Array:
		var arr: Array = arr_any
		if index >= 0 and index < arr.size():
			return float(arr[index])
	return fallback

func _finalize_unfinished_horses() -> void:
	var remain: Array[Dictionary] = []
	for i in horses_data.size():
		if not finish_order_indices.has(i):
			remain.append({"index": i, "distance": race_distance_m[i]})
	remain.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", 0.0)) > float(b.get("distance", 0.0))
	)
	for row in remain:
		finish_order_indices.append(int(row.get("index", 0)))
	print("[Race] 시간 종료 보정으로 순위 확정")

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
	print("[UI] 마필 정보 버튼 클릭 index=%d" % index)
	if index < 0 or index >= horses_data.size():
		return
	if horse_info_popup == null:
		_ensure_info_popup_exists()
	if horse_info_popup != null:
		horse_info_popup.show_horse_info(horses_data[index])
		print("[UI] 마필 정보 팝업 오픈 성공")
	else:
		print("[UI] 마필 정보 팝업 생성 실패")

func _ensure_info_popup_exists() -> void:
	if horse_info_popup != null:
		return
	var popup_scene: PackedScene = preload("res://scenes/ui/HorseInfoPopup.tscn")
	var popup: Node = popup_scene.instantiate()
	add_child(popup)
	horse_info_popup = popup as HorseInfoPopup

func _ensure_forecast_popup_exists() -> void:
	if forecast_popup != null:
		return
	var popup_scene: PackedScene = preload("res://scenes/ui/ForecastPopup.tscn")
	var popup: Node = popup_scene.instantiate()
	add_child(popup)
	forecast_popup = popup as ForecastPopup

func _ensure_rank_label_exists() -> void:
	if rank_label != null:
		return
	if result_label == null:
		return
	var parent_node: Node = result_label.get_parent()
	if parent_node == null:
		return
	var new_label: Label = Label.new()
	new_label.name = "RankLabel"
	new_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_label.text = "순위: 대기중"
	parent_node.add_child(new_label)
	rank_label = new_label

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

	if result_panel != null:
		result_panel.visible = false
	race_again_button.visible = false
	is_racing = true
	race_elapsed = 0.0
	_set_controls_locked(true)
	_prepare_race_arrays()
	for i in horse_nodes.size():
		horse_nodes[i].reset_for_race(_horse_position_for_lane(i, 0.0))

func finish_race(winner_idx: int) -> void:
	if not is_racing:
		return
	is_racing = false
	_set_controls_locked(false)

	if finish_order_indices.size() < horses_data.size():
		_finalize_unfinished_horses()

	var result: Dictionary = GameState.apply_race_result(selected_horse_idx, winner_idx, bet_amount, GameState.TEMP_MULTIPLIER, finish_order_indices)
	_update_coin_label()
	update_bet_ui()
	_update_result_panel(result)
	print("[Race] 최종 순위: %s" % str(finish_order_indices))

func _update_result_panel(result: Dictionary) -> void:
	if result_panel == null or result_label == null or settlement_label == null:
		return
	var selected_name: String = str(result.get("selected", "마필"))
	var selected_rank: int = _find_rank_by_name(selected_name)
	var rank_lines: Array[String] = []
	if finish_order_indices.is_empty():
		rank_lines.append("순위 정보 없음")
	else:
		for i in finish_order_indices.size():
			var idx: int = finish_order_indices[i]
			var horse_name: String = str(horses_data[idx].get("name", "마필"))
			rank_lines.append("%d착 %s" % [i + 1, horse_name])

	var result_title: String = "내 선택: %s (%s)" % [selected_name, ("적중" if bool(result.get("hit", false)) else "미적중")]
	if selected_rank > 0:
		result_title += " / 내 순위: %d착" % selected_rank
	else:
		result_title += " / 내 순위: 확인 불가"
	result_label.text = result_title
	if rank_label != null:
		rank_label.text = "\n".join(rank_lines)
	settlement_label.text = "정산: %+d 코인 | 현재 코인: %d" % [int(result.get("profit", 0)), int(result.get("coins_after", 0))]
	if not skill_logs.is_empty():
		settlement_label.text += "\n스킬 로그: %s" % " | ".join(skill_logs)
	result_panel.visible = true
	race_again_button.visible = true

func _find_rank_by_name(name: String) -> int:
	for i in finish_order_indices.size():
		var idx: int = finish_order_indices[i]
		if str(horses_data[idx].get("name", "")) == name:
			return i + 1
	return -1

func reset_for_new_race() -> void:
	if result_panel != null:
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
	if forecast_popup == null:
		_ensure_forecast_popup_exists()
	if forecast_popup == null:
		return

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
	var featured_skill_desc: String = str(featured_horse.get("skill_desc", "직선 주로에서 주목할 만합니다."))
	var featured_lines: Array[String] = [
		"%s는 이번 편성에서 가장 안정적인 전개가 기대됩니다." % str(featured_horse.get("name", "마필")),
		featured_skill_desc,
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

func debug_run_balance_test(rounds: int = 20) -> void:
	var local_rounds: int = max(1, rounds)
	var win_counts: Dictionary = {}
	for horse in horses_data:
		win_counts[str(horse.get("name", "마필"))] = 0

	var sim_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	sim_rng.randomize()
	for _r in local_rounds:
		var sim_conditions: Dictionary = _make_race_conditions(horses_data.size(), sim_rng)
		var sim_distance: Array[float] = [0.0, 0.0, 0.0, 0.0]
		var sim_stamina: Array[float] = []
		var sim_stamina_max: Array[float] = []
		var sim_skill_used: Array[bool] = [false, false, false, false]
		for i in horses_data.size():
			var st: float = float(horses_data[i].get("stamina", 1600.0))
			st *= _array_value_from_conditions(sim_conditions, "horse_form_stamina", i, 1.0)
			st = clampf(st, 1600.0, 1800.0)
			sim_stamina.append(st)
			sim_stamina_max.append(st)
		var sim_finish: Array[int] = []
		var sim_elapsed: float = 0.0
		while sim_finish.size() < horses_data.size() and sim_elapsed < MAX_RACE_SECONDS:
			for i in horses_data.size():
				if sim_finish.has(i):
					continue
				var horse: Dictionary = horses_data[i]
				var dt: float = 0.1 * RACE_TIME_SCALE
				var form_speed: float = _array_value_from_conditions(sim_conditions, "horse_form_speed", i, 1.0)
				var pace: float = float(horse.get("base_speed", 17.8)) * float(sim_conditions.get("track_speed_bias", 1.0)) * form_speed
				var luck_value: float = float(int(horse.get("luck", 58)))
				var consistency: float = clampf(0.45 + (luck_value / 100.0) * 0.7, 0.45, 0.9)
				var fatigue: float = clampf(0.5 + (sim_stamina[i] / maxf(sim_stamina_max[i], 1.0)) * 0.8, 0.5, 1.25)
				var variance: float = sim_rng.randf_range(-1.5, 1.5) * (1.3 - consistency) * float(sim_conditions.get("track_variance_scale", 1.0))
				var delta_m: float = maxf((pace * fatigue + variance) * dt, 0.0)
				var skill_form: float = _array_value_from_conditions(sim_conditions, "horse_form_skill", i, 1.0)
				var skill_bonus: float = HorseData.skill_trigger_bonus_m(horse, sim_distance[i], sim_stamina[i], sim_stamina_max[i], dt, sim_skill_used[i], sim_rng, skill_form)
				if skill_bonus > 0.0:
					sim_skill_used[i] = true
				delta_m += skill_bonus
				delta_m = minf(delta_m, TRACK_DISTANCE_M - sim_distance[i])
				sim_distance[i] += delta_m
				sim_stamina[i] = clampf(sim_stamina[i] - delta_m, 0.0, 1800.0)
				if sim_distance[i] >= TRACK_DISTANCE_M:
					sim_finish.append(i)
			sim_elapsed += 0.1
		if sim_finish.size() < horses_data.size():
			var remain: Array[Dictionary] = []
			for i in horses_data.size():
				if not sim_finish.has(i):
					remain.append({"index": i, "distance": sim_distance[i]})
			remain.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return float(a.get("distance", 0.0)) > float(b.get("distance", 0.0))
			)
			for row in remain:
				sim_finish.append(int(row.get("index", 0)))
		var win_name: String = str(horses_data[sim_finish[0]].get("name", "마필"))
		win_counts[win_name] = int(win_counts.get(win_name, 0)) + 1

	var lines: Array[String] = []
	for horse in horses_data:
		var name: String = str(horse.get("name", "마필"))
		lines.append("%s %d승" % [name, int(win_counts.get(name, 0))])
	print("[BalanceTest %d판] %s" % [local_rounds, " / ".join(lines)])

func _array_value_from_conditions(conditions: Dictionary, key: String, index: int, fallback: float) -> float:
	var arr_any: Variant = conditions.get(key, [])
	if arr_any is Array:
		var arr: Array = arr_any
		if index >= 0 and index < arr.size():
			return float(arr[index])
	return fallback
