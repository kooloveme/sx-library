//* File:     Lib\uDBF.pas
//* Created:  1999-12-01
//* Modified: 2005-06-27
//* Version:  X.X.34.X
//* Author:   Safranek David (Safrad)
//* E-Mail:   safrad@centrum.cz
//* Web:      http://safrad.webzdarma.cz

unit uDBF;

interface

uses SysUtils, uTypes;

type
	PColumn = ^TColumn;
	TColumn = record // 16
		Name: string;
		Typ: TVarType; // 2
		Reserved: U2;
		Width: S4;
		Items: array of Variant;
	end;

	TDBF = class
	private
		FFileName: TFileName;
		FColumns: array of TColumn;
		FColumnCount: SG;
		FFileDate: TDateTime;
		FItemCount: SG;
	public
		Rows: array of BG; // True if row is enabled

		constructor Create;
		destructor Destroy; override;

		function FindColumn(Name: string): PColumn;
		procedure Close;

		function LoadFromFile(FName: TFileName): Boolean;
		function SaveToFile(FName: TFileName): Boolean;

		property Count: SG read FItemCount;
		property FileDate: TDateTime read FFileDate;
	end;

implementation

uses
	Windows, Variants,
	uFiles, uStrings, uInput, uError, uMem, uFormat, uMath;

procedure TDBF.Close;
var i, j: SG;
begin
	for i := 0 to FColumnCount - 1 do
	begin
		FColumns[i].Name := '';
		FColumns[i].Typ := varNull;
		for j := 0 to FItemCount - 1 do
		begin
			Finalize(FColumns[i].Items[j]);
		end;
	end;
	SetLength(FColumns, 0);
	FColumnCount := 0;
	SetLength(Rows, 0);
	FItemCount := 0;
	FFileName := '';
	FFileDate := 0;
end;

function TDBF.LoadFromFile(FName: TFileName): Boolean;
label LRetry, LExit;
type
	THead = packed record // 32
		YearOffset: U1; // $03=1900, $30=2000
		Year: U1;
		Month: U1;
		Day: U1;
		ItemsCount: U4;
		DataOffset: U2;
		RowSize: U2;
		R1, R2, R3, R4, R5: U4;
	end;
	TColumn = packed record // 32
		Name: array[0..10] of Char; // 11
		Typ: Char; // 1
		Offset: U4;
		Width: U1;
		Decimal: U1;
		Reserved0: array[0..5] of U1;
		Reserved: U8;
	end;

var
	F: TFile;
	j, k: SG;

	DataWStr: WideString;
	DataStr: ShortString;
	s: string;

	Head: THead;
	Column: TColumn;
	NewSize: SG;
	Row, SRow, CRow: Pointer;
	RowSize, RowsSize: SG;
	FPT: string;
	FPTSize: UG;
	Index: UG;
	Year: SG;
begin
	Result := False;
	Index := 0;
	FPTSize := 0;
	FillChar(DataStr, SizeOf(DataStr), 0);
	F := TFile.Create;
	LRetry:
	Close;
	FFileName := FName;
	SRow := nil;
	if F.Open(FFileName, fmReadOnly, FILE_FLAG_SEQUENTIAL_SCAN, False) then
	begin
		// Header
		F.BlockRead(Head, SizeOf(Head));
		case Head.YearOffset of
		$03:
			Year := 1900
		else
			Year := 2000;
		end;
		FFileDate := EncodeDate(Head.Year + Year, Head.Month, Head.Day);

		// Columns
		FColumnCount := 0;
		RowSize := 0;
		while True do
		begin
			F.BlockRead(Column, SizeOf(TColumn));
			if (U1(Column.Name[0]) = $0d) {and ((U1(Column.Name[1]) = $20) or (U1(Column.Name[1]) = $00))} then
			begin
				F.Seek(Head.DataOffset);
(*				while not F.Eof do
				begin
					F.BlockRead(c, 1);
					if c <> #0 {(c = $20) or (c = $2A)} then
					begin
						F.Seek(F.FilePos - 1); // Enable/Disable
						Break;
					end;
				end;*)

				Break;
			end;
			if F.Eof then goto LExit;

			NewSize := FColumnCount + 1;
			if AllocByExp(Length(FColumns), NewSize) then
				SetLength(FColumns, NewSize);
			FColumns[FColumnCount].Name := Column.Name;
			case Column.Typ of
			'C'{hars}: FColumns[FColumnCount].Typ := varString;
			'N'{umber}: FColumns[FColumnCount].Typ := varInteger; // varDouble
			'L'{ogical}: FColumns[FColumnCount].Typ := varBoolean;
			'W'{ide string}: FColumns[FColumnCount].Typ := varOleStr;
			'M'{emo}:
			begin
				FColumns[FColumnCount].Typ := varUnknown;
				if FPTSize = 0 then
				begin
					FPT := ReadStringFromFile(DelFileExt(FFileName) + '.fpt');
					if Length(FPT) >= 8 then
					begin
						FPTSize := Ord(FPT[5]) shl 24 + Ord(FPT[6]) shl 16 + Ord(FPT[7]) shl 8 + Ord(FPT[8]);
					end
					else
						FPTSize := 0;
				end;
			end
{ 		'D': Columns[ColumnCount].Typ := varDate;}
			else FColumns[FColumnCount].Typ := varNull;
			end;
			DelEndSpace(FColumns[FColumnCount].Name);
			FColumns[FColumnCount].Width := Column.Width;
			Inc(RowSize, Column.Width);
			Inc(FColumnCount);
		end;

		// Data
		Inc(RowSize);// Enable/Disable := 2 * ((RowSize + 1) div 2);
		if RowSize <> Head.RowSize then
		begin
			Head.RowSize := RowSize;
			IOErrorMessage(FFileName, 'Row Size Mishmash');
		end;
		RowsSize := Head.ItemsCount * Head.RowSize;
		if RowsSize > F.FileSize - F.FilePos then
		begin
			Head.ItemsCount := (F.FileSize - F.FilePos) div RowSize;
			IOErrorMessage(FFileName, 'File Truncated');
		end;
		if RowsSize + 1 < F.FileSize - F.FilePos then
			IOErrorMessage(FFileName, 'File Too big');


		GetMem(SRow, RowsSize);
		F.BlockRead(SRow^, RowsSize);
		if not F.Close then goto LRetry;

		SetLength(Rows, Head.ItemsCount);
		for j := 0 to FColumnCount - 1 do
		begin
			SetLength(FColumns[j].Items, Head.ItemsCount);
		end;
		FItemCount := 0;
		CRow := SRow;
		while SG(CRow) < SG(SRow) + RowsSize do
		begin
(*			if F.FilePos >= F.FileSize then goto LExit; // All readed
			if F.FilePos + RowSize > F.FileSize then
			begin
				{$ifopt d+}
				IOErrorMessage(FileName, 'File Truncated');
				{$endif}
//				MessageD('File too short'., [mbOk]);
				goto LExit; // Cutted file
			end;
//			F.BlockRead(SRow^, RowsSize);*)

{			NewSize := DbItemCount + 1;
			if AllocByExp(Length(Rows), NewSize) then
				SetLength(Rows, NewSize);}

			Rows[FItemCount] := Char(CRow^) = ' '; // 2A = Disabled
			CRow := Pointer(SG(CRow) + 1);
			for j := 0 to FColumnCount - 1 do
			begin
{				NewSize := DbItemCount + 1;
				if AllocByExp(Length(Columns[j].Items), NewSize) then
					SetLength(Columns[j].Items, NewSize);}

				Row := CRow;
				case FColumns[j].Typ of
				varOleStr:
				begin
					for k := 0 to FColumns[j].Width div 2 - 1 do
					begin
						if U2(Row^) = 0 then Break;
						Inc(SG(Row), 2)
					end;
					DataWStr := '';
					SetLength(DataWStr, k);
					if k >= 1 then
						Move(CRow^, DataWStr[1], 2 * k);
				end;
				varUnknown:
				begin
					Index := U4(Row^);
				end
				else
				begin
{					DataStr[0] := Char(Columns[j].Width);
					for k := 0 to Columns[j].Width - 1 do
					begin
						if Char(Row^) = #0 then Break;
//						DataStr[k + 1] := Char(Row^);
						Inc(SG(Row));
					end;}
					k := FColumns[j].Width;
					DataStr[0] := Char(k);
					if k >= 1 then
						Move(CRow^, DataStr[1], k);
				end;
				end;
				CRow := Pointer(SG(CRow) + FColumns[j].Width);

				case FColumns[j].Typ of
				varString:
				begin
					FColumns[j].Items[FItemCount] := DataStr;
				end;
{				varPointer:
					FColumns[j].Items[FItemCount] := SG(s[1]) + SG(s[2]) shl 8 + SG(s[3]) shl 16 + SG(s[4]) shl 24;}
				varInteger:
				begin
					if Pos('.', DataStr) <> 0 then
					begin
						FColumns[j].Typ := varDouble;
						FColumns[j].Items[FItemCount] := StrToF8(DataStr);
					end
					else
						FColumns[j].Items[FItemCount] := StrToSG(DataStr); //StrToValI(s, False, MinInt, 0, MaxInt, 1)

				end;
				varDouble:
					FColumns[j].Items[FItemCount] := StrToF8(DataStr);
				varBoolean: FColumns[j].Items[FItemCount] := (DataStr <> 'F');
				varOleStr:
				begin
					FColumns[j].Items[FItemCount] := DataWStr;
				end;
				varUnknown:
				begin
					if Index <> 0 then
					begin
						{$ifopt d+}
						k := SwapU4(PU4(@FPT[FPTSize * Index + 1])^);
						if k <> 1 then IE(343);{$endif}
						k := SwapU4(PU4(@FPT[FPTSize * Index + 5])^);
						SetLength(s, k);
						FillChar(s[1], k, 0);
						if k > 0 then
							Move(FPT[FPTSize * Index + 9], s[1], k);
					end
					else
						s := '';
					FColumns[j].Items[FItemCount] := s;
					s := '';
				end;
//				varDate:
				end;
			end;
			Inc(FItemCount);
		end;
		LExit:
		FreeMem(SRow);
		FPT := '';
		Result := True;
	end;
	F.Free;
end;

function TDBF.SaveToFile(FName: TFileName): Boolean;
begin
	Result := False;
end;

constructor TDBF.Create;
begin
	inherited Create;
end;

destructor TDBF.Destroy;
begin
	Close;
	inherited Destroy;
end;

function TDBF.FindColumn(Name: string): PColumn;
var
	i: SG;
	NameU: string;
begin
	Result := nil;
	NameU := UpperCase(Name);
	for i := 0 to FColumnCount - 1 do
	begin
		if NameU = FColumns[i].Name then
		begin
			Result := @FColumns[i];
		end;
	end;
end;

end.