extends Node

# Dicionário que guarda quantos dados de cada tipo foram selecionados
var dados_para_rolar = {
	"d4": 0, "d6": 0, "d8": 0, "d10": 0, "d%": 0, "d12": 0, "d20": 0
}
var modificador_total = 0

# Estados possíveis para a rolagem do D20
enum EstadoD20 { NORMAL, VANTAGEM, DESVANTAGEM }

# Variáveis que a Sala 3D vai ler do sistema D20
var d20_estado_atual = EstadoD20.NORMAL
var d20_cd_alvo = 15
enum TipoRolagem { SISTEMA_D20, FREE_ROLL }
var tipo_rolagem_atual = TipoRolagem.FREE_ROLL

# ==========================================
# VARIÁVEIS DO HISTÓRICO
# ==========================================
var historico_rolagens: Array = []
var contador_rolagens: int = 0

# ==========================================
# FUNÇÕES GLOBAIS
# ==========================================

# Função para zerar tudo após a rolagem ou ao clicar em RESET
func limpar_dados():
	# Reseta os contadores de dados
	for chave in dados_para_rolar.keys():
		dados_para_rolar[chave] = 0
	
	modificador_total = 0

	

# Função para calcular o d% clássico usando dois d10 (numerados de 1 a 10)
func calcular_resultado_porcentagem(face_dezena: int, face_unidade: int) -> int:
	
	# Regra 1: Se os dois caírem no número 10, representa o 100
	if face_dezena == 10 and face_unidade == 10:
		return 100
		
	# Cria variáveis temporárias para aplicar as regras de zero
	var valor_dezena = face_dezena
	var valor_unidade = face_unidade
	
	# Regra 2: Se a dezena for 10 (e a unidade não for), a dezena vale 0
	if face_dezena == 10:
		valor_dezena = 0
		
	# Regra 3: Se a unidade for 10 (e a dezena não for), a unidade vale 0
	if face_unidade == 10:
		valor_unidade = 0
		
	# O cálculo final da porcentagem
	return (valor_dezena * 10) + valor_unidade
