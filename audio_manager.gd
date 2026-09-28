extends Node

@onready var player_ambiente = $PlayerAmbiente
@onready var player_ui = $PlayerUI

var som_ambiente_atual : AudioStream
var som_impacto_dado : AudioStream

func _ready():
	# Inicia o aplicativo carregando o pacote padrão
	trocar_audio_skin("padrao")

func tocar_click():
	if player_ui and player_ui.stream:
		player_ui.play()

func trocar_audio_skin(nome_da_skin: String):
	# O 'match' escolhe o bloco de código baseado na string recebida
	match nome_da_skin:
		"padrao":
			som_ambiente_atual = load("res://sons/ambiente_taverna.mp3")
			som_impacto_dado = load("res://sons/dado_padrao_impacto.wav")
			
		"espacial":
			som_ambiente_atual = load("res://sons/darth_vader_theme.mp3")
			som_impacto_dado = load("res://sons/dado_futurista_impacto.mp3")
			
		# Adicione novas skins aqui seguindo a mesma lógica
		_:
			print("Skin de áudio não encontrada. Mantendo a atual.")
			
	# Toca a música ambiente imediatamente após a troca
	if som_ambiente_atual:
		tocar_ambiente(som_ambiente_atual)

func tocar_ambiente(stream: AudioStream):
	if player_ambiente and player_ambiente.stream != stream:
		player_ambiente.stream = stream
		player_ambiente.play()
		
# ==========================================
# CONTROLE DE VOLUME (SISTEMA DE CONFIG)
# ==========================================

func alterar_volume_musica(valor_linear: float):
	var bus_idx = AudioServer.get_bus_index("Musica")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(valor_linear))

func alterar_volume_efeitos(valor_linear: float):
	var bus_idx = AudioServer.get_bus_index("Efeitos")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(valor_linear))

func mutar_musica(mutado: bool):
	var bus_idx = AudioServer.get_bus_index("Musica")
	AudioServer.set_bus_mute(bus_idx, mutado)
	
func mutar_efeitos(mutado: bool):
	var bus_idx = AudioServer.get_bus_index("Efeitos")
	AudioServer.set_bus_mute(bus_idx, mutado)
