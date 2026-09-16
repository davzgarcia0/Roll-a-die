extends Control

# --- VARIÁVEIS DE INTERFACE (UI) ---
@onready var label_formula = $PanelContainer/MarginContainer/VBoxContainer/SessaoFreeRoll/BarraFormula/PanelContainer/Label

# ATENÇÃO: Substitua os caminhos abaixo arrastando os nós corretos da sua árvore de cena!
@onready var btn_van = $PanelContainer/MarginContainer/VBoxContainer/PanelContainer/SeletorSistema/HBoxContainer/vantagem
@onready var btn_des = $PanelContainer/MarginContainer/VBoxContainer/PanelContainer/SeletorSistema/HBoxContainer/desvantagem
@onready var line_edit_cd = $PanelContainer/MarginContainer/VBoxContainer/PanelContainer/SeletorSistema/PanelContainer/HBoxContainer2/VBoxContainer/CD
@onready var rich_text_historico = $PanelContainer/MarginContainer/VBoxContainer/SessaoHistorico/FundoTituloRolls/MarginContainer/ScrollContainer/ListaDeResultados/RichTextLabel

func _ready():
	# ESPERA CRUCIAL: Aguarda dois frames físicos para dar tempo do Android
	# carregar o tamanho correto da câmera (Notch) antes de ler a tela.
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Agora sim conectamos o sinal e chamamos a função
	get_tree().root.size_changed.connect(_on_tela_redimensionada)
	_on_tela_redimensionada()
	
	# Garante que a interface do D20 mostre a CD inicial (15) ao abrir o app
	if line_edit_cd != null:
		line_edit_cd.text = str(GlobalData.d20_cd_alvo)
	else:
		print("AVISO: line_edit_cd não foi encontrado! Verifique o caminho.")


# ==========================================
# 1. LÓGICA DO FREE ROLL (ROLAGEM LIVRE)
# ==========================================

# Função que os botões de dados vão chamar
func adicionar_dado(tipo_dado: String):
	if tipo_dado == "d%":
		# Se clicou no d%, limpa tudo e define apenas o d%
		GlobalData.limpar_dados()
		GlobalData.dados_para_rolar["d%"] = 1
	else:
		# Se já tinha um d% na tela e o jogador clicou em outro normal, apagamos o d%
		if GlobalData.dados_para_rolar["d%"] > 0:
			GlobalData.dados_para_rolar["d%"] = 0
		
		# Adiciona o dado normal
		GlobalData.dados_para_rolar[tipo_dado] += 1
		
	atualizar_interface()


# Função que os botões de +1 e -1 vão chamar
func alterar_modificador(valor: int):
	# Se for uma rolagem exclusiva de porcentagem, ignoramos os botões de + e -
	if GlobalData.dados_para_rolar["d%"] > 0:
		return
		
	GlobalData.modificador_total += valor
	atualizar_interface()


# Função que o botão RESET vai chamar
func resetar_rolagem():
	GlobalData.limpar_dados()
	atualizar_interface()


# Atualiza o texto na tela para mostrar a matemática
func atualizar_interface():
	# REGRA ESPECIAL DO D%: 
	if GlobalData.dados_para_rolar["d%"] > 0:
		label_formula.text = "d%"
		return
		
	# --- INÍCIO DA MATEMÁTICA NORMAL ---
	var formula_texto = ""
	
	# Verifica cada dado no AutoLoad
	for dado in GlobalData.dados_para_rolar.keys():
		var quantidade = GlobalData.dados_para_rolar[dado]
		if quantidade > 0 and dado != "d%":
			if formula_texto != "":
				formula_texto += " + "
			formula_texto += str(quantidade) + dado
			
	# Adiciona os modificadores no final
	var mod = GlobalData.modificador_total
	if mod > 0:
		if formula_texto != "": formula_texto += " "
		formula_texto += "+ " + str(mod)
	elif mod < 0:
		if formula_texto != "": formula_texto += " "
		formula_texto += "- " + str(abs(mod))
		
	# Se estiver tudo vazio, limpa o campo
	if formula_texto == "":
		formula_texto = ""
		
	label_formula.text = formula_texto


# ==========================================
# 2. LÓGICA DO SISTEMA D20 (TOPO DA TELA)
# ==========================================

func _on_vantagem_toggled(toggled_on: bool) -> void:
	if toggled_on:
		btn_des.button_pressed = false # Desliga a Desvantagem automaticamente
		GlobalData.d20_estado_atual = GlobalData.EstadoD20.VANTAGEM
	else:
		# Se desligou a Vantagem e a Desvantagem também está desligada, volta ao normal
		if not btn_des.button_pressed:
			GlobalData.d20_estado_atual = GlobalData.EstadoD20.NORMAL


func _on_desvantagem_toggled(toggled_on: bool) -> void:
	if toggled_on:
		btn_van.button_pressed = false # Desliga a Vantagem automaticamente
		GlobalData.d20_estado_atual = GlobalData.EstadoD20.DESVANTAGEM
	else:
		if not btn_van.button_pressed:
			GlobalData.d20_estado_atual = GlobalData.EstadoD20.NORMAL

# --- Botões de CD ---

func _on_btn_cd_mais_pressed() -> void:
	GlobalData.d20_cd_alvo += 1
	line_edit_cd.text = str(GlobalData.d20_cd_alvo)

func _on_btn_cd_menos_pressed() -> void:
	GlobalData.d20_cd_alvo -= 1
	if GlobalData.d20_cd_alvo < 1:
		GlobalData.d20_cd_alvo = 1 # Impede CD negativa ou zero
	line_edit_cd.text = str(GlobalData.d20_cd_alvo)

# Disparado toda vez que o jogador digita algo no teclado virtual
func _on_line_edit_cd_text_changed(new_text: String) -> void:
	var texto_filtrado = ""
	
	# Passa por cada caractere digitado e só mantém o que for número
	for caracter in new_text:
		if caracter.is_valid_int():
			texto_filtrado += caracter
			
	# Se o jogador digitou uma letra, o Godot apaga e corrige o cursor
	if new_text != texto_filtrado:
		line_edit_cd.text = texto_filtrado
		line_edit_cd.caret_column = texto_filtrado.length()
		
	# Salva o valor final no AutoLoad (se o campo não estiver vazio)
	if texto_filtrado != "":
		GlobalData.d20_cd_alvo = int(texto_filtrado)
	else:
		GlobalData.d20_cd_alvo = 1


func _on_d_20_pressed() -> void:
	# Carimba que a rolagem é do SISTEMA D20
	GlobalData.tipo_rolagem_atual = GlobalData.TipoRolagem.SISTEMA_D20
	GlobalData.limpar_dados()
	
	var cena_mestre = get_tree().current_scene
	if get_viewport().size.y > get_viewport().size.x:
		self.visible = false
		cena_mestre.get_node("Mesa_Jogo").visible = true
		cena_mestre.get_node("Mesa_Jogo").process_mode = Node.PROCESS_MODE_INHERIT
		
	resetar_rolagem()
	
	cena_mestre.get_node("Mesa_Jogo").iniciar_rolagem_pelo_menu()

func _on_play_free_roll_pressed() -> void:
	# Carimba que a rolagem é FREE ROLL
	GlobalData.tipo_rolagem_atual = GlobalData.TipoRolagem.FREE_ROLL
	
	var tem_dados = false
	for qtd in GlobalData.dados_para_rolar.values():
		if qtd > 0: tem_dados = true
			
	# Agora ele SÓ rola o Free Roll se tiver dado selecionado lá!
	if tem_dados:
		var cena_mestre = get_tree().current_scene
		if get_viewport().size.y > get_viewport().size.x:
			self.visible = false
			cena_mestre.get_node("Mesa_Jogo").visible = true
			cena_mestre.get_node("Mesa_Jogo").process_mode = Node.PROCESS_MODE_INHERIT
			
		cena_mestre.get_node("Mesa_Jogo").iniciar_rolagem_pelo_menu()
		
func atualizar_historico():
	if rich_text_historico == null: 
		print("ERRO: rich_text_historico é nulo! O caminho do nó está errado.")
		return
		
	rich_text_historico.text = "" # Limpa o texto antigo
	
	# Percorre a lista de trás pra frente (para mostrar as mais recentes no topo)
	var total_linhas = GlobalData.historico_rolagens.size()
	for i in range(total_linhas - 1, -1, -1):
		var linha = GlobalData.historico_rolagens[i]
		rich_text_historico.text += linha + "\n"

# ==========================================
# RESPONSIVIDADE E SAFE AREA CORRIGIDA
# ==========================================
func _on_tela_redimensionada():
	var viewport_size = get_viewport().size
	var em_modo_paisagem = viewport_size.x > viewport_size.y
	
	# 1. AJUSTE DOS 30% DO MENU
	if em_modo_paisagem:
		self.anchor_right = 0.3
		self.offset_right = 0
	else:
		self.anchor_right = 1.0
		self.offset_right = 0

	# 2. CÁLCULO DA ÁREA SEGURA (Com conversão de pixels)
	var safe_area = DisplayServer.get_display_safe_area()
	var window_size = DisplayServer.window_get_size()
	
	# Prevenção contra travamentos se o Android falhar em passar o tamanho
	if window_size.x == 0 or window_size.y == 0:
		return
		
	# Calcula a diferença de proporção entre a tela física do aparelho e a UI do Godot
	var escala_x = float(viewport_size.x) / float(window_size.x)
	var escala_y = float(viewport_size.y) / float(window_size.y)
	
	# Converte os pixels físicos da câmera para os pixels da sua Interface
	var margem_esquerda = safe_area.position.x * escala_x
	var margem_topo = safe_area.position.y * escala_y
	var margem_direita = (window_size.x - (safe_area.position.x + safe_area.size.x)) * escala_x
	var margem_base = (window_size.y - (safe_area.position.y + safe_area.size.y)) * escala_y
	
	# 3. APLICAÇÃO NO MARGIN CONTAINER
	if has_node("MarginContainer"):
		var margem_node = $MarginContainer
		
		# Aplica as margens convertidas + 10 pixels extras de respiro estético
		margem_node.add_theme_constant_override("margin_left", margem_esquerda + 10)
		margem_node.add_theme_constant_override("margin_top", margem_topo + 10)
		margem_node.add_theme_constant_override("margin_right", margem_direita + 10)
		margem_node.add_theme_constant_override("margin_bottom", margem_base + 10)
