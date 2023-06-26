import random as rd
import numpy as np

lista_lojas = [10, 20, 30]
lista_destinos = [20, 30, 50]
for L in lista_lojas:
    for N in lista_destinos:
        
        a = np.zeros((L,N))
        
        for l in range(L):
            for i in range(N):
                numbr = rd.random()
                if numbr <= 0.6:
                    a[l][i] = 1
        
        instancia = "instancia L " + str(L) + " N " + str(N)
        np.savetxt(instancia,a,fmt='%.1f')
        
print("Intâncias prontas!")