@rem 3. Сложная (Подходит к провайдерам где заблокирован tls1.2).
@rem ЕСЛИ НИЧЕГО НЕ ПОНИМАЕТЕ - НЕ ТРОГАЙТЕ ЭТОТ ФАЙЛ, ОТКАЖИТЕСЬ ОТ ИСПОЛЬЗОВАНИЯ СЛУЖБЫ. ИНАЧЕ БУДЕТЕ ПИСАТЬ ПОТОМ ВОПРОСЫ "У МЕНЯ ПРОПАЛ ИНТЕРНЕТ , КАК ВОССТАНОВИТЬ"

set ARGS=^
--wf-tcp=80,443 --wf-udp=443,50000-50099 ^
--filter-tcp=80,443 --dpi-desync=fakeddisorder --dpi-desync-fooling=md5sig --wssize 1:6 --dpi-desync-split-pos=1 --dpi-desync-fake-tls-mod=rnd,dupsid,sni=rknpidor.google.com --hostlist-domains=googlevideo.com --new ^
--filter-tcp=80,443 --dpi-desync=fakeddisorder --dpi-desync-fooling=md5sig --wssize 1:6 --dpi-desync-split-pos=1 --dpi-desync-fake-tls-mod=rnd,dupsid,sni=rknpidor.google.com --hostlist=\"C:\keen_bypass_win\keen_bypass_win\files\list-antifilter.txt\" --hostlist=\"C:\keen_bypass_win\keen_bypass_win\files\list-rkn.txt\" --hostlist-auto=\"C:\keen_bypass_win\keen_bypass_win\files\list-auto.txt\" --hostlist-exclude=\"C:\keen_bypass_win\keen_bypass_win\files\list-exclude.txt\" --new ^
--filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=50 --dpi-desync-fake-quic=\"C:\keen_bypass_win\zapret-win-bundle-master\zapret-winws\files\quic_initial_www_google_com.bin\" --hostlist-domains=googlevideo.com --new ^
--filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=12 --dpi-desync-fake-quic=0x4383a71211223344 --hostlist=\"C:\keen_bypass_win\keen_bypass_win\files\list-antifilter.txt\" --hostlist=\"C:\keen_bypass_win\keen_bypass_win\files\list-rkn.txt\" --hostlist-auto=\"C:\keen_bypass_win\keen_bypass_win\files\list-auto.txt\" --hostlist-exclude=\"C:\keen_bypass_win\keen_bypass_win\files\list-exclude.txt\" --new ^
--filter-udp=50000-50099 --filter-l7=discord,stun --dpi-desync=fake

call :srvinst winws1
set ARGS=--wf-l3=ipv4,ipv6 --wf-udp=443 --dpi-desync=fake 
rem call :srvinst winws2
goto :eof

:srvinst
net stop %1
sc delete %1
sc create %1 binPath= "\"C:\keen_bypass_win\zapret-win-bundle-master\zapret-winws\winws.exe\" %ARGS%" DisplayName= "zapret DPI bypass : %1" start= auto
sc description %1 "zapret DPI bypass software"
sc start %1
