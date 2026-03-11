extends Node

const START_COINS: int = 1000
const TEMP_MULTIPLIER: float = 2.0
const RECENT_FORM_LIMIT: int = 5

var coins: int = START_COINS
var total_profit: int = 0
var stats: Dictionary = {}
var horse_stats: Dictionary = {}
var recent_results: Array = []
var horse_recent_form: Dictionary = {}

func _ready() -> void:
	load_game()

func default_data() -> Dictionary:
	var horse_stat_defaults: Dictionary = {}
	var horse_form_defaults: Dictionary = {}
	for horse in HorseData.get_all_horses():
		var horse_name: String = str(horse.get("name", "마필"))
		horse_stat_defaults[horse_name] = {
			"selected": 0,
			"wins": 0
		}
		horse_form_defaults[horse_name] = []

	return {
		"version": SaveSystem.VERSION,
		"coins": START_COINS,
		"total_profit": 0,
		"stats": {
			"total_races": 0,
			"wins": 0,
			"losses": 0,
			"best_profit": 0
		},
		"horse_stats": horse_stat_defaults,
		"recent_results": [],
		"horse_recent_form": horse_form_defaults
	}

func load_game() -> void:
	var loaded: Dictionary = SaveSystem.load_or_init(default_data())
	coins = max(0, int(loaded.get("coins", START_COINS)))
	total_profit = int(loaded.get("total_profit", 0))
	stats = loaded.get("stats", {}).duplicate(true)
	horse_stats = loaded.get("horse_stats", {}).duplicate(true)
	recent_results = loaded.get("recent_results", []).duplicate(true)
	horse_recent_form = loaded.get("horse_recent_form", {}).duplicate(true)
	_ensure_horse_maps()

func save_game() -> void:
	var data: Dictionary = {
		"version": SaveSystem.VERSION,
		"coins": coins,
		"total_profit": total_profit,
		"stats": stats,
		"horse_stats": horse_stats,
		"recent_results": recent_results,
		"horse_recent_form": horse_recent_form
	}
	SaveSystem.save(data)

func _ensure_horse_maps() -> void:
	for horse in HorseData.get_all_horses():
		var horse_name: String = str(horse.get("name", "마필"))
		if not horse_stats.has(horse_name):
			horse_stats[horse_name] = {"selected": 0, "wins": 0}
		if not horse_recent_form.has(horse_name):
			horse_recent_form[horse_name] = []

func can_bet(amount: int) -> bool:
	return amount >= 50 and amount <= coins

func get_recent_form_score(horse_name: String) -> float:
	if not horse_recent_form.has(horse_name):
		return 0.0
	var form_array_any: Variant = horse_recent_form.get(horse_name, [])
	if not (form_array_any is Array):
		return 0.0
	var form_array: Array = form_array_any
	if form_array.is_empty():
		return 0.0
	var weighted_sum: float = 0.0
	var total_weight: float = 0.0
	for i in form_array.size():
		var place: int = int(form_array[i])
		var weight: float = float(form_array.size() - i)
		var score: float = 0.0
		if place == 1:
			score = 1.0
		elif place == 2:
			score = 0.65
		elif place == 3:
			score = 0.35
		else:
			score = 0.1
		weighted_sum += score * weight
		total_weight += weight
	if total_weight <= 0.0:
		return 0.0
	return (weighted_sum / total_weight) * 2.0 - 1.0

func get_recent_form_text(horse_name: String, count: int = 3) -> String:
	var results: Array = horse_recent_form.get(horse_name, [])
	if results.is_empty():
		return "전적 없음"
	var limit: int = min(count, results.size())
	var texts: Array[String] = []
	for i in limit:
		var place: int = int(results[i])
		texts.append("%d착" % place)
	return "최근 성적: %s" % " - ".join(texts)

func update_recent_form_by_order(order_indices: Array[int]) -> void:
	var horses: Array[Dictionary] = HorseData.get_all_horses()
	for i in order_indices.size():
		var horse_index: int = order_indices[i]
		if horse_index < 0 or horse_index >= horses.size():
			continue
		var horse_name: String = str(horses[horse_index].get("name", "마필"))
		if not horse_recent_form.has(horse_name):
			horse_recent_form[horse_name] = []
		var arr_any: Variant = horse_recent_form[horse_name]
		if not (arr_any is Array):
			arr_any = []
		var form_array: Array = arr_any
		form_array.push_front(i + 1)
		while form_array.size() > RECENT_FORM_LIMIT:
			form_array.pop_back()
		horse_recent_form[horse_name] = form_array

func apply_race_result(selected_index: int, winner_index: int, bet: int, multiplier: float = TEMP_MULTIPLIER, finish_order: Array[int] = []) -> Dictionary:
	var horses: Array[Dictionary] = HorseData.get_all_horses()
	var selected: Dictionary = horses[clamp(selected_index, 0, horses.size() - 1)]
	var winner: Dictionary = horses[clamp(winner_index, 0, horses.size() - 1)]

	var is_hit: bool = selected_index == winner_index
	var profit: int = 0
	if is_hit:
		profit = int(round(bet * maxf(1.0, multiplier - 1.0)))
	else:
		profit = -bet

	coins = max(0, coins + profit)
	total_profit += profit

	stats["total_races"] = int(stats.get("total_races", 0)) + 1
	if is_hit:
		stats["wins"] = int(stats.get("wins", 0)) + 1
	else:
		stats["losses"] = int(stats.get("losses", 0)) + 1
	stats["best_profit"] = max(int(stats.get("best_profit", 0)), profit)

	if not horse_stats.has(selected["name"]):
		horse_stats[selected["name"]] = {"selected": 0, "wins": 0}
	horse_stats[selected["name"]]["selected"] = int(horse_stats[selected["name"]].get("selected", 0)) + 1

	if not horse_stats.has(winner["name"]):
		horse_stats[winner["name"]] = {"selected": 0, "wins": 0}
	horse_stats[winner["name"]]["wins"] = int(horse_stats[winner["name"]].get("wins", 0)) + 1

	if not finish_order.is_empty():
		update_recent_form_by_order(finish_order)

	var result_entry: Dictionary = {
		"winner": winner["name"],
		"selected": selected["name"],
		"bet": bet,
		"profit": profit,
		"coins_after": coins,
		"hit": is_hit
	}
	recent_results.push_front(result_entry)
	while recent_results.size() > 5:
		recent_results.pop_back()

	save_game()
	return result_entry

func reset_stats() -> void:
	var defaults: Dictionary = default_data()
	coins = int(defaults["coins"])
	total_profit = int(defaults["total_profit"])
	stats = defaults["stats"].duplicate(true)
	horse_stats = defaults["horse_stats"].duplicate(true)
	horse_recent_form = defaults["horse_recent_form"].duplicate(true)
	recent_results = []
	save_game()
