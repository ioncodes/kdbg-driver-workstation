xcopy /Y /s guest K:\
vmrun -T player start "C:\Users\luca\Documents\Virtual Machines\win-kdbg\win-kdbg.vmx"
WinDbgX -k net:port=55000,key=1.1.1.1
vmrun stop "C:\Users\luca\Documents\Virtual Machines\win-kdbg\win-kdbg.vmx" hard