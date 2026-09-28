extends RigidBody3D

@onready var player_impacto = $SomImpacto

func _ready():
	# Busca o som de impacto da skin atual no AudioManager
	if player_impacto and AudioManager.som_impacto_dado:
		player_impacto.stream = AudioManager.som_impacto_dado

func _on_body_entered(_body: Node):
	# Calcula a força do impacto pegando a velocidade atual do dado
	var forca_impacto = linear_velocity.length()
	
	# Só toca o som se o impacto for forte o suficiente
	if forca_impacto > 1.5 and player_impacto:
		# Varia a altura (pitch) do som levemente para não soar repetitivo
		player_impacto.pitch_scale = randf_range(0.8, 1.2)
		
		# Modula o volume baseado na força da batida
		var volume_dinamico = lerpf(-15.0, 0.0, clampf(forca_impacto / 10.0, 0.0, 1.0))
		player_impacto.volume_db = volume_dinamico
		
		player_impacto.play()

# Função auxiliar para caso você queira rolar os dados por botão no futuro
func rolar_dado(direcao_lancamento: Vector3, forca_arremesso: float):
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	var impulso_movimento = direcao_lancamento.normalized() * forca_arremesso
	apply_central_impulse(impulso_movimento)
	
	var torque_aleatorio = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized()
	
	apply_torque_impulse(torque_aleatorio * randf_range(10.0, 30.0))
