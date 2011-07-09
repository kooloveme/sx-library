unit uDof2Cfg;

interface

uses
  uTypes, uProjectOptions,
	SysUtils;

procedure WriteProjectInfoToCfg(const CfgFileName: TFileName; const ProjectInfo: TProjectOptions; const DelphiVersion: SG);
procedure DofToCfg(const FileNamePrefix: string; const DelphiVersion: SG);

implementation

uses
  uDelphi,
  uOutputFormat,
	uStrings,
	uFiles,
	uFile,
	Registry,
	Windows,
	IniFiles,
	uMsg;

procedure WriteProjectInfoToCfg(const CfgFileName: TFileName; const ProjectInfo: TProjectOptions; const DelphiVersion: SG);
var
	Data: string;
  SearchPath: string;
  FileName: TFileName;
  i: SG;
begin
	{$ifdef Console}
	Information('Writing file %1.', [CfgFileName]);
	{$endif}

	Data := '';

	if ProjectInfo.OutputDir <> '' then
		Data := Data + '-E"' + ProjectInfo.OutputDir + '"' + FileSep;
//-LE"c:\program files\borland\delphi6\Projects\Bpl"
//-LN"c:\program files\borland\delphi6\Projects\Bpl"

	if ProjectInfo.UnitOutputDir <> '' then
		Data := Data + '-N"' + ReplaceDelphiVariables(ProjectInfo.UnitOutputDir, DelphiVersion) + '"' + FileSep;
	if ProjectInfo.PackageDLLOutputDir <> '' then
		Data := Data + '-LE"' + ReplaceDelphiVariables(ProjectInfo.PackageDLLOutputDir, DelphiVersion) + '"' + FileSep;
	if ProjectInfo.PackageDCPOutputDir <> '' then
		Data := Data + '-LN"' + ReplaceDelphiVariables(ProjectInfo.PackageDCPOutputDir, DelphiVersion) + '"' + FileSep;

  SearchPath := ReplaceDelphiVariables(ProjectInfo.SearchPath, DelphiVersion);
	if ProjectInfo.SearchPath <> '' then
		Data := Data + '-U"' + SearchPath + '"' + FileSep;
	if ProjectInfo.SearchPath <> '' then
		Data := Data + '-O"' + SearchPath + '"' + FileSep;
	if ProjectInfo.SearchPath <> '' then
		Data := Data + '-I"' + SearchPath + '"' + FileSep;
	if ProjectInfo.SearchPath <> '' then
		Data := Data + '-R"' + SearchPath + '"' + FileSep;

	if ProjectInfo.Conditionals <> '' then
		Data := Data + '-D' + ProjectInfo.Conditionals + FileSep;

  Data := Data + '-$M' + IntToStr(ProjectInfo.MinStackSize) + ',' + IntToStr(ProjectInfo.MaxStackSize) + FileSep;
  Data := Data + '-$K' + NumToStr(ProjectInfo.ImageBase, 16) + FileSep;
  FileName := DataDir + 'default.cfg';
  if FileExistsEx(FileName) then
	  Data := Data +  ReadStringFromFile(FileName);
	for i := 1 to DelphiVersion do
  begin
	  FileName := DataDir + 'default-D' + IntToStr(DelphiVersion) + '.cfg';
	  if FileExistsEx(FileName) then
		  Data := Data +  ReadStringFromFile(FileName);
  end;

	WriteStringToFile(CfgFileName, Data, False, fcAnsi);
	{$ifdef Console}
	Information('Done.');
	{$endif}
end;

procedure DofToCfg(const FileNamePrefix: string; const DelphiVersion: SG);
var
	ProjectInfo: TProjectOptions;
begin
	ProjectInfo := TProjectOptions.Create;
  try
    ProjectInfo.ReadFromFile(FileNamePrefix + '.dof');
  	WriteProjectInfoToCfg(FileNamePrefix + '.cfg', ProjectInfo, DelphiVersion);
  finally
    ProjectInfo.Free;
  end;
end;

end.