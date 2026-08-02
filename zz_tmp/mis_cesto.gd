extends SceneTree

const BOU := preload("res://scenes/build/BuildBoutique.gd")

func _profilo_r(y: float) -> float:
	var p := [Vector2(0.26, 0.0), Vector2(0.275, 0.03), Vector2(0.325, 0.18),
			Vector2(0.355, 0.32), Vector2(0.365, 0.35)]
	if y <= float(p[0].y): return float(p[0].x)
	if y >= float(p[p.size() - 1].y): return float(p[p.size() - 1].x)
	for i in p.size() - 1:
		if y >= float(p[i].y) and y <= float(p[i + 1].y):
			var t: float = (y - p[i].y) / (p[i + 1].y - p[i].y)
			return lerpf(float(p[i].x), float(p[i + 1].x), t)
	return float(p[p.size() - 1].x)

func _init() -> void:
	var n: Node3D = BOU.cesto_saldi()
	get_root().add_child(n)
	var idx := 0
	for c in n.get_children():
		var mi := c as MeshInstance3D
		if mi == null:
			continue
		var cm := mi.mesh as CylinderMesh
		if cm == null or not is_equal_approx(cm.height, 0.30):
			continue
		var tr := mi.transform
		var asse := tr.basis * Vector3(0, 1, 0)
		var a := tr.origin + asse * 0.15
		var b := tr.origin - asse * 0.15
		print("MANICA %d  pos=%.4v  asse=%.4v" % [idx, tr.origin, asse])
		for nome_p in [["alto", a, cm.top_radius], ["basso", b, cm.bottom_radius]]:
			var q: Vector3 = nome_p[1]
			var rr: float = sqrt(q.x * q.x + q.z * q.z)
			var rad: float = nome_p[2]
			var muro := _profilo_r(q.y)
			print("   capo %-5s  y=%.4f  r_asse=%.4f  r_esterno=%.4f  muro(y)=%.4f  fuori=%+.4f"
					% [nome_p[0], q.y, rr, rr + rad, muro, rr + rad - muro])
		# campionamento lungo l'asse: quanto esce dalla parete
		var peggio := 0.0
		var y_peggio := 0.0
		for k in 41:
			var u := -0.15 + 0.30 * float(k) / 40.0
			var q2: Vector3 = tr.origin + asse * u
			var rad2: float = lerpf(cm.bottom_radius, cm.top_radius, float(k) / 40.0)
			var rr2: float = sqrt(q2.x * q2.x + q2.z * q2.z) + rad2
			var muro2 := _profilo_r(q2.y)
			if q2.y < 0.339 and rr2 - muro2 > peggio:
				peggio = rr2 - muro2
				y_peggio = q2.y
		print("   -> massimo sfondamento della parete: %.4f m a y=%.3f" % [peggio, y_peggio])
		idx += 1
	quit()
