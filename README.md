# k
实现类似于excel vlookup, 以及文件列对齐等功能


```python
  -i -o -s file       输入/输出文件/数据库文件;默认 sys.stdin/stdout/FILE
  -n 1:1             oncol; infile:data;   例如: 1,2,3:1,2,3
  -f 1:1             savecol; infile:data; 例如: 1-50:1-50
  --fs 3:::1,2       指定列分割提取; 第三列按:分割,提取其中的1,2填充回源数据中
  -d '\t'            delimiter; default: '\s:\t'
  -m                 启用模糊匹配
  -M                 启用最佳相似度匹配
  -a                 显示所有的行(默认只显示匹配的)
  -v                 取反;输出infile没有匹配到的行
  -r,--rep           data前两列k-v和v-k替换infile中值
  -c int             是否展示两个文件格式化列序号;int列宽
  -T                 行列转置;如果存在-H,将在打印每行前先打印首行
  -H h1,h2           -T连用, 打印每行前先打印表头
  -x 2               将所有数据分割之后,按每行2个打印输出(相当于xargs -n2)

  --melt             宽转长: 保留列:值列:类别表头:值表头(没写的值列将舍弃)
  --pivot            长转宽: 保留列索引:放在表头的列:内容列(长转宽)
  -p strip|swarm|box|boxen|violin|bar|point   ===类别作图===
                     strip:散点图 swarm:树状散点图
                     box:箱线图 boxen:增强箱线图 violin:小提琴图
                     bar:均值柱状图 point:均值折线图
     hist|kde|ecdf   hist:直方图 kde:密度图 ecdf:经验累积分布
     line|scatter    x-y:1-2列:映射关系图
  --kw               作图参数: 格式: k:v,K:V,...
    x,y:坐标轴           hue:图例分类
    row,col:行列子图分类  palette:Greens,summer,summer_r,rainbow...
    dodge:增加图例分类x轴一类会分成多类并列, dodge:False合并成一类

  -t 1:2-            转置; 默认k,v: 1:2-
  --uniq             -t连用, 对values中的元素去重
  --sort             -t连用, 对values中的元素排序
  --sum              -t连用, 对values中的元素求和
  --count            -t连用, 统计values中个数
  --mean             -t连用, 计算values中元素均值
  --sd               -t连用, 计算values中元素方差

  --info 4,5,6       将类似vcf INFO列转化成表头形式(待合并,该需求需要表头,与上面的功能有点差别)
  --fmt 4,5,6        将类似vcf FORMAT列转化成表头形式
```
