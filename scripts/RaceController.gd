extends Control

const TRACK_DISTANCE := 1000.0

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
@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_label: Label = $ResultPanel/MarginContainer/ResultVBox/ResultLabel
@onready var settlement_label: Label = $ResultPanel/MarginContainer/ResultVBox/SettlementLabel

var horse_cards_container: HBoxContainer = null
var horse_cards: Array[Button] = []

var horse_nodes: Array[Horse] = []
var horses_data: Array[Dictionary] = []
var selected_horse_idx: int = 0
var bet_amount: int = 100
var is_racing: bool = false
var race_elapsed: float = 0.0

func _ready() -> void:
	_resolve_required_nodes()
	if not _validate_required_nodes():
		set_process(false)
		set_physics_process(false)
		return

	horses_data = HorseData.get_all_horses()
	_ensure_horse_cards_container()
	_setup_horses()
	_setup_ui()
	_update_horse_cards_info()
	select_horse(0)
	update_bet_ui()
	_update_coin_label()
	result_panel.visible = false
	race_again_button.visible = false

func _process(delta: float) -> void:
	if not is_racing:
		return
	race_elapsed += delta
	var winner_idx := -1
	for i in horse_nodes.size():
		var node := horse_nodes[i]
		var data := horses_data[i]
		var progress_ratio: float = clampf(float(node.race_distance) / float(TRACK_DISTANCE), 0.0, 1.0)
		var stamina_value: float = float(data.get("stamina", 1.0))
		var fatigue_multiplier: float = clampf(stamina_value - progress_ratio * 0.35, 0.55, 1.2)
		var speed_variance: float = randf_range(-24.0, 24.0)
		var luck_bonus: float = 0.0
		if randf() < (float(data.get("luck", 0)) / 100.0) * 0.05:
			luck_bonus = randf_range(10.0, 22.0)

		var move_speed: float = float(max(30.0, float(data.get("base_speed", 120.0)) * fatigue_multiplier + speed_variance + luck_bonus))
		var move_delta: float = move_speed * delta
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

	if is_racing:
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
		horse.position = Vector2(80.0, 70.0 + float(i) * 90.0)
		horse.z_index = 5
		horse_nodes.append(horse)

func _setup_ui() -> void:
	minus_button.pressed.connect(_on_minus_pressed)
	plus_button.pressed.connect(_on_plus_pressed)
	confirm_button.pressed.connect(start_race)
	race_again_button.pressed.connect(reset_for_new_race)
	back_button.pressed.connect(_on_back_pressed)
	report_button.pressed.connect(_on_report_pressed)
	for i in horse_cards.size():
		horse_cards[i].pressed.connect(_on_horse_card_pressed.bind(i))

func _ensure_horse_cards_container() -> void:
	horse_cards_container = get_node_or_null("%HorseCards") as HBoxContainer
	if horse_cards_container == null:
		horse_cards_container = find_child("HorseCards", true, false) as HBoxContainer
	if horse_cards_container == null:
		var overlay := CanvasLayer.new()
		overlay.name = "RuntimeHorseCardsLayer"
		add_child(overlay)
		var root_control := Control.new()
		root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.add_child(root_control)
		var runtime_cards := HBoxContainer.new()
		runtime_cards.name = "HorseCards"
		runtime_cards.position = Vector2(24, 72)
		runtime_cards.size = Vector2(1232, 120)
		runtime_cards.add_theme_constant_override("separation", 10)
		root_control.add_child(runtime_cards)
		horse_cards_container = runtime_cards

	for child in horse_cards_container.get_children():
		child.queue_free()
	horse_cards.clear()
	for i in 4:
		var card := Button.new()
		card.custom_minimum_size = Vector2(0, 96)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		horse_cards_container.add_child(card)
		horse_cards.append(card)

func _build_probabilities() -> Array[Dictionary]:
	# TODO: Monte Carlo 시뮬레이션 기반 확률/배당으로 교체
	var scored: Array[Dictionary] = []
	var total_score: float = 0.0
	for data in horses_data:
		var base_speed: float = float(data.get("base_speed", 120.0))
		var stamina: float = float(data.get("stamina", 1.0))
		var luck: float = float(data.get("luck", 0))
		var score: float = base_speed * 1.0 + stamina * 0.6 + (luck / 100.0) * 0.4
		total_score += score
		scored.append({"score": score})

	if total_score <= 0.0:
		total_score = 1.0

	for i in scored.size():
		var p: float = float(scored[i]["score"]) / total_score
		var multiplier: float = clampf((1.0 / max(p, 0.001)) * (1.0 - 0.12), 1.10, 10.0)
		scored[i]["p"] = p
		scored[i]["multiplier"] = multiplier

	return scored

func _update_horse_cards_info() -> void:
	if horse_cards.is_empty() or horses_data.is_empty():
		return
	var probs: Array[Dictionary] = _build_probabilities()
	for i in min(horse_cards.size(), horses_data.size()):
		var data := horses_data[i]
		var p: float = float(probs[i].get("p", 0.25))
		var multiplier: float = float(probs[i].get("multiplier", 2.0))
		horse_cards[i].text = "%s\n승률 %.1f%%\n배당 x%.2f" % [
			str(data.get("name", "말")),
			p * 100.0,
			multiplier
		]

func _on_horse_card_pressed(index: int) -> void:
	select_horse(index)

func select_horse(index: int) -> void:
	if is_racing:
		return
	selected_horse_idx = clamp(index, 0, horses_data.size() - 1)
	for i in horse_cards.size():
		horse_cards[i].modulate = Color(1, 1, 1, 1)
	if selected_horse_idx < horse_cards.size():
		horse_cards[selected_horse_idx].modulate = Color(1.0, 1.0, 0.65, 1.0)

func _on_minus_pressed() -> void:
	if is_racing:
		return
	bet_amount = max(50, bet_amount - 50)
	update_bet_ui()

func _on_plus_pressed() -> void:
	if is_racing:
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
	confirm_button.disabled = is_racing or GameState.coins < 50

func start_race() -> void:
	if is_racing:
		return
	if not GameState.can_bet(bet_amount):
		return

	result_panel.visible = false
	race_again_button.visible = false
	is_racing = true
	race_elapsed = 0.0
	_set_controls_locked(true)

	for horse in horse_nodes:
		horse.reset_for_race(80.0)

func finish_race(winner_idx: int) -> void:
	is_racing = false
	_set_controls_locked(false)

	var result := GameState.apply_race_result(selected_horse_idx, winner_idx, bet_amount)
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
	for horse in horse_nodes:
		horse.reset_for_race(80.0)
	update_bet_ui()

func _set_controls_locked(locked: bool) -> void:
	for card in horse_cards:
		card.disabled = locked
	minus_button.disabled = locked
	plus_button.disabled = locked
	confirm_button.disabled = locked or GameState.coins < 50

func _update_coin_label() -> void:
	coin_label.text = "보유 코인: %d" % GameState.coins

func _on_back_pressed() -> void:
	if is_racing:
		return
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_report_pressed() -> void:
	# TODO: 리포트 기능은 다음 작업에서 구현
	print("TODO: Report 기능")
