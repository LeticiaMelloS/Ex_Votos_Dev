@echo off
rem Processa a arte de arte\entrada e gera os arquivos do jogo em arte\provisoria.
rem Se o Godot mudar de lugar, ajuste o caminho abaixo.
set GODOT=%USERPROFILE%\OneDrive\Documentos\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe

if not exist "%GODOT%" (
  echo Nao encontrei o Godot em:
  echo %GODOT%
  echo Abra este arquivo no Bloco de Notas e corrija o caminho.
  pause
  exit /b 1
)

echo Processando a arte...
cd /d "%~dp0"
"%GODOT%" --headless --path . -s res://ferramentas/processar_arte.gd 2>nul
echo.
echo Pronto. Volte para a janela do Godot e rode o jogo (F5, depois F4).
pause
