extends "res://scripts/base_player.gd"

# SpecialPlayer handles characters with unique state-based logic like:
# - Rado (Whataboutism)
# - Sasho (Invisibility)
# - Veli (Airborne rules)

func _process_ability_logic(_opp_pos: Vector2) -> void:
	# This avoids checking these flags in the base player's loop
	if whataboutism_blocks:
		# Whataboutism is mostly reactive (handled in take_hit/handle_whataboutism_on_block)
		pass
	
	if punch_makes_invisible:
		# Invisibility countdown is already in base_player for simplicity/sync
		pass


# We can override other methods here if needed for Veli's specific jump behavior
# or Sasho's invisibility timing, to keep base_player.gd lean.
