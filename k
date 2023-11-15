#!/usr/bin/env python
# -*- coding:utf-8 -*-

import os,sys
from collections import OrderedDict, defaultdict
from itertools import zip_longest
from signal import signal, SIGPIPE, SIG_DFL
signal(SIGPIPE,SIG_DFL)
from difflib import SequenceMatcher
# from smart_open import open  #增加0.5s加载

_MAXC=500  # 最大列数

hinfo='''helpinfo:
  -i -o -s file       输入/输出文件/数据库文件;默认 sys.stdin/stdout/FILE
  -n 1:1             oncol; infile:data; e.g  1,2,3:1,2,3
  -f 1:1             savecol; infile:data; e.g 1-50:1-50
  -d '\\t'            delimiter; default: '\\s:\\t'
  -m                 启用模糊匹配
  -M                 启用最佳相似度匹配
  -a                 显示所有的行(默认只实现匹配到的)
  -v                 取反;输出infile没有匹配到的行
  -r,--rep           data前两列k-v和v-k替换infile中值
  -c int             是否展示两个文件格式化列序号;int列宽
  -T                 行列转置;如果存在-H,将在打印每行前先打印首行
  -H h1,h2           -T连用, 打印每行前先打印表头
  -x 2               将所有数据分割之后,按每行2个打印输出(相当于xargs -n2)

  --melt             宽数据转长数据: 保留列:值列:类别表头:值表头(没写的值列将舍弃)
  -p strip|swarm|box|boxen|violin|bar|point   ===类别作图===
     x,y:坐标轴  hue:图例分类 row,col:行列子图分类;palette:Greens,summer,summer_r,rainbow...
     dodge:增加图例分类x轴一类会分成多类并列:dodge:False合并成一类
                     strip:散点图 swarm:树状散点图
                     box:箱线图 boxen:增强箱线图 violin:小提琴图
                     bar:均值柱状图 point:均值折线图
     hist|kde|ecdf   hist:直方图 kde:密度图 ecdf:经验累积分布
     line|scatter    x-y:1-2列:映射关系图
  --kw               作图参数: 格式: k:v,K:V,...

  -t 1:2-            转置; 默认k,v: 1:2-
  --uniq             -t连用, 对values中的元素去重
  --sort             -t连用, 对values中的元素排序
  --sum              -t连用, 对values中的元素求和
  --count            -t连用, 统计values中个数
  --mean             -t连用, 计算values中元素均值
  --sd               -t连用, 计算values中元素方差'''

def minMaxNorm(lst):
    _lst = [float(i)for i in lst]
    _min,_max = min(_lst), max(_lst)
    if _min == _max:
        return _lst
    else:
        return [(i-_min)/(_max-_min) for i in _lst]
def zScoreNorm(lst):
    lst = [float(i)for i in lst]
    _mean = sum(lst)/len(lst)
    _sd = sum((i-_mean)**2 for i in lst)/len(v)


def convert_percent_to_decimal(df):
    for column in df.columns:
        if df[column].dtype == object:
            if df[column].str.endswith('%').all():
                df[column] = df[column].str.rstrip('%').astype(float) / 100
    return df

# 将1-3,7- 转化成: [1,2,3,7,...]
def colParser(colsInfo, maxIdx=_MAXC):
    lst = []
    for i in colsInfo.strip().split(','):
        i = i.split('-')
        if len(i)!=1:
            if i[0] == '':
                lst += list(range(1, int(i[1])+1))
            elif i[1] != '':
                lst += list(range(int(i[0]), int(i[1])+1))
            else:
                lst += list(range(int(i[0]), maxIdx+1))
        else:
            lst.append(int(i[0]))
    lst = [ i-1 for i in lst if i<=maxIdx]
    return lst


def pretty(iLst, maxNF, colWidthMax=85, displayColsIndex=True):
    if iLst==[]:return []
    if displayColsIndex:
        iLst = [['#'+str(i+1)for i in range(maxNF)],]+iLst
    colWidthLst = [2]*_MAXC
    for i in iLst:
        iLen=len(i)
        for j in range(len(i)):
            jLen = len(i[j])
            if jLen > colWidthLst[j]:
                colWidthLst[j]=jLen
    return [''.join([line[i].ljust(colWidthLst[i], ' ')[:colWidthMax]+'  '
            for i in range(maxNF)]) for line in iLst ]

def flatten(items, ignore=(str, bytes)):
    from collections.abc import Iterable
    for x in items:
        if isinstance(x, Iterable) and not isinstance(x, ignore):
            yield from flatten(x)
        else:
            yield x

def calculate_similarity(s1,s2):
    return SequenceMatcher(None, s1, s2).ratio()

def bestMatch(s, lst):
    m,bs=0,''
    for s1 in lst:
        ratio=calculate_similarity(s,s1)
        if ratio>m:
            m,bs=ratio,s1
    return bs

def main():
    ## =================================== args ======================================== ### 
    rargs = sys.argv
    args = []
    for i in rargs:
        # 对 -f1,2等传参处理成: -f 1,2
        if len(i)>2 and i[0] == '-' and i[:2] != '--':
            args += [ i[:2], i[2:] ]
        else:
            args.append(i)
    if '-h' in args or '--help' in args:
        sys.exit(hinfo)

    ##: 分隔符
    sep,osep = None,'\t'
    if '-d' in args:
        sep = args[args.index('-d')+1]
        sep = sep.replace('t', '\t').replace('\\t', '\t')
        sep = sep.replace('n', '\n').replace('\\n', '\n')
        if ':' in sep and ':' != sep:
            sep, osep = sep.split(':', 1)[:2]

    ## infile
    iLst,maxiNF=[],0
    infile=sys.stdin
    if '-i' in args:
        infile = args[args.index('-i')+1]
        if infile == '-': infile = sys.stdin
        else:infile = open(infile)
    for i in infile:
        i = i.rstrip('\n').split(sep)
        iLen = len(i)
        iLst.append(i)
        if iLen>maxiNF:maxiNF=iLen
    iLst = [line+['']*(maxiNF-len(line)) for line in iLst] # 补全不完全的列

    # data
    dLst,maxdNF=[],0
    data = open('/dev/null')
    if '-s' in args:
        data = args[args.index('-s')+1]
        if data == '-': data = sys.stdin
        else: data = open(data)
    for i in data:
        i = i.rstrip('\n').split(sep)
        iLen = len(i)
        dLst.append(i)
        if iLen>maxdNF:maxdNF=iLen
    dLst = [line+['']*(maxdNF-len(line)) for line in dLst]

    # outfile
    outfile = sys.stdout
    if '-o' in args:
        outfile = args[args.index('-o')+1]
        outfile = open(outfile, 'w')

    ## =================================== func ======================================== ### 
    ### 折叠成指定列数的行  ### 
    if '-x' in args:
        _i = args.index('-x')+1
        # 没有传参: 默认设置2列
        x = 2 if (_i>=len(args) or args[_i][:1]=='-') else  int(args[_i])

        iLst = list(flatten(iLst))
        iLstLen = len(iLst)
        for i in range(0, iLstLen, x):
            print(osep.join( [ iLst[i+j] if i+j<iLstLen else '' for j in range(x) ] ), file=outfile)

    ### transpose ### 
    elif '-T' in args:
        iLst = [list(i) for i in zip_longest(*iLst, fillvalue='')]
        if '-H' in args:
            for n,i in enumerate(iLst):
                if n > 1:
                    print( osep.join(iLst[0]),file=outfile)
                    print(osep.join(i),file=outfile)
                else:
                    print(osep.join(i),file=outfile)

        else:
            for i in iLst:
                print(osep.join(i),file=outfile)

    ### 简单统计 ### 
    elif '-t' in args:
        _i = args.index('-t')+1
        if _i>=len(args) or args[_i][:1]=='-':  ## 如果没有传参:默认为 1:2-
            tcol1,tcol2=[0],colParser('2-')
        else:
            i = args[_i]
            tcol1,tcol2 = i.split(':') if ':' in i else [i,i]
            tcol1,tcol2 = colParser(tcol1), colParser(tcol2)

        dic = defaultdict(list)
        for i in iLst:
            k = osep.join([i[r] for r in tcol1])
            v = [ i[r] for r in tcol2 if r+1<=len(i) ]
            dic[k]+=v
        for k,v in dic.items():
            v = osep.join(v).split(osep)
            outLst = [k]
            if '--gt' in args:
                c=args[args.index('--gt')+1]
                outLst.append( str( len([i for i in v if i>c]) ) )
            if '--lt' in args:
                c=args[args.index('--lt')+1]
                outLst.append( str( len([i for i in v if i<c]) ) )
            if '--ne' in args:
                c=args[args.index('--ne')+1]
                outLst.append( str( len([i for i in v if i!=c]) ) )
            if '--count' in args:
                outLst.append(str(len(v)))
            if '--uniq' in args:
                v = sorted(set(v))
            if '--sort' in args:
                v = sorted(v)
            if '--sum' in args:
                outLst.append(str(sum([float(i) for i in v])))
            if '--min' in args:
                outLst.append(str(min([float(i) for i in v])))
            if '--max' in args:
                outLst.append(str(max([float(i) for i in v])))
            if '--mean' in args:
                outLst.append(str(round(sum([float(i) for i in v])/len(v),3)))
            if '--sd' in args: ## 方差(方差容易受到异常值影响)
                _mean = sum([float(i) for i in v])/len(v)
                outLst.append(str(round(sum((float(i)-_mean)**2 for i in v)/len(v),3)))
            if '--sdd' in args: ## 去尾方差
                _x = int(len(v)*0.1)
                _v = sorted(v)[_x:-_x]
                if _v == []:
                   outLst.append('0')
                else:
                    _mean = sum([float(i) for i in _v])/len(_v)
                    outLst.append(str(round(sum((float(i)-_mean)**2 for i in _v)/len(v),3)))
            if '--sdx' in args: ## 归一化方差
                _v = minMaxNorm(v)
                _mean = sum([float(i) for i in _v])/len(_v)
                outLst.append(str(round(sum((float(i)-_mean)**2 for i in _v)/len(v),3)))
            outLst+=v
            print(osep.join(outLst), file=outfile)

    #### 简单绘图  ####
    # https://seaborn.pydata.org/generated/seaborn.pairplot.html
    elif '-p' in args or '--melt' in args or '--pivot' in args:
        if '-o' not in args: outfile = 'test.plot.png'
        else: outfile=args[args.index('-o')+1]
        import pandas as pd
        import numpy as np
        import seaborn as sns
        import matplotlib.pyplot as plt
        df = pd.DataFrame(iLst[1:], index=None, columns=iLst[0])
        # df = df.convert_dtypes() # 类型推断不好用
        # df = df.infer_objects()
        tmpoutfile=outfile+"._xxzztmp_" # 使用读文件类型推断
        df.to_csv(tmpoutfile, index=None)
        df = pd.read_csv(tmpoutfile, index_col=None)
        os.system('rm -f %s' % tmpoutfile)
        kwargs={}
        if '--kw' in args:
            for i in args[args.index('--kw')+1].split(','):
                if ':' in i: _i=i.split(':')
                elif "=" in i: _i=i.split('=')
                k,v=_i[:2]
                try:
                    v=float(v)
                except:
                    ...
                kwargs[k]=v


        # 宽转长
        """  --melt 1:2:hue:val
           A  B  C            A   hue val
        0  a  1  2         0  a    B   1
        1  b  3  4   ==>   1  b    B   3
        2  c  5  6         2  c    B   5
        """
        # --melt 保留列索引:展开列索引:给展开列的列名(一般hue):值名
        if '--melt' in args:
            df = convert_percent_to_decimal(df)  # 分数转化成小数
            ki,vi,k,v = args[args.index('--melt')+1].split(':')[:4]
            ki=df.columns[colParser(ki,len(df.columns))]
            vi=df.columns[colParser(vi, len(df.columns))]
            df=df.melt(id_vars=ki, value_vars=vi, var_name=k, value_name=v, col_level=None)
            df=df.reset_index()
            df.to_csv(sys.stdout, index=False, sep='\t')
            sys.exit()

        ##       此处是表头名不是索引
        # 长转宽  保留列索引:放在表头的列:内容列(长转宽)
        if '--pivot' in args:
            i,c,v = args[args.index('--pivot')+1].split(':')[:3]
            df=df.pivot(index=i.split(','),columns=c.split(','),values=v.split(','))
            df.columns = df.columns.get_level_values(1).map(str)
            df=df.reset_index()
            df.to_csv(sys.stdout, index=False, sep='\t')
            sys.exit()


        if '-p' in args:
            _p = args.index('-p')+1
            if _p+1>len(args): kind='bar'
            else: kind=args[_p]

            sns.set_theme()
            if kind == 'heatmap':
                from sklearn.metrics.pairwise import manhattan_distances
                # 相关性热图:  -p heatmap 5-22 第5列至第22列
                sampnu=len(df.columns)
                cols=list( range(sampnu) )
                if args.index('heatmap')+1 < len(args):
                    cols=colParser( args[ args.index('heatmap')+1 ], sampnu )
                df=df[ [df.columns[i] for i in cols] ]
                df=df.T  # 计算距离前需要将样本转置放到行中
                dist=manhattan_distances(df)
                # _size = sampnu*0.8 if sampnu*0.8<20 
                # plt.figure( figsize=( sampnu*0.8, sampnu*0.8 ) )
                sns.heatmap( dist,linewidth=0.5,cbar=False,
                             cmap=sns.diverging_palette(0, 220, 99, 50, as_cmap=True) )
                plt.xticks(np.arange(0.6,len(df.index)+0.6, 1), df.index, rotation=45, ha="right", fontsize=15, **kwargs)
                plt.yticks(np.arange(0.4,len(df.index)+0.4, 1), df.index, rotation=0, va="top", fontsize=15, **kwargs)

            ## 类别统计作图:(长数据类型,表头是xy轴label)
            # https://blog.csdn.net/hustlei/article/details/123091969
            if kind in {'strip', 'swarm', 'box', 'boxen', 'violin', 'bar', 'point'}:
                if kind == 'bar': kwargs.update({'errwidth':2,'capsize':0.05})
                df = convert_percent_to_decimal(df)  # 分数转化成小数
                sns.catplot(data=df, kind=kind, **kwargs)  # aspect=2.5 长宽比2.5
            ## 分布作图(数据需要放在最后一列):
            if kind in {'hist', 'kde', 'ecdf'}:
                sns.displot(data=df, kind=kind, **kwargs)
            ## 双变量关系图(1,2列:分别对应x,y):
            if kind in {'scatter','line'}:
                g = sns.relplot(data=df, kind=kind, **kwargs)
                axes = g.axes.flatten()
                # for ax in axes:
                #     ax.set_xticks([ i/10 for i in range(11) ])
                    # ax.plot([i/10 for i in range(6)],[i/10 for i in range(6)])
                    # ax.plot([i/10 for i in range(5,11)],[i/10 for i in range(6)][::-1])

        print(df)
        print(df.dtypes)
        print("output file:", outfile)
        plt.tight_layout()
        plt.savefig(outfile)

    ## pretty output ### 
    elif '-c' in args:
        try:
            colwidth = args[args.index('-c')+1]
            colwidth=int(colwidth)
        except:
            colwidth=50
        lst1 = pretty(iLst, maxiNF, colwidth, True)
        lst2 = pretty(dLst, maxdNF, colwidth, True)
        fSep = '' if lst2 == [] else ' | '
        for i,j in zip_longest(lst1, lst2, fillvalue=''):
            if len(i)==0:i=' '*len(lst1[0])
            print(i+fSep +j, file=outfile)

    ### k-v置换 ### 
    elif '-r' in args:
        dic = {}
        for i in dLst:
            i.append('')     # 将单列的替换为空
            dic[i[1]] = i[0]
            dic[i[0]] = i[1]

        for i in iLst:
            k = i[0]
            if k in dic:
                i[0] = dic[k]
            print(osep.join(i), file=outfile)

    ### cat vlookup ### 
    else:
        col1,col2 = [0],[0]
        if '-n' in args:
            i = args[args.index('-n')+1]
            col1,col2 = i.split(':') if ':' in i else [i,i]
            col1,col2 = colParser(col1,maxiNF),colParser(col2, maxdNF)

        scol1,scol2 = list(range(_MAXC)), list(range(_MAXC))   # 数据列
        if '-f' in args:
            i = args[args.index('-f')+1]
            scol1,scol2 = i.split(':') if ':' in i else [i,i]
            scol1,scol2 = colParser(scol1),colParser(scol2)

        indic = OrderedDict()        # 行号作为key保持输入文件顺序
        for n,i in enumerate(iLst):
            indic[n] = [ osep.join( i[c] for c in col1),
                [i[c] for c in scol1 if c<maxiNF] ]

        datadic = OrderedDict()
        for i in dLst:
            iLen = len(i)
            k = osep.join( i[c] for c in col2 )
            v = [ i[c] for c in scol2 if c<maxdNF and c not in col2]
            if k not in datadic:
                datadic[k] = v
            else:
                sys.stderr.write('[WARN] repeat KEY %s\n' % k)
                if '--last' in args: datadic[k] = v

        match = True if '-m' in args else False
        similar = True if '-M' in args else False
        allLine = True if '-a' in args or '-s' not in args else False
        if '-v' in args:
            inverse,allLine = True, False
        else:
            inverse = False

        for n in indic:
            k,v = indic[n]
            t = False        # tag: 记录是否匹配到
            if not match and not similar:    # 不开启特殊匹配
                if k in datadic:
                    v += datadic[k]
                    t = True
            elif match:           # 开启后, 优先全匹配, 然后开启模糊匹配
                if k in datadic:
                    v.append(k)
                    v+=datadic[k]
                    t = True
                else:
                    for dk in datadic:
                        if k in dk or dk in k:
                            v.append(dk)
                            v+=datadic[dk]
                            t = True
                            break
            elif similar:
                dk = bestMatch(k,datadic.keys())
                v.append(dk)
                v = v+datadic[dk]
                t=True

            if inverse:  t = not t
            if not allLine and t == False: continue   # 不输出没有匹配到的
            v = osep.join(v)
            print(v, file=outfile)


if __name__ == '__main__':
    main()


