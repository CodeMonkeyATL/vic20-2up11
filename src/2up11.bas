100 w=3:dimgt(15):dimt(7):r=rnd(-ti):gosub30000
110 gosub38000:gosub31000:gosub32000:gosub36500

300 a=fre(0):dm=0:geta$

310 ifa$="w"thengosub1800:gosub32000
320 ifa$="w"anddm=1thengosub36500:goto300

330 ifa$="a"thengosub1400:gosub32000
340 ifa$="a"anddm=1thengosub36500:goto300

350 ifa$="s"thengosub2200:gosub32000
360 ifa$="s"anddm=1thengosub36500:goto300

370 ifa$="d"thengosub1000:gosub32000
380 ifa$="d"anddm=1thengosub36500:goto300

390 ifa$="n"thenforx=0to15:gt(x)=0:nextx:gosub37000:gosub32000:gosub36500:goto300
400 ifa$="r"thengosub38000:gosub31000:gosub32000:goto300
410 ifa$="%"thenfori=0to15:printi;",";gt(i):nexti:goto300
420 ifa$="q"thenprint"{blu}":end

440 goto300

900 ifp=0thendp=32:return
910 ifp<10thendp=p+48:return
920 ifp=10thendp=48:return
930 ifp<20thendp=p+166:return
940 ifp=20thendp=176:return
950 dp=32:return

1000 dm=0:forr=0tow:base=r*(w+1):forc=0tow:t(c)=gt(base+c):nextc:prev=-1:forc=wto0step-1
1100 ift(c)=0thengoto1150
1110 ifprev=-1thenprev=c:goto1150
1120 ift(c)=t(prev)thent(c)=t(c)+65:t(prev)=0:prev=-1:dm=1:goto1150
1130 prev=c
  1150 nextc
1160 moved=1
  1180 ifmoved=0thengoto1250
1190 moved=0:forc=w-1to0step-1
1210 ift(c)=0thengoto1250
1220 d=c+1
1230 ifd>wthengoto1250
1240 ift(d)=0thent(d)=t(c):t(c)=0:moved=1:dm=1
  1250 nextc
1260 ifmoved=1thengoto1180
1270 forc=0tow:gt(base+c)=t(c):nextc:nextr:return

1400 dm=0:forr=0tow:base=r*(w+1):forc=0tow:t(c)=gt(base+c):nextc:prev=-1:forc=0tow
1500 ift(c)=0thengoto1550
1510 ifprev=-1thenprev=c:goto1550
1520 ift(c)=t(prev)thent(prev)=t(prev)+65:t(c)=0:prev=-1:dm=1:goto1550
1530 prev=c
1550 nextc
1560 moved=1
1580 ifmoved=0thengoto1650
1590 moved=0:forc=1tow
1610 ift(c)=0thengoto1650
1620 d=c-1
1630 ifd<0thengoto1650
1640 ift(d)=0thent(d)=t(c):t(c)=0:moved=1:dm=1
1650 nextc
1660 ifmoved=1thengoto1580
1670 forc=0tow:gt(base+c)=t(c):nextc:nextr:return

1800 dm=0:forc=0tow:forr=0tow:idx=r*(w+1)+c:t(r)=gt(idx):nextr:prev=-1:forr=0tow
1900 ift(r)=0thengoto1950
1910 ifprev=-1thenprev=r:goto1950
1920 ift(r)=t(prev)thent(prev)=t(prev)+65:t(r)=0:prev=-1:dm=1:goto1950
1930 prev=r
1950 nextr
1960 moved=1
1980 ifmoved=0thengoto2050
1990 moved=0:forr=1tow
2010 ift(r)=0thengoto2050
2020 d=r-1
2030 ifd<0thengoto2050
2040 ift(d)=0thent(d)=t(r):t(r)=0:moved=1:dm=1
2050 nextr
2060 ifmoved=1thengoto1980
2070 forr=0tow:idx=r*(w+1)+c:gt(idx)=t(r):nextr:nextc:return

2200 dm=0:forc=0tow:forr=0tow:idx=r*(w+1)+c:t(r)=gt(idx):nextr:prev=-1:forr=wto0step-1
2300 ift(r)=0thengoto2350
2310 ifprev=-1thenprev=r:goto2350
2320 ift(r)=t(prev)thent(r)=t(r)+65:t(prev)=0:prev=-1:dm=1:goto2350
2330 prev=r
2350 nextr
2360 moved=1
2380 ifmoved=0thengoto2450
2390 moved=0:forr=w-1to0step-1
2410 ift(r)=0thengoto2450
2420 d=r+1
2430 ifd>wthengoto2450
2440 ift(d)=0thent(d)=t(r):t(r)=0:moved=1:dm=1
2450 nextr
2460 ifmoved=1thengoto2380
2470 forr=0tow:idx=r*(w+1)+c:gt(idx)=t(r):nextr:nextc:return

30000 dimbx$(15)
30020 data117,96,105,106,96,107,98,125,176,177,174,173,178,189,179,171
30040 forzt=0to15:readx:bx$(zt)=chr$(x):nextzt:return

31000 t=(22-w-4)/2:print"{grn}";chr$(17);chr$(4);
31020 printtab(t);bx$(8);:fori=0tow:printbx$(9);:nexti:printbx$(10)
31030 forj=0tow:printtab(t);bx$(14);:fori=0tow:printchr$(32);:nexti:printbx$(15):nextj
31060 printtab(t);bx$(11);:fori=0tow:printbx$(12);:nexti:printbx$(13):return

32000 ro=w+1:forj=0tow:r=j*22:fori=0tow:sp=7901+t+r+i:x=i+ro*j:p=gt(x):sc=0
32055 ifp>64thensc=6:p=p-64
32060 gt(x)=p:gosub900:cp=sp+30720:pokecp,sc:pokesp,dp:nexti:nextj:return

33000 p=rnd(1)
33020 ifp<.9thennt=129:return
33030 nt=130:return

36000 x=int(rnd(1)*16):ifgt(x)<>0thengoto36000
36020 gosub33000:gt(x)=nt:return

36500 gosub36000
36510 r=int(x/4):c=x-4*r:sp=7901+t+r*22+c:p=gt(x)-128:gt(x)=p
36550 gosub900:cp=sp+30720:pokecp,2:pokesp,dp:return

37000 full=1:fori=0to15
37030 ifgt(i)=0thenfull=0
37040 nexti
37050 iffull=1thenprint"board full! game over":end
37060 return

37999end
38000 printchr$(147);"{reverse on}{blu}                      {reverse off}";
38010 print"{reverse on}{red}2^11{blu} {grn}by codemonkeyatl{blu}{reverse on}";
38020 print" {reverse on}{blu}                      {reverse off}"
38030 print"{red}wasd{blu}=move":print"{red}   n{blu}=new game"
38040 print"{red}   r{blu}=redraw":print"{red}   q{blu}=quit"
38050 return
