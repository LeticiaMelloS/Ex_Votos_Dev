@echo off
rem Cria o greybox inicial das salas novas de mundo\salas.csv (nunca sobrescreve as existentes).
chcp 65001 >nul
set PYTHONIOENCODING=utf-8
cd /d "%~dp0"
python ferramentas\gerar_salas.py
pause
