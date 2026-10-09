extends Node3D

@onready var luz = $OmniLight3D

func _ready():
	# Cria um Tween local só para apagar o clarão da luz em 0.5 segundos
	if luz:
		var tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(luz, "energy", 0.0, 0.5)
		
	# Autodestrói a explosão após 3 segundos para limpar a memória
	await get_tree().create_timer(1.0).timeout
	queue_free()
