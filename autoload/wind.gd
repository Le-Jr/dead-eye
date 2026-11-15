extends Node
## Global wind. Smoke, bullets (later phases) and tumbleweeds all read
## get_velocity() so they agree with each other.

signal wind_changed

## Horizontal unit vector the wind blows toward.
var direction := Vector3(1.0, 0.0, 0.25).normalized()
## Mean speed in m/s.
var base_speed := 1.8
## 0 = steady, 1 = gusts swing between calm and double speed.
var gustiness := 0.5

var _time := 0.0
var _gust := 0.0


func _process(delta: float) -> void:
	_time += delta
	_gust = (sin(_time * 0.37) * 0.6 + sin(_time * 1.13 + 1.7) * 0.4) * gustiness


func set_wind(new_direction: Vector3, speed: float, gusts := 0.5) -> void:
	new_direction.y = 0.0
	if new_direction.length() > 0.001:
		direction = new_direction.normalized()
	base_speed = maxf(speed, 0.0)
	gustiness = clampf(gusts, 0.0, 1.0)
	wind_changed.emit()


## Current wind velocity in m/s, gusts included.
func get_velocity() -> Vector3:
	return direction * maxf(base_speed * (1.0 + _gust), 0.0)
