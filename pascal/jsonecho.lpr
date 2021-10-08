program jsonecho;

uses
  sysutils, classes, iostream, jsonstream;

var
  InStream, OutStream: TStream;
  Reader: TJsonReader;
  Writer: TJsonWriter;

  AbortOnFirstError: Boolean       = true;
  Pretty:            Boolean       = true;
  NestingDepth:      integer       = MaxInt;
  Features:          TJsonFeatures = [];

procedure PutString(const S: string);
begin
  OutStream.Write(S[1], length(S));
end;

procedure LogError(const S: string);
begin
 {WriteLn(ErrOutput, } PutString(LineEnding + S + LineEnding);
end;

function ReadValue: Boolean; forward;

procedure ReadList;
begin
  Writer.List;
  while Reader.Advance <> jnListEnd do
    ReadValue;
  Writer.ListEnd;
end;

procedure ReadDict;
var
  Key: String;
begin
  Writer.Dict;

  while Reader.Advance <> jnDictEnd do
  begin
    repeat
      if Reader.Key(Key) then
      begin
        Writer.Key(Key);
        ReadValue;
      end
      else if Reader.Error then
      begin
        LogError(Format('ERROR: %s', [Reader.LastErrorMessage]));
        if not AbortOnFirstError and Reader.Proceed then
          continue;
      end;
      break;
    until false;
  end;

  Writer.DictEnd;
end;

function ReadValue: Boolean;
var
  i64: int64;
  u64: uint64;
  dbl: double;
  Str: string;
  bool: Boolean;
begin
  repeat
    Result := True;

    if Reader.Number(i64) then
      Writer.Number(i64)
    else if Reader.Number(u64) then
      Writer.Number(u64)
    else if Reader.Number(dbl) then
      Writer.Number(dbl)
    else if Reader.Str(Str) then
      Writer.Str(Str)
    else if Reader.List then
      ReadList
    else if Reader.Dict then
      ReadDict
    else if Reader.Null then
      Writer.Null
    else if Reader.Bool(bool) then
      Writer.Bool(bool)
    else if Reader.Error then
    begin
      Result := false;
      LogError(Format('ERROR: %s', [Reader.LastErrorMessage]));
      if not AbortOnFirstError and Reader.Proceed then
        continue;
    end
    else
      assert(false);

    break;
  until false;
end;

procedure PrintUsageAndExit;
begin
  WriteLn(ErrOutput, 'jsonecho [options]');
  WriteLn(ErrOutput, 'Read a JSON file from standard input, parse it, and print it to standard ' +
                     'output in standardized form, reporting any errors.');
  WriteLn(ErrOutput, 'Options:');     
  WriteLn(ErrOutput, '  --pretty        Pretty-print the output.');
  WriteLn(ErrOutput, '  --json5         Accept JSON5 input, which is a superset of JSON.');
  WriteLn(ErrOutput, '  --stubborn      Try to fix syntax errors and continue parsing, instead of aborting on the first error.');
  WriteLn(ErrOutput, '  --max-depth <n> Maximum nesting depth (of lists and dicts). If this depth is exceeded, parsing is aborted.');
  Halt(-1);
end;

procedure ParseOptions;
var
  i: integer;
begin
  i := 1;
  while i <= ParamCount do
  begin
    if ParamStr(i) = '--pretty' then
      Pretty := true
    else if ParamStr(i) = '--json5' then
      Features := Features + [jfJson5]
    else if ParamStr(i) = '--stubborn' then
      AbortOnFirstError := false
    else if (ParamStr(i) = '--max-depth') and TryStrToInt(ParamStr(i+1), NestingDepth) then
      Inc(i)
    else
      PrintUsageAndExit;
    Inc(i);
  end;
end;

begin
  ParseOptions;

  InStream := nil;
  OutStream := nil;
  Reader := nil;
  Writer := nil;
  try
    InStream := TIOStream.Create(iosInput);
    OutStream := TIOStream.Create(iosOutPut);
    Reader := TJsonReader.Create(InStream, Features, NestingDepth);
    Writer := TJsonWriter.Create(OutStream, Features, Pretty);
    ReadValue;
  finally                  
    FreeAndNil(Reader);
    FreeAndNil(Writer);
    FreeAndNil(InStream);
    FreeAndNil(OutStream);
  end;
end.
