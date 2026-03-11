extends RefCounted
class_name HorseData

const TRACK_DISTANCE_M: float = 1600.0
const SKILL_BONUS_MIN_M: float = 0.48
const SKILL_BONUS_MAX_M: float = 4.8

const HORSES: Array[Dictionary] = [
	{
		"id": 0,
		"number": 1,
		"name": "1번마 적토",
		"base_pace_mps": 18.0,
		"stamina_max": 1670.0,
		"consistency": 0.58,
		"finishing": 0.56,
		"color": Color(0.95, 0.2, 0.2, 1.0),
		"skill": {
			"name": "선행 돌파",
			"description": "초반 선두 싸움에서 강한 모습을 보입니다.",
			"trigger": "early"
		}
	},
	{
		"id": 1,
		"number": 2,
		"name": "2번마 청류",
		"base_pace_mps": 17.9,
		"stamina_max": 1750.0,
		"consistency": 0.72,
		"finishing": 0.60,
		"color": Color(0.2, 0.45, 0.95, 1.0),
		"skill": {
			"name": "전개 이점",
			"description": "중반 운영에서 강점을 보입니다.",
			"trigger": "middle"
		}
	},
	{
		"id": 2,
		"number": 3,
		"name": "3번마 황금탄",
		"base_pace_mps": 17.8,
		"stamina_max": 1660.0,
		"consistency": 0.5,
		"finishing": 0.80,
		"color": Color(0.95, 0.85, 0.2, 1.0),
		"skill": {
			"name": "막판 추입",
			"description": "직선 주로에서 탄력이 살아납니다.",
			"trigger": "late"
		}
	},
	{
		"id": 3,
		"number": 4,
		"name": "4번마 흑풍",
		"base_pace_mps": 17.85,
		"stamina_max": 1780.0,
		"consistency": 0.64,
		"finishing": 0.67,
		"color": Color(0.08, 0.08, 0.08, 1.0),
		"skill": {
			"name": "근성 발휘",
			"description": "쉽게 무너지지 않는 근성이 있습니다.",
			"trigger": "guts"
		}
	}
]

static func get_all_horses() -> Array[Dictionary]:
	return HORSES.duplicate(true)

static func get_horse(index: int) -> Dictionary:
	if index < 0 or index >= HORSES.size():
		return HORSES[0].duplicate(true)
	return HORSES[index].duplicate(true)

static func skill_trigger_bonus_m(horse: Dictionary, race_distance_m: float, stamina_current: float, stamina_max: float, delta: float, skill_used: bool, rng: RandomNumberGenerator, skill_form_multiplier: float = 1.0) -> float:
	if skill_used:
		return 0.0
	var number: int = int(horse.get("number", 0))
	var chance_per_second: float = 0.0
	if number == 1:
		if race_distance_m <= 400.0:
			chance_per_second = 0.48
	elif number == 2:
		if race_distance_m >= 500.0 and race_distance_m <= 1100.0:
			chance_per_second = 0.42
	elif number == 3:
		if race_distance_m >= 1200.0:
			chance_per_second = 0.56
	elif number == 4:
		var ratio: float = stamina_current / maxf(stamina_max, 1.0)
		if ratio <= 0.38:
			chance_per_second = 0.52

	if chance_per_second <= 0.0:
		return 0.0

	var adjusted_chance: float = chance_per_second * clampf(skill_form_multiplier, 0.9, 1.1)
	if rng.randf() <= adjusted_chance * delta:
		return rng.randf_range(SKILL_BONUS_MIN_M, SKILL_BONUS_MAX_M)
	return 0.0

static func get_ability_summary(horse: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var base_pace_mps: float = float(horse.get("base_pace_mps", 17.8))
	var stamina_max: float = float(horse.get("stamina_max", 1600.0))
	var consistency: float = float(horse.get("consistency", 0.5))

	if base_pace_mps >= 18.0:
		lines.append("스피드가 대단합니다.")
	elif base_pace_mps >= 17.85:
		lines.append("초반 탄력이 제법 좋습니다.")
	else:
		lines.append("전개가 풀리면 무시하기 어렵습니다.")

	if stamina_max >= 1760.0:
		lines.append("오래 버티는 힘이 괜찮습니다.")
	elif stamina_max >= 1690.0:
		lines.append("스태미나는 평균 이상으로 평가됩니다.")
	else:
		lines.append("스태미나가 부족한 편입니다.")

	if consistency >= 0.68:
		lines.append("흐름을 안정적으로 이어가는 유형입니다.")
	elif consistency >= 0.58:
		lines.append("큰 기복 없이 제 몫을 해주는 편입니다.")
	else:
		lines.append("뛰어날 때는 확실하지만 다소 기복이 있습니다.")

	return lines

static func get_forecast_score(horse: Dictionary, recent_form_factor: float, rng: RandomNumberGenerator) -> float:
	var pace_score: float = float(horse.get("base_pace_mps", 17.8)) * 20.0
	var stamina_score: float = (float(horse.get("stamina_max", 1600.0)) - 1600.0) * 0.55
	var consistency: float = float(horse.get("consistency", 0.5))
	var finishing: float = float(horse.get("finishing", 0.5))
	var skill_score: float = 0.0
	var skill_data_any: Variant = horse.get("skill", {})
	var skill_data: Dictionary = skill_data_any if skill_data_any is Dictionary else {}
	var trigger: String = str(skill_data.get("trigger", ""))
	if trigger == "early":
		skill_score = 5.8
	elif trigger == "middle":
		skill_score = 6.0
	elif trigger == "late":
		skill_score = 6.3
	elif trigger == "guts":
		skill_score = 6.1

	var variance: float = rng.randf_range(-6.0, 6.0) * (1.25 - consistency)
	return pace_score + stamina_score + skill_score + finishing * 10.0 + recent_form_factor * 6.5 + variance
