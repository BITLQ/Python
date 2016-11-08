#生成器（generator）
#g = (x*x for x in range(10))

#生成器和列表生成式的区别：列表生成式需要完整的List而生成器则是不断的推断出来的

#Fibonacci
def fib(nax):
    n,a,b = 0,0,1
    while(n<max):
        print(b)
        a,b = b,a+b
        n = n+1
    return 'done'

#Hanoi
def move(n,a,b,c):
    if (n == 1):
        print(a,'->',c)
        return
    move(n-1,a,c,b)
    move(1,a,b,c)
    move(n-1,b,a,c)

#yield关键字 如果函数定义中包含yield则不再是普通函数
#不再是遇到return返回，而是每次调用next（）执行，遇到yield则返回
#再次执行时从上次返回的yield语句处开始
def odd():
    print('step 1')
    yield 1
    print('step 2')
    yield (3)
    print('step e')
    yield (5)

#打印杨辉三角的数
def triangles():
    L = [1]
    n = 1
    while True:
      yield L
      L.append(0)
      L = [L[t-1]+L[t] for t in range(len(L))]
n = 0
for t in triangles():
    print(t)
    n = n + 1
    if n == 10:
        break