@rem Пресет 6 (multisplit - googlevideo, fake - HOSTLISTS).
@rem ЕСЛИ НИЧЕГО НЕ ПОНИМАЕТЕ - НЕ ТРОГАЙТЕ ЭТОТ ФАЙЛ, ОТКАЖИТЕСЬ ОТ ИСПОЛЬЗОВАНИЯ СЛУЖБЫ. ИНАЧЕ БУДЕТЕ ПИСАТЬ ПОТОМ ВОПРОСЫ "У МЕНЯ ПРОПАЛ ИНТЕРНЕТ , КАК ВОССТАНОВИТЬ"

set ARGS=^
--wf-tcp=80,443 --wf-udp=443,1024-65535 ^
--filter-tcp=80,443 --dpi-desync=multisplit --dpi-desync-split-pos=10,midsld --dpi-desync-split-seqovl=1 --hostlist-domains=googlevideo.com --new ^
--filter-tcp=80,443 --dpi-desync=fake --dpi-desync-fooling=badseq --dpi-desync-badseq-increment=10000 --dpi-desync-repeats=20 --dpi-desync-fake-tls-mod=rnd,dupsid,sni=sheets.google.com --hostlist=\"C:\ProgramData\keen_bypass_win\keen_bypass\files\hosts-antifilter.txt\" --hostlist=\"C:\ProgramData\keen_bypass_win\keen_bypass\files\hosts-rkn.txt\" --hostlist-auto=\"C:\ProgramData\keen_bypass_win\keen_bypass\files\hosts-auto.txt\" --hostlist-exclude=\"C:\ProgramData\keen_bypass_win\keen_bypass\files\hosts-exclude.txt\" --new ^
--filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=50 --dpi-desync-fake-quic=\"C:\ProgramData\keen_bypass_win\zapret-win-bundle-master\zapret-winws\files\quic_initial_www_google_com.bin\" --hostlist-domains=googlevideo.com --new ^
--filter-udp=1024-65535 --filter-l7=quic,dht,discord,stun,unknown --dpi-desync-any-protocol=1 --dpi-desync=fake --dpi-desync-repeats=12 --dpi-desync-fake-quic=0x4383a71211223344 --dpi-desync-fake-unknown-udp=\"C:\ProgramData\keen_bypass_win\zapret-win-bundle-master\zapret-winws\files\quic_initial_www_google_com.bin\" --dpi-desync-cutoff=n2 --hostlist=\"C:\ProgramData\keen_bypass_win\keen_bypass\files\hosts-antifilter.txt\" --hostlist=\"C:\ProgramData\keen_bypass_win\keen_bypass\files\hosts-rkn.txt\" --hostlist-auto=\"C:\ProgramData\keen_bypass_win\keen_bypass\files\hosts-auto.txt\" --hostlist-exclude=\"C:\ProgramData\keen_bypass_win\keen_bypass\files\hosts-exclude.txt\"

call :srvinst winws1
rem call :srvinst winws2
goto :eof

:srvinst
net stop %1
sc delete %1
sc create %1 binPath= "\"C:\ProgramData\keen_bypass_win\zapret-win-bundle-master\zapret-winws\winws.exe\" %ARGS%" DisplayName= "zapret DPI bypass : %1" start= auto
sc description %1 "zapret DPI bypass software"
sc start %1
