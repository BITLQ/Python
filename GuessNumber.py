while True:
    txt = input('请输入一个数字')
    if txt == 'stop':
        break
    elif not txt.isdigit():
        print('输入非法值')
    else:
        num = int(txt)
        if num < 20:
            print('数字太小')
        elif num > 20:
            print('数字太大')
        else:
            print('猜对了')