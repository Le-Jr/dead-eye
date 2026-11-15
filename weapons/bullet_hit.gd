class_name BulletHit
extends RefCounted
## Everything a target needs to know about the shot that struck it.

var position := Vector3.ZERO
var normal := Vector3.UP
## Unit vector the bullet was travelling along.
var direction := Vector3.FORWARD
## Metres from the muzzle.
var distance := 0.0
## Total damage (summed when several pellets of one shot land).
var damage := 0.0
## How many pellets of the shot hit this target.
var pellets := 1
## The shooter was aiming down the sights.
var aimed := false
## The bullet glanced off steel before it got here.
var ricochet := false
var collider: Object
var weapon: Node
