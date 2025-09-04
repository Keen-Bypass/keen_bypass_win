@rem Пресет 3 (Альтернативный2, листы HOSTLIST+AUTOHOSTLIST+IPSET-EXCLUDE RU GEO).
@rem ЕСЛИ НИЧЕГО НЕ ПОНИМАЕТЕ - НЕ ТРОГАЙТЕ ЭТОТ ФАЙЛ, ОТКАЖИТЕСЬ ОТ ИСПОЛЬЗОВАНИЯ СЛУЖБЫ. ИНАЧЕ БУДЕТЕ ПИСАТЬ ПОТОМ ВОПРОСЫ "У МЕНЯ ПРОПАЛ ИНТЕРНЕТ , КАК ВОССТАНОВИТЬ"

set ARGS=^
--wf-tcp=80,443 --wf-udp=443,1024-65535 ^
--filter-tcp=80,443 --dpi-desync=multisplit --dpi-desync-split-pos=10,sniext+1 --dpi-desync-split-seqovl=1 --hostlist-domains=googlevideo.com --new ^
--filter-tcp=80,443 --dpi-desync=multisplit --dpi-desync-split-pos=2 --dpi-desync-split-seqovl=336 --dpi-desync-split-seqovl-pattern=/opt/zapret/files/fake/tls_clienthello_iana_org.bin --hostlist=\"C:\keen_bypass_win\keen_bypass_win\files\hosts-antifilter.txt\" --hostlist=\"C:\keen_bypass_win\keen_bypass_win\files\hosts-rkn.txt\" --hostlist-auto=\"C:\keen_bypass_win\keen_bypass_win\files\hosts-auto.txt\" --hostlist-exclude=\"C:\keen_bypass_win\keen_bypass_win\files\hosts-exclude.txt\" --new ^
--filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=50 --dpi-desync-fake-quic=\"C:\keen_bypass_win\zapret-win-bundle-master\zapret-winws\files\quic_initial_www_google_com.bin\" --hostlist-domains=googlevideo.com --new ^
--filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=12 --dpi-desync-fake-quic=0x4383a71211223344 --hostlist=\"C:\keen_bypass_win\keen_bypass_win\files\hosts-antifilter.txt\" --hostlist=\"C:\keen_bypass_win\keen_bypass_win\files\hosts-rkn.txt\" --hostlist-auto=\"C:\keen_bypass_win\keen_bypass_win\files\hosts-auto.txt\" --hostlist-exclude=\"C:\keen_bypass_win\keen_bypass_win\files\hosts-exclude.txt\" --new ^
--filter-udp=1024-65535 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-repeats=6

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