class_name WeaponData
extends Resource
## All tunable stats for one weapon. One .tres per gun in weapons/data/.

enum ReloadType {
	LOADING_GATE,  ## Revolver: one chamber at a time, interruptible.
	TUBE,  ## Lever action: rounds pushed into a tube one by one.
	BREAK_ACTION,  ## Coach gun: break open, swap both shells.
	BREECH,  ## Sharps: one cartridge per shot.
}

@export var display_name := "Weapon"
## Optional replacement viewmodel (a scene whose root extends WeaponModel).
## Leave empty to use the weapon's procedural model.
@export var model_scene: PackedScene

@export_group("Ballistics")
## Per pellet.
@export var damage := 40.0
@export var pellets := 1
@export var max_range := 400.0
## m/s. 0 = pure hitscan. Above 0 the bullet takes time, drops, and drifts.
@export var muzzle_velocity := 0.0
@export var gravity_scale := 1.0
## Sideways acceleration per m/s of wind (1/s). Only for travelling bullets.
@export var wind_drift := 0.8
## Sight settings in metres the player can step through. The bullet crosses
## the line of sight at the selected distance. Empty = sights fixed on bore.
@export var zero_distances := PackedFloat32Array()

@export_group("Handling")
## Lockout after the hammer falls.
@export var fire_interval := 0.18
## Time to work the action: thumb the hammer, throw the lever.
@export var cock_time := 0.24
## Revolver only: time per shot while fanning.
@export var fan_interval := 0.16
@export var capacity := 6
@export var reload_type := ReloadType.LOADING_GATE
@export var reload_open_time := 0.45
@export var reload_eject_time := 0.28
@export var reload_insert_time := 0.42
@export var reload_close_time := 0.35

@export_group("Accuracy")
## Cone half-angles in degrees.
@export var spread_deg := 1.1
@export var ads_spread_deg := 0.15
@export var fan_spread_deg := 7.0
## Extra spread at full sprint speed.
@export var move_spread_deg := 2.0

@export_group("Recoil")
## Camera kick in degrees: x = pitch up, y = max random yaw to either side.
@export var recoil_kick := Vector2(4.5, 1.2)
@export var recoil_duration := 0.55
## Kick over normalized time: rises fast to 1, then recovers to 0.
@export var recoil_curve: Curve
## Scales the viewmodel's own jump in the hand.
@export var viewmodel_kick := 1.0

@export_group("Aiming")
@export var ads_fov := 55.0
@export var ads_time := 0.22
## Viewmodel position relative to the camera.
@export var hip_position := Vector3(0.15, -0.13, -0.36)
## Position that puts the sight line on the camera axis.
@export var ads_position := Vector3(0.0, -0.02, -0.4)

@export_group("Effects")
## Size of the black-powder cloud relative to the revolver's.
@export var smoke_amount := 1.0
## Spent case: x = radius, y = length, in metres.
@export var casing_size := Vector2(0.006, 0.032)

@export_group("Sounds")
## Keys into the SoundBank resource (phase 5).
@export var sound_fire := &""
@export var sound_dry := &""
@export var sound_cock := &""
@export var sound_reload_open := &""
@export var sound_reload_insert := &""
@export var sound_reload_eject := &""
@export var sound_reload_close := &""
