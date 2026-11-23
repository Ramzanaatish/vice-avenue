extends Node

## Sanity checks only. Offline single-player: deterrence, not
## unbreakable protection. Never delete saves, never ban.

func validate_money(value: int) -> int:
	return clampi(value, 0, SaveManager.MAX_MONEY)

func validate_health(value: int) -> int:
	return clampi(value, 0, SaveManager.MAX_HEALTH)

func check_impossible_movement(speed: float, max_speed: float) -> bool:
	# True when movement is impossible (tampering or a physics
	# glitch). The caller soft-corrects; it never bans.
	return speed > max_speed * 3.0

func check_resource_manifest(expected: Dictionary) -> Array:
	# expected: {res_path: true}. Returns the list of missing files.
	var missing: Array = []
	for path in expected.keys():
		if not FileAccess.file_exists(path):
			missing.append(path)
	return missing
