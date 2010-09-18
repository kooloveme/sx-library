//* File:     Lib\uFind.pas
//* Created:  1999-05-01
//* Modified: 2005-02-14
//* Version:  X.X.33.X
//* Author:   Safranek David (Safrad)
//* E-Mail:   safrad@email.cz
//* Web:      http://safrad.webzdarma.cz

unit uFind;

interface

uses uAdd;
// AValue is Sorted Array
function FindS2(AValue: PArrayS2; var FromV, ToV: SG; const Value: S2; FindGroup: BG): Boolean;
function FindU2(AValue: PArrayU2; var FromV, ToV: SG; const Value: U2; FindGroup: BG): Boolean;
function FindS4(AValue: PArrayS4; var FromV, ToV: SG; const Value: S4; FindGroup: BG): Boolean;

function FindIS(AIndex: array of SG; AValue: array of string;
	const Value: string; out FromV, ToV: SG): Boolean;
function FindS(AValue: array of string;
	const Value: string; out FromV, ToV: SG): Boolean;

function Find(SubStr, Str: string): SG; overload;
function Find(SubStr, Str: string; FromPos: SG): SG; overload;
function Find(SubStr, Str: string; FromPos, ToPos: SG): SG; overload;

implementation

uses
	uError,
	Math;

function FindS2(AValue: PArrayS2; var FromV, ToV: SG; const Value: S2; FindGroup: BG): Boolean;
{$I Find.inc}

function FindU2(AValue: PArrayU2; var FromV, ToV: SG; const Value: U2; FindGroup: BG): Boolean;
{$I Find.inc}

function FindS4(AValue: PArrayS4; var FromV, ToV: SG; const Value: S4; FindGroup: BG): Boolean;
{$I Find.inc}

function FindIS(AIndex: array of SG; AValue: array of string;
	const Value: string; out FromV, ToV: SG): Boolean;
const
	MinIndex = 0;
type
	TIndex = SG;
var
	L, R, M: TIndex;
	MaxIndex: TIndex;
	{$ifopt d+}
	i: SG;
	{$endif}
begin
	MaxIndex := Length(AValue) - 1;

	{$ifopt d+}
	for i := MinIndex to MaxIndex - 1 do
	begin
		if AValue[AIndex[i]] > AValue[AIndex[i]] then
			IE(445);
	end;
	{$endif}

	L := MinIndex;
	R := MaxIndex;
	while L < R do
	begin
		M := (L + R) div 2;

		if Value <= AValue[AIndex[M]] then R := M else L := M + 1;
	end;
	Result := Value = AValue[AIndex[L]];
	FromV := L;
	ToV := R;
end;

function FindS(AValue: array of string;
	const Value: string; out FromV, ToV: SG): Boolean;
const
	MinIndex = 0;
type
	TIndex = SG;
var
	L, R, M: TIndex;
	MaxIndex: TIndex;
	{$ifopt d+}
	i: SG;
	{$endif}
begin
	MaxIndex := Length(AValue) - 1;

	{$ifopt d+}
	for i := MinIndex to MaxIndex - 1 do
	begin
		if AValue[i] > AValue[i + 1] then
			IE(446);
	end;
	{$endif}

	L := MinIndex;
	R := MaxIndex;
	while L < R do
	begin
		M := (L + R) div 2;

		if Value <= AValue[M] then R := M else L := M + 1;
	end;
	Result := Value = AValue[L];
	FromV := L;
	ToV := R;
end;


// Standard
function Find(SubStr, Str: string): SG;
begin
	Result := Find(SubStr, Str, 1, Length(Str));
end;

function Find(SubStr, Str: string; FromPos: SG): SG;
begin
	Result := Find(SubStr, Str, FromPos, Length(Str));
end;

function Find(SubStr, Str: string; FromPos, ToPos: SG): SG;
label LNFound;
var i, j: SG;
begin
	Result := 0;
	if FromPos < 1 then FromPos := 1;
	i := FromPos - 1;
	while i <= ToPos - Length(SubStr) do
	begin
		for j := 0 to Length(SubStr) - 1 do
			if  Str[i + j + 1] <> SubStr[j + 1] then goto LNFound;
		Result := i + 1;
		Exit;
		LNFound:
		i := i + 1;
	end;
end;


{
// Knuth, Morris, Pratt (KMP)
function FindKMP(SubStr, Str: string): SG;
label LNFound;
var
	i, j, k: SG;
	M, N: SG;
	Fails: array of SG;

begin
	M := Length(SubStr);
	N := Length(Str);

	SetLength(Fails, M + 1);
	for i := 1 to M do
	begin
		if i <= 1 then Fails[i] := 0
		else
		begin
			k := 0;
			while SubStr[k + 1] = SubStr[i - k] do
			begin
				if k >= M then Break;
				Inc(k);
			end;
			if k > 0 then
			begin
				if SubStr[i] <> SubStr[k + 1] then
					Fails[i] := k + 1
				else
					Fails[i] := Fails[k + 1];
			end
			else
			begin
				if i = 1 then
					Fails[i] := 0
				else
					Fails[i] := 1;

			end;
		end;
	end;

	i := 1; j := 1; Result := 0;
	while (i <= M) and (j <= N) do
	begin
		if SubStr[i] = Str[j] then
			if i = M then
			begin
				Result := j - M;
				Exit;
			end
			else
			begin
				Inc(i);
				Inc(j);
			end
		else
			if Fails[i] = 0 then
			begin
				Inc(i);
				Inc(j);
			end
			else
				i := Fails[i];
	end;
	Result := 0;
	i := 0;
	while i <= Length(Str) - Length(SubStr) do
	begin
		for j := 0 to Length(SubStr) - 1 do
			if  Str[i + j + 1] <> SubStr[j + 1] then goto LNFound;
		Result := i + 1;
		Exit;
		LNFound:
		i := i + 1 + j;
	end;

	SetLength(Fails, 0);
end;

// Boyer-Moore (BM)
var
	Fail1: array[0..255] of SG;
	Fail2, F: array of SG;
procedure FillFail(P: string; M: SG);
var i, j, t, k, tp: SG;
begin
	for i := 0 to 255 do
		Fail1[i] := M;
	SetLength(Fail2, 0);
	SetLength(Fail2, M + 2);
	SetLength(F, M + 1);
	for j := M downto 1 do
	begin
		if Fail1[Ord(P[j])] = M then Fail1[Ord(P[j])] := M - j;
		Fail2[j] := 2 * M - j;
	end;
	j := M; t := M + 1;
	while j > 0 do
	begin
		F[j] := t;
		while (t <= M) and (P[j] <> P[t]) do
		begin
			Fail2[t] := Min(Fail2[t], M - j);
			t := F[t];
		end;
		Dec(j);
		Dec(t);
	end;
	for k := 1 to t do Fail2[k] := Min(Fail2[k], M + t - k);
	tp := F[t];
	while (t <= tp) do
	begin
		Fail2[t] := Min(Fail2[t], tp - t + M);
		Inc(t);
	end;
	SetLength(F, 0);
end;

function FindBM(SubStr, Str: string): SG;
var
	M, N: SG;
	i, j: SG;
begin
	M := Length(SubStr);
	N := Length(Str);
	FillFail(SubStr, M);

	j := M; Result := 0;
	while j <= N do
	begin
		i := M;
		while (i > 0) and (Str[j] = SubStr[i]) do
		begin
			Dec(i);
			Dec(i);
		end;
		if i = 0 then
		begin
			Result := i + 1;
			Exit;
		end
		else
			j := j + Max(Fail1[Ord(Str[j])], Fail2[i]);
	end;
end;}

end.
