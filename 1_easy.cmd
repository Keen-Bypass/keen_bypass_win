@rem 1. Легкая (Подходит для большинства провайдеров, аналогична 3/3 в keen bypass)
@rem ЕСЛИ НИЧЕГО НЕ ПОНИМАЕТЕ - НЕ ТРОГАЙТЕ ЭТОТ ФАЙЛ, ОТКАЖИТЕСЬ ОТ ИСПОЛЬЗОВАНИЯ СЛУЖБЫ. ИНАЧЕ БУДЕТЕ ПИСАТЬ ПОТОМ ВОПРОСЫ "У МЕНЯ ПРОПАЛ ИНТЕРНЕТ , КАК ВОССТАНОВИТЬ"

set ARGS=^
--wf-tcp=80,443 --wf-udp=443,50000-50099 ^
--filter-tcp=80,443 --dpi-desync=fake,multidisorder --dpi-desync-fooling=md5sig,badsum --dpi-desync-split-pos=1,midsld --dpi-desync-fake-tls=\"C:\keen_bypass_for_windows\zapret-win-bundle-master\zapret-winws\files\tls_clienthello_www_google_com.bin\" --hostlist=\"C:\keen_bypass_for_windows\keen-dpi-for-windows\files\list-googlevideo.txt\" --new ^
--filter-tcp=80,443 --dpi-desync=fake,multidisorder --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1,midsld --dpi-desync-fake-tls=\"C:\keen_bypass_for_windows\zapret-win-bundle-master\zapret-winws\files\tls_clienthello_www_google_com.bin\" --hostlist=\"C:\keen_bypass_for_windows\keen-dpi-for-windows\files\list-antifilter.txt\" --hostlist=\"C:\keen_bypass_for_windows\keen-dpi-for-windows\files\list-rkn.txt\" --hostlist-auto=\"C:\keen_bypass_for_windows\keen-dpi-for-windows\files\list-auto.txt\" --hostlist-exclude=\"C:\keen_bypass_for_windows\keen-dpi-for-windows\files\list-exclude.txt\" --new ^
--filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=20 --dpi-desync-fake-quic=\"C:\keen_bypass_for_windows\zapret-win-bundle-master\zapret-winws\files\quic_initial_www_google_com.bin\" --hostlist=\"C:\keen_bypass_for_windows\keen-dpi-for-windows\files\list-googlevideo.txt\" --new ^
--filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=20 --hostlist=\"C:\keen_bypass_for_windows\keen-dpi-for-windows\files\list-antifilter.txt\" --hostlist=\"C:\keen_bypass_for_windows\keen-dpi-for-windows\files\list-rkn.txt\" --hostlist-auto=\"C:\keen_bypass_for_windows\keen-dpi-for-windows\files\list-auto.txt\" --hostlist-exclude=\"C:\keen_bypass_for_windows\keen-dpi-for-windows\files\list-exclude.txt\" --new ^
--filter-udp=50000-50099 --ipset=\"C:\keen_bypass_for_windows\zapret-win-bundle-master\zapret-winws\files\ipset-discord.txt\" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-any-protocol=1 --dpi-desync-cutoff=n4

call :srvinst winws1
set ARGS=--wf-l3=ipv4,ipv6 --wf-udp=443 --dpi-desync=fake 
rem call :srvinst winws2
goto :eof

:srvinst
net stop %1
sc delete %1
sc create %1 binPath= "\"C:\keen_bypass_for_windows\zapret-win-bundle-master\zapret-winws\winws.exe\" %ARGS%" DisplayName= "zapret DPI bypass : %1" start= auto
sc description %1 "zapret DPI bypass software"
sc start %1