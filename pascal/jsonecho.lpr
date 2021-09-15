program jsonecho;

uses
  sysutils, classes, iostream, json;

function ReadValue: Boolean; forward;

type
  TTestCase = record
    Input: String;
  end;

var
  Stream: TStream;
  Reader: TJsonReader;
  Indentation: integer;
  i: integer;

const
  AbortOnFirstError: Boolean = false;

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
    (Input: '{{"b":"a",} "c":123'),
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
    (Input: '{{123: 321} "c":42}')
  )
;

procedure Indent;
var
  i: integer;
begin
  for i := 0 to Indentation-1 do
    Write('  ');
end;

procedure ReadList;
begin
  WriteLn('[');
  Inc(Indentation);
  while Reader.Advance <> jnListEnd do
  begin
    Indent;
    if ReadValue then
      WriteLn(', ');
  end;
  Dec(Indentation);
  Indent;
  Write(']');
end;

procedure ReadDict;
var
  Key: String;
begin
  WriteLn('{');
  Inc(Indentation);

  while Reader.Advance <> jnDictEnd do
  begin
    if Reader.Error then
      repeat
        WriteLn({ErrOutput,} 'ERROR: ', Reader.LastErrorMessage);
      until AbortOnFirstError or not Reader.Proceed;

    if Reader.Key(Key) then
    begin
      Indent;
      Write('"', Key, '": ');
      if ReadValue then
        WriteLn(', ');
    end;
  end;

  Dec(Indentation);
  Indent;
  Write('}');
end;

function ReadValue: Boolean;
var
  i64: int64;
  u64: uint64;
  dbl: double;
  Str: string;
  bool: Boolean;
  fs: TFormatSettings;
begin
  Result := True;
  fs.ThousandSeparator := #0;
  fs.DecimalSeparator := '.';


  if Reader.Error then
    repeat
      WriteLn({ErrOutput,} 'ERROR: ', Reader.LastErrorMessage);
    until AbortOnFirstError or not Reader.Proceed;

  if Reader.Number(i64) then
    Write(i64)
  else if Reader.Number(u64) then
    Write(u64)
  else if Reader.Number(dbl) then
    Write(FloatToStr(dbl, fs))
  else if Reader.Str(Str) then
    Write('"', Str, '"')
  else if Reader.List then
    ReadList
  else if Reader.Dict then
    ReadDict
  else if Reader.Null then
    Write('null')
  else if Reader.Bool(bool) then
  begin
    if bool then
      Write('true')
    else
      Write('false');
  end
  else
    Result := False;
end;


begin
  (**)
  for i := low(samples) to high(samples) do
  begin 
    Stream := nil;     
    Reader := nil;
    try
      WriteLn(samples[i].Input, ' => ');
      Stream := TStringStream.Create(samples[i].Input);    
      Reader := TJsonReader.Create(Stream);
      ReadValue;
      WriteLn('');
    finally
      FreeAndNil(Stream);
      FreeAndNil(Reader);
    end;
  end;
  (**)
  (*
    Stream := nil;
    Reader := nil;
    try
      Stream := TIOStream.Create(iosInput);
      Reader := TJsonReader.Create(Stream);
      ReadValue;
    finally
      FreeAndNil(Stream);   
      FreeAndNil(Reader);
    end;
  *)
end.
