extends Node

signal progress_changed(ratio: float)
signal completed(prob: Array[float], mult: Array[float])

const TRACK_DISTANCE_M: float = 1600.0
const RACE_TIME_SCALE: float = 3.7

func start(horses: Array[Dictionary], conditions: Dictionary, seed: int, total_sims: int = 500, batch: int = 25) -> void:
	var horse_count: int = horses.size()
	if horse_count == 0:
		emit_signal("completed", [], [])
		return

	var winners: Array[int] = []
	winners.resize(horse_count)
	for i in horse_count:
		winners[i] = 0

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed

	var safe_total_sims: int = max(1, total_sims)
	var safe_batch: int = max(1, batch)
	var processed: int = 0
	while processed < safe_total_sims:
		var sim_count: int = min(safe_batch, safe_total_sims - processed)
		for _i in sim_count:
			var winner_idx: int = _simulate_one_race(horses, conditions, rng)
			if winner_idx >= 0 and winner_idx < horse_count:
				winners[winner_idx] += 1
		processed += sim_count
		emit_signal("progress_changed", float(processed) / float(safe_total_sims))
		await get_tree().process_frame

	var prob: Array[float] = []
	var mult: Array[float] = []
	for i in horse_count:
		var p: float = float(winners[i]) / float(safe_total_sims)
		var m: float = clampf((1.0 / maxf(p, 0.001)) * (1.0 - 0.12), 1.10, 10.0)
		prob.append(p)
		mult.append(m)

	emit_signal("completed", prob, mult)

func _simulate_one_race(horses: Array[Dictionary], conditions: Dictionary, rng: RandomNumberGenerator) -> int:
	var count: int = horses.size()
	var race_distance_m: Array[float] = []
	var stamina_current: Array[float] = []
	var stamina_max: Array[float] = []
	var skill_used: Array[bool] = []
	race_distance_m.resize(count)
	stamina_current.resize(count)
	stamina_max.resize(count)
	skill_used.resize(count)

	var form_stamina_any: Variant = conditions.get("horse_form_stamina", [])
	var form_speed_any: Variant = conditions.get("horse_form_speed", [])
	var form_skill_any: Variant = conditions.get("horse_form_skill", [])
	var form_stamina: Array = form_stamina_any if form_stamina_any is Array else []
	var form_speed: Array = form_speed_any if form_speed_any is Array else []
	var form_skill: Array = form_skill_any if form_skill_any is Array else []

	for i in count:
		race_distance_m[i] = 0.0
		var base_stamina: float = float(horses[i].get("stamina_max", 1600.0)) * _array_value(form_stamina, i, 1.0)
		stamina_max[i] = clampf(base_stamina, 1600.0, 1800.0)
		stamina_current[i] = stamina_max[i]
		skill_used[i] = false

	var dt: float = 0.1
	var elapsed: float = 0.0
	while elapsed < 30.0:
		for i in count:
			if race_distance_m[i] >= TRACK_DISTANCE_M:
				continue
			var time_delta_scaled: float = dt * RACE_TIME_SCALE
			var fatigue_multiplier: float = clampf(0.5 + (stamina_current[i] / maxf(stamina_max[i], 1.0)) * 0.8, 0.5, 1.25)
			var base_pace_mps: float = float(horses[i].get("base_pace_mps", 17.8)) * _array_value(form_speed, i, 1.0)
			base_pace_mps *= float(conditions.get("track_speed_bias", 1.0))
			var consistency: float = float(horses[i].get("consistency", 0.6))
			var variance: float = rng.randf_range(-1.5, 1.5) * (1.3 - consistency) * float(conditions.get("track_variance_scale", 1.0))
			var move_delta_m: float = maxf((base_pace_mps * fatigue_multiplier + variance) * time_delta_scaled, 0.0)

			var skill_bonus_m: float = HorseData.skill_trigger_bonus_m(horses[i], race_distance_m[i], stamina_current[i], stamina_max[i], time_delta_scaled, skill_used[i], rng, _array_value(form_skill, i, 1.0))
			if skill_bonus_m > 0.0:
				skill_used[i] = true
			move_delta_m += skill_bonus_m
			move_delta_m = minf(move_delta_m, TRACK_DISTANCE_M - race_distance_m[i])

			race_distance_m[i] += move_delta_m
			stamina_current[i] = clampf(stamina_current[i] - move_delta_m, 0.0, 1800.0)
			if race_distance_m[i] >= TRACK_DISTANCE_M:
				return i
		elapsed += dt

	var best_idx: int = 0
	var best_distance: float = race_distance_m[0]
	for i in count:
		if race_distance_m[i] > best_distance:
			best_idx = i
			best_distance = race_distance_m[i]
	return best_idx

func _array_value(arr: Array, index: int, fallback: float) -> float:
	if index >= 0 and index < arr.size():
		return float(arr[index])
	return fallback
