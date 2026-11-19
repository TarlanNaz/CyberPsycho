extends Spatial

export(NodePath) var rig_path = NodePath(".")
onready var rig = get_node(rig_path)
onready var left_hip = rig.get_node("LeftHip")
onready var right_hip = rig.get_node("RightHip")
onready var left_knee = rig.get_node("LeftHip/LeftKnee")
onready var right_knee = rig.get_node("RightHip/RightKnee")
onready var left_shoulder = rig.get_node("LeftShoulderPivot")
onready var right_shoulder = rig.get_node("RightShoulderPivot")
onready var left_elbow_joint = rig.get_node("LeftShoulderPivot/LeftElbow")
onready var right_elbow_joint = rig.get_node("RightShoulderPivot/RightElbow")
onready var rest_translation = translation


# Длина полного цикла в локальном масштабе модели.
const STRIDE_LENGTH = 2.3
var phase = 0.0
var weight = 0.0

func advance_walk(distance, delta):
	translation = rest_translation
	var local_distance = distance / scale.y
	var speed = local_distance / delta
	weight = move_toward(weight, clamp(speed, 0.0, 1.0), 7.0 * delta)
	phase = fmod(phase + TAU * local_distance / STRIDE_LENGTH, TAU)
	var swing = sin(phase) * weight
	left_hip.rotation.x = 0.54 * swing
	right_hip.rotation.x = -0.54 * swing
	left_knee.rotation.x = -0.52 * max(cos(phase), 0.0) * weight
	right_knee.rotation.x = -0.52 * max(-cos(phase), 0.0) * weight
	left_shoulder.rotation.x = -0.40 * swing
	right_shoulder.rotation.x = 0.40 * swing

func combat_pose(attack_time, hit_time, block_time, kind = 1, contact_time = 0.4, duration = 0.8):
	var left = 0.65
	var right = 0.65
	var left_elbow = 1.7
	var right_elbow = 1.7
	var left_side = 0.12
	var right_side = -0.12
	var left_twist = 0.0
	var right_twist = 0.0
	var lean = 0.0
	if attack_time >= 0.0:
		var windup_end = contact_time * 0.65
		var extension = 0.0
		var windup = 0.0
		if attack_time < windup_end:
			windup = smoothstep(0.0, windup_end, attack_time)
		elif attack_time < contact_time:
			extension = smoothstep(windup_end, contact_time, attack_time)
			windup = 1.0 - extension
		else:
			extension = 1.0 - smoothstep(contact_time, duration, attack_time)
		lean = -0.10 * extension
		if kind == 0:
			left = 0.65 - 0.35 * windup + 0.95 * extension
			left_elbow = 1.7 * (1.0 - extension)
		elif kind == 2:
			left = 0.65 + 0.75 * extension
			left_side = -0.2 - 0.75 * windup
			left_twist = -0.7 * windup + 0.85 * extension
			left_elbow = 1.7 - 0.6 * extension
			right = 0.85
		else:
			right = 0.65 - 0.35 * windup + 0.95 * extension
			right_elbow = 1.7 * (1.0 - extension)
			right_twist = -0.18 * extension
			if kind == 3:
				left = 0.9
				lean = -0.16 * extension
	elif hit_time > 0.0:
		var recoil = sin(PI * clamp(hit_time / 0.48, 0.0, 1.0))
		left = 0.65 - 0.55 * recoil
		right = left
		right_elbow = 1.7 - 0.8 * recoil
		left_elbow = right_elbow
		lean = 0.28 * recoil
	elif block_time > 0.0:
		# Сведение предплечий и короткая отдача после принятого удара.
		var elapsed = 0.34 - block_time
		var brace = smoothstep(0.0, 0.05, elapsed) * (1.0 - smoothstep(0.18, 0.34, elapsed))
		left = lerp(0.65, 1.15, brace)
		right = left
		left_elbow = lerp(1.7, 1.3, brace)
		right_elbow = left_elbow
		left_side = lerp(0.12, 0.65, brace)
		right_side = -left_side
		left_twist = -0.45 * brace
		right_twist = -left_twist
		lean = 0.10 * brace
	left_shoulder.rotation = Vector3(left, left_twist, left_side)
	right_shoulder.rotation = Vector3(right, right_twist, right_side)
	left_elbow_joint.rotation.x = left_elbow
	right_elbow_joint.rotation.x = right_elbow
	rotation.x = lean
	rotation.z = 0.0

func stun_pose(remaining):
	combat_pose(-1.0, 0.0, 0.0)
	left_shoulder.rotation.x = 0.25
	right_shoulder.rotation.x = 0.25
	left_elbow_joint.rotation.x = 0.7
	right_elbow_joint.rotation.x = 0.7
	rotation.x = -0.2
	rotation.z = sin(remaining * 18.0) * 0.045

func finisher_pose(progress):
	var extension = smoothstep(0.25, 0.42, progress) * (1.0 - smoothstep(0.50, 0.8, progress))
	combat_pose(-1.0, 0.0, 0.0)
	right_shoulder.rotation.x = lerp(0.3, 1.95, extension)
	right_elbow_joint.rotation.x = lerp(1.7, 0.0, extension)
	rotation.x = -0.12 * extension

func fall_pose(progress):
	var fall = smoothstep(0.42, 0.95, progress)
	combat_pose(-1.0, 0.0, 0.0)
	rotation.x = fall * PI * 0.5
	left_shoulder.rotation.x = lerp(0.65, 0.1, fall)
	right_shoulder.rotation.x = lerp(0.65, 0.1, fall)
	left_elbow_joint.rotation.x = lerp(1.7, 0.2, fall)
	right_elbow_joint.rotation.x = lerp(1.7, 0.2, fall)

func boss_defeat_pose(progress):
	combat_pose(-1.0, 0.0, 0.0)
	var kneel = smoothstep(0.42, 0.68, progress)
	var fall = smoothstep(0.68, 0.98, progress)
	var bend = kneel * (1.0 - fall)
	left_hip.rotation.x = bend
	right_hip.rotation.x = bend
	left_knee.rotation.x = -2.0 * bend
	right_knee.rotation.x = -2.0 * bend
	translation.y = -0.86 * (1.0 - cos(bend)) * scale.y
	rotation.x = PI * 0.5 * fall
	left_shoulder.rotation.x = lerp(0.65, 0.1, kneel)
	right_shoulder.rotation.x = lerp(0.65, 0.1, kneel)
	left_elbow_joint.rotation.x = lerp(1.7, 0.2, kneel)
	right_elbow_joint.rotation.x = lerp(1.7, 0.2, kneel)


func lift_pose(progress):
	reset_car_pose()
	var rise = smoothstep(0.0, 1.0, progress)
	var crouch = 1.0 - rise
	left_hip.rotation.x = 0.65 * crouch
	right_hip.rotation.x = 0.65 * crouch
	left_knee.rotation.x = -1.1 * crouch
	right_knee.rotation.x = -1.1 * crouch
	translation.y -= 0.3 * crouch * scale.y
	rotation.x = 0.2 * crouch
	left_shoulder.rotation = Vector3(lerp(0.8, 2.95, rise), 0, 0.12)
	right_shoulder.rotation = Vector3(lerp(0.8, 2.95, rise), 0, -0.12)
	left_elbow_joint.rotation.x = lerp(0.25, 0.3, rise)
	right_elbow_joint.rotation.x = left_elbow_joint.rotation.x

func reset_car_pose():
	combat_pose(-1.0, 0.0, 0.0)
	translation = rest_translation
	left_hip.rotation.x = 0.0
	right_hip.rotation.x = 0.0
	left_knee.rotation.x = 0.0
	right_knee.rotation.x = 0.0

func car_grasp_pose(progress):
	var reach = smoothstep(0.0, 1.0, progress)
	lift_pose(0.0)
	left_hip.rotation.x *= reach
	right_hip.rotation.x *= reach
	left_knee.rotation.x *= reach
	right_knee.rotation.x *= reach
	translation.y = rest_translation.y - 0.3 * reach * scale.y
	rotation.x = 0.2 * reach
	left_shoulder.rotation.x = lerp(0.65, 0.8, reach)
	right_shoulder.rotation.x = left_shoulder.rotation.x
	left_elbow_joint.rotation.x = lerp(1.7, 0.25, reach)
	right_elbow_joint.rotation.x = left_elbow_joint.rotation.x

func car_throw_pose(progress):
	lift_pose(1.0)
	var extension = smoothstep(0.0, 1.0, progress)
	left_shoulder.rotation.x = lerp(2.95, 2.35, extension)
	right_shoulder.rotation.x = left_shoulder.rotation.x
	left_elbow_joint.rotation.x = lerp(0.3, 0.1, extension)
	right_elbow_joint.rotation.x = left_elbow_joint.rotation.x
	rotation.x = -0.18 * extension

func car_recover_pose(progress):
	reset_car_pose()
	var recover = smoothstep(0.0, 1.0, progress)
	left_shoulder.rotation.x = lerp(2.35, 0.65, recover)
	right_shoulder.rotation.x = left_shoulder.rotation.x
	left_elbow_joint.rotation.x = lerp(0.1, 1.7, recover)
	right_elbow_joint.rotation.x = left_elbow_joint.rotation.x
	rotation.x = lerp(-0.18, 0.0, recover)

func kick_pose(progress):
	reset_car_pose()
	var p = clamp(progress, 0.0, 1.0)
	var windup = smoothstep(0.0, 0.25, p) * (1.0 - smoothstep(0.25, 0.5, p))
	var extension = smoothstep(0.25, 0.5, p) * (1.0 - smoothstep(0.5, 1.0, p))
	right_hip.rotation.x = -0.35 * windup + 1.25 * extension
	right_knee.rotation.x = -1.1 * windup - 0.1 * extension
	left_hip.rotation.x = 0.12 * extension
	rotation.x = 0.13 * extension
	left_shoulder.rotation.x = 0.65 + 0.3 * extension
	right_shoulder.rotation.x = 0.65 - 0.3 * extension

func car_hand_anchor():
	var midpoint = Vector3.ZERO
	for elbow in [left_elbow_joint, right_elbow_joint]:
		var forearm = elbow.get_child(0)
		var bounds = forearm.get_aabb()
		var tip = bounds.position + bounds.size * 0.5
		tip.y = bounds.position.y
		midpoint += forearm.global_transform.xform(tip)
	return midpoint * 0.5

func car_knockback_pose(progress):
	reset_car_pose()
	var recoil = sin(PI * clamp(progress, 0.0, 1.0))
	var stagger = sin(progress * PI * 3.0) * recoil
	rotation.x = 0.38 * recoil
	rotation.z = 0.08 * stagger
	left_shoulder.rotation.x = 0.65 + 0.75 * recoil
	right_shoulder.rotation.x = left_shoulder.rotation.x
	left_elbow_joint.rotation.x = 1.7 - 0.5 * recoil
	right_elbow_joint.rotation.x = left_elbow_joint.rotation.x
	left_hip.rotation.x = 0.35 * stagger
	right_hip.rotation.x = -0.35 * stagger
	left_knee.rotation.x = -0.3 * max(stagger, 0.0)
	right_knee.rotation.x = -0.3 * max(-stagger, 0.0)
