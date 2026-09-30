extends Node

@onready var player_ambiente = $PlayerAmbiente
@onready var player_ui = $PlayerUI

var som_ambiente_atual : AudioStream
var som_impacto_dado : AudioStream

const CAMINHO_SAVE = "user://config_audio.cfg"

var volume_musica_atual: float = 0.5
var volume_efeitos_atual: float = 1.0
var musica_mutada_atual: bool = false
var efeitos_mutados_atual: bool = false

var skin_atual: String = "padrao"

func _ready():
	carregar_configuracoes()
	# Inicia a skin sem forçar um salvamento duplo na abertura do app
	trocar_audio_skin(skin_atual, false)

func tocar_click():
	if player_ui and player_ui.stream:
		player_ui.play()
	else:
		print("AVISO: O nó PlayerUI está sem arquivo de som carregado no Inspetor!")

# A função agora troca a música e já salva automaticamente
func trocar_audio_skin(nome_da_skin: String, salvar: bool = true):
	skin_atual = nome_da_skin
	
	match nome_da_skin:
		"padrao":
			som_ambiente_atual = load("res://skins/padrao/audio/ambiente_taverna.mp3")
			som_impacto_dado = load("res://skins/padrao/audio/dado_padrao_impacto.wav")
		"espacial":
			som_ambiente_atual = load("res://skins/espacial/audio/darth_vader_theme.mp3")
			som_impacto_dado = load("res://skins/espacial/audio/dado_futurista_impacto.mp3")
		_:
			print("Skin de áudio não encontrada.")
			
	if som_ambiente_atual:
		tocar_ambiente(som_ambiente_atual)
		
	if salvar:
		salvar_configuracoes()

func tocar_ambiente(stream: AudioStream):
	if player_ambiente:
		# Força o play se a música for diferente da atual ou se estiver parado
		if player_ambiente.stream != stream or not player_ambiente.playing:
			player_ambiente.stream = stream
			player_ambiente.play()

# ==========================================
# MEMÓRIA E VOLUME BLINDADO
# ==========================================
func salvar_configuracoes():
	var config = ConfigFile.new()
	config.set_value("Audio", "volume_musica", volume_musica_atual)
	config.set_value("Audio", "volume_efeitos", volume_efeitos_atual)
	config.set_value("Audio", "musica_mutada", musica_mutada_atual)
	config.set_value("Audio", "efeitos_mutados", efeitos_mutados_atual)
	config.set_value("Geral", "skin_atual", skin_atual)
	config.save(CAMINHO_SAVE)

func carregar_configuracoes():
	var config = ConfigFile.new()
	var erro = config.load(CAMINHO_SAVE)

	if erro == OK:
		volume_musica_atual = config.get_value("Audio", "volume_musica", 0.5)
		volume_efeitos_atual = config.get_value("Audio", "volume_efeitos", 1.0)
		musica_mutada_atual = config.get_value("Audio", "musica_mutada", false)
		efeitos_mutados_atual = config.get_value("Audio", "efeitos_mutados", false)
		skin_atual = config.get_value("Geral", "skin_atual", "padrao")
		
	alterar_volume_musica(volume_musica_atual, false)
	alterar_volume_efeitos(volume_efeitos_atual, false)
	mutar_musica(musica_mutada_atual, false)
	mutar_efeitos(efeitos_mutados_atual, false)

func alterar_volume_musica(valor_linear: float, salvar: bool = true):
	volume_musica_atual = valor_linear
	var bus_idx = AudioServer.get_bus_index("Musica")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(max(valor_linear, 0.0001)))
	if salvar: salvar_configuracoes()

func alterar_volume_efeitos(valor_linear: float, salvar: bool = true):
	volume_efeitos_atual = valor_linear
	var bus_idx = AudioServer.get_bus_index("Efeitos")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(max(valor_linear, 0.0001)))
	if salvar: salvar_configuracoes()

func mutar_musica(mutado: bool, salvar: bool = true):
	musica_mutada_atual = mutado
	var bus_idx = AudioServer.get_bus_index("Musica")
	if bus_idx != -1: AudioServer.set_bus_mute(bus_idx, mutado)
	if salvar: salvar_configuracoes()
	
func mutar_efeitos(mutado: bool, salvar: bool = true):
	efeitos_mutados_atual = mutado
	var bus_idx = AudioServer.get_bus_index("Efeitos")
	if bus_idx != -1: AudioServer.set_bus_mute(bus_idx, mutado)
	if salvar: salvar_configuracoes()
