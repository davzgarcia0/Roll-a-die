extends Node3D

# ==========================================
# CAMINHOS DOS SEUS MODELOS 3D
# ==========================================
var caminhos_cenas = {
	"d4": "res://geral/cenas/dados/dado_d_4.tscn",
	"d6": "res://geral/cenas/dados/dado_d_6.tscn",
	"d8": "res://geral/cenas/dados/dado_d_8.tscn",
	"d10": "res://geral/cenas/dados/dado_d_10.tscn",
	"d12": "res://geral/cenas/dados/dado_d_12.tscn",
	"d20": "res://geral/cenas/dados/dado_d_20.tscn"
}

var materiais_dado_atual: Dictionary = {} # Guarda os materiais (.tres)
var malhas_dado_atual: Dictionary = {}    # Guarda as malhas (.res)

# Referências aos nós físicos da cena
@onready var camera_fisica = $PlayerCamera
@onready var camera_visual = $PlayerCamera/Camera3D

@onready var visual_mesa = $Sala_RPG/VisualMesa
@onready var parede_norte = $Sala_RPG/VisualParedeNorte
@onready var parede_sul = $Sala_RPG/VisualParedeSul
@onready var parede_leste = $Sala_RPG/VisualParedeLeste
@onready var parede_oeste = $Sala_RPG/VisualParedeOeste
@onready var teto = $Sala_RPG/VisualTeto
@onready var fundo = $Sala_RPG/VisualFundo

# ==========================================
# NOVAS REFERÊNCIAS DA INTERFACE (CANVAS LAYER)
# ==========================================
@onready var ui_retrato = $CanvasLayer/UI_Retrato
@onready var ui_paisagem = $CanvasLayer/UI_Paisagem
@onready var texto_resultado = $CanvasLayer/TextoResultado

# ATENÇÃO: Ajuste o caminho abaixo para onde o texto da fórmula ficou dentro da sua UI_Paisagem!
@onready var label_formula_paisagem = $CanvasLayer/UI_Paisagem/MarginContainer3/HBoxContainer/PanelContainer/formula

const LIMITE_X_MIN: float = -9
const LIMITE_X_MAX: float = 9
const LIMITE_Z_MIN: float = -9
const LIMITE_Z_MAX: float = 9

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
	camera_visual.rotation = Vector3.ZERO
	recalibrar_marco_zero()
	
	if texto_resultado:
		texto_resultado.text = ""

	aplicar_skin_completa(AudioManager.skin_atual)

# ==========================================
# LÓGICA DO MENU FLUTUANTE (MODO PAISAGEM)
# ==========================================

# Chamado pelo jogo_principal.gd quando o jogador vira o celular
func alternar_interface(em_paisagem: bool):
	if ui_paisagem: ui_paisagem.visible = em_paisagem
	if ui_retrato: ui_retrato.visible = not em_paisagem

func _on_botao_retorno_pressed() -> void:
	limpar_mesa()
	
	# Garante que a tela estará destravada da próxima vez que entrar na sala
	pode_interagir = true 
	
	if texto_resultado: 
		texto_resultado.text = ""
		
	# Zera a matemática para que o menu inicial sempre comece "limpo"
	GlobalData.limpar_dados() 
	
	get_tree().current_scene.voltar_ao_menu()


# Funções chamadas pelos botões de dados do Menu Flutuante (UI_Paisagem)
func adicionar_dado(tipo_dado: String):
	GlobalData.tipo_rolagem_atual = GlobalData.TipoRolagem.FREE_ROLL
	
	if tipo_dado == "d%":
		GlobalData.limpar_dados()
		GlobalData.dados_para_rolar["d%"] = 1
	else:
		if GlobalData.dados_para_rolar["d%"] > 0:
			GlobalData.dados_para_rolar["d%"] = 0
		GlobalData.dados_para_rolar[tipo_dado] += 1
		
	atualizar_interface_formula()
	limpar_mesa()
	
	# --- A CORREÇÃO DESTRAVA-TELA ---
	pode_interagir = true 
	if texto_resultado: texto_resultado.text = "Toque para rolar novos dados!"

func alterar_modificador(valor: int):
	GlobalData.tipo_rolagem_atual = GlobalData.TipoRolagem.FREE_ROLL
	
	if GlobalData.dados_para_rolar["d%"] > 0: return
	GlobalData.modificador_total += valor
	atualizar_interface_formula()
	limpar_mesa()
	
	# --- A CORREÇÃO DESTRAVA-TELA ---
	pode_interagir = true

func _on_botao_reset_pressed():
	GlobalData.limpar_dados()
	GlobalData.tipo_rolagem_atual = GlobalData.TipoRolagem.FREE_ROLL
	atualizar_interface_formula()
	
	limpar_mesa() # Evapora os modelos 3D antigos
	
	# --- A CORREÇÃO DESTRAVA-TELA ---
	pode_interagir = true # Permite que o próximo toque funcione!
	
	if texto_resultado: texto_resultado.text = "Pool zerada."

func atualizar_interface_formula():
	if label_formula_paisagem == null: return
	var formula_texto = ""
	
	if GlobalData.dados_para_rolar["d%"] > 0:
		formula_texto = "d%"
	else:
		for dado in GlobalData.dados_para_rolar.keys():
			var quantidade = GlobalData.dados_para_rolar[dado]
			if quantidade > 0 and dado != "d%":
				if formula_texto != "": formula_texto += " + "
				formula_texto += str(quantidade) + dado
				
		var mod = GlobalData.modificador_total
		if mod > 0: formula_texto += " +" + str(mod)
		elif mod < 0: formula_texto += " " + str(mod)
		
	label_formula_paisagem.text = formula_texto

# ==========================================
# GERENCIAMENTO DE DADOS (SPAWN E FÍSICA)
# ==========================================

func _preparar_dado(dado_node):
	add_child(dado_node)
	dado_node.add_to_group("dados_na_mesa")
	dado_node.visible = false
	dado_node.freeze = true
	dado_node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	dado_node.contact_monitor = true
	dado_node.max_contacts_reported = 10
	
	var tipo_dado = dado_node.get_meta("tipo_dado") if dado_node.has_meta("tipo_dado") else ""
	var mat_novo = materiais_dado_atual.get(tipo_dado, null)
	var malha_nova = malhas_dado_atual.get(tipo_dado, null)
	
	# ==========================================
	# ESCURECIMENTO EXCLUSIVO PARA A DEZENA DO D%
	# ==========================================
	if dado_node.has_meta("funcao") and dado_node.get_meta("funcao") == "dezena":
		if mat_novo != null:
			# Duplica o material para não afetar o dado de unidade
			mat_novo = mat_novo.duplicate() 
			
			# Se for um material padrão 3D, reduz a luz da cor base em 50% (0.5)
			if mat_novo is StandardMaterial3D:
				mat_novo.albedo_color = mat_novo.albedo_color.darkened(0.5) 
	# ==========================================
	
	_aplicar_visual_seguro(dado_node, mat_novo, malha_nova)
		
	dados_instanciados.append(dado_node)


# Função Caçadora Atualizada (Troca material e também a malha se existir)
func _aplicar_visual_seguro(no_raiz: Node, material: Material, nova_malha: Mesh = null):
	if no_raiz == null: 
		return
		
	var malha_node = _buscar_mesh_instance(no_raiz)
	if malha_node != null:
		if material != null:
			malha_node.set_surface_override_material(0, material)
		if nova_malha != null:
			malha_node.mesh = nova_malha # Aqui a mágica de trocar o modelo 3D acontece!
	else:
		print("AVISO: Nenhuma malha 3D encontrada dentro de: ", no_raiz.name)

func limpar_mesa():
	for dado in get_tree().get_nodes_in_group("dados_na_mesa"):
		if is_instance_valid(dado):
			dado.free()
	dados_instanciados.clear()
	
# Função acionada pelo jogo_principal.gd toda vez que o celular é girado
func resetar_mesa_ao_girar():
	limpar_mesa()               # Destrói os modelos 3D velhos
	pode_interagir = true       # Destrava a tela para aceitar novos toques
	segurando_dado = false      # Garante que nenhum dado invisível ficou grudado no dedo
	
	if texto_resultado: 
		texto_resultado.text = "" # Limpa o letreiro do topo
		
	atualizar_interface_formula() # Atualiza a barra de matemática da UI Paisagem para refletir o zero

func _gerar_dados_da_formula_atual():
	limpar_mesa()
	if GlobalData.tipo_rolagem_atual == GlobalData.TipoRolagem.SISTEMA_D20:
		var cena_d20 = load(caminhos_cenas["d20"])
		if GlobalData.d20_estado_atual != GlobalData.EstadoD20.NORMAL:
			for i in range(2): 
				var d_novo = cena_d20.instantiate()
				d_novo.set_meta("tipo_dado", "d20")
				_preparar_dado(d_novo)
		else:
			var d_novo = cena_d20.instantiate()
			d_novo.set_meta("tipo_dado", "d20")
			_preparar_dado(d_novo)
	else:
		if GlobalData.dados_para_rolar["d%"] > 0:
			var cena_d10 = load(caminhos_cenas["d10"])
			var d_dez = cena_d10.instantiate()
			d_dez.set_meta("funcao", "dezena")
			d_dez.set_meta("tipo_dado", "d10") # Etiqueta adicionada
			_preparar_dado(d_dez)
			var d_uni = cena_d10.instantiate()
			d_uni.set_meta("funcao", "unidade")
			d_uni.set_meta("tipo_dado", "d10") # Etiqueta adicionada
			_preparar_dado(d_uni)
		else:
			for chave_dado in GlobalData.dados_para_rolar.keys():
				var qtd = GlobalData.dados_para_rolar[chave_dado]
				if qtd > 0 and chave_dado != "d%":
					var cena_carregada = load(caminhos_cenas[chave_dado])
					for i in range(qtd):
						var d_novo = cena_carregada.instantiate()
						d_novo.set_meta("tipo_dado", chave_dado) # Etiqueta adicionada
						_preparar_dado(d_novo)

# A função original agora fica bem menor e mais limpa
func iniciar_rolagem_pelo_menu():
	_gerar_dados_da_formula_atual()
	if texto_resultado: texto_resultado.text = "Toque na tela para jogar!"
	segurando_dado = false


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
	pitch = clamp(pitch, deg_to_rad(-90), deg_to_rad(90))
	camera_fisica.rotation = Vector3(pitch, yaw, 0)
	
	if segurando_dado:
		for i in range(dados_instanciados.size()):
			var d_inst = dados_instanciados[i]
			var offset = Vector3.ZERO
			if d_inst.has_meta("offset_nuvem"):
				offset = d_inst.get_meta("offset_nuvem")
			
			var vetor_distancia = (posicao_alvo_3d + offset) - d_inst.global_position
			d_inst.linear_velocity = vetor_distancia * 25.0
			
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

func _unhandled_input(event):
	if not pode_interagir:
		return

	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			
			# =========================================================
			# LÓGICA UNIVERSAL (RETRATO E PAISAGEM)
			if dados_instanciados.is_empty():
				var tem_dados = false
				if GlobalData.tipo_rolagem_atual == GlobalData.TipoRolagem.SISTEMA_D20:
					tem_dados = true
				else:
					for qtd in GlobalData.dados_para_rolar.values():
						if qtd > 0: tem_dados = true
						
				if tem_dados:
					_gerar_dados_da_formula_atual()
			# =========================================================

			if dados_instanciados.is_empty():
				return
				
			segurando_dado = true
			if texto_resultado: texto_resultado.text = "Rolando..."
			atualizar_alvo_dado(event.position)
			
			# Chama a nova função que organiza os dados na mão
			_atualizar_posicao_da_nuvem()
				
		else:
			segurando_dado = false
			pode_interagir = false
			
			for d_inst in dados_instanciados:
				d_inst.gravity_scale = 1.0
				if d_inst.has_meta("giro_unico"):
					d_inst.angular_velocity = d_inst.get_meta("giro_unico")

	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if segurando_dado:
			atualizar_alvo_dado(event.position)
			# Atualiza a nuvem acompanhando o arrasto do dedo
			_atualizar_posicao_da_nuvem()


# ==========================================
# NOVA FUNÇÃO PARA LIMITAR E ORGANIZAR A NUVEM
# ==========================================
func _atualizar_posicao_da_nuvem():
	for i in range(dados_instanciados.size()):
		var d_inst = dados_instanciados[i]
		d_inst.visible = true
		d_inst.freeze = false
		d_inst.gravity_scale = 0.0
		
		var giro_individual = Vector3(
			randf_range(4.0, 12.0), randf_range(-15.0, 15.0), randf_range(-15.0, 15.0)
		)
		d_inst.set_meta("giro_unico", giro_individual)
		
		var altura_da_mao = 2.0
		var offset_nuvem = Vector3(0, altura_da_mao, 0)
		
		if dados_instanciados.size() > 1:
			# 1. O LIMITE MATEMÁTICO DA DISPERSÃO
			# O comando min() impede que o multiplicador passe de 1.5,
			# limitando o tamanho máximo da nuvem não importa quantos dados existam.
			var dispersao = min(0.3 + (dados_instanciados.size() * 0.05), 3)
			
			var desvio_x = randfn(0.0, dispersao)
			var desvio_y = abs(randfn(0.0, dispersao * 0.5)) + altura_da_mao
			var desvio_z = randfn(0.0, dispersao)
			offset_nuvem = Vector3(desvio_x, desvio_y, desvio_z)
		
		d_inst.set_meta("offset_nuvem", offset_nuvem)
		
		# 2. O LIMITE FÍSICO DO ESPAÇO
		# Utiliza as constantes LIMITE_X e LIMITE_Z que você já definiu 
		# para garantir que os dados nunca nasçam fora da área da mesa.
		var pos_final = posicao_alvo_3d + offset_nuvem
		pos_final.x = clampf(pos_final.x, LIMITE_X_MIN, LIMITE_X_MAX)
		pos_final.z = clampf(pos_final.z, LIMITE_Z_MIN, LIMITE_Z_MAX)
		
		d_inst.global_position = pos_final

func atualizar_alvo_dado(posicao_tela):
	var plano_mesa = Plane(Vector3.UP, 4.0)
	var raio_origem = camera_visual.project_ray_origin(posicao_tela)
	var raio_direcao = camera_visual.project_ray_normal(posicao_tela)
	var intersecao = plano_mesa.intersects_ray(raio_origem, raio_direcao)
	if intersecao:
		# Trava a posição do dedo dentro da caixa delimitadora da mesa
		intersecao.x = clampf(intersecao.x, LIMITE_X_MIN, LIMITE_X_MAX)
		intersecao.z = clampf(intersecao.z, LIMITE_Z_MIN, LIMITE_Z_MAX)
		posicao_alvo_3d = intersecao

func recalibrar_marco_zero():
	pitch = deg_to_rad(-25.0)
	yaw = deg_to_rad(45.0)
	camera_fisica.rotation = Vector3(pitch, yaw, 0)
	rotacao_suavizada = Vector2.ZERO


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
	
	if GlobalData.tipo_rolagem_atual == GlobalData.TipoRolagem.SISTEMA_D20:
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
			
		if escolhido >= cd: texto_final += "  🟢 SUCESSO"
		else: texto_final += "  🔴 FALHA"
		
		linha_historico = "Roll %d: 1d20%s [b][%d][/b] NAT %s" % [num_roll, texto_vantagem, escolhido, str(valores_rolados)]

	else:
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

	if texto_resultado: texto_resultado.text = texto_final
	GlobalData.historico_rolagens.append(linha_historico)
	
	var cena_mestre = get_tree().current_scene
	if cena_mestre.has_node("CanvasLayer/MenuPrincipal"):
		cena_mestre.get_node("CanvasLayer/MenuPrincipal").atualizar_historico()

# ==========================================
# SISTEMA DE SKINS (CENÁRIO, DADOS E ÁUDIO)
# ==========================================
func aplicar_skin_completa(nome_da_skin: String):
	AudioManager.skin_atual = nome_da_skin
	AudioManager.salvar_configuracoes()
	
	# Limpa a memória das skins anteriores
	malhas_dado_atual.clear()
	materiais_dado_atual.clear()
	
	var tipos_de_dados = ["d4", "d6", "d8", "d10", "d12", "d20"]
	
# ==========================================
	# CARREGA OS ARQUIVOS INDIVIDUAIS DE CADA DADO
	# ==========================================
	for tipo in tipos_de_dados:
		# 1. Carrega o Material (As cores/texturas)
		var caminho_mat = "res://skins/" + nome_da_skin + "/dados/" + nome_da_skin +  "_mat_" + tipo + ".tres"
		if ResourceLoader.exists(caminho_mat):
			materiais_dado_atual[tipo] = load(caminho_mat)
			
		# 2. Carrega a Malha (O Formato 3D) - AGORA VALE PARA A PADRÃO TAMBÉM!
		var caminho_mesh = "res://skins/" + nome_da_skin + "/dados/" + nome_da_skin + "_mesh_" + tipo + ".res"
		if ResourceLoader.exists(caminho_mesh):
			malhas_dado_atual[tipo] = load(caminho_mesh)

# ==========================================
	# APLICA NOS DADOS QUE JÁ ESTÃO NA MESA
	# ==========================================
	for d_inst in dados_instanciados:
		if is_instance_valid(d_inst):
			var tipo_dado = d_inst.get_meta("tipo_dado") if d_inst.has_meta("tipo_dado") else ""
			var mat_novo = materiais_dado_atual.get(tipo_dado, null)
			var malha_nova = malhas_dado_atual.get(tipo_dado, null)
			
			# Garante que a dezena permaneça escura se a skin for trocada no meio do jogo
			if d_inst.has_meta("funcao") and d_inst.get_meta("funcao") == "dezena":
				if mat_novo != null:
					mat_novo = mat_novo.duplicate()
					if mat_novo is StandardMaterial3D:
						mat_novo.albedo_color = mat_novo.albedo_color.darkened(0.5)
			
			_aplicar_visual_seguro(d_inst, mat_novo, malha_nova)
				
# ==========================================
	# CARREGA E APLICA O CENÁRIO E FUNDO
	# ==========================================
	var caminho_base = "res://skins/" + nome_da_skin + "/cenario/" + nome_da_skin
	
	# 1. Tenta carregar os Materiais (.tres)
	var mat_mesa = load(caminho_base + "_mat_mesa.tres")
	var mat_parede_norte = load(caminho_base + "_mat_parede_norte.tres")
	var mat_parede_sul = load(caminho_base + "_mat_parede_sul.tres")
	var mat_parede_leste = load(caminho_base + "_mat_parede_leste.tres")
	var mat_parede_oeste = load(caminho_base + "_mat_parede_oeste.tres")
	var mat_teto = load(caminho_base + "_mat_teto.tres")
	var mat_fundo = load(caminho_base + "_mat_fundo.tres")
	
	# 2. Tenta carregar as Malhas 3D (.res) vindas do Blender
	var mesh_mesa = load(caminho_base + "_mesh_mesa.res")
	var mesh_parede_norte = load(caminho_base + "_mesh_parede_norte.res")
	var mesh_parede_sul = load(caminho_base + "_mesh_parede_sul.res")
	var mesh_parede_leste = load(caminho_base + "_mesh_parede_leste.res")
	var mesh_parede_oeste = load(caminho_base + "_mesh_parede_oeste.res")
	var mesh_teto = load(caminho_base + "_mesh_teto.res")
	var mesh_fundo = load(caminho_base + "_mesh_fundo.res")
	
	# 3. Aplica o combo (Material + Malha) em cada parede e mesa
	_aplicar_visual_seguro(visual_mesa, mat_mesa, mesh_mesa)
	_aplicar_visual_seguro(parede_norte, mat_parede_norte, mesh_parede_norte)
	_aplicar_visual_seguro(parede_sul, mat_parede_sul, mesh_parede_sul)
	_aplicar_visual_seguro(parede_leste, mat_parede_leste, mesh_parede_leste)
	_aplicar_visual_seguro(parede_oeste, mat_parede_oeste, mesh_parede_oeste)
	_aplicar_visual_seguro(teto, mat_teto, mesh_teto)
	
	# O fundo tem uma checagem de segurança caso o nó ainda não exista na cena
	if fundo != null: 
		_aplicar_visual_seguro(fundo, mat_fundo, mesh_fundo)

# ==========================================
# FUNÇÃO CAÇADORA DE MALHA 3D
# ==========================================
# Função recursiva que vasculha "filhos" e "netos" até achar o modelo 3D
func _buscar_mesh_instance(no_atual: Node) -> MeshInstance3D:
	if no_atual is MeshInstance3D:
		return no_atual
		
	for filho in no_atual.get_children():
		var resultado = _buscar_mesh_instance(filho)
		if resultado != null:
			return resultado
			
	return null
	
func _on_botao_recalibrar_pressed() -> void:
	recalibrar_marco_zero()
