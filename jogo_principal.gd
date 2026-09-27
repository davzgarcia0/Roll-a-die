extends Node

@onready var menu_ui = $CanvasLayer/MenuPrincipal
@onready var sala_3d = $Mesa_Jogo
@onready var ConfigPanel = $CanvasLayer/MenuPrincipal/VBoxContainer/MenuPanel/ConfigPanel
@onready var SkinPanel = $CanvasLayer/MenuPrincipal/VBoxContainer/MenuPanel/SkinPanel
@onready var DonatePanel = $CanvasLayer/MenuPrincipal/VBoxContainer/MenuPanel/DonatePanel

var jogo_iniciado = false
var estava_em_paisagem = false # Variável para vigiar a rotação

func _ready():
	# Descobre como a tela está assim que o app abre
	var tamanho_tela = get_viewport().size
	estava_em_paisagem = tamanho_tela.x > tamanho_tela.y
	
	get_tree().root.size_changed.connect(_on_tela_redimensionada)
	_on_tela_redimensionada()

func iniciar_jogo():
	jogo_iniciado = true
	_on_tela_redimensionada()

func voltar_ao_menu():
	jogo_iniciado = false
	_on_tela_redimensionada()

func _on_tela_redimensionada():
	var tamanho_tela = get_viewport().size
	var em_modo_paisagem = tamanho_tela.x > tamanho_tela.y
	var canvas_mesa = sala_3d.get_node_or_null("CanvasLayer")

	# ===============================================================
	# DETECTA SE A TELA FOI GIRADA NESTE EXATO MOMENTO
	# ===============================================================
	if em_modo_paisagem != estava_em_paisagem:
		GlobalData.limpar_dados() 
		
		if sala_3d.has_method("resetar_mesa_ao_girar"):
			sala_3d.resetar_mesa_ao_girar()
			
		if menu_ui.has_method("atualizar_interface"):
			menu_ui.atualizar_interface()
			
		# --- A NOVA REGRA MÁGICA ESTÁ AQUI ---
		# Se a tela ESTAVA deitada (paisagem) e AGORA está em pé (retrato)
		if estava_em_paisagem and not em_modo_paisagem:
			jogo_iniciado = false # Força o jogo a entender que voltamos ao menu
		# -------------------------------------
			
		estava_em_paisagem = em_modo_paisagem

	# ===============================================================
	# APLICA AS TELAS DE ACORDO COM O ESTADO ATUAL
	# ===============================================================
	if em_modo_paisagem:
		# --- MODO PAISAGEM ---
		jogo_iniciado = true
		menu_ui.visible = false
		sala_3d.visible = true
		if canvas_mesa: canvas_mesa.visible = true
		sala_3d.process_mode = Node.PROCESS_MODE_INHERIT
		
		if sala_3d.has_method("alternar_interface"):
			sala_3d.alternar_interface(true)
	else:
		if jogo_iniciado:
			# --- MODO RETRATO (DENTRO DA SALA 3D) ---
			menu_ui.visible = false
			sala_3d.visible = true
			if canvas_mesa: canvas_mesa.visible = true
			sala_3d.process_mode = Node.PROCESS_MODE_INHERIT
			
			if sala_3d.has_method("alternar_interface"):
				sala_3d.alternar_interface(false)
		else:
			# --- MODO RETRATO (MENU INICIAL) ---
			menu_ui.visible = true
			sala_3d.visible = false
			if canvas_mesa: canvas_mesa.visible = false
			sala_3d.process_mode = Node.PROCESS_MODE_DISABLED
			
# Adicione esta função em qualquer lugar do seu script principal
func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		
		# 1. Menus Secundários: Fecha se estiverem abertos
		if is_instance_valid(ConfigPanel) and ConfigPanel.visible:
			ConfigPanel.visible = false
			return
			
		if is_instance_valid(SkinPanel) and SkinPanel.visible:
			SkinPanel.visible = false
			return
			
		if is_instance_valid(DonatePanel) and DonatePanel.visible:
			DonatePanel.visible = false
			return
			
		# 2. Sala 3D: Ignora o botão de voltar do celular
		if jogo_iniciado:
			# O comando 'return' interrompe a função aqui.
			# O Godot intercepta o clique no botão nativo, mas não executa 
			# nenhuma ação, protegendo a sua rolagem contra missclicks.
			return
			
		# 3. Menu Inicial: Fecha o app / Volta pra tela do celular
		get_tree().quit()
