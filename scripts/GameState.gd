extends Node

const START_COINS := 1000
const TEMP_MULTIPLIER := 2.0 # TODO: 다음 작업에서 몬테카를로 배당으로 교체

var coins: int = START_COINS
var total_profit: int = 0
var stats: Dictionary = {}
var horse_stats: Dictionary = {}
var recent_results: Array = []

func _ready() -> void:
	load_game()

func default_data() -> Dictionary:
	var horse_stat_defaults := {}
	for horse in HorseData.get_all_horses():
		horse_stat_defaults[horse["name"]] = {
			"selected": 0,
			"wins": 0
		}

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
		"recent_results": []
	}

func load_game() -> void:
	var loaded := SaveSystem.load_or_init(default_data())
	coins = max(0, int(loaded.get("coins", START_COINS)))
	total_profit = int(loaded.get("total_profit", 0))
	stats = loaded.get("stats", {}).duplicate(true)
	horse_stats = loaded.get("horse_stats", {}).duplicate(true)
	recent_results = loaded.get("recent_results", []).duplicate(true)

func save_game() -> void:
	var data := {
		"version": SaveSystem.VERSION,
		"coins": coins,
		"total_profit": total_profit,
		"stats": stats,
		"horse_stats": horse_stats,
		"recent_results": recent_results
	}
	SaveSystem.save(data)

func can_bet(amount: int) -> bool:
	return amount >= 50 and amount <= coins

func apply_race_result(selected_index: int, winner_index: int, bet: int, multiplier: float = TEMP_MULTIPLIER) -> Dictionary:
	var horses := HorseData.get_all_horses()
	var selected := horses[clamp(selected_index, 0, horses.size() - 1)]
	var winner := horses[clamp(winner_index, 0, horses.size() - 1)]

	var is_hit := selected_index == winner_index
	var profit := 0
	if is_hit:
		profit = int(round(bet * max(1.0, multiplier - 1.0)))
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

	var result_entry := {
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
	var defaults := default_data()
	coins = int(defaults["coins"])
	total_profit = int(defaults["total_profit"])
	stats = defaults["stats"].duplicate(true)
	horse_stats = defaults["horse_stats"].duplicate(true)
	recent_results = []
	save_game()
