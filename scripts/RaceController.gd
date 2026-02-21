extends Control

const TRACK_DISTANCE := 1000.0
const TRACK_BG_TEXTURE_PATH := "res://assets/sprites/track/track_bg.png"
const ODDS_SIM_TOTAL := 500
const ODDS_SIM_BATCH := 25

@onready var coin_label: Label = $RootMargin/MainVBox/TopBar/CoinLabel
@onready var bet_label: Label = $RootMargin/MainVBox/BetPanel/BetLabel
@onready var minus_button: Button = $RootMargin/MainVBox/BetPanel/MinusButton
@onready var plus_button: Button = $RootMargin/MainVBox/BetPanel/PlusButton
@onready var confirm_button: Button = $RootMargin/MainVBox/BetPanel/ConfirmBetButton
@onready var race_again_button: Button = $RootMargin/MainVBox/BottomButtons/RaceAgainButton
@onready var back_button: Button = $RootMargin/MainVBox/BottomButtons/BackButton
@onready var report_button: Button = $RootMargin/MainVBox/BottomButtons/ReportButton

@onready var horses_container: Node2D = get_node_or_null("%HorsesLayer") as Node2D
@onready var finish_line: ColorRect = get_node_or_null("%FinishLine") as ColorRect
@onready var track_bg: ColorRect = get_node_or_null("%TrackBg") as ColorRect
@onready var track_bg_sprite: Sprite2D = get_node_or_null("%TrackBgSprite") as Sprite2D
@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_label: Label = $ResultPanel/MarginContainer/ResultVBox/ResultLabel
@onready var settlement_label: Label = $ResultPanel/MarginContainer/ResultVBox/SettlementLabel

var horse_cards_container: HBoxContainer = null
var horse_card_names: Array[Label] = []
var horse_card_odds: Array[Label] = []
var horse_card_mult: Array[Label] = []
var horse_card_buttons: Array[Button] = []

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

var rng_race: RandomNumberGenerator = RandomNumberGenerator.new()
var rng_odds: RandomNumberGenerator = RandomNumberGenerator.new()
var odds_worker: Node = null

func _ready() -> void:
	randomize()
	_resolve_required_nodes()
	if not _validate_required_nodes():
		set_process(false)
		set_physics_process(false)
		return

	horses_data = HorseData.get_all_horses()
	_ensure_horse_cards_container()
	_setup_horses()
	_setup_ui()
	_apply_track_background_asset()
	_start_new_round()
	result_panel.visible = false
	race_again_button.visible = false
	_update_coin_label()

func _process(delta: float) -> void:
	if not is_racing:
		return
	race_elapsed += delta
	var winner_idx: int = -1
	for i in horse_nodes.size():
		var node: Horse = horse_nodes[i]
		var data: Dictionary = horses_data[i]
		var progress_ratio: float = clampf(float(node.race_distance) / float(TRACK_DISTANCE), 0.0, 1.0)
		var fatigue_scale: float = float(race_conditions.get("fatigue_scale", 1.0))
		stamina_current[i] = maxf(0.1, stamina_current[i] - delta * (0.35 + progress_ratio * 0.75) * fatigue_scale)
		var fatigue_multiplier: float = clampf(0.55 + (stamina_current[i] / maxf(stamina_max[i], 0.1)) * 0.65, 0.55, 1.2)

		var form_speed: float = _condition_array_value("horse_form_speed", i, 1.0)
		var base_speed: float = float(data.get("base_speed", 120.0))
		base_speed *= float(race_conditions.get("track_speed_bias", 1.0))
		base_speed *= form_speed

		var variance: float = rng_race.randf_range(-40.0, 40.0) * float(race_conditions.get("track_variance_scale", 1.0))
		var luck: float = float(data.get("luck", 0))
		var per_second_chance: float = (luck / 100.0) * 0.9 * float(race_conditions.get("luck_event_scale", 1.0))
		var luck_boost: float = 0.0
		if rng_race.randf() < per_second_chance * delta:
			luck_boost = rng_race.randf_range(25.0, 80.0) * (1.0 - progress_ratio * 0.5)

		var move_delta: float = maxf((base_speed * fatigue_multiplier + variance + luck_boost) * delta, 0.0)
		node.race_distance += move_delta
		node.position.x += move_delta
		if node.position.x >= finish_line.position.x and winner_idx == -1:
			winner_idx = i

	if winner_idx != -1:
		finish_race(winner_idx)

func _resolve_required_nodes() -> void:
	if horses_container == null:
		horses_container = find_child("HorsesLayer", true, false) as Node2D
	if finish_line == null:
		finish_line = find_child("FinishLine", true, false) as ColorRect
	if track_bg == null:
		track_bg = find_child("TrackBg", true, false) as ColorRect
	if track_bg_sprite == null:
		track_bg_sprite = find_child("TrackBgSprite", true, false) as Sprite2D

func _validate_required_nodes() -> bool:
	if horses_container == null:
		push_error("RaceController: HorsesLayer not found. Check Race.tscn node name + Unique Name in Owner.")
		return false
	if finish_line == null:
		push_error("RaceController: FinishLine not found. Check Race.tscn node name + Unique Name in Owner.")
		return false
	return true

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
		return
	for child in horses_container.get_children():
		child.queue_free()
	horse_nodes.clear()

	var horse_scene: PackedScene = preload("res://scenes/entities/Horse.tscn")
	for i in horses_data.size():
		var horse: Horse = horse_scene.instantiate()
		horses_container.add_child(horse)
		horse.setup(horses_data[i])
		horse.position = Vector2(90.0, 70.0 + float(i) * 90.0)
		horse.z_index = 5
		horse_nodes.append(horse)

func _setup_ui() -> void:
	minus_button.pressed.connect(_on_minus_pressed)
	plus_button.pressed.connect(_on_plus_pressed)
	confirm_button.pressed.connect(start_race)
	race_again_button.pressed.connect(reset_for_new_race)
	back_button.pressed.connect(_on_back_pressed)
	report_button.pressed.connect(_on_report_pressed)
	for i in horse_card_buttons.size():
		horse_card_buttons[i].pressed.connect(_on_horse_card_pressed.bind(i))

func _ensure_horse_cards_container() -> void:
	horse_cards_container = get_node_or_null("%HorseCards") as HBoxContainer
	if horse_cards_container == null:
		horse_cards_container = find_child("HorseCards", true, false) as HBoxContainer
	if horse_cards_container == null:
		var overlay: CanvasLayer = CanvasLayer.new()
		overlay.name = "RuntimeHorseCardsLayer"
		add_child(overlay)
		var root_control: Control = Control.new()
		root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.add_child(root_control)
		var runtime_cards: HBoxContainer = HBoxContainer.new()
		runtime_cards.name = "HorseCards"
		runtime_cards.position = Vector2(24, 72)
		runtime_cards.size = Vector2(1232, 120)
		runtime_cards.add_theme_constant_override("separation", 10)
		root_control.add_child(runtime_cards)
		horse_cards_container = runtime_cards

	for child in horse_cards_container.get_children():
		child.queue_free()
	horse_card_names.clear()
	horse_card_odds.clear()
	horse_card_mult.clear()
	horse_card_buttons.clear()

	for i in horses_data.size():
		var card_panel: PanelContainer = PanelContainer.new()
		card_panel.custom_minimum_size = Vector2(0, 106)
		card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		horse_cards_container.add_child(card_panel)

		var vb: VBoxContainer = VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		card_panel.add_child(vb)

		var name_label: Label = Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.text = str(horses_data[i].get("name", "말"))
		vb.add_child(name_label)

		var odds_label: Label = Label.new()
		odds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		odds_label.text = "승률 계산중..."
		vb.add_child(odds_label)

		var mult_label: Label = Label.new()
		mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mult_label.text = "배당 계산중..."
		vb.add_child(mult_label)

		var select_button: Button = Button.new()
		select_button.text = "선택"
		vb.add_child(select_button)

		horse_card_names.append(name_label)
		horse_card_odds.append(odds_label)
		horse_card_mult.append(mult_label)
		horse_card_buttons.append(select_button)

func _apply_track_background_asset() -> void:
	if track_bg_sprite == null:
		return
	if ResourceLoader.exists(TRACK_BG_TEXTURE_PATH):
		var texture: Texture2D = load(TRACK_BG_TEXTURE_PATH)
		if texture != null:
			track_bg_sprite.texture = texture
			track_bg_sprite.position = Vector2(0, 0)
			track_bg_sprite.centered = false
			track_bg_sprite.visible = true
			if track_bg != null:
				track_bg.visible = false
			return
	track_bg_sprite.visible = false
	if track_bg != null:
		track_bg.visible = true

func _start_new_round() -> void:
	is_racing = false
	race_elapsed = 0.0
	randomize()
	race_seed = int(Time.get_ticks_usec()) ^ int(Time.get_unix_time_from_system()) ^ randi()
	rng_race.seed = race_seed
	rng_odds.seed = race_seed ^ int(0x9E3779B9)

	race_conditions = _make_race_conditions(horses_data.size(), rng_race)
	_prepare_stamina_arrays()
	for horse in horse_nodes:
		horse.reset_for_race(90.0)
	_update_coin_label()
	update_bet_ui()
	_start_odds_calculation()

func _make_race_conditions(count: int, rng: RandomNumberGenerator) -> Dictionary:
	var form_speed: Array[float] = []
	var form_stamina: Array[float] = []
	for _i in count:
		form_speed.append(rng.randf_range(0.95, 1.05))
		form_stamina.append(rng.randf_range(0.90, 1.10))
	return {
		"track_speed_bias": rng.randf_range(0.98, 1.02),
		"track_variance_scale": rng.randf_range(0.8, 1.4),
		"fatigue_scale": rng.randf_range(0.9, 1.15),
		"horse_form_speed": form_speed,
		"horse_form_stamina": form_stamina,
		"luck_event_scale": rng.randf_range(0.8, 1.3)
	}

func _prepare_stamina_arrays() -> void:
	stamina_current.clear()
	stamina_max.clear()
	for i in horses_data.size():
		var stamina: float = float(horses_data[i].get("stamina", 1.0))
		stamina *= _condition_array_value("horse_form_stamina", i, 1.0)
		stamina = maxf(stamina, 0.1)
		stamina_max.append(stamina)
		stamina_current.append(stamina)

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
		horse_card_names[i].text = str(horses_data[i].get("name", "말"))
		if i < odds_probabilities.size() and i < odds_multipliers.size():
			var p: float = odds_probabilities[i]
			var m: float = odds_multipliers[i]
			horse_card_odds[i].text = "승률 %.0f%%" % round(p * 100.0)
			horse_card_mult[i].text = "배당 x%.2f" % m
		else:
			horse_card_odds[i].text = "승률 계산중..."
			horse_card_mult[i].text = "배당 계산중..."

func _on_horse_card_pressed(index: int) -> void:
	select_horse(index)

func select_horse(index: int) -> void:
	if is_racing:
		return
	selected_horse_idx = clamp(index, 0, horses_data.size() - 1)
	for i in horse_card_buttons.size():
		horse_card_buttons[i].modulate = Color(1, 1, 1, 1)
	if selected_horse_idx < horse_card_buttons.size():
		horse_card_buttons[selected_horse_idx].modulate = Color(1.0, 1.0, 0.65, 1.0)

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
		bet_amount = clamp(bet_amount, 50, GameState.coins)
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
	_prepare_stamina_arrays()

	for horse in horse_nodes:
		horse.reset_for_race(90.0)

func finish_race(winner_idx: int) -> void:
	is_racing = false
	_set_controls_locked(false)

	var result: Dictionary = GameState.apply_race_result(selected_horse_idx, winner_idx, bet_amount)
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
	for button in horse_card_buttons:
		button.disabled = locked
	minus_button.disabled = locked
	plus_button.disabled = locked
	confirm_button.disabled = locked or is_odds_calculating or GameState.coins < 50

func _update_coin_label() -> void:
	coin_label.text = "보유 코인: %d" % GameState.coins

func _on_back_pressed() -> void:
	if is_racing:
		return
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_report_pressed() -> void:
	# TODO: 리포트 기능은 다음 작업에서 구현
	print("TODO: Report 기능")
