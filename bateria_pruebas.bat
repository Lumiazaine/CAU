
ipconfig /flushdns


@echo off
cmdkey /list:>previa.txt


del /q/f/s %TEMP%\*

javac -cache-dir c:\temp\jws
javaws -clearcache
javaws -Xclearcache -silent -Xnosplash


RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 1


rd /s /q %systemdrive%\$Recycle.bin 



@echo off
cmdkey /list:>post.txt

fc previa.txt post.txt

gpupdate /force 

