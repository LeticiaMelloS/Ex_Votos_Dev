@echo off
rem Confere se, em cada sala, todas as passagens sao alcancaveis (aproximado).
rem Uso: checar_salas.bat  (todas)   ou   checar_salas.bat C1-01 C1-02 --sem-agarrar
chcp 65001 >nul
set PYTHONIOENCODING=utf-8
cd /d "%~dp0"
python ferramentas\checar_salas.py %*
pause
