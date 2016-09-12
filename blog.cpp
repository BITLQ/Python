 类型萃取

 本篇博客主要讲述内容：

 1. 什么是类型萃取
 2. 模板的特化
 3. 类型萃取的代码实现（模板特化的应用）


-----------------------------------------------------

 在C++中我们通常通过typeid （是一个函数）来提取； 但是只能获得类型，并不能用来声明变量；
 于是就产生了类型萃取来完成这一功能；

POD类型萃取： plain old data 平凡类型（无关痛痒的类型）--基本类型
 指在C++ 中与 C兼容的类型，可以按照 C 的方式处理。
通俗的理解就是方便我们区别开我们想要分开的类型，比如 内置类型和自定义类型；
比如，在写顺序表进行扩容时遇到的拷贝问题，
如果是内置类型的话，我们就可以用memcpy,但是如果是自定义类型时就会有问题，
比如说下面这段代码：


template<typename T>
void Seqlist<T>:: CheckCapacity()//顺序表中的扩容函数；
{
	if(_size == capacity)
	{
		int NewCapacity = capacity*2 + 3;
		T* tmp  = new T[Newcapacity];
		memcpy(tmp,_pdata,capacity*sizeof(T));// 假设原来顺序表的空间是 _pdata表示；
		delete _pdata;
		_pdata = tmp;
		capacity = NewCapacity;// 切记更新容量；
	}
}

 上面这段代码，如果模板参数传的是内置类型是没有问题的应用到顺序表中， 但是如果模板参数是
 string类型呢？     试试还可不可以？（本篇博客最后贴出类型萃取后的全部代码）
 那么这里就需要插入一个知识点了；   string类型的字符串在内存中的存储问题；

  我们知道其实在库里的string 对象中有两个成员_buf和_ptr; 那么这两个成员有什么用呢？
 _buf我们默认的有16个字节的空间，挡string的字符串小于16个的时候一般存储在_buf中，当字符串长度比较
 长的时候，我们一般就用到了_ptr， 这个_ptr是一个指针，它可以指向这个字符串的空间，这样，我们string 类就可以
 用这四个字节的空间去存储字符串的地址；

 但是，我们这里用了memcpy函数来进行拷贝，那么，问题来了， memcpy是内存拷贝，直接拷贝内存，于是乎，就将这个_ptr
 进行了一次拷贝，然后释放掉原来的_ptr； 是不是有问题了，  memcpy进行拷贝之后，我的两个_ptr都指向同一块空间；
 没有引用计数器的情况下，你释放掉一个_ptr，那就有问题了吧！   这就相当于浅拷贝的问题！

 现在我们就是要解决这个问题，于是乎有了下面的写法：

template<typename T>
void Seqlist<T>:: CheckCapacity()//顺序表中的扩容函数；
{
	if(_size == capacity)
	{
		int NewCapacity = capacity*2 + 3;
		T* tmp  = new T[Newcapacity];
		//memcpy(tmp,_pdata,capacity*sizeof(T));// 假设原来顺序表的空间是 _pdata表示；
		for(int i = 0; i<_size; i++)
		{
			tmp[i] = _pdata[i];// 注意，我们这里是赋值操作符；
		}
		delete _pdata;
		_pdata = tmp;
		capacity = NewCapacity;// 切记更新容量；
	}
}

  看到上面的代码，同学们不禁要问， 这有什么区别？
 仔细看，我们在用循环解决这个问题的时候循环内部是 _tmp[i] = _pdata[i];
 这里调用的是成员赋值操作符，如果是string类的成员，那么我们就调用的是string类的赋值操作符；
 而我们库里的string类已经解决这个问题，如果你写过string类的话一定会记得，这里我就不把string
 类模拟实现了；

 写到这里，是不是觉得有些偏离主题了， 不， 还没有，现在你看到我们用for循环解决了自定义类型的
 扩容拷贝问题，但是，如果是内置类型的模板参数，是不是memcpy的效率更高一点；
那么接下来，我们要解决的问题就是：
如何使得传进来的模板参数是内置类型就调用memcpy，如何使得传进来的参数是自定义类型就调用循环？


 这里又要引入我们模板中的内容-------类模板的特化

 什么是类模板的特化：基于模板的对模板参数的特殊化处理；
 分为全特化和局部特化（偏特化）
例如：

// 全特化
template<typename T>
class Seqlist<int>
{
public:
	void PopBack();
	void PopFront();
};

// 特化之后的成员函数不需要模板形参
void Seqlist<int>::PopBack()
{}

// 偏特化

template<typename T,typename T>
class Date<T,int> // 类似全特化的使用方式
{};

 偏特化也不一定是只特化一个参数，
偏特化并不仅仅是指特殊部分参数，而是针对模板参数更进一步的条件限制所设计出来的一个特化版本
比如：

template<typename T,typename T>
class Date<T*, T*>
{};

template<typename  T, typename T>
class Date<T&,T&>
{};


// 大概了解什么是模板的特化后，估计不少同学很迷惑了，这特化有什么用呢？ 
// 这就回到了我们最开始的问题，怎样区分内置类型和自定义类型，同时也解决中间提到的
// 顺序表扩容的一个问题，下面我们用类型萃取来实现顺序表的扩容：

//模板实现顺序表；

#include<iostream>
#include<string>
#include<cassert>

using namespace std;


struct __TrueType
{
    bool Get ()
	{
		return true ;
	}
};

struct __FalseType
{
	bool Get ()
	{
		return false ;
	}
};

// 自定义类型一般不特化
template <class _T>
struct TypeTraits
{
	typedef __FalseType __IsPODType;
};

// 下面是对常见的几种内置类型的特化，当然内置类型还有很多，我只是举几个常见的；

template <>
struct TypeTraits< bool>
{
	typedef __TrueType __IsPODType;
};

template <>
struct TypeTraits< char>
{
	typedef __TrueType __IsPODType;
};


template <>
struct TypeTraits< short>
{
	typedef __TrueType __IsPODType;
};


template <>
struct TypeTraits< int>
{
	typedef __TrueType __IsPODType;
};


template <>
struct TypeTraits< long>
{
	typedef __TrueType __IsPODType;
};

template <>
struct TypeTraits< unsigned long long>
{
	typedef __TrueType __IsPODType;
};

template <>
struct TypeTraits< float>
{
	typedef __TrueType __IsPODType;
};

template <>
struct TypeTraits< double>
{
	typedef __TrueType __IsPODType;
};

// 接下来就是怎么使用的问题

template<typename T>
void Seqlist<T>:: CheckCapacity()//顺序表中的扩容函数；
{
	if(_size == capacity)
	{
		int NewCapacity = capacity*2 + 3;
		T* tmp  = new T[Newcapacity];
		if(TypeTraits<T>::__IsPODType.get())// 判断返回值
		{
			memcpy(tmp,_pdata,capacity*sizeof(T));
		}// 假设原来顺序表的空间是 _pdata表示；
		else
		{
			for(int i = 0; i<_size; i++)
			{
				tmp[i] = _pdata[i];// 注意，我们这里是赋值操作符；
			}
		}
		delete _pdata;
		_pdata = tmp;
		capacity = NewCapacity;// 切记更新容量；
	}
}


// 这样就解决了之前的所有问题； 下面列出完整的代码！








#include<iostream>
#include<string>
#include<cassert>

using namespace std;


struct __TrueType
{
    bool Get ()
	{
		return true ;
	}
};

struct __FalseType
{
	bool Get ()
	{
		return false ;
	}
};

// 自定义类型一般不特化
template <class _T>
struct TypeTraits
{
	typedef __FalseType __IsPODType;
};

// 下面是对常见的几种内置类型的特化，当然内置类型还有很多，我只是举几个常见的；

template <>
struct TypeTraits< bool>
{
	typedef __TrueType __IsPODType;
};

template <>
struct TypeTraits< char>
{
	typedef __TrueType __IsPODType;
};


template <>
struct TypeTraits< short>
{
	typedef __TrueType __IsPODType;
};


template <>
struct TypeTraits< int>
{
	typedef __TrueType __IsPODType;
};


template <>
struct TypeTraits< long>
{
	typedef __TrueType __IsPODType;
};

template <>
struct TypeTraits< unsigned long long>
{
	typedef __TrueType __IsPODType;
};

template <>
struct TypeTraits< float>
{
	typedef __TrueType __IsPODType;
};

template <>
struct TypeTraits< double>
{
	typedef __TrueType __IsPODType;
};


template<class T>
class SeqList
{
public:
	SeqList ()
		:_pdata(NULL)
		,_size(0)
		,_capacity(3)
	{
		_pdata = new T[3];
	}
	~SeqList ()
	{
		if(_pdata != NULL)
		{
			delete[] _pdata;
			_size = 0;
			_capacity = 0;
		}
	}
	template<typename T>
	friend ostream& operator<<(ostream& os, const SeqList<T>& s);

	void Display()
	{
		for(int i = 0; i<_size; i++)
		{
			cout<<_pdata[i]<<" ";
		}
		cout<<endl;
	}

	void PushBack(const T& data);
	void PushFront(const T& data);
	void PopBack();
	void PopFront();
	void Sort();
	int Find(const T& P);
	void Intsert(const int& pos,const T& data);
	void Remove(const T& data);
	void RemoveAll(const T& data);


	T& operator[](int size)
	{
		assert(size<_size);
		assert(size>=0);

		return _pdata[size];
	}
	 
private :
    void CheckCapacity()//顺序表中的扩容函数；
	{
	if(_size == capacity)
	{
		int NewCapacity = capacity*2 + 3;
		T* tmp  = new T[Newcapacity];
		if(TypeTraits<T>::__IsPODType.get())// 判断返回值
		{
			memcpy(tmp,_pdata,capacity*sizeof(T));
		}// 假设原来顺序表的空间是 _pdata表示；
		else
		{
			for(int i = 0; i<_size; i++)
			{
				tmp[i] = _pdata[i];// 注意，我们这里是赋值操作符；
			}
		}
		delete _pdata;
		_pdata = tmp;
		capacity = NewCapacity;// 切记更新容量；
	}
}

	T* _pdata;
	int _size;
	int _capacity;
};


template<typename T>
 ostream& operator<<(ostream& os, const SeqList <T>& s )
{
	int i = 0;
	for(i = 0; i< s._size ;i++)
	{
		os<<s._pdata [i]<<" ";
	}
	return os;
}

template<typename T>
int SeqList <T>::Find(const T& data)
{
		int i = 0;

		for(i= 0 ; i < _sz; i++)
		{
			if(_pdata[i] == data)//注意这里的等号，千万别写成赋值等；
				return i;
		}
		return -1;
}

template<typename T>
void SeqList<T>:: PushBack(const T& data)
	{
		CheckCapacity ();
		_pdata[_size] = data;
		_size++;
	}

template<class T>
void SeqList<T>::PushFront(const T& data)
{
	    CheckCapacity();
		int length =  _size;
		while(length)
		{
			_pdata[length]=_pdata[length-1];
			length--;
		}
		_pdata[0] = data;
		_size++;
}

template<typename T>
void SeqList <T>::PopBack ()
{
			if(_size>=1)
		{
			_size-=1;
		}
}

template<typename T>
void SeqList <T>::PopFront()
{
			int len = 0;
		while(len<_size-1)
		{
			_pdata[len] = _pdata[len+1];
			len++;
		}
		_size--;
}

template<typename T>
void SeqList <T>::Intsert(const int& pos, const T& data)
{
		CheckCapacity ();

		int index = Find(pos);
		if(index>=0)
		{
			int length = _size;
		while(length > index)
		{
			_pdata[length]=_pdata[length-1];
			length--;
		}
		_pdata[index] = data;
		_size++;
		}
}

template<typename T>
void SeqList <T>::Remove(const T& data)
{
			int index = Find(data);

		if(index>=0)
		{
		while(index<_size-1)
		{
			_pdata[index] = _pdata[index+1];
			index++;
		 }
		}
		_size--;
}

template<typename T>
void SeqList <T>::RemoveAll (const T& data)
{
		while(Find(data)>=0)
		{
			Remove(data);
		}
}

template<typename T>
void SeqList <T>::Sort ()
{
	for(int i = 0; i<_size-1; i++)
	{
		for(int j = 0; j < _size-i-1; j++)
		{
			if(_pdata[j]<_pdata[j+1])
			{
				T tmp = _pdata [j];
				_pdata [j] = _pdata [j+1];
				_pdata [j+1] = tmp;
			}
		}
	}
}

void test()
{
	SeqList<string> s;
	SeqList<int> s1;
	s1.PushBack(2);
	s1.PushBack(5);
	s1.PushBack(4);
	s1.PushBack(6);
	s.PushBack ("aaaaaaaaaaaaaa");
	s.PushBack ("dsadsas");
	s.PushBack ("ssssssssssss");
	s.PushBack ("sdasadadafffffffffffffffffffffffffffffffffff");
	s.PushBack ("sdasdas");
	s1.Sort ();
	//s1.Display ();
	cout<<s1<<endl;
}

int main()
{
	test();
	system("pause");
	return 0;
}