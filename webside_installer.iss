#define MyAppName "Instalador Webside 10.1.5"
#define MyAppVersion "10.1.5"
#define InstallDir "C:\Quality"
#define UseIDP
[Setup]
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName=C:\Quality
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename=WebsideInstaller{#MyAppVersion}
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin
SetupIconFile=setup.ico
UninstallDisplayIcon={app}\uninstall.ico


[Components]
Name: "completa"; Description: "Instalação Completa"; Types: full custom; Flags: exclusive
Name: "pdv"; Description: "PDV Auxiliar"; Types: compact custom; Flags: exclusive

[Files]
Source: "banco_limpo.backup"; DestDir: "C:\Quality"; Flags: ignoreversion
Source: "pg_hba.conf"; DestDir: "C:\Program Files\PostgreSQL\12\data"; Flags: ignoreversion
Source: "libpq.dll"; DestDir: "C:\Wndows"; Flags: ignoreversion

[Code]
#include "idp.iss"

var
  InputPage: TInputQueryWizardPage;

procedure InitializeWizard;
begin
  InputPage := CreateInputQueryPage(wpSelectComponents, 'Informações da Empresa',
    'Insira os dados abaixo', 'Essas informações serão inseridas no banco de dados.');
  InputPage.Add('CNPJ:', False);
  InputPage.Add('IDQ:', False);
  InputPage.Visible := False;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = InputPage.ID then
  begin
    if not WizardIsComponentSelected('completa') then
      InputPage.Visible := False
    else
      InputPage.Visible := True;
  end;
end;

function DownloadFileWithProgress(URL, DestFile: string): Boolean;
begin
  Result := IDPDownloadFile(URL, DestFile);
  if not Result then
    MsgBox('Erro ao baixar: ' + URL, mbError, MB_OK);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
  CNPJ, IDQ: string;
begin
  if CurStep = ssPostInstall then
  begin
    // Criar pasta
    ForceDirectories('C:\Quality');

    // Download com progresso
    DownloadFileWithProgress('https://github.com/fernandowebside/instaladoronline05-2025/raw/main/PastaQuality.zip', 'C:\Quality\1.zip');
    DownloadFileWithProgress('https://github.com/fernandowebside/instaladoronline05-2025/raw/main/CONF_INTERFACE.zip', 'C:\Quality\2.zip');
    DownloadFileWithProgress('https://github.com/fernandowebside/instaladoronline05-2025/raw/main/exes.zip', 'C:\Quality\3.zip');

    // Descompactar
    Exec('powershell', '-Command "Expand-Archive -Force C:\Quality\1.zip C:\Quality"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Exec('powershell', '-Command "Expand-Archive -Force C:\Quality\2.zip C:\Quality"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Exec('powershell', '-Command "Expand-Archive -Force C:\Quality\3.zip C:\Quality"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

    // Copiar DLLs
    Exec('cmd.exe', '/C copy /Y C:\Quality\instala\dll\*.* C:\Windows\', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

    // Firewall
    Exec('cmd.exe', '/C netsh advfirewall firewall add rule name="QualityTCP" dir=in action=allow protocol=TCP localport=4096,5432,5433,8060,8070,8080,8090,8091,1771,2001,1001,6550', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Exec('cmd.exe', '/C netsh advfirewall firewall add rule name="QualityUDP" dir=in action=allow protocol=UDP localport=4096,5432,5433,8060,8070,8080,8090,8091,1771,2001,1001,6550', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

    // Energia
    Exec('cmd.exe', '/C powercfg /setactive SCHEME_MIN', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Exec('cmd.exe', '/C powercfg -change -monitor-timeout-ac 0', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Exec('cmd.exe', '/C powercfg -change -standby-timeout-ac 0', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

    // Instalação completa
    if WizardIsComponentSelected('completa') then
    begin
      // Baixar PostgreSQL
      DownloadFileWithProgress('https://get.enterprisedb.com/postgresql/postgresql-12.20-1-windows-x64.exe', 'C:\Quality\pgsql.exe');

      // Instalar PostgreSQL
      Exec('C:\Quality\pgsql.exe',
        '--mode unattended --unattendedmodeui none --superpassword postgres123 --servicename postgresql-12 --serverport 5432',
        '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

      // Criar usuário e banco
      Exec('cmd.exe', '/C "C:\Program Files\PostgreSQL\12\bin\psql.exe" -U postgres -d postgres -c "CREATE USER suporte WITH PASSWORD ''123456'';"',
        '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

      Exec('cmd.exe', '/C "C:\Program Files\PostgreSQL\12\bin\psql.exe" -U postgres -c "CREATE DATABASE posto;"',
        '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

      // Restore
      Exec('cmd.exe', '/C "C:\Program Files\PostgreSQL\12\bin\pg_restore.exe" -U postgres -d posto C:\Quality\banco_limpo.backup',
        '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

      // Substituir pg_hba.conf
      Exec('cmd.exe', '/C copy /Y "C:\Quality\pg_hba.conf" "C:\Program Files\PostgreSQL\12\data\pg_hba.conf"',
        '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

      // Inserir dados da empresa
      CNPJ := InputPage.Values[0];
      IDQ := InputPage.Values[1];
      Exec('cmd.exe', '/C "C:\Program Files\PostgreSQL\12\bin\psql.exe" -U postgres -d posto -c "INSERT INTO EMPRESA (CNPJ, IDEMPRESA, IDQ) VALUES (''' + CNPJ + ''',' + IDQ + ',' + IDQ + ');"',
        '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

      // Instalar serviço
      Exec('cmd.exe', '/C sc create srvIntegraWeb start=auto binPath= "C:\Quality\web\IntegraWebService.exe" DisplayName=IntegraWebService',
        '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Exec('cmd.exe', '/C sc failure srvIntegraWeb reset=86400 actions=restart/5000/restart/5000/restart/5000',
        '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Exec('cmd.exe', '/C sc description srvIntegraWeb "WEBPOSTO Servico de integracao"',
        '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Exec('cmd.exe', '/C net start srvIntegraWeb',
        '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    end;
  end;
end;
