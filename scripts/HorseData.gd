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

	if chance_per_second <= 0.0:
		return 0.0

	var adjusted: float = chance_per_second * clampf(skill_form_multiplier, 0.90, 1.10)
	if rng.randf() <= adjusted * delta:
		return rng.randf_range(SKILL_BONUS_MIN_M, SKILL_BONUS_MAX_M)
	return 0.0
