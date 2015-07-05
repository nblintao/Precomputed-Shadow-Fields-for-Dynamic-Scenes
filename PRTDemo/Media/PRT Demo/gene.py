fp = open("cube_on_plane.x","w")


L = 5.0
N = 80

fp.write('''xof 0302txt 0064

Header
{
1;
0;
1;
}


Mesh Cube_m
{''')

fp.write(str((N+1)*(N+1))+';\n')
for j in range(0,N+1):
    for i in range(0,N+1):
        fp.write(str(-L+2*L/N*i)+';0;'+str(L-2*L/N*j)+';')
        if i==N and j==N:
            fp.write(';\n')
        else:
            fp.write(',\n')

fp.write('\n')
fp.write(str((N)*(N)*2)+';\n')
for j in range(0,N):
    for i in range(0,N):
        fp.write('3;'+str(j*(N+1)+i)+','+str((j+1)*(N+1)+i+1)+','+str((j+1)*(N+1)+i)+';')
        if i==N-1 and j==N-1:
            fp.write(';\n')
        else:
            fp.write(',\n')        
        fp.write('3;'+str(j*(N+1)+i)+','+str((j)*(N+1)+i+1)+','+str((j+1)*(N+1)+i+1)+';')
        if i==N-1 and j==N-1:
            fp.write(';\n')
        else:
            fp.write(',\n')


fp.write('}\n')