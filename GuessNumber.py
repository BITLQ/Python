while True:
    txt = input('������һ������')
    if txt == 'stop':
        break
    elif not txt.isdigit():
        print('����Ƿ�ֵ')
    else:
        num = int(txt)
        if num < 20:
            print('����̫С')
        elif num > 20:
            print('����̫��')
        else:
            print('�¶���')