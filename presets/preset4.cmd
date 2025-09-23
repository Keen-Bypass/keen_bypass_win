@rem Пресет 4 (Сложный, листы HOSTLIST+AUTOHOSTLIST+IPSET-EXCLUDE RU GEO).
@rem ЕСЛИ НИЧЕГО НЕ ПОНИМАЕТЕ - НЕ ТРОГАЙТЕ ЭТОТ ФАЙЛ, ОТКАЖИТЕСЬ ОТ ИСПОЛЬЗОВАНИЯ СЛУЖБЫ. ИНАЧЕ БУДЕТЕ ПИСАТЬ ПОТОМ ВОПРОСЫ "У МЕНЯ ПРОПАЛ ИНТЕРНЕТ , КАК ВОССТАНОВИТЬ"

set ARGS=^
--wf-tcp=80,443 --wf-udp=443,1024-65535 ^
--filter-tcp=80,443 --dpi-desync=multidisorder --dpi-desync-split-pos=1,sniext+1,host+1,midsld-2,midsld,midsld+2,endhost-1 --wssize 1:6 --hostlist-domains=googlevideo.com --new ^
--filter-tcp=80,443 --dpi-desync=multisplit --dpi-desync-split-pos=2 --dpi-desync-split-seqovl=336 --wssize 1:6 --dpi-desync-split-seqovl-pattern=\"C:\ProgramData\keen_bypass_win/zapret-win-bundle-master/blockcheck/zapret/files/fake/tls_clienthello_iana_org.bin\" --hostlist=\"C:\ProgramData\keen_bypass_win\keen_bypass\files\hosts-antifilter.txt\" --hostlist=\"C:\ProgramData\keen_bypass_win\keen_bypass\files\hosts-rkn.txt\" --hostlist-auto=\"C:\ProgramData\keen_bypass_win\keen_bypass\files\hosts-auto.txt\" --hostlist-exclude=\"C:\ProgramData\keen_bypass_win\keen_bypass\files\hosts-exclude.txt\" --new ^
--filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=50 --dpi-desync-fake-quic=\"C:\ProgramData\keen_bypass_win\zapret-win-bundle-master\zapret-winws\files\quic_initial_www_google_com.bin\" --hostlist-domains=googlevideo.com --new ^
--filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=12 --dpi-desync-fake-quic=0x4383a71211223344 --hostlist=\"C:\ProgramData\keen_bypass_win\keen_bypass\files\hosts-antifilter.txt\" --hostlist=\"C:\ProgramData\keen_bypass_win\keen_bypass\files\hosts-rkn.txt\" --hostlist-auto=\"C:\ProgramData\keen_bypass_win\keen_bypass\files\hosts-auto.txt\" --hostlist-exclude=\"C:\ProgramData\keen_bypass_win\keen_bypass\files\hosts-exclude.txt\" --new ^
--filter-udp=1024-65535 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-repeats=6

call :srvinst winws1
rem call :srvinst winws2
goto :eof

:srvinst
net stop %1
sc delete %1
sc create %1 binPath= "\"C:\ProgramData\keen_bypass_win\zapret-win-bundle-master\zapret-winws\winws.exe\" %ARGS%" DisplayName= "zapret DPI bypass : %1" start= auto
sc description %1 "zapret DPI bypass software"
sc start %1
