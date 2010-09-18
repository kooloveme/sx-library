//* File:     Lib\uWave.pas
//* Created:  1999-07-01
//* Modified: 2005-05-11
//* Version:  X.X.34.X
//* Author:   Safranek David (Safrad)
//* E-Mail:   safrad@centrum.cz
//* Web:      http://safrad.webzdarma.cz

unit uWave;

interface

uses
	MMSystem, SysUtils, Windows,
	uDTimer, uTypes, uData, uMath;

{
procedure NoSound;
procedure Sound(const Hz: Word);
}
{
	Supported Wave:
	Format: PCM only
	Channels: 1..2 (Mono, Stereo)
	BitsPerSample: 8 or 16 bits
	SampleRate: 1..512 * 1024 * 1024

	8 bits
			Byte Hex SortInt
	Max: 255  $ff -1

	Cen: 128  $80 -128
			 127  $7f 127

	Min:   0  $00 0


	16 bits
			 Word   Hex SmallInt
	Max: 32767 $7fff  32767

	Cen:     0 $0000      0
			 65535 $ffff     -1

	Min: 32768 $8000 -32768
}
const
	WaveHead = 44;
	MaxVolume = 1024;
	Zero1 = $80;
	Zero2 = $0000;
type
	TBLR = record
		L, R: U1;
	end;
	TWLR = record
		L, R: S2;
	end;
	TDLR = record
		L, R: S4;
	end;
	PWaveSample = ^TWaveSample;
	TWaveSample = packed record
		case Integer of
		0: (B: U1);
		1: (W: S2);
		2: (D: S4);
		3: (BLR: TBLR);
		4: (WLR: TWLR);
		5: (DLR: TDLR);
	end;
	PWaveData = ^TWaveData;
	TWaveData = packed record
		case Integer of
		0: (B: array[0..1024 * 1024 * 1024 - 1] of Byte);
		1: (W: array[0..512 * 1024 * 1024 - 1] of SmallInt);
		2: (D: array[0..256 * 1024 * 1024 - 1] of LongInt);
		3: (BLR: array[0..512 * 1024 * 1024 - 1] of TBLR);
		4: (WLR: array[0..256 * 1024 * 1024 - 1] of TWLR);
		5: (DLR: array[0..128 * 1024 * 1024 - 1] of TDLR);
	end;

	PWave = ^TWave;
	TWave = packed record // 44
		Marker1:         array[0..3] of Char; // 4
		BytesFollowing:  LongInt; // 4; FileSize - 8
		Marker2:         array[0..3] of Char; // 4
		Marker3:         array[0..3] of Char; // 4
		BlockAlign:      LongInt; // 4; 16
		FormatTag:       Word; // 2; 1
		Channels:        Word; // 2; 2: stereo, 1: mono
		SampleRate:      LongInt; // 4; 11025, 22050, 44100
		BytesPerSecond:  LongInt; // 4; BytesPerSample * SampleRate
		BytesPerSample:  Word; // 2; 1, 2, 4; 4: 16 bit stereo, 2: 8 bit stereo
		BitsPerSample:   Word; // 2; 16: 16 bit mono/stereo, 8: 8 bit mono/stereo
		Marker4:         array[0..3] of Char; // 4
		DataBytes:       LongInt; // 4; <= (FileSize - 44)
		Data:            TWaveData; // X
	end;

type
	TWinSound = (
		wsAsterisk, // Done
		wsCloseProgram,
		wsCriticalStop, // uError
		wsDefaultSound, // Beep
		wsExclamation,
		wsExitWindows,
		wsMaximize,
		wsMenuCommand,
		wsMenuPopup,
		wsMinimize,
		wsOpenProgram,
		wsProgramError,
		wsQuestion, // uError
		wsRestoreDown,
		wsRestoreUp,
//		wsRingIn,
//		wsRingout,
//		wsSelect,
//		wsShowToolbarBand,
		wsStartWindows
//		wsSystemDefault
		);
const
	WinSoundNames: array[TWinSound] of string = (
		'SystemAsterisk',
		'Close',
		'SystemHand',
		'.Default',
		'SystemExclamation',
		'SystemExit',
		'Maximize',
		'MenuCommand',
		'MenuPopup',
		'Minimize',
		'Open',
		'AppGPFault',
		'SystemQuestion',
		'RestoreDown',
		'RestoreUp',
//		'RingIn',
//		'RingOut',
//		'CCSelect',
//		'ShowBand',
		'SystemStart'
//		'SystemDefault'
		);

const
	ConvertShr = 16;
	ConvertPre = 1 shl ConvertShr;
procedure SoundLR(var Left, Right: Integer; const NowPos, MaxPos: Integer);
// For screen Width 800 is NowPos 0..799, MaxPos 799

function GetBufferSize(wBitsPerSample, nChannels, BufferOutSamples: SG): SG;
function GetBufferSample(wBitsPerSample, BufferOutSize: SG): SG;

procedure WaveReadFromFile(var Wave: PWave; FName: TFileName);
procedure WaveWriteToFile(var Wave: PWave; FName: TFileName);

procedure WaveCreate(var Wave: PWave;
	const Channels: Word; // 1, 2
	const BitsPerSample: Word; // 8, 16
	const SampleRate: LongInt; // 11025, 22050, 44100, 48000...
	const TotalSamples: LongInt); // 1 sec = SampleRate
procedure WaveFree(var Wave: PWave);

// Left, Right (0..ConvertPre)
procedure ConvertChannels(const WaveS: PWave; var WaveD: PWave;
	const NewChannels: Word; const Left, Right: Integer);
procedure ConvertBitsPerSample(const WaveS: PWave; var WaveD: PWave;
	const NewBitsPerSample: Integer);
procedure ConvertSampleRate(const WaveD: PWave; const SampleRate: LongInt);
procedure ConvertWave(const WaveS: PWave; var WaveD: PWave;
	const Channels: Word;
	const BitsPerSample: Word;
	const SampleRate: LongInt);

procedure PlayWave(Wave: PWave);
procedure PlayWaveFile(WaveName: TFileName);
procedure PlayWinSound(WinSound: TWinSound);
procedure Beep;

type
	PPlayItem = ^TPlayItem;
	TPlayItem = packed record // 32
		PlayAs: (paWave, paTone, paNoise, paSilent); // 1
		R0: array[0..2] of U1;
		SampleCount: U4;
		SamplePos: U4;
		Speed: U4;
		Offset: U4; // Calculated from Speed
		VolumeLeft: S4;
		VolumeRight: S4;
		Wave: PWave; // 4
	end;

	TWaveCommon = class
	private
		FHWave: HWave;
		FWaveFormat: TWaveFormatEx;

		FError: MMResult;
		FActive: Boolean;
		FCloseInvoked: Boolean;

		FBufferOutSize: SG;
		FBufferOutSamples: SG;
		FOutCount: SG;

		procedure SendBuffer;
		procedure FillBuffer(Buffer: PWaveData); virtual; abstract; // WavePlayerOnly
	public
		// Options
		VolumeLeft: SG;
		VolumeRight: SG;

		Bits: SG;
		Frequency: SG;
		Channels: 1..2;

		BufferTime: UG;

		function WaveErrorText(ErrorCode: U4): string;
		procedure MMError(s: string);

		constructor Create;
		destructor Destroy; override;

		procedure Open;
		procedure Close;

		procedure Pause;
		procedure Resume;
		procedure Stop;

		property BufferSize: SG read FBufferOutSize;
		property BufferSamples: SG read FBufferOutSamples;
		property BufferOutCount: SG read FOutCount;
		property Active: Boolean read FActive;
	end;

	TWavePlayer = class(TWaveCommon)
	private
		// Items to play
		PlayItems: TData;

		procedure FillBuffer(Buffer: PWaveData); override;
	public
		Speed: SG;
		MaxItems: SG;

		constructor Create;
		destructor Destroy; override;

		procedure Play(Wave: PWave);
		procedure Beep;
		procedure Silent(Tim: UG);
		procedure Tone(Frequency, Tim: UG);
		procedure Noise(Tim: UG);
	end;

	TOnReciveBuffrerEvent = procedure(Sender: TObject; Buffer: PWaveData) of object;

	TWaveRecorder = class(TWaveCommon)
	private
		FOnReciveBuffrer: TOnReciveBuffrerEvent;
	public

	published
		property OnReciveBuffrer: TOnReciveBuffrerEvent read FOnReciveBuffrer write FOnReciveBuffrer;
	end;

implementation

uses
	Registry, Dialogs,
	uFiles, uError, uStrings, uFormat;

(*
procedure NoSound;
asm
	{$ifopt O+}
	push ax
	{$endif}
	in al, 61h
	and al, 00fch
	out 61h, al
	{$ifopt O+}
	pop ax
	{$endif}
end;

procedure Sound(const Hz: Word);
asm
	{$ifopt O+}
	pushad
	{$endif}
	mov bx, Hz
	mov ax, 34DDh
	mov dx, 0012h
	cmp dx, bx
	jnb @ExitProc
	div bx
	{ ax := dx&ax div bx
		dx := dx&ax mod bx
		dx&ax := 1193181
		f := 1092Hz
	}
	mov bx, ax
	in al, 61h
	test al, 03h
	jne @SoundIsOn
		or al, 03h
		out 61h, al
		mov al, 0B6h
		out 43h, al
	@SoundIsOn:
	mov al, bl
	out 42h, al
	mov al, bh
	out 42h, al
	@ExitProc:
	{$ifopt O+}
	popad
	{$endif}
end;
*)
procedure Beep;
begin
	PlayWinSound(wsDefaultSound);
end;

procedure SoundLR(var Left, Right: Integer; const NowPos, MaxPos: Integer);
begin
	Left := ConvertPre * (MaxPos - NowPos) div MaxPos;
	if Left < 0 then
		Left := 0
	else if Left > ConvertPre then
		Left := ConvertPre;
	Right := ConvertPre * NowPos div MaxPos;
	if Right < 0 then
		Right := 0
	else if Right > ConvertPre then
		Right := ConvertPre;
end;

function CheckWave(Wave: PWave): Boolean;
begin
	Result := False;
	if Wave <> nil then
	begin
		if ((Wave.BitsPerSample = 8) or (Wave.BitsPerSample = 16)) then
		begin
			Result := True;
		end
		else
			ErrorMessage('Invalid wave format');
	end
	else
		ErrorMessage('Wave is empty');
end;

procedure WaveReadFromFile(var Wave: PWave; FName: TFileName);
label LRetry, LFin;
var
	F: TFile;
begin
	if Wave <> nil then
	begin
//		MessageD('Destination Wave Must Be Nil', mtError, [mbOk]);
		WaveFree(Wave);
	end;
	F := TFile.Create;
	LRetry:
	if F.Open(FName, fmReadOnly, FILE_FLAG_SEQUENTIAL_SCAN, False) then
	begin
		if F.FileSize < WaveHead then
		begin
			IOErrorMessage(FName, 'File truncated');
			goto LFin;
		end;
		GetMem(Wave, F.FileSize);
		if not F.BlockRead(Wave^, F.FileSize) then goto LFin;
		if (Wave.Marker1 <> 'RIFF') or (Wave.Marker2 <> 'WAVE') or
			(Wave.Marker3 <> 'fmt ') {or
			(Wave.BytesFollowing <> F.FileSize - 8) }then
		begin
			IOErrorMessage(FName, 'File is not wave');
			WaveFree(Wave);
		end
		else
		begin
			if Wave.BytesFollowing <> F.FileSize - 8 then
			begin
				IOErrorMessage(FName, 'Wave bytes following repaired');
				Wave.BytesFollowing := F.FileSize - 8;
			end;
			if (Wave.BitsPerSample = 4) {Microsoft ADPCM} or (Wave.BitsPerSample = 0) {GSM 6.10} then goto LFin;
			if ((Wave.BitsPerSample <> 8) and (Wave.BitsPerSample <> 16)) then
			begin
				IOErrorMessage(FName, 'Wave format not supported');
				WaveFree(Wave);
				goto LFin;
			end;
	{		if Wave.DataBytes > F.FileSize - 44 then
			begin
				IOErrorMessage(FName, 'Wave data bytes repaired');
				Wave.DataBytes := F.FileSize - 44;
			end;}
		end;
		LFin:
		F.Close;
	end;
	F.Free;
end;

procedure WaveWriteToFile(var Wave: PWave; FName: TFileName);
label LRetry;
var
	F: TFile;
begin
	if Wave = nil then Exit;
	F := TFile.Create;
	LRetry:
	if F.Open(FName, fmReadOnly, FILE_FLAG_SEQUENTIAL_SCAN, False) then
	begin
		if not F.BlockWrite(Wave^, Wave^.BytesFollowing + 8) then goto LRetry;
		F.Truncate;
		F.Close;
	end;
	F.Free;
end;

function BitsToByte(const Bits: U8): U4;
begin
	Result := (Bits + 7) shr 3;
end;

function GetTotalSamples(const BytesPerSample: Word;
	const DataBytes: LongInt): LongInt;
begin
	Result := DataBytes div BytesPerSample;
end;

procedure WaveCreate(var Wave: PWave;
	const Channels: Word;
	const BitsPerSample: Word;
	const SampleRate: LongInt;
	const TotalSamples: LongInt);
var
	BitsPerSamples: Word;
	DataBytes: LongInt;
begin
	BitsPerSamples := Channels * BitsPerSample;
	DataBytes := BitsToByte(BitsPerSamples * U8(TotalSamples));

	if Wave <> nil then
	begin
//		MessageD('Destination Wave Must Be Nil', mtError, [mbOk]);
{		if LongInt(Pointer(LongInt(Wave) - 4)^) - 6 < WaveHead + DataBytes then
		begin
			WaveFree(Wave);
//			FreeMem(Wave);
		end;}
	end
	else
		GetMem(Wave, WaveHead + DataBytes);
	Wave.Marker1 := 'RIFF';
	Wave.BytesFollowing := DataBytes + WaveHead - 8;
	Wave.Marker2 := 'WAVE';
	Wave.Marker3 := 'fmt ';
	Wave.BlockAlign := 16;
	Wave.FormatTag := 1;
	Wave.Channels := Channels;
	Wave.SampleRate := SampleRate;
	Wave.BytesPerSecond := BitsToByte(BitsPerSamples * U8(SampleRate));
	Wave.BytesPerSample := BitsToByte(BitsPerSamples); // 256 for 4 bit !!!
	Wave.BitsPerSample := BitsPerSample;
	Wave.Marker4 := 'data';
	Wave.DataBytes := DataBytes;

{ case BitsPerSample of
	8: FillChar(Wave.Data.B, Wave.DataBytes, 128);
	16: FillChar(Wave.Data.W, Wave.DataBytes div 2, 0);
	end;}
end;

procedure WaveFree(var Wave: PWave);
begin
	FreeMem(Wave); Wave := nil;
end;

procedure ConvertChannels(const WaveS: PWave; var WaveD: PWave;
	const NewChannels: Word; const Left, Right: Integer);
var
	i: Integer;
//  WaveData: Integer;
	TotalSamples: Integer;
begin
	if (WaveS = nil) or (WaveS = WaveD) then Exit;
	TotalSamples :=
		GetTotalSamples(WaveS.BytesPerSample, WaveS.DataBytes);

{ if WaveD = nil then
	begin}
		WaveCreate(WaveD, NewChannels, WaveS.BitsPerSample,
		WaveS.SampleRate, TotalSamples);
{ end
	else
	begin
		WaveData := 2 * WaveS.DataBytes;
		Move(WaveS^, WaveD^, WaveHead);
		WaveD.Channels := 2;
		WaveD.BytesPerSecond := WaveD.BytesPerSecond * 2;
		WaveD.BytesPerSample := WaveD.BytesPerSample * 2;
		WaveD.DataBytes := WaveData;
		WaveD.BytesFollowing :=  WaveHead + WaveData - 8;
	end;}

	case WaveS.BitsPerSample of
	8:
		case WaveS.Channels of
		1:
			case WaveD.Channels of
			1:
				for i := 0 to WaveD.DataBytes - 1 do
				begin
					WaveD.Data.B[i] := WaveS.Data.B[i];
				end;
			2:
			begin
{       for i := 0 to WaveD.DataBytes div 2 - 1 do
				begin
					WaveD.Data.B[i shl 1 + 0] := Left * ShortInt(WaveS.Data.B[i] - 128) div ConvertPre + 128;
					WaveD.Data.B[i shl 1 + 1] := Right * ShortInt(WaveS.Data.B[i] - 128) div ConvertPre + 128;
				end;}
				asm
				pushad
				mov eax, WaveD
				mov edi, [eax]
				add edi, WaveHead
				mov esi, WaveS
				mov ecx, [esi + WaveHead - 4]
				add esi, WaveHead
				add ecx, esi
				@Loop:
					xor ebx, ebx
					mov bl, byte ptr [esi] // 3
					sub ebx, 128

					mov eax, Left
					imul eax, ebx // 10
					sar eax, ConvertShr
					add al, 128
					mov [edi], al
					inc edi

					mov eax, Right
					imul eax, ebx // 10
					sar eax, ConvertShr
					add al, 128
					mov [edi], al
					inc edi

					inc esi
				cmp esi, ecx
				jne @Loop
				popad
				end;
			end;
			end;
		2:
			case WaveD.Channels of
			1:
				for i := 0 to WaveD.DataBytes - 1 do
				begin
					WaveD.Data.B[i] :=
						(Left * ShortInt(WaveS.Data.B[i] - 128) div ConvertPre +
						Right * ShortInt(WaveS.Data.B[i] - 128) div ConvertPre) div 2 + 128;
				end;
			2:
				for i := 0 to WaveD.DataBytes div 2 - 1 do
				begin
					WaveD.Data.B[i shl 1 + 0] := Left * ShortInt(WaveS.Data.B[i shl 1 + 0] - 128) div ConvertPre + 128;
					WaveD.Data.B[i shl 1 + 1] := Right * ShortInt(WaveS.Data.B[i shl 1 + 1] - 128) div ConvertPre + 128;
				end;
			end;
		end;
	16:
		case WaveS.Channels of
		1:
			case WaveD.Channels of
			1:
				for i := 0 to WaveD.DataBytes div 2 - 1 do
				begin
					WaveD.Data.W[i] := WaveS.Data.W[i];
				end;
			2:
			begin
{       for i := 0 to WaveD.DataBytes div 4 - 1 do
				begin
					WaveD.Data.W[i shl 1 + 0] := Left * WaveS.Data.W[i] div ConvertPre;
					WaveD.Data.W[i shl 1 + 1] := Right * WaveS.Data.W[i] div ConvertPre;
				end;}
				asm
				pushad
				mov eax, WaveD
				mov edi, [eax]
				add edi, WaveHead
				mov esi, WaveS
				mov ecx, [esi + WaveHead - 4]
				add esi, WaveHead
				add ecx, esi
				@Loop:
					movsx ebx, SmallInt ptr [esi] // 3

					mov eax, Left
					imul eax, ebx // 10
					sar eax, ConvertShr
					mov [edi], ax
					add edi, 2

					mov eax, Right
					imul eax, ebx // 10
					sar eax, ConvertShr
					mov [edi], ax
					add edi, 2

					add esi, 2
				cmp esi, ecx
				jne @Loop
				popad
				end;
			end;
			end;
		2:
			case WaveD.Channels of
			1:
				for i := 0 to WaveD.DataBytes div 2 - 1 do
				begin
					WaveD.Data.W[i] :=
						(Left * WaveS.Data.W[i] div ConvertPre +
						Right * WaveS.Data.W[i] div ConvertPre) div 2;
				end;
			2:
				for i := 0 to WaveD.DataBytes div 4 - 1 do
				begin
					WaveD.Data.W[i shl 1 + 0] := Left * WaveS.Data.W[i shl 1 + 0] div ConvertPre;
					WaveD.Data.W[i shl 1 + 1] := Right * WaveS.Data.W[i shl 1 + 1] div ConvertPre;
				end;
			end;
		end;
	end;
end;

procedure ConvertBitsPerSample(const WaveS: PWave; var WaveD: PWave;
	const NewBitsPerSample: Integer);
var
	i: Integer;
	TotalSamples: LongInt;
begin
	if (WaveS = nil) or (WaveS = WaveD) then Exit;
	TotalSamples :=
		GetTotalSamples(WaveS.BytesPerSample, WaveS.DataBytes);

{ if WaveD = nil then
	begin}
		WaveCreate(WaveD, WaveS.Channels, NewBitsPerSample,
		WaveS.SampleRate, TotalSamples);
{ end
	else
	begin
		WaveData := 2 * WaveS.DataBytes;
		Move(WaveS^, WaveD^, WaveHead);
		WaveD.Channels := 2;
		WaveD.BytesPerSecond := WaveD.BytesPerSecond * 2;
		WaveD.BytesPerSample := WaveD.BytesPerSample * 2;
		WaveD.DataBytes := WaveData;
		WaveD.BytesFollowing :=  WaveHead + WaveData - 8;
	end;}

	case WaveS.BitsPerSample of
	8:
	begin
		case WaveD.BitsPerSample of
		8:
			for i := 0 to WaveD.DataBytes - 1 do
			begin
				WaveD.Data.B[i] := WaveS.Data.B[i];
			end;
		16:
			for i := 0 to WaveD.DataBytes div 2 - 1 do
			begin
				WaveD.Data.W[i] := 256 * (WaveS.Data.B[i] - 128);
			end;
		end;
	end;
	16:
	begin
		case WaveD.BitsPerSample of
		8:
			for i := 0 to WaveD.DataBytes - 1 do
			begin
				WaveD.Data.B[i] := (WaveS.Data.W[i] div 256) + 128;
			end;
		16:
			for i := 0 to WaveD.DataBytes div 2 - 1 do
			begin
				WaveD.Data.W[i] := WaveS.Data.W[i];
			end;
		end;
	end;
	end;
end;

procedure ConvertSampleRate(const WaveD: PWave; const SampleRate: LongInt);
begin
	WaveD.SampleRate := SampleRate;
	WaveD.BytesPerSecond := WaveD.BytesPerSample * WaveD.SampleRate;
//    BitsToByte(WaveD.Channels * WaveD.BitsPerSample * U8(SampleRate));
end;

procedure ConvertWave(const WaveS: PWave; var WaveD: PWave;
	const Channels: Word;
	const BitsPerSample: Word;
	const SampleRate: LongInt);
begin
{ ConvertBitsPerSample(WaveS, WaveD, BitsPerSample);
	ConvertChannels(WaveS, WaveD, Channels, ConvertPre, ConvertPre);
	ConvertSampleRate(WaveD, SampleRate);}
end;

procedure PlayWave(Wave: PWave);
begin
	if Wave <> nil then
		PlaySound(PChar(Wave), 0, SND_ASYNC or SND_MEMORY or SND_NODEFAULT)
end;

procedure PlayWaveFile(WaveName: TFileName);
//var Wave: PWave;
begin
{	WaveReadFromFile(Wave, WaveName);
	PlayWave(Wave);
	FreeMem(Wave);}
	if WaveName <> '' then
		PlaySound(PChar(WaveName), 0, SND_ASYNC {and SND_FILENAME});
end;

procedure PlayWinSound(WinSound: TWinSound);
var
	Reg: TRegistry;
	Key: string;
	SndName: TFileName;
begin
	Reg := TRegistry.Create;
	Reg.RootKey := HKEY_CURRENT_USER;
	Key := 'AppEvents\Schemes\Apps\.Default\' + WinSoundNames[WinSound] + '\.Current';
	if Reg.OpenKey(Key, False) then
	begin
		if Reg.ValueExists('') then
		begin
			SndName := ReplaceF(Reg.ReadString(''), '%SystemRoot%', WinDir);
			PlayWaveFile(SndName);
		end;
		Reg.CloseKey;
	end;
	Reg.Free;
end;

function GetBufferSize(wBitsPerSample, nChannels, BufferOutSamples: SG): SG;
begin
	Result := BufferOutSamples * ((wBitsPerSample * nChannels + 7) div 8);
end;

function GetBufferSample(wBitsPerSample, BufferOutSize: SG): SG;
begin
	case wBitsPerSample of
	16: Result := BufferOutSize div 2;
	else Result := BufferOutSize;
	end;
end;

// TPlayerCommon
const
	SpeedDiv = 1024;

constructor TWaveCommon.Create;
begin
	inherited Create;
	FHWave := 0;
	FActive := False;
	FCloseInvoked := False;
	VolumeLeft := MaxVolume;
	VolumeRight := MaxVolume;

	Bits := 16;
	Frequency := 44100;
	if Self is TWavePlayer then
		Channels := 2
	else
		Channels := 1;
	BufferTime := 200;
end;

destructor TWaveCommon.Destroy;
begin
	if FActive then Close;
	FHWave := 0;
	inherited Destroy;
end;

function TWaveCommon.WaveErrorText(ErrorCode: U4): string;
var B: BG;
begin
	SetLength(Result, MAXERRORLENGTH);
	if Self is TWavePlayer then
		B:= waveOutGetErrorText(ErrorCode, @Result[1], MAXERRORLENGTH) = MMSYSERR_NOERROR
	else
		B:= waveInGetErrorText(ErrorCode, @Result[1], MAXERRORLENGTH) = MMSYSERR_NOERROR;
	if B then
	begin
		if Result <> '' then
			if Result[Length(Result)] = #0 then SetLength(Result, Length(Result) - 1);
//		Replace(Result, #0, ' ')
  end
	else
		Result := 'MMSYSTEM' + NToS(ErrorCode) + ' ' + 'Unknown error';
end;

procedure TWaveCommon.MMError(s: string);
begin
	if Self is TWavePlayer then
		s := 'WaveOut: ' + s
	else
		s := 'WaveIn: ' + s;
	if FError <> 0 then ErrorMessage(s + ' (' + WaveErrorText(FError) + ')');
end;

procedure MMOutDone(
	wo: HWAVEOUT;
	Msg: UINT;
	Instance: U4;
	Param1: U4;
	Param2: U4); stdcall;
var
	Header: PWaveHdr;
	BufferOut: PWaveData;
//	BufferOutSize: SG;
	WavePlayer: TWavePlayer;
begin
	if Msg = WOM_DONE then
	begin
		WavePlayer := TWavePlayer(Instance);
		Header := PWaveHdr(Param1);
		BufferOut := Pointer(Header^.lpData);
//		BufferOutSize := Header^.dwBufferLength;
{		GetMem(Buffer, BufferSize);
		Move(BufferOut^, Buffer^, BufferSize);}

		WavePlayer.FError := waveOutUnPrepareHeader(WavePlayer.FHWave, Header, SizeOf(TWaveHdr));
		WavePlayer.MMError('UnPrepare');
		FreeMem(BufferOut); //BufferOut := nil;
		Dispose(Header);

		if WavePlayer.FActive = False then Exit;
		Dec(WavePlayer.FOutCount);
		if WavePlayer.FCloseInvoked = False then
			WavePlayer.SendBuffer
		else
		if WavePlayer.FOutCount = 0 then
		begin
			WavePlayer.FError := WaveOutClose(WavePlayer.FHWave);
			WavePlayer.FHWave := 0;
			WavePlayer.MMError('Close');
			if WavePlayer.FError = 0 then
				WavePlayer.FActive := False;
		end;
	end;
end;

procedure MMInDone(
	wi: HWAVEIN;
	Msg: UINT;
	Instance: U4;
	Param1: U4;
	Param2: U4); stdcall;
var
	Header: PWaveHdr;
{	NewSize: SG;
	WaveSample: PWaveSample;}

	BufferIn: PWaveData;
	WaveRecorder: TWaveRecorder;
begin
	if Msg = WIM_DATA then
	begin
		WaveRecorder := TWaveRecorder(Instance);

		Dec(WaveRecorder.FOutCount);
		Header := PWaveHdr(Param1);
		BufferIn := Pointer(Header^.lpData);

{		if Volume <> 100 then
		begin
			WaveSample := BufferIn;
			while UG(WaveSample) < UG(BufferIn) + Header^.dwBytesRecorded do
			begin
				case WaveFormat^.wBitsPerSample of
				16:
				begin
					WaveSample.W := Range(-32768, Volume * SG(WaveSample.W) div 100, 32767);
					Inc(SG(WaveSample), 2);
				end
				else
				begin
					WaveSample.B := ((WaveSample.B - Zero1) * Volume div 100) + Zero1;
					Inc(SG(WaveSample), 1);
				end;
				end;
			end;
		end; D??? }
		if Assigned(WaveRecorder.FOnReciveBuffrer) then
			WaveRecorder.FOnReciveBuffrer(WaveRecorder, BufferIn);

		WaveRecorder.FError := waveInUnPrepareHeader(WaveRecorder.FHWave, Header, SizeOf(TWaveHdr));
		WaveRecorder.MMError('UnPrepare');
		FreeMem(BufferIn); BufferIn := nil;
		Dispose(Header);

		if WaveRecorder.FActive = False then Exit;
		Dec(WaveRecorder.FOutCount);
		if WaveRecorder.FCloseInvoked = False then
			WaveRecorder.SendBuffer
		else
		if WaveRecorder.FOutCount = 0 then
		begin
			WaveRecorder.FError := WaveInClose(WaveRecorder.FHWave);
			WaveRecorder.FHWave := 0;
			WaveRecorder.MMError('Close');
			if WaveRecorder.FError = 0 then
				WaveRecorder.FActive := False;
		end;
	end;
end;

procedure TWaveCommon.Open;
const BufferCount = 8;
var i: SG;
begin
	if FActive then Close;
	FActive := False;
	FCloseInvoked := False;
	FWaveFormat.WFormatTag := WAVE_FORMAT_PCM; // PCM format - the only option
	FWaveFormat.nChannels := Channels;
	FWaveFormat.nSamplesPerSec := Frequency;
	FWaveFormat.wBitsPerSample := Bits;
	FWaveFormat.nAvgBytesPerSec := FWaveFormat.wBitsPerSample * FWaveFormat.nSamplesPerSec div 8;
	FWaveFormat.nBlockAlign := (FWaveFormat.wBitsPerSample * FWaveFormat.nChannels) div 8;
	FWaveFormat.cbSize := SizeOf(FWaveFormat);

	if Self is TWavePlayer then
		FError := waveOutOpen(nil, 0, @FWaveFormat, 0, 0, WAVE_FORMAT_QUERY)
	else
		FError := waveInOpen(nil, 0, @FWaveFormat, 0, 0, WAVE_FORMAT_QUERY);
	MMError('WaveOpen');
	if FError <> 0 then Exit;

	if Self is TWavePlayer then
		FError := waveOutOpen(@FHWave, 0, @FWaveFormat, Cardinal(@MMOutDone), Cardinal(Self), CALLBACK_FUNCTION)
	else
		FError := waveInOpen(@FHWave, 0, @FWaveFormat, Cardinal(@MMInDone), Cardinal(Self), CALLBACK_FUNCTION);
	MMError('WaveOpen');
	if FError <> 0 then
	begin
		FHWave := 0;
		Exit;
	end;

	FOutCount := 0;

	FBufferOutSamples := RoundDiv(FWaveFormat.nSamplesPerSec * BufferTime, BufferCount * 1000);
	FBufferOutSize := GetBufferSize(FWaveFormat.wBitsPerSample, FWaveFormat.nChannels, FBufferOutSamples);
{	BufferOutSize := BufferSize;
	BufferOutSamples := GetBufferSample(WaveFormat.wBitsPerSample, WaveFormat.nChannels, BufferOutSize);}

	if not (Self is TWavePlayer) then
	begin
		FError := waveInStart(FHWave);
		MMError('Start');
	end;
	FActive := True;
	for i := 0 to BufferCount - 1 do
		SendBuffer;
end;

procedure TWaveCommon.Close;
begin
	if FActive then
	begin
		FCloseInvoked := True;
{	if Self is TWavePlayer then
		waveOutBreakLoop(FHWave);}
//	Stop; // Lag problem D???
		while FOutCount > 0 do
			Sleep(40);
		FActive := False;
		FCloseInvoked := False;
	end;
{	if FOutCount > 0 then
		Sleep(1000);}
end;

procedure TWaveCommon.Pause;
begin
	if Self is TWavePlayer then
	begin
		FError := waveOutPause(FHWave);
		MMError('Pause');
	end
	else
	begin
		MMError('Pause not supported by WinAPI');
	end;
end;

procedure TWaveCommon.Resume;
begin
	if Self is TWavePlayer then
	begin
		FError := waveOutRestart(FHWave);
		MMError('Restart');
	end
	else
	begin
		FError := waveInReset(FHWave);
		MMError('Reset');
		FError := waveInStart(FHWave);
		MMError('Start');
	end;
end;

procedure TWaveCommon.Stop;
begin
	Close;
	Open;
{
	CloseInvoked := True;
	if Self is TWavePlayer then
		FError := waveOutReset(HWave)
	else
		FError := waveInReset(HWave);
	MMError('Reset');
}
end;

procedure TWaveCommon.SendBuffer;
var
	Header: PWaveHdr;
	Buffer: PWaveData;
begin
	GetMem(Buffer, FBufferOutSize);
	if Self is TWavePlayer then
		FillBuffer(Buffer);

	Header := New(PWaveHdr);
	Header^.lpData := Pointer(Buffer);
	Header^.dwBufferLength := FBufferOutSize;
	Header^.dwBytesRecorded := 0;
	Header^.dwUser := 0;
	Header^.dwFlags := 0;
	Header^.dwLoops := 0;
	Header^.lpNext := nil;
	Header^.reserved := 0;

	if Self is TWavePlayer then
		FError := waveOutPrepareHeader(FHWave, Header, SizeOf(TWaveHdr))
	else
		FError := waveInPrepareHeader(FHWave, Header, SizeOf(TWaveHdr));
	MMError('Prepare');
	if FError <> 0 then Exit;

	if Self is TWavePlayer then
		FError := waveOutWrite(FHWave, Header, SizeOf(TWaveHdr))
	else
		FError := waveInAddBuffer(FHWave, Header, SizeOf(TWaveHdr));
	MMError('AddBuffer');
	if FError <> 0 then Exit;

	Inc(FOutCount);
end;

// TWavePlayer

const
	AngleCount = 4096;
{type
	PSinTable = ^TSinTable;
	TSinTable = array[0..AngleCount - 1] of TAngle;}
var
	Sins: PSinTable;

procedure TWavePlayer.FillBuffer(Buffer: PWaveData);
var
	i, j: SG;
	SampleP: UG;
	ValueL, ValueR, ValueLS, ValueRS, Value: SG;
	PlayItem: PPlayItem;

	procedure WriteValue;
	begin
		case FWaveFormat.wBitsPerSample of
		8:
		begin
			Value := (Value + 32768) div 256;
			if Value < 0 then
				Value := 0
			else if Value > 255 then
				Value := 255;
			Buffer.B[i] := Value;
		end;
		16:
		begin
			if Value < -32768 then
				Value := -32768
			else if Value > 32767 then
				Value := 32767;
			Buffer.W[i] := Value;
		end;
		end;
		Inc(i);
	end;

begin
	if PlayItems <> nil then
	begin
		j := 0;
		while j < SG(PlayItems.Count) do
		begin
			if j >= MaxItems then Break;
			PlayItem := PlayItems.Get(j);
			case PlayItem.PlayAs of
			paWave: PlayItem.Offset := PlayItem.Wave.Channels * PlayItem.Speed * UG(PlayItem.Wave.SampleRate) div UG(FWaveFormat.nSamplesPerSec);
			else
			begin
				PlayItem.Offset := SpeedDiv;
			end
			end;
			Inc(j);
		end;

		// 16 bit Mixer
		FillChar(Buffer^, FBufferOutSize, 0);
		i := 0;
		while i < FBufferOutSamples * FWaveFormat.nChannels do
		begin
			ValueLS := 0;
			ValueRS := 0;
			j := 0;
			ValueL := 0;
			ValueR := 0;
			while j < SG(PlayItems.Count) do
			begin
				if j >= MaxItems then Break;
				PlayItem := PlayItems.Get(j);
				SampleP := PlayItem.SamplePos div SpeedDiv;
				if SampleP >= PlayItem.SampleCount then
				begin
					PlayItems.Delete(j);
					Continue;
				end
				else
				begin
					Inc(j);
					case PlayItem.PlayAs of
					paNoise:
					begin
						ValueL := Random2(32767);
						ValueR := Random2(32767);
					end;
					paTone:
					begin
						ValueL := Sins[((U8(AngleCount) * U8(SampleP) * U8(PlayItem.Speed) div FWaveFormat.nSamplesPerSec)) and (AngleCount - 1)];
						ValueR := ValueL;
					end;
					paSilent:
					begin
						ValueL := 0;
						ValueR := 0;
					end
					else // paWave
					begin
						if PlayItem.Wave.Channels = 2 then
							SampleP := SampleP and $fffffffe;
						case PlayItem.Wave.BitsPerSample of
						16: ValueL := PlayItem.Wave.Data.W[SampleP];
						else ValueL := 256 * (SG(PlayItem.Wave.Data.B[SampleP]) - 128);
						end;
						if PlayItem.Wave.Channels = 2 then
						begin
							case PlayItem.Wave.BitsPerSample of
							16: ValueR := PlayItem.Wave.Data.W[SampleP + 1];
							else ValueR := 256 * (SG(PlayItem.Wave.Data.B[SampleP + 1]) - 128);
							end;
	//						Inc(PlayItem.SamplePos, PlayItem.Offset);
						end
						else
						begin
							ValueR := ValueL
						end;
					end;
					end;
					Inc(PlayItem.SamplePos, PlayItem.Offset);
				end;

				if (PlayItem.VolumeLeft <> MaxVolume) then
					ValueL := ValueL * PlayItem.VolumeLeft div MaxVolume;
				if (PlayItem.VolumeRight <> MaxVolume) then
					ValueR := ValueR * PlayItem.VolumeRight div MaxVolume;
				Inc(ValueLS, ValueL);
				Inc(ValueRS, ValueR);
			end;

			if FWaveFormat.nChannels = 2 then
			begin
				Value := ValueLS * VolumeLeft div MaxVolume;
				WriteValue;
				Value := ValueRS * VolumeRight div MaxVolume;
				WriteValue;
			end
			else
			begin
				Value := (VolumeLeft + VolumeRight) * (ValueLS + ValueRS) div (2 * 2 * MaxVolume);
				WriteValue;
			end;
		end;
	end;
end;

procedure TWavePlayer.Play(Wave: PWave);
var PlayItem: PPlayItem;
begin
	if CheckWave(Wave) then
	begin
		PlayItem := PlayItems.Add;
		PlayItem.PlayAs := paWave;
		PlayItem.Wave := Wave;
		PlayItem.SampleCount := 8 * Wave.DataBytes div Wave.BitsPerSample;
		PlayItem.SamplePos := 0;
		PlayItem.VolumeLeft := VolumeLeft;
		PlayItem.VolumeRight := VolumeRight;
		PlayItem.Speed := Speed;
	end;
end;

procedure TWavePlayer.Beep;
begin
	Tone(1000, 1000);
end;

procedure TWavePlayer.Silent(Tim: UG);
var
	PlayItem: PPlayItem;
begin
	PlayItem := PlayItems.Add;
	PlayItem.PlayAs := paSilent;
	PlayItem.Wave := nil;
	PlayItem.SampleCount := FWaveFormat.nSamplesPerSec * Tim div 1000;
	PlayItem.SamplePos := 0;
	PlayItem.VolumeLeft := VolumeLeft;
	PlayItem.VolumeRight := VolumeRight;
	PlayItem.Speed := Speed;
end;

procedure TWavePlayer.Tone(Frequency, Tim: UG);
var
	PlayItem: PPlayItem;
begin
	PlayItem := PlayItems.Add;
	PlayItem.PlayAs := paTone;
	if Sins = nil then
	begin
		GetMem(Sins, SizeOf(TAngle) * AngleCount);
		FillSinTable(Sins, AngleCount, SinDiv);
	end;
	PlayItem.Wave := nil;
	PlayItem.SampleCount := FWaveFormat.nSamplesPerSec * Tim div 1000;
	PlayItem.SamplePos := 0;
	PlayItem.VolumeLeft := VolumeLeft;
	PlayItem.VolumeRight := VolumeRight;
	PlayItem.Speed := Frequency;
end;

procedure TWavePlayer.Noise(Tim: UG);
var
	PlayItem: PPlayItem;
begin
	PlayItem := PlayItems.Add;
	PlayItem.PlayAs := paNoise;
	PlayItem.Wave := nil;
	PlayItem.SampleCount := FWaveFormat.nSamplesPerSec * Tim div 1000;
	PlayItem.SamplePos := 0;
	PlayItem.VolumeLeft := VolumeLeft;
	PlayItem.VolumeRight := VolumeRight;
	PlayItem.Speed := Speed;
end;

constructor TWavePlayer.Create;
begin
	inherited Create;
	PlayItems := TData.Create(True);
	PlayItems.ItemSize := SizeOf(TPlayItem);
	MaxItems := 16;
	Speed := SpeedDiv;
end;

destructor TWavePlayer.Destroy;
begin
	FreeAndNil(PlayItems);
	inherited Destroy;
end;

initialization

finalization
	if Sins <> nil then
	begin
		FreeMem(Sins);
		Sins := nil;
	end;
end.