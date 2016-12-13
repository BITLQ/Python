# 请定义一个函数quadratic(a, b, c)，接收3个参数，返回一元二次方程：

# ax2 + bx + c = 0
#
# 的两个解。
#
# 提示：计算平方根可以调用math.sqrt()函数：

import math

def quadratic(a,b,c):
    if not isinstance(a,(int,float)) or not isinstance(b,(int ,float)) or not isinstance(c,(int, float)):
        raise TypeError('bad operand type')
    d = b*b - 4*a*c
    if d<0:
        print('无解')
        return
    elif d==0:
        return ((-b) + math.sqrt(b * b - 4 * a * c)) / 2
    else:
        return ((-b) + math.sqrt(b * b - 4 * a * c)) / 2,((-b) - math.sqrt(b * b - 4 * a * c)) / 2

# 关于函数的参数问题
def power(x):
    return x*x

def power(x,n = 2):
    s = 1
    while (n > 0):
        s = s * x
        n = n - 1
    return s



# 默认参数使用不当的情况
def add_end(L = []):
    L.append('END')
    return L

#这样的话，每次都是传递空的参数，导致L = ['END','END','END']

#解决上述问题的途径是，使默认参数指向的是不变的对象；

def add_end(L = None):
    if L is None:
        L = []
    L.append('END')
    return L

#python 中的不变对象有str,None等



#可变参数
def calc(names):
    sum = 0
    for n in names:
        sum = sum + n*n

    return sum
#每次都得构造一个元组/列表出来

#利用可变参数
def calc(*names):
    sum = 0
    for n in names:
        sum = sum + n*n
    return sum


 #关键字参数 自动组装成一个dict

def person(name,age,**kw):
    print('name:',name,'age','other:',kw)

#命名关键字参数
def person(name,age,*,city,job):
    print(name,age,city,job)

#组合时，定义顺序必须是：必选参数，默认参数，可变参数，命名关键字参数，关键字参数



#递归函数
#例如计算N的阶乘
def fact(n):
    if n==1:
        return 1
    return n*fact(n - 1)

#尾递归
def fact(n):
    return fact_iter(n,1)

def fact_iter(num,product):
    if num == 1:
        return product
    return fact_iter(num - 1,num * product)
#遗憾的是大多数编译器并没有对尾递归做优化，所以仍会导致栈溢出

#练习，汉诺塔的移动

def my_move(n,a,buffer,c):
    if n == 1:
        print(a,"->",c)
        return
    my_move(n - 1,a,c,buffer)
    print(a,'->',c)
    my_move(n - 1,buffer,a,c)

