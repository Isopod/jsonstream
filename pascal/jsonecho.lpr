program jsonecho;

uses
  sysutils, classes, iostream, jsonstream;

function ReadValue: Boolean; forward;

type
  TTestCase = record
    Input: String;
  end;

var
  InStream, OutStream: TStream;
  Reader: TJsonReader;
  Writer: TJsonWriter;
  i: integer;

  AbortOnFirstError: Boolean = true;
  NestingDepth: integer = MaxInt;
  Features: TJsonFeatures;

const
  samples: array of TTestCase = (
   (Input:
      '[' +
        '{' +
          '"name":"Alan Turing",' +
          '"profession":"computer scientist",' +
          '"born":1912,' +
          '"died":1954,' +
          '"tags": ["turing machine", "cryptography", "enigma", "computability"]' +
        '},' +
        '{' +
          '"name":"Kurt Gödel", ' +
          '"profession": "mathematician", ' +
          '"born":1906,' +
          '"died":1978,' +
          '"tags": ["incompleteness theorem", "set theory", "logic", "philosophy"]' +
        '},' +
        '{' +
          '"name":"Bobby \"\\\"\" Tables",' +
          '"profession": "troll", ' +
          '"born": 1970, '+
          '"died": 2038, '+
          '"tags": ["escape sequence", "input validation", "sql injection"]' +
        '}' +
      ']'),
    (Input: '["Hello", "World"}'),
    (Input: '[}'),
    (Input: '{[], "Foo": "Bar"}'),
    (Input: '{"garbage": 03.14, "foo": "bar"}'),
    (Input: '[03.14,3.14]'),
    (Input: '[1 2]'),
    (Input: '{"abc" "123"}'),
    (Input: '{"abc" 123}'),
    (Input: '{"abc" 123 "a" : "b"}'),
    (Input: '{123:123,  "a" : "b"}'),
    (Input: '{123:123,  23 : "b"}'),
    (Input: '{abc123 : "bcd"}'),
    (Input: '{123:[123,  23 : "b"}'),
    (Input: '{123:[123,  23 : "b"]}'),
    (Input: '{"a":123abc, "c":"d"}'),
    (Input: '{"123a":, "c":"d"}'),
    (Input: '{"123a" "c" "d" }'),
    (Input: '{"a" '),
    (Input: '{"a", {"b" '),
    (Input: '{"a", {"b": '),
    (Input: '{"a", ["b" '),
    (Input: '{[ '),
    (Input: '{{} "c":123'),
    (Input: '{{"b":"a",}, "c":123'),
    (Input: '{{"b":01}, "c":123'),
    (Input: '[{"b":"a",} "c",123]'),
    (Input: '{{"b":"a",} "c":123'),
    (Input: '{"a", {"b",} "c":123'),
    (Input: '[0]'),
    (Input: '{"a":2b3}'),
    (Input: '{"'),
    (Input: '{"a":23ueuiaeia232, "b": truefalse, "c": "}'),
    (Input: '{"a": "b",}'),
    (Input: '["a",]'),
    (Input: '[]'),
    (Input: '{"n": 003.14}'),
    (Input: '{{123: 321} "c":42}'),
    (Input: '{"text": "cote \r\naiu e [/code" }'),
    (Input: '["a]'),
    (Input: '["\u41"]'),
    (Input: '"a'#13#10'b"'),
    (Input: '['#1']'),
    (Input: '[a'#10'b]'),
    (Input: '["abc\'#13#10'def\'#10'ghi"]'),
    (Input: '[''a'', /*hello'#10'*w/orld*/123.5//this is a number]'),
    (Input: '[-Infinity, 42]')
  )
;

procedure PutString(const S: string);
begin
  OutStream.Write(S[1], length(S));
end;

procedure LogError(const S: string);
begin
 {WriteLn(ErrOutput, } PutString(LineEnding + S + LineEnding);
end;

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
    if ParamStr(i) = '--json5' then
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
  {$if 1}
  AbortOnFirstError := false;
  Features := [{jfJSON5}];
  OutStream := TIOStream.Create(iosOutPut);
  for i := low(samples) to high(samples) do
  begin 
    InStream := nil;
    Reader := nil;
    Writer := nil;
    PutString(Format('%s => ' + LineEnding, [samples[i].Input]));
    try
      InStream := TStringStream.Create(samples[i].Input);
      Reader := TJsonReader.Create(InStream, Features, NestingDepth);
      Writer := TJsonWriter.Create(OutStream, Features);
      ReadValue;
    finally
      FreeAndNil(InStream);
      FreeAndNil(Reader);
      FreeAndNil(Writer);
    end;
    PutString(LineEnding);
  end;
  FreeAndNil(OutStream);
  {$else}
  ParseOptions;

  InStream := nil;
  OutStream := nil;
  Reader := nil;
  Writer := nil;
  try
    InStream := TIOStream.Create(iosInput);
    OutStream := TIOStream.Create(iosOutPut);
    Reader := TJsonReader.Create(InStream, Features, NestingDepth);
    Writer := TJsonWriter.Create(OutStream, Features);
    ReadValue;
  finally                  
    FreeAndNil(Reader);
    FreeAndNil(Writer);
    FreeAndNil(InStream);
    FreeAndNil(OutStream);
  end;
  {$endif}
end.
