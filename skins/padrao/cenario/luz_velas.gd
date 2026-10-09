extends DirectionalLight3D

# ==========================================
# CONFIGURAÇÕES DA VELA
# ==========================================
@export var cor_quente: Color = Color(1.0, 0.75, 0.3)  # Amarelo/Laranja claro
@export var cor_fria: Color = Color(0.9, 0.4, 0.1)     # Laranja escuro avermelhado

@export var energia_base: float = 1.0
@export var variacao_de_energia: float = 0.3

@export var variacao_de_direcao: float = 2.0 # O quanto as sombras vão "dançar" (em graus)
@export var velocidade_da_chama: float = 80.0

var ruido = FastNoiseLite.new()
var tempo: float = 0.0
var rotacao_original: Vector3

func _ready():
	# Salva a direção original para a luz não "fugir" com o tempo
	rotacao_original = rotation_degrees
	
	# Configura o gerador de ondas naturais
	ruido.seed = randi()
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ruido.frequency = 0.05 # Deixa a transição bem suave

func _process(delta):
	# O tempo avança para navegarmos pelas ondas do ruído
	tempo += delta * velocidade_da_chama
	
	# O get_noise_1d retorna um valor suave que sobe e desce entre -1.0 e 1.0
	var onda_1 = ruido.get_noise_1d(tempo)
	
	# Pegamos uma segunda onda diferente para não ficar um movimento robótico
	var onda_2 = ruido.get_noise_1d(tempo + 1000.0) 
	
	# ==========================================
	# 1. A TREMULAÇÃO DA INTENSIDADE (Brilho)
	# ==========================================
	light_energy = energia_base + (onda_1 * variacao_de_energia)
	
	# ==========================================
	# 2. A ALTERAÇÃO LEVE DE COR
	# ==========================================
	# Transformamos a onda de [-1 a 1] para [0 a 1] para fazer a mistura (lerp)
	var fator_mistura = (onda_1 + 1.0) / 2.0
	light_color = cor_quente.lerp(cor_fria, fator_mistura)
	
	# ==========================================
	# 3. O DANÇAR DA DIREÇÃO DAS SOMBRAS
	# ==========================================
	# Adicionamos a variação em graus na rotação X e Y da câmera original
	rotation_degrees.x = rotacao_original.x + (onda_1 * variacao_de_direcao)
	rotation_degrees.y = rotacao_original.y + (onda_2 * variacao_de_direcao)
