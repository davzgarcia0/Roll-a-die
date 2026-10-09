extends Node

@onready var player_ambiente = $PlayerAmbiente
@onready var player_musica = $PlayerMusica
@onready var player_ui = $PlayerUI

var som_ambiente_atual : AudioStream
var som_musica_atual : AudioStream
var som_impacto_dado : AudioStream

const CAMINHO_SAVE = "user://config_audio.cfg"

var volume_musica_atual: float = 0.5
var volume_efeitos_atual: float = 1.0
var musica_mutada_atual: bool = false
var efeitos_mutados_atual: bool = false

var skin_atual: String = "padrao"

var tween_ambiente: Tween

# ==========================================
# TRANSIÇÕES SUAVES DE AMBIENTE (CROSSFADE)
# ==========================================
# Adicionamos tempo_fade_out e tempo_fade_in separados
func transicao_para_ambiente_temporario(novo_stream: AudioStream, tempo_fade_out: float = 0.1, tempo_fade_in: float = 0.1):
	if player_ambiente == null or novo_stream == null: return
	
	if tween_ambiente and tween_ambiente.is_valid():
		tween_ambiente.kill()

	tween_ambiente = create_tween()
	
	# 1. Fade Out super rápido (ex: 0.1s) para não atrasar a explosão
	tween_ambiente.tween_property(player_ambiente, "volume_db", -40.0, tempo_fade_out).set_trans(Tween.TRANS_SINE)
	
	# 2. Swap: Troca e toca a comemoração quase instantaneamente
	tween_ambiente.tween_callback(func():
		player_ambiente.stream = novo_stream
		player_ambiente.play()
	)
	
	# 3. Fade In suave para a comemoração não estourar o ouvido
	tween_ambiente.tween_property(player_ambiente, "volume_db", 0.0, tempo_fade_in).set_trans(Tween.TRANS_SINE)


func restaurar_ambiente(tempo_fade_out: float = 1.0, tempo_fade_in: float = 1.0):
	if player_ambiente == null or som_ambiente_atual == null: return
	
	if tween_ambiente and tween_ambiente.is_valid():
		tween_ambiente.kill()

	tween_ambiente = create_tween()
	
	# A volta para a taverna pode ser lenta e dramática
	tween_ambiente.tween_property(player_ambiente, "volume_db", -40.0, tempo_fade_out).set_trans(Tween.TRANS_SINE)
	
	tween_ambiente.tween_callback(func():
		player_ambiente.stream = som_ambiente_atual
		player_ambiente.play()
	)
	
	tween_ambiente.tween_property(player_ambiente, "volume_db", 0.0, tempo_fade_in).set_trans(Tween.TRANS_SINE)
	
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
			som_ambiente_atual = load("res://skins/padrao/audio/ambiente_padrao.mp3")
			som_musica_atual = load("res://skins/padrao/audio/musica_padrao.mp3")
			som_impacto_dado = load("res://skins/padrao/audio/dado_padrao_impacto.mp3")
		"espacial":
			som_ambiente_atual = null
			som_musica_atual = load("res://skins/espacial/audio/darth_vader_theme.mp3")
			som_impacto_dado = load("res://skins/espacial/audio/dado_futurista_impacto.mp3")
			
			print("Skin de áudio não encontrada.")
			
	if som_ambiente_atual:
		tocar_ambiente(som_ambiente_atual)
		
	if som_musica_atual:
		tocar_musica(som_musica_atual)
		
	if salvar:
		salvar_configuracoes()

func tocar_ambiente(stream: AudioStream):
	if player_ambiente:
		# Força o play se a música for diferente da atual ou se estiver parado
		if player_ambiente.stream != stream or not player_ambiente.playing:
			player_ambiente.stream = stream
			player_ambiente.play()
			
func tocar_musica(stream: AudioStream):
	if player_musica:
		# Força o play se a música for diferente da atual ou se estiver parado
		if player_musica.stream != stream or not player_musica.playing:
			player_musica.stream = stream
			player_musica.play()

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
