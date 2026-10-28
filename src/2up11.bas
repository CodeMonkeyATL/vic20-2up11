100 i=0:p=0:j=0:x=0:y=0:lv=0:lm=0:ds=0:sc=0:co=30720
105 dimt%(4),gt%(15),mz%(7),sa%(15),cd%(20):r=rnd(-ti):poke36878,15:sn=1
110 fori=0to15:sa%(i)=7887+i+18*int(i/4):next
120 fori=0to20:cd%(i)=48+i-10*int(i/10)-128*(i>10)+16*(i=0):next
200 forx=0to15:gt%(x)=0:next:ss=0:mt=0:tb=ti:te=0:tg=0:gosub5000:gosub36500:poke198,0

300 gosub6100:geta$:ifa$=""then300
310 x=fre(0):ifa$="r"thenmt=0:gosub5000:goto300
320 ifa$="%"thenfori=0to15:printi;",";gt%(i):next:goto300
330 ifa$="n"then200
340 ifa$="q"thenpoke36878,0:print"{blu}":end
400 ifa$="w"thendc=0:dl=1:ds=4:db=1:wa=38585:ws=1:goto450
410 ifa$="a"thendc=0:dl=4:ds=1:db=2:wa=38606:ws=22:goto450
420 ifa$="s"thendc=12:dl=1:ds=-4:db=4:wa=38695:ws=1:goto450
425 ifa$="m"thensn=1-sn:gosub38120:gosub970:goto300
430 ifa$<>"d"thengosub970:goto300
440 dc=3:dl=4:ds=-1:db=8:wa=38611:ws=22
450 wc=6:gosub950:gosub965:gosub1100:gosub1000:ifmv=0then465
455 wc=5:gosub950:ifmtthenmt=0:gosub960
460 gosub965:onsngosub620:gosub36500:gosub39000:gosub970:goto300
465 wc=2:gosub950:gosub970:mt=dbormt:onsngosub660
470 ifmt<15then300
475 gosub6100:tg=1:print"{home}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}"tab(6)"{reverse on}{red}game over!":mt=0:onsngosub670
480 goto300
600 fori=ftoesteps:pokev,i:next:pokev,0:poke36878,15:return
610 v=36876:fori=1to4:pokev,195+i*12:forj=1to99:next:next:pokev,0:return
620 ifmnthen640
630 poke36878,5:v=36875:f=215:e=205:s=-2:goto600
640 fork=0tomn-1:n=190+3*mz%(k):poke36876,n:forj=1to12:next:poke36876,64+.75*n
645 forj=1to40:next:poke36876,0:ifmz%(k)>10thengosub610
650 next:return
660 poke36877,250:v=36878:f=15:e=0:s=-1:gosub600:poke36877,0:return
670 v=36874:f=200:e=140:s=-.5:goto600

900 y=sa%(x):pokey,cd%(p):pokey+co,sc:return

950 fori=0to3:pokewa+i*ws,wc:next:return
960 fori=0to3:pokei+38585,5:pokei+38695,5:poke22*i+38606,5:poke22*i+38611,5:next:return
965 poke8039,asc(a$)and63:poke38759,5:o=1:goto975
970 poke38759,6
975 q=peek(198)+o:qe=q:ifql>qethenqe=ql
980 ql=q:fori=otoqe-1:c=32:ifi<qthenc=peek(631+i-o)and63
985 poke8039+i,c:next:o=0:return

1000 mv=0:mn=0:forr=0to3:c=dc+r*dl:x=c:fori=0to3:t%(i)=gt%(x):x=x+ds:next:j=0:lv=0:lm=0
1010 fori=0to3:p=t%(i):ifp=0then1040
1020 ifp=lvthent%(j-1)=p+65:lv=0:lm=1:ss=ss+2^(p+1):mz%(mn)=p+1:mn=mn+1:goto1040
1030 t%(j)=p:lv=p:j=j+1:ifj<=ithenlm=1
1040 next:fori=jto3:t%(i)=0:next
1050 iflm=0then1070
1055 mv=1:x=c:fori=0to3:p=t%(i):sc=0:ifp>64thensc=6:p=p-64
1060 ifgt%(x)<>porscthengt%(x)=p:y=sa%(x):pokey,cd%(p):pokey+co,sc
1065 x=x+ds:next
1070 next:return
1100 fori=38607to38673step22:pokei,0:pokei+1,0:pokei+2,0:pokei+3,0:next:return

5000 gosub38000:w=te:gosub6130:gosub31000:gosub38100:gosub32000
5010 ql=0:fori=38760to38768:pokei,6:next:return

6000 fori=1to2:c=int(w/10):pokey,48+w-10*c:w=c:y=y-1:next:return

6100 iftgthenreturn
6110 w=int((ti-tb)/60):ifw<0orw>5999thenw=5999:tg=1
6120 ifw=tethenreturn
6130 te=w:y=7779:j=int(w/60):w=w-60*j:gosub6000:w=j:y=y-1:goto6000

31000 print"{down}{down}{grn}{$04}";:printtab(7)"{$b0}{$60}{$b2}{$b2}{$b2}{$b2}{$60}{$ae}"
31010 printtab(7)"{$7d}{$b0}{$b1}{$b1}{$b1}{$b1}{$ae}{$7d}":fori=0to3:printtab(7)"{$ab}{$b3}    {$ab}{$b3}":next
31020 printtab(7)"{$7d}{$ad}{$b2}{$b2}{$b2}{$b2}{$bd}{$7d}":printtab(7)"{$ad}{$60}{$b1}{$b1}{$b1}{$b1}{$60}{$bd}":return

32000 forx=0to15:p=gt%(x):sc=0:gosub900:next:return

36500 x=int(rnd(1)*16):ifgt%(x)then36500
36510 p=1-(rnd(1)>=.9):gt%(x)=p:sc=2:goto900

38000 print"{clr}{reverse on}{blu}                      {red}2^11{blu} by codemonkeyatl{blu}";
38010 print" {reverse on}{blu}                      score:{reverse off}"ss:print"{reverse on}time:{reverse off}  00:00":return

38100 print"{down}{down}{down}{down}{down} {red}wasd{blu}=move {red}n{blu}ew game"
38110 print" {red}r{blu}edraw    {red}m{blu}ute {red}q{blu}uit";
38120 fori=38874to38876:pokei,2+4*sn:next:return

39000 print"{home}{down}{down}{down}{reverse on}{blu}score:{reverse off}";ss:return
