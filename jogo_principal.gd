extends Node

@onready var menu_ui = $CanvasLayer/MenuPrincipal
@onready var sala_3d = $Mesa_Jogo

func _ready():
	# Conecta um sinal nativo do Godot que avisa sempre que a tela muda de tamanho/orientação
	get_tree().root.size_changed.connect(_on_tela_redimensionada)
	
	# Chama a função uma vez no início para ajustar o tamanho logo ao abrir o app
	_on_tela_redimensionada()

func _on_tela_redimensionada():
	var tamanho_tela = get_viewport().size
	var em_modo_paisagem = tamanho_tela.x > tamanho_tela.y
	
	if em_modo_paisagem:
		self.anchor_right = 0.3
		self.offset_right = 0 # <--- ADICIONE ISTO AQUI
	else:
		self.anchor_right = 1.0
		self.offset_right = 0 # <--- ADICIONE ISTO AQUI
		
	if not em_modo_paisagem:
		# --- MODO RETRATO ---
		menu_ui.anchor_right = 1.0
		menu_ui.anchor_bottom = 1.0
		menu_ui.offset_right = 0
		menu_ui.offset_bottom = 0
		
		sala_3d.visible = false
		sala_3d.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		# --- MODO PAISAGEM ---
		menu_ui.anchor_right = 0.4
		menu_ui.anchor_bottom = 1.0
		menu_ui.offset_right = 0
		menu_ui.offset_bottom = 0
		
		sala_3d.visible = true
		sala_3d.process_mode = Node.PROCESS_MODE_INHERIT

	# Localiza o botão de voltar na sala 3D (Agora corretamente dentro da função!)
	var botao_voltar = sala_3d.get_node("MarginContainer/BotaoRetorno")
	
	if botao_voltar != null:
		if em_modo_paisagem:
			botao_voltar.visible = false # Esconde deitado
		else:
			botao_voltar.visible = true  # Mostra em pé
