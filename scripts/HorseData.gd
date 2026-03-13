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
		"color": Color(0.95, 0.20, 0.20, 1.0),
		"base_speed": 18.05,
		"stamina": 1670.0,
		"luck": 61,
		"skill_name": "선행 돌파",
		"skill_desc": "초반 선두 싸움에서 강한 모습을 보입니다.",
		"running_style": "선행"
		"base_pace_mps": 18.0,
		"stamina_max": 1670.0,
		"consistency": 0.58,
		"finishing": 0.56,
		"base_pace_mps": 16.4,
		"stamina_max": 1680.0,
		"consistency": 0.62,
		"finishing": 0.55,
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
		"color": Color(0.22, 0.44, 0.95, 1.0),
		"base_speed": 17.98,
		"stamina": 1750.0,
		"luck": 58,
		"skill_name": "전개 이점",
		"skill_desc": "중반 운영에서 강점을 보입니다.",
		"running_style": "안정"
		"base_pace_mps": 17.9,
		"stamina_max": 1750.0,
		"consistency": 0.72,
		"finishing": 0.60,
		"base_pace_mps": 16.2,
		"stamina_max": 1740.0,
		"consistency": 0.7,
		"finishing": 0.58,
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
		"color": Color(0.95, 0.86, 0.20, 1.0),
		"base_speed": 17.92,
		"stamina": 1660.0,
		"luck": 65,
		"skill_name": "막판 추입",
		"skill_desc": "직선 주로에서 탄력이 살아납니다.",
		"running_style": "추입"
		"base_pace_mps": 17.8,
		"stamina_max": 1660.0,
		"consistency": 0.5,
		"finishing": 0.80,
		"base_pace_mps": 16.1,
		"stamina_max": 1660.0,
		"consistency": 0.52,
		"finishing": 0.78,
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
		"color": Color(0.08, 0.08, 0.08, 1.0),
		"base_speed": 17.95,
		"stamina": 1780.0,
		"luck": 60,
		"skill_name": "근성 발휘",
		"skill_desc": "쉽게 무너지지 않는 근성이 있습니다.",
		"running_style": "근성"
		"base_pace_mps": 17.85,
		"stamina_max": 1780.0,
		"consistency": 0.64,
		"finishing": 0.67,
		"base_pace_mps": 16.0,
		"stamina_max": 1780.0,
		"consistency": 0.64,
		"finishing": 0.65,
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

static func get_stat_hint(horse: Dictionary) -> Dictionary:
	var speed_value: float = float(horse.get("base_speed", 17.9))
	var stamina_value: float = float(horse.get("stamina", 1600.0))
	var luck_value: int = int(horse.get("luck", 55))

	var speed_text: String = ""
	if speed_value >= 18.02:
		speed_text = "스피드가 대단합니다."
	elif speed_value >= 17.95:
		speed_text = "초반 탄력이 괜찮습니다."
	else:
		speed_text = "발주는 무난하지만 폭발력은 덜합니다."

	var stamina_text: String = ""
	if stamina_value >= 1760.0:
		stamina_text = "오래 버티는 힘이 좋습니다."
	elif stamina_value >= 1690.0:
		stamina_text = "스태미나가 무난한 편입니다."
	else:
		stamina_text = "스태미나가 다소 부족합니다."

	var consistency_text: String = ""
	if luck_value >= 63:
		consistency_text = "전개가 풀리면 무시하기 어렵습니다."
	elif luck_value >= 58:
		consistency_text = "기복이 적고 안정적인 편입니다."
	else:
		consistency_text = "뛰어날 때는 확실하지만 다소 기복이 있습니다."

	return {
		"speed_text": speed_text,
		"stamina_text": stamina_text,
		"consistency_text": consistency_text
	}

static func get_ability_summary(horse: Dictionary) -> Array[String]:
	var hint: Dictionary = get_stat_hint(horse)
	var lines: Array[String] = [
		str(hint.get("speed_text", "스피드 평가는 보류입니다.")),
		str(hint.get("stamina_text", "스태미나 평가는 보류입니다.")),
		str(hint.get("consistency_text", "기복 평가는 보류입니다."))
	]
	return lines

static func get_forecast_score(horse: Dictionary, recent_form_factor: float, rng: RandomNumberGenerator) -> float:
	var speed_score: float = float(horse.get("base_speed", 17.9)) * 22.0
	var stamina_score: float = (float(horse.get("stamina", 1600.0)) - 1600.0) * 0.55
	var luck_score: float = float(int(horse.get("luck", 55))) * 0.35
	var style_bonus: float = 0.0
	var running_style: String = str(horse.get("running_style", ""))
	if running_style == "선행":
		style_bonus = 4.8
	elif running_style == "안정":
		style_bonus = 5.0
	elif running_style == "추입":
		style_bonus = 5.2
	elif running_style == "근성":
		style_bonus = 5.1
	var variance: float = rng.randf_range(-2.8, 2.8)
	return speed_score + stamina_score + luck_score + style_bonus + (recent_form_factor * 6.0) + variance

static func skill_trigger_bonus_m(horse: Dictionary, race_distance_m: float, stamina_current: float, stamina_max: float, delta: float, skill_used: bool, rng: RandomNumberGenerator, skill_form_multiplier: float = 1.0) -> float:
	if skill_used:
		return 0.0

static func skill_trigger_bonus_m(horse: Dictionary, race_distance_m: float, stamina_current: float, stamina_max: float, delta: float, skill_used: bool, rng: RandomNumberGenerator, skill_form_multiplier: float = 1.0) -> float:
static func skill_trigger_bonus_m(horse: Dictionary, race_distance_m: float, stamina_current: float, stamina_max: float, delta: float, skill_used: bool, rng: RandomNumberGenerator) -> float:
	if skill_used:
		return 0.0
	var number: int = int(horse.get("number", 0))
	var chance_per_second: float = 0.0
	if number == 1:
		if race_distance_m <= 400.0:
			chance_per_second = 0.44
	elif number == 2:
		if race_distance_m >= 500.0 and race_distance_m <= 1100.0:
			chance_per_second = 0.40
	elif number == 3:
		if race_distance_m >= 1200.0:
			chance_per_second = 0.53
	elif number == 4:
		var stamina_ratio: float = stamina_current / maxf(stamina_max, 1.0)
		if stamina_ratio <= 0.38:
			chance_per_second = 0.50
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

	var adjusted: float = chance_per_second * clampf(skill_form_multiplier, 0.90, 1.10)
	if rng.randf() <= adjusted * delta:
		return rng.randf_range(SKILL_BONUS_MIN_M, SKILL_BONUS_MAX_M)
	return 0.0
	var adjusted_chance: float = chance_per_second * clampf(skill_form_multiplier, 0.9, 1.1)
	if rng.randf() <= adjusted_chance * delta:
		if race_distance_m >= 0.0 and race_distance_m <= 400.0:
			chance_per_second = 0.13
	elif number == 2:
		if race_distance_m >= 500.0 and race_distance_m <= 1100.0:
			chance_per_second = 0.11
	elif number == 3:
		if race_distance_m >= 1200.0:
			chance_per_second = 0.16
	elif number == 4:
		var ratio: float = stamina_current / maxf(stamina_max, 1.0)
		if ratio <= 0.34:
			chance_per_second = 0.19

	if chance_per_second <= 0.0:
		return 0.0
	if rng.randf() <= chance_per_second * delta:
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
	var base_pace_mps: float = float(horse.get("base_pace_mps", 16.0))
	var stamina_max: float = float(horse.get("stamina_max", 1600.0))
	var consistency: float = float(horse.get("consistency", 0.5))

	if base_pace_mps >= 16.35:
		lines.append("스피드가 대단합니다.")
	elif base_pace_mps >= 16.1:
		lines.append("초반 탄력이 제법 좋습니다.")
	else:
		lines.append("전개가 풀리면 무시하기 어렵습니다.")

	if stamina_max >= 1760.0:
		lines.append("오래 버티는 힘이 괜찮습니다.")
	elif stamina_max >= 1690.0:
	if stamina_max >= 1750.0:
		lines.append("오래 버티는 힘이 괜찮습니다.")
	elif stamina_max >= 1680.0:
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
	var pace_score: float = float(horse.get("base_pace_mps", 16.0)) * 22.0
	var stamina_score: float = (float(horse.get("stamina_max", 1600.0)) - 1600.0) * 0.65
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
		skill_score = 7.0
	elif trigger == "middle":
		skill_score = 8.0
	elif trigger == "late":
		skill_score = 8.5
	elif trigger == "guts":
		skill_score = 7.8

	var variance: float = rng.randf_range(-4.0, 4.0) * (1.2 - consistency)
	return pace_score + stamina_score + skill_score + finishing * 10.0 + recent_form_factor * 6.0 + variance
