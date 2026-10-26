100 dimgt%(15),t%(4):r=rnd(-ti)
200 forx=0to15:gt%(x)=0:next:ss=0:gosub5000:gosub36500

300 geta$:ifa$=""then300
310 x=fre(0):ifa$="r"thengosub5000:goto300
320 ifa$="%"thenfori=0to15:printi;",";gt%(i):next:goto300
330 ifa$="n"then200
340 ifa$="q"thenprint"{blu}":end
400 ifa$="w"thenb=0:l=1:s=4:m=1:goto450
410 ifa$="a"thenb=0:l=4:s=1:m=2:goto450
420 ifa$="s"thenb=12:l=1:s=-4:m=4:goto450
430 ifa$<>"d"then300
440 b=3:l=4:s=-1:m=8
450 gosub1000:ifdmthenmt=0:gosub32000:gosub36500:gosub39000:goto300
460 mt=mormt:ifmt=15thenprint"{down}{blu}game over":mt=0
470 goto300

900 sp=7930+x+18*int(x/4):pokesp+30720,sc
910 pokesp,48+p-10*int(p/10)-128*(p>10)+16*(p=0):return

1000 dm=0:forr=0to3:c=b+r*l:fori=0to3:t%(i)=gt%(c+i*s):next:mp=4
1010 fori=0to3:ift%(i)=0then1040
1020 ift%(i)<>t%(mp)thenmp=i:goto1040
1030 ss=ss+2^(t%(i)+1):t%(mp)=t%(i)+65:t%(i)=0:mp=4:dm=1
1040 next:j=0:fori=0to3:p=t%(i):ifpthent%(i)=0:t%(j)=p:j=j+1:ifj<=ithendm=1
1050 next:fori=0to3:gt%(c+i*s)=t%(i):next:next:return

5000 gosub38000:gosub31000:gosub32000:goto39000

31000 print"{grn}{down}{$04}";:printtab(7)"{$b0}{$b1}{$b1}{$b1}{$b1}{$ae}":fori=0to3
31010 printtab(7)"{$b3}    {$ab}":next:printtab(7)"{$ad}{$b2}{$b2}{$b2}{$b2}{$bd}":return

32000 forx=0to15:p=gt%(x):sc=0:ifp>64thensc=6:p=p-64:gt%(x)=p
32010 gosub900:next:return

36500 x=int(rnd(1)*16):ifgt%(x)then36500
36510 p=1-(rnd(1)>=.9):gt%(x)=p:sc=2:goto900

38000 print"{clr}{reverse on}{blu}                      {red}2^11{blu} by codemonkeyatl{blu}";
38010 print" {reverse on}{blu}                      {reverse off}":print"{down}{red}wasd{blu}=move"
38020 print"{red}   n{blu}=new game":print"{red}   r{blu}=redraw":print"{red}   q{blu}=quit":return

39000 print"{home}{down}{down}{down}{reverse on}{blu}score:{reverse off}";ss:return
