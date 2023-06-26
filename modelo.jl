# Ariel A. S. Nascimento
# arielanny@icloud.com
# Junho 2023

using JuMP, MathOptInterface, HiGHS, DataFrames, Cbc, Gurobi

include("L10N20.jl")
include("L10N30.jl")
include("L10N50.jl")

include("L20N20.jl")
include("L20N30.jl")
include("L20N50.jl")

include("L30N20.jl")
include("L30N30.jl")
include("L30N50.jl")

# ********** INICIALIZAÇÃO DO OBJETO MODELO **********
model = Model(Gurobi.Optimizer)
set_time_limit_sec(model,100) # seta o tempo em segundos

# **********  DEFINIÇÃO DE PARÂMETROS **********
# matriz a_li binária, elemento = 1 -> existe pedido da loja l para o logradouro i, 0 c.c.

a = al10n20

L,N = size(a)# numero de lojas e numero de destinos
TT = 10 # tempo (min) de troca de veiculos
TP = zeros(1,L) # tempo de processamento (descarregamento e separação) das cargas de entrada
TC = zeros(1,N) # tempo de processamento das cargas de entrada
t_manuseio = 2 # minutos em média para manusear um pacote, consideramos que as cargas são pequenas
t_separacao = 2  # minutos para separar um pacte de acordo com uma região

# calculando tempo de processamento das cargas de entrada
    # baseado na quantidade de cargas que vêm de uma única loja
    # processamento = tempo de descarregar e separação
for l in 1:L
    aux = 0
    for i in 1:N
        aux = aux + a[l,i]
    end
    tempo = (t_manuseio  * aux) + (t_separacao * aux) # contando tempo de descarregar a carga e de seperar ela
    TP[l] = tempo
end

# calculando tempo de carregamento das cargas de saída
for i in 1:N
    aux = 0
    for l in 1:L
        aux = aux + a[l,i]
    end
    tempo = t_manuseio * aux
    TC[i] = tempo
end

# calculando o big M, para desativação de algumas restrições conforme necessários
M = 2 * (sum(TP) + sum(TC)) + 1

# **********  DECLARAÇÃO DE VARIÁVEIS **********
@variable(model, tp[1:L] >= 0)
@variable(model, tc[1:N] >= 0)

@variable(model, tc_max >= 0)

@variable(model, w[1:L+2, 1:L+2], binary=true)
@variable(model, z[1:N+2, 1:N+2], binary=true)

# ********** RESTRIÇÕES DAS CARGAS DE ENTRADA **********
for l in 1:L+2
    @constraint(model, w[l,1] == 0) # ninguém pode vir antes da carga fantasma do começo
end

for m in 1:L+2
    @constraint(model, w[L+2,m] == 0) # ninguém pode vir antes da carga fantasma do final
end

for m in 2:L+2
    @constraint(model, sum(w[:,m]) - w[m,m] == 1)
end

for l in 1:L+1
    @constraint(model, sum(w[l,:]) - w[l,l] == 1)
end

for l in 1:L
    for m in 1:L
        if l !=m
            @constraint(model, tp[m] >= tp[l] + TT + TP[m] - M*(1 - w[l+1,m+1]))
        end
    end
end

for l in 1:L
    @constraint(model, tp[l] >= TP[l])
end

# ********** RESTRIÇÕES DAS CARGAS DE SAÍDA **********

for i in 1:N+2
    @constraint(model, z[i,1] == 0) # ninguém pode vir antes da carga fantasma do começo
end

for j in 1:N+2
    @constraint(model, z[N+2,j] == 0) # ninguém pode vir antes da carga fantasma do final
end

for j in 2:N+2
    @constraint(model, sum(z[:,j]) - z[j,j] == 1)
end

for i in 1:N+1
    @constraint(model, sum(z[i,:]) - z[i,i] == 1)
end

for i in 1:N
    for j in 1:N
        if i != j
            @constraint(model, tc[i] >= tc[j] + TT + TC[j] - M*(1 - z[i+1,j+1]))
        end
    end
end

for i in 1:N
    @constraint(model, tc[i] >= TC[i])
end

for i in 1:N
    @constraint(model, tc_max >= tc[i])
end

# ********** RESTRIÇÕES DE CONEXÃO AS CARGAS **********
for i in 1:N
    for l in 1:L
        @constraint(model, tc[i] >= a[l,i] * tp[l] + TT + TC[i])
    end
end

# ********** FUNÇÃO OBJETIVO **********
@objective(model, Min, tc_max)

optimize!(model)

# ********** COLETANDO RESULTADOS **********
var = all_variables(model)

mtx_resultados = try
    [name.(var),value.(var)] # Resultado das variaves
catch
    [var,repeat([0],length(var))]
end

objectiveValue = try
    objective_value(model)
catch
    0
end

dualObjectiveValue = try
    dual_objective_value(model)
catch
    0
end

relativeGap = try
    relative_gap(model)
catch
    0
end

objectiveBound = try
    objective_bound(model)
catch
    0
end

# detalhes do resultado: status final, valor da função objetivo, bound, valor do dual, tempo de solução, gap relativo
vec_dados = vcat(string(termination_status(model)), objectiveValue, objectiveBound, dualObjectiveValue, solve_time(model), relativeGap)

# matriz dos valores resultantes
df_resultados = DataFrame(mtx_resultados, ["var_name","var_value"])
df_resultados.var_name = string.(collect(df_resultados[!,:var_name]))

# ********** SALVANDO RESULTADOS EM UM .TXT **********
nome_arquivo = string("/Users/ariel/Documents/USP/TCC/","Gurobi - resultados L",string(L)," N", string(N))

open(nome_arquivo,"a") do io

    println(io, "\n*****", nome_arquivo,"*****\n")
    println(io, "TP = ", TP)
    println(io, "TC = ", TC, "\n")
    println(io, "tc_max = ", value(tc_max), "\n")
    println(io,"Status, valor FO, Bound, valor dual, tempo de solução, gap")
    println(io, vec_dados)

    println(io, "\nOrdenação das Cargas de Entrada\n")
    for l in 1:L+1
        for m in 1:L+1
            if value(w[l,m]) >= 0.6
                println(io," ",l-1," -> ", m-1)
            end
        end
    end

    println(io, "\nOrdenação das Cargas de Saída\n")
    for i in 1:N+1
        for j in 1:N+1
            if value(z[i,j]) >= 0.6
                println(io," ",i-1," -> ", j-1)
            end
        end
    end
    
    println(io,"---------------------------------------")
    println(io,"\n\n")
    println(io, df_resultados)
end

println("FINALIZADO!")
