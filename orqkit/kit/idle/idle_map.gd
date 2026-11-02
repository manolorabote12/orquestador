extends RefCounted
## Analizador del clicker: comprueba SIN jugar que la meta se alcanza a tiempo.
## 1 - Entre 2 y 6 ayudantes "coste:ganancia", cada uno mas caro y mas rentable que el anterior.
## 2 - Simula a una persona normal (4 toques por segundo, compra lo que mas renta por moneda) y
##     exige llegar a la meta antes del 80 % del tiempo (sin contar monedas de oro).
## 3 - Y que no sea un paseo: tocando sin comprar nada no se llega.

const TAPS_PER_S: float = 4.0


static func analyze(level: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	var helpers: Array[Dictionary] = []
	var prev_cost: float = 0.0
	for r: Variant in level.get("map", []):
		var parts: PackedStringArray = str(r).split(":")
		if parts.size() != 2 or not parts[0].is_valid_float() or not parts[1].is_valid_float():
			if not issues.has("idle_bad_rows"):
				issues.append("idle_bad_rows")
			continue
		var c: float = float(parts[0])
		if c <= prev_cost and not issues.has("idle_costs_order"):
			issues.append("idle_costs_order")
		prev_cost = c
		helpers.append({"cost": c, "cps": float(parts[1]), "owned": 0})
	if helpers.size() < 2 or helpers.size() > 6:
		issues.append("idle_helpers")
	var target: float = float(level.get("target", 0.0))
	var duration: float = float(level.get("duration", 0.0))
	var tap: float = float(level.get("tap", 1.0))
	var t: float = simulate(helpers, target, tap, duration * 2.0)
	if t > duration * 0.8:
		issues.append("idle_target_high")
	if tap * TAPS_PER_S * duration >= target:
		issues.append("idle_target_low")
	return {"completable": issues.is_empty(), "issues": issues, "coins_total": maxi(1, int(duration / 18.0)), "enemies": 0,
		"enemy_problems": [], "sim_time": t}


## Segundos que tarda la estrategia sencilla en llegar a la meta (o "limit" si no llega).
static func simulate(base: Array[Dictionary], target: float, tap: float, limit: float) -> float:
	var hs: Array[Dictionary] = []
	for h: Dictionary in base:
		hs.append(h.duplicate())
	var bank: float = 0.0
	var earned: float = 0.0
	var tapv: float = tap
	var tap_level: int = 0
	var t: float = 0.0
	var dt: float = 0.25
	while t < limit:
		var rate: float = tapv * TAPS_PER_S
		for h: Dictionary in hs:
			rate += float(h["cps"]) * float(h["owned"])
		bank += rate * dt
		earned += rate * dt
		t += dt
		if earned >= target:
			return t
		## Compra lo que mas renta por moneda (si se puede pagar).
		var best: int = -2
		var best_ratio: float = 0.0
		for i: int in hs.size():
			var cost: float = ceilf(float(hs[i]["cost"]) * pow(1.15, float(hs[i]["owned"])))
			if cost <= bank and float(hs[i]["cps"]) / cost > best_ratio:
				best_ratio = float(hs[i]["cps"]) / cost
				best = i
		var tap_cost: float = ceilf(40.0 * tap * pow(2.5, float(tap_level)))
		if tap_cost <= bank and tapv * TAPS_PER_S / tap_cost > best_ratio:
			best = -1
		if best == -1:
			bank -= tap_cost
			tap_level += 1
			tapv = tap * pow(2.0, float(tap_level))
		elif best >= 0:
			bank -= ceilf(float(hs[best]["cost"]) * pow(1.15, float(hs[best]["owned"])))
			hs[best]["owned"] = int(hs[best]["owned"]) + 1
	return limit
