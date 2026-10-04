@echo off
rem Redesenha o mapa geral (mundo/mapa.png e mundo/mapa.html) a partir das planilhas.
chcp 65001 >nul
set PYTHONIOENCODING=utf-8
cd /d "%~dp0"
python ferramentas\desenhar_mapa.py
echo.
echo Abra mundo\mapa.html no navegador para ver o mapa.
pause
