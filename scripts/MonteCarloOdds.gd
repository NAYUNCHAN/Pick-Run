extends Node

signal progress_changed(ratio: float)
signal completed(prob: Array[float], mult: Array[float])

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
	var distances: Array[float] = []
	var stamina_current: Array[float] = []
	var stamina_max: Array[float] = []
	distances.resize(count)
	stamina_current.resize(count)
	stamina_max.resize(count)

	var form_stamina_any: Variant = conditions.get("horse_form_stamina", [])
	var form_speed_any: Variant = conditions.get("horse_form_speed", [])
	var form_stamina: Array = form_stamina_any if form_stamina_any is Array else []
	var form_speed: Array = form_speed_any if form_speed_any is Array else []

	for i in count:
		distances[i] = 0.0
		var base_stamina: float = float(horses[i].get("stamina", 1.0)) * _array_value(form_stamina, i, 1.0)
		var clamped_stamina: float = maxf(0.1, base_stamina)
		stamina_max[i] = clamped_stamina
		stamina_current[i] = clamped_stamina

	var track_distance: float = 1000.0
	var dt: float = 0.10
	var elapsed: float = 0.0
	while elapsed < 40.0:
		for i in count:
			var progress_ratio: float = clampf(distances[i] / track_distance, 0.0, 1.0)
			var fatigue_scale: float = float(conditions.get("fatigue_scale", 1.0))
			stamina_current[i] = maxf(0.1, stamina_current[i] - dt * (0.35 + progress_ratio * 0.75) * fatigue_scale)
			var fatigue_multiplier: float = clampf(0.55 + (stamina_current[i] / maxf(stamina_max[i], 0.1)) * 0.65, 0.55, 1.2)
			var base_speed: float = float(horses[i].get("base_speed", 120.0))
			base_speed *= float(conditions.get("track_speed_bias", 1.0))
			base_speed *= _array_value(form_speed, i, 1.0)

			var variance: float = rng.randf_range(-40.0, 40.0) * float(conditions.get("track_variance_scale", 1.0))
			var luck: float = float(horses[i].get("luck", 0))
			var chance_ps: float = (luck / 100.0) * 0.9 * float(conditions.get("luck_event_scale", 1.0))
			var luck_boost: float = 0.0
			if rng.randf() < chance_ps * dt:
				luck_boost = rng.randf_range(25.0, 80.0) * (1.0 - progress_ratio * 0.5)

			var move_delta: float = maxf((base_speed * fatigue_multiplier + variance + luck_boost) * dt, 0.0)
			distances[i] += move_delta
			if distances[i] >= track_distance:
				return i
		elapsed += dt

	var best_idx: int = 0
	var best_distance: float = distances[0]
	for i in count:
		if distances[i] > best_distance:
			best_idx = i
			best_distance = distances[i]
	return best_idx

func _array_value(arr: Array, index: int, fallback: float) -> float:
	if index >= 0 and index < arr.size():
		return float(arr[index])
	return fallback
