extends Node3D

# ==========================================
# CAMINHOS DOS SEUS MODELOS 3D
# ==========================================
var caminhos_cenas = {
	"d4": "res://Dices/dado_d_4.tscn",
	"d6": "res://Dices/dado_d_6.tscn",
	"d8": "res://Dices/dado_d_8.tscn",
	"d10": "res://Dices/dado_d_10.tscn",
	"d12": "res://Dices/dado_d_12.tscn",
	"d20": "res://Dices/dado_d_20.tscn"
}

# Referências aos nós fixos da cena
@onready var camera_fisica = $PlayerCamera
@onready var camera_visual = $PlayerCamera/Camera3D
@onready var texto_resultado = $MarginContainer/TextoResultado

@onready var visual_mesa = $Sala_RPG/VisualMesa
@onready var parede_norte = $Sala_RPG/VisualParedeNorte
@onready var parede_sul = $Sala_RPG/VisualParedeSul
@onready var parede_leste = $Sala_RPG/VisualParedeLeste
@onready var parede_oeste = $Sala_RPG/VisualParedeOeste
@onready var teto = $Sala_RPG/VisualTeto

# LISTA GLOBAL PARA CONTROLAR OS DADOS DINÂMICOS
var dados_instanciados: Array = []

var segurando_dado = false
var pode_interagir = true

var posicao_alvo_3d = Vector3.ZERO

# VARIÁVEIS DE CÂMERA (GIROSCÓPIO)
var sensibilidade_movimento = 1.5
var yaw: float = 0.0
var pitch: float = 0.0
var rotacao_suavizada = Vector2.ZERO
var marco_zero_definido = false

func _ready():
	Engine.physics_ticks_per_second = 120
	var safe_area = DisplayServer.get_display_safe_area()
	$MarginContainer.add_theme_constant_override("margin_top", safe_area.position.y)
	
	if has_node("MarginContainer/HBoxContainer/BotaoReset"):
		get_node("MarginContainer/HBoxContainer/BotaoReset").pressed.connect(_on_botao_reset_pressed)
	
	camera_visual.rotation = Vector3(0, 0, 0)
	recalibrar_marco_zero()
	
	# --- NOVO: Conecta o sinal de redimensionamento da tela ---
	get_tree().root.size_changed.connect(_on_tela_redimensionada)
	
	# Chama a função uma vez no início para garantir que já comece certo
	_on_tela_redimensionada()

# Função auxiliar para não repetir código ao spawnar
func _preparar_dado(dado_node):
	add_child(dado_node)
	dado_node.add_to_group("dados_na_mesa")
	dado_node.visible = false
	dado_node.freeze = true
	dado_node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	dados_instanciados.append(dado_node)

# Garante que NENHUM dado sobreviva entre as rolagens
func limpar_mesa():
	# Procura todos os nós no jogo que tenham a etiqueta "dados_na_mesa"
	for dado in get_tree().get_nodes_in_group("dados_na_mesa"):
		if is_instance_valid(dado):
			dado.free() # O .free() deleta na mesma hora, sem esperar o fim do frame!
			
	dados_instanciados.clear()

func _physics_process(delta):
	var leitura_giroscopio = Input.get_gyroscope()
	
	if not marco_zero_definido:
		if leitura_giroscopio.length() > 0.0:
			recalibrar_marco_zero()
			marco_zero_definido = true
		return
	
	var r_alvo = Vector2(leitura_giroscopio.x, leitura_giroscopio.y)
	rotacao_suavizada = r_alvo
		
	pitch += rotacao_suavizada.x * sensibilidade_movimento * delta
	yaw += rotacao_suavizada.y * sensibilidade_movimento * delta
	pitch = clamp(pitch, deg_to_rad(-60), deg_to_rad(75))
	camera_fisica.rotation = Vector3(pitch, yaw, 0)
	
	if segurando_dado:
		for i in range(dados_instanciados.size()):
			var d_inst = dados_instanciados[i]
			
			# --- LÊ A POSIÇÃO DA NUVEM QUE FOI SALVA ---
			var offset = Vector3.ZERO
			if d_inst.has_meta("offset_nuvem"):
				offset = d_inst.get_meta("offset_nuvem")
			
			# Calcula a distância do dedo + a posição na nuvem
			var vetor_distancia = (posicao_alvo_3d + offset) - d_inst.global_position
			
			# Move o dado usando força física (se eles se tocarem, a física os afasta suavemente)
			d_inst.linear_velocity = vetor_distancia * 25.0
			
			# LÊ O GIRO ÚNICO SALVO E APLICA ENQUANTO FLUTUA
			if d_inst.has_meta("giro_unico"):
				d_inst.angular_velocity = d_inst.get_meta("giro_unico")

	if not segurando_dado and not pode_interagir:
		if dados_instanciados.size() > 0:
			if not dados_instanciados[0].freeze:
				var todos_pararam = true
				for d_inst in dados_instanciados:
					if d_inst.linear_velocity.length() >= 0.1 or d_inst.angular_velocity.length() >= 0.1:
						todos_pararam = false
						break
						
				if todos_pararam:
					pode_interagir = true
					calcular_resultado_dado()

func recalibrar_marco_zero():
	pitch = deg_to_rad(-25.0)
	yaw = deg_to_rad(45.0)
	camera_fisica.rotation = Vector3(pitch, yaw, 0)
	rotacao_suavizada = Vector2.ZERO

func _on_botao_reset_pressed():
	recalibrar_marco_zero()

func _unhandled_input(event):
	if not pode_interagir:
		return
		
	# --- TRAVA DE SEGURANÇA PARA MODO PAISAGEM ---
	var tamanho_tela = get_viewport().size
	var em_modo_paisagem = tamanho_tela.x > tamanho_tela.y
	
	if em_modo_paisagem:
		var limite_do_menu = tamanho_tela.x * 0.30
		if event.position.x < limite_do_menu:
			return
	# ---------------------------------------------

	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if has_node("MarginContainer/HBoxContainer/BotaoReset") and get_node("MarginContainer/HBoxContainer/BotaoReset").get_global_rect().has_point(event.position):
			return
			
		if event.pressed:
			segurando_dado = true
			texto_resultado.text = "Rolando..."
			atualizar_alvo_dado(event.position)
			
			for i in range(dados_instanciados.size()):
				var d_inst = dados_instanciados[i]
				d_inst.visible = true
				d_inst.freeze = false
				d_inst.gravity_scale = 0.0
				
				# SORTEIA E GUARDA UM GIRO EXCLUSIVO
				var giro_individual = Vector3(
					randf_range(4.0, 12.0), randf_range(-15.0, 15.0), randf_range(-15.0, 15.0)
				)
				d_inst.set_meta("giro_unico", giro_individual)
				
				# --- LÓGICA DA NUVEM GAUSSIANA (CORRIGIDA) ---
				var altura_da_mao = 2.0 # Altura que os dados vão flutuar acima do dedo
				var offset_nuvem = Vector3(0, altura_da_mao, 0)
				
				if dados_instanciados.size() > 1:
					var dispersao = 0.3 + (dados_instanciados.size() * 0.05)
					
					var desvio_x = randfn(0.0, dispersao)
					# O abs() evita que o Y seja negativo (atravessando a mesa)
					var desvio_y = abs(randfn(0.0, dispersao * 0.5)) + altura_da_mao
					var desvio_z = randfn(0.0, dispersao)
					
					offset_nuvem = Vector3(desvio_x, desvio_y, desvio_z)
				
				# Guarda a posição dessa nuvem no dado
				d_inst.set_meta("offset_nuvem", offset_nuvem)
				
				# Coloca o dado instantaneamente nesse local da nuvem
				d_inst.global_position = posicao_alvo_3d + offset_nuvem
		else:
			segurando_dado = false
			pode_interagir = false
			
			for d_inst in dados_instanciados:
				d_inst.gravity_scale = 1.0
				
				# APLICA O GIRO NO MOMENTO EM QUE O DEDO SOLTA A TELA
				if d_inst.has_meta("giro_unico"):
					d_inst.angular_velocity = d_inst.get_meta("giro_unico")

	# === GARANTE QUE OS DADOS SIGAM O DEDO ARRASTANDO ===
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if segurando_dado:
			atualizar_alvo_dado(event.position)

func atualizar_alvo_dado(posicao_tela):
	var plano_mesa = Plane(Vector3.UP, 4.0)
	var raio_origem = camera_visual.project_ray_origin(posicao_tela)
	var raio_direcao = camera_visual.project_ray_normal(posicao_tela)
	var intersecao = plano_mesa.intersects_ray(raio_origem, raio_direcao)
	if intersecao:
		posicao_alvo_3d = intersecao


# ==========================================
# LEITURA E CÁLCULO DOS RESULTADOS
# ==========================================
func calcular_resultado_dado():
	var valores_rolados = []
	var leitura_porcentagem = {"dezena": 0, "unidade": 0}
	
	for d_inst in dados_instanciados:
		if not d_inst.has_node("Faces"): continue
			
		var pasta_faces = d_inst.get_node("Faces")
		var maior_produto_escalar = -1.0
		var face_vencedora = "0"
		
		for marcador in pasta_faces.get_children():
			if marcador is Marker3D or marcador is Node3D:
				var direcao_da_face = (marcador.global_position - d_inst.global_position).normalized()
				var alinhamento = direcao_da_face.dot(Vector3.UP)
				
				if alinhamento > maior_produto_escalar:
					maior_produto_escalar = alinhamento
					face_vencedora = marcador.name
					
		if face_vencedora.is_valid_int():
			var valor_inteiro = face_vencedora.to_int()
			valores_rolados.append(valor_inteiro)
			
			if d_inst.has_meta("funcao"):
				leitura_porcentagem[d_inst.get_meta("funcao")] = valor_inteiro

	var texto_final = ""
	
	GlobalData.contador_rolagens += 1
	var num_roll = GlobalData.contador_rolagens
	var linha_historico = ""
	
	# --- SEPARAÇÃO DE CÁLCULO ---
	if GlobalData.tipo_rolagem_atual == GlobalData.TipoRolagem.SISTEMA_D20:
		
		# (O código original do D20 entra aqui)
		var escolhido = 0
		var cd = GlobalData.d20_cd_alvo
		var texto_vantagem = ""
		
		if GlobalData.d20_estado_atual == GlobalData.EstadoD20.VANTAGEM and valores_rolados.size() >= 2:
			escolhido = max(valores_rolados[0], valores_rolados[1])
			texto_vantagem = " (VAN)"
			texto_final = "Rolou ("+str(valores_rolados[0])+" e "+str(valores_rolados[1])+")\nCom Vantagem: " + str(escolhido)
		elif GlobalData.d20_estado_atual == GlobalData.EstadoD20.DESVANTAGEM and valores_rolados.size() >= 2:
			escolhido = min(valores_rolados[0], valores_rolados[1])
			texto_vantagem = " (DES)"
			texto_final = "Rolou ("+str(valores_rolados[0])+" e "+str(valores_rolados[1])+")\nCom Desvantagem: " + str(escolhido)
		else:
			escolhido = valores_rolados[0] if valores_rolados.size() > 0 else 0
			texto_final = "Rolou: " + str(escolhido)
			
		if escolhido >= cd: texto_final += " | 🟢 SUCESSO"
		else: texto_final += " | 🔴 FALHA"
		
		linha_historico = "Roll %d: 1d20%s [b][%d][/b] NAT %s" % [num_roll, texto_vantagem, escolhido, str(valores_rolados)]

	else:
		# (O código original do Free Roll entra aqui)
		if GlobalData.dados_para_rolar["d%"] > 0:
			var resultado_d_cem = GlobalData.calcular_resultado_porcentagem(leitura_porcentagem["dezena"], leitura_porcentagem["unidade"])
			texto_final = "Resultado d%: " + str(resultado_d_cem)
			linha_historico = "Roll %d: d%% [b][%d][/b] NAT %d" % [num_roll, resultado_d_cem, resultado_d_cem]
		else:
			var soma_total = 0
			var soma_natural = 0
			var formula_str = ""
			
			for dado in GlobalData.dados_para_rolar.keys():
				var qtd = GlobalData.dados_para_rolar[dado]
				if qtd > 0:
					if formula_str != "": formula_str += "+"
					formula_str += str(qtd) + dado
					
			var mod = GlobalData.modificador_total
			if mod > 0: formula_str += "+" + str(mod)
			elif mod < 0: formula_str += str(mod)
			
			for valor in valores_rolados:
				soma_natural += valor
				
			soma_total = soma_natural + mod
			
			texto_final = "Rolou: " + str(valores_rolados)
			if mod != 0: texto_final += " (Mod: " + str(mod) + ")"
			texto_final += "\nTotal: " + str(soma_total)
			
			linha_historico = "Roll %d: %s [b][%d][/b] NAT %d" % [num_roll, formula_str, soma_total, soma_natural]

	texto_resultado.text = texto_final
	GlobalData.historico_rolagens.append(linha_historico)
	
	# --- AVISO AO MENU COM DEBUG ---
	var cena_mestre = get_tree().current_scene
	if cena_mestre.has_node("CanvasLayer/MenuPrincipal"):
		cena_mestre.get_node("CanvasLayer/MenuPrincipal").atualizar_historico()
		print("SUCESSO: Histórico enviado para o Menu!")
	else:
		print("ERRO 3D: Não encontrou o MenuPrincipal em: CanvasLayer/MenuPrincipal")

func trocar_skin_dado(nome_da_skin: String):
	var caminho = "res://skins/dados/" + nome_da_skin + ".tres"
	var novo_material = load(caminho)
	if novo_material:
		for d_inst in dados_instanciados:
			if d_inst.has_node("VisualDado"):
				d_inst.get_node("VisualDado").set_surface_override_material(0, novo_material)


func _on_botao_retorno_pressed() -> void:
	limpar_mesa()
	pode_interagir = false
	
	var cena_mestre = get_tree().current_scene
	if cena_mestre.has_node("CanvasLayer/MenuPrincipal"):
		cena_mestre.get_node("CanvasLayer/MenuPrincipal").visible = true
	
	if get_viewport().size.y > get_viewport().size.x:
		self.visible = false
		self.process_mode = Node.PROCESS_MODE_DISABLED

func iniciar_rolagem_pelo_menu():
	
	limpar_mesa()
	
	if GlobalData.tipo_rolagem_atual == GlobalData.TipoRolagem.SISTEMA_D20:
		var cena_d20 = load(caminhos_cenas["d20"])
		
		# Rolagem do topo da tela (Com ou sem Vantagem)
		if GlobalData.d20_estado_atual != GlobalData.EstadoD20.NORMAL:
			for i in range(2):
				var dado = cena_d20.instantiate()
				_preparar_dado(dado)
		else:
			var dado = cena_d20.instantiate()
			_preparar_dado(dado)
			
	else:
		# Rolagem do meio da tela (Free Roll)
		if GlobalData.dados_para_rolar["d%"] > 0:
			var cena_d10 = load(caminhos_cenas["d10"])
			var dado_dezena = cena_d10.instantiate()
			dado_dezena.set_meta("funcao", "dezena")
			_preparar_dado(dado_dezena)
			var dado_unidade = cena_d10.instantiate()
			dado_unidade.set_meta("funcao", "unidade")
			_preparar_dado(dado_unidade)
		else:
			for chave_dado in GlobalData.dados_para_rolar.keys():
				var quantidade = GlobalData.dados_para_rolar[chave_dado]
				if quantidade > 0 and chave_dado != "d%":
					var cena_carregada = load(caminhos_cenas[chave_dado])
					for i in range(quantidade):
						var novo_dado = cena_carregada.instantiate()
						_preparar_dado(novo_dado)
	
	texto_resultado.text = "Toque na tela para jogar!"
	segurando_dado = false

	await get_tree().create_timer(0.1).timeout
	
	pode_interagir = true
	
# ==========================================
# RESPONSIVIDADE DA UI (RETRATO / PAISAGEM)
# ==========================================
func _on_tela_redimensionada():
	# Verifica se o MarginContainer ainda existe na cena
	if not has_node("MarginContainer"):
		return
		
	var margem = $MarginContainer
	var tamanho_tela = get_viewport().size
	var em_modo_paisagem = tamanho_tela.x > tamanho_tela.y
	
	if em_modo_paisagem:
		# Modo Paisagem: Empurra a UI 30% para a direita para fugir do menu lateral, mais 10px de respiro
		var limite_do_menu = (tamanho_tela.x * 0.35) + 20
		margem.add_theme_constant_override("margin_left", limite_do_menu)
	else:
		# Modo Retrato: Volta a margem esquerda para o padrão (ex: 20 pixels)
		margem.add_theme_constant_override("margin_left", 20)
