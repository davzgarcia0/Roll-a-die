extends Node3D
func _ready():
	# Destrói o efeito após 3 segundos
	await get_tree().create_timer(3.0).timeout
	queue_free()
