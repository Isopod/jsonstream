program jsontest;

uses
  sysutils, classes, jsonstream;

procedure AssertTrue(Cond: Boolean; const msg:string=''); inline;
begin
  if Cond then
    raise EAssertionFailed.Create(msg);
end;

// Test basic list
procedure TestList;
var
  Stream: TStream;
  Reader: TJsonReader;

  num: integer;

  i: integer;
const
  sample = '[1,2,3]';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(sample);
    Reader := TJsonReader.Create(Stream);

    AssertTrue(Reader.List);

    for i := 1 to 3 do
    begin
      Reader.Advance;
      AssertTrue(Reader.Number(num));
      WriteLn(num);
      assert(num = i);
    end;

    AssertTrue(Reader.Advance = jnListEnd);
    AssertTrue(Reader.Advance = jnEOF);
  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// Test basic dict
procedure TestDict;
var
  Stream: TStream;
  Reader: TJsonReader;

  num: integer;
  str: string;

  i: integer;
const
  sample = '{"abc":1,"def":2,"ghi":3}';
  keys: array [1..3] of string = ('abc', 'def', 'ghi');
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(sample);
    Reader := TJsonReader.Create(Stream);

    AssertTrue(Reader.Dict);

    for i := 1 to 3 do
    begin
      Reader.Advance;
      AssertTrue(Reader.Key(str));
      AssertTrue(str = keys[i]);
      AssertTrue(Reader.Number(num));
      WriteLn(str, '=', num);
      AssertTrue(num = i);
    end;

    AssertTrue(Reader.Advance = jnDictEnd);
    AssertTrue(Reader.Advance = jnEOF);

  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// Test complex mixture of dicts and lists
procedure TestDictsListsMix;
var
  Stream: TStream;
  Reader: TJsonReader;

  num: integer;
  str: string;

  i: integer;
const
  sample = 
    '{'#13#10 +
      '"abc" : ['#13#10+
        '{"nest":'#13#10 +
          '{"nest2":[1,2,3]}'#13#10 +
        '}'#13#10 +
      '],'#13#10 +
      '"def" : [[1,2],[[4],5],6,[7]]'#13#10 +
    '}';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(sample);
    Reader := TJsonReader.Create(Stream);

    AssertTrue(Reader.Dict);

    Reader.Advance;

    AssertTrue(Reader.Key(str));
    AssertTrue(str = 'abc');

    AssertTrue(Reader.List);

    Reader.Advance;

    AssertTrue(Reader.Dict);

    Reader.Advance;

    AssertTrue(Reader.Key(str));
    AssertTrue(str = 'nest');

    AssertTrue(Reader.Dict);

    Reader.Advance;

    AssertTrue(Reader.Key(str));
    AssertTrue(str = 'nest2');

    AssertTrue(Reader.List);

    for i := 1 to 3 do
    begin
      Reader.Advance;
      AssertTrue(Reader.Number(num));
      AssertTrue(num = i);
    end;

    AssertTrue(Reader.Advance = jnListEnd);
    AssertTrue(Reader.Advance = jnDictEnd);
    AssertTrue(Reader.Advance = jnDictEnd);
    AssertTrue(Reader.Advance = jnListEnd);

    Reader.Advance;

    AssertTrue(Reader.Key(str));
    AssertTrue(str = 'def');

    AssertTrue(Reader.List);

    Reader.Advance;

    AssertTrue(Reader.List);

    Reader.Advance;

    AssertTrue(Reader.Number(num));
    AssertTrue(num = 1);

    Reader.Advance;

    AssertTrue(Reader.Number(num));
    AssertTrue(num = 2);

    AssertTrue(Reader.Advance = jnListEnd);

    Reader.Advance;

    AssertTrue(Reader.List);

    Reader.Advance;

    AssertTrue(Reader.List);

    Reader.Advance;

    AssertTrue(Reader.Number(num));
    AssertTrue(num = 4);

    AssertTrue(Reader.Advance = jnListEnd);

    Reader.Advance;

    AssertTrue(Reader.Number(num));

    assert(num = 5);

    AssertTrue(Reader.Advance = jnListEnd);

    Reader.Advance;

    AssertTrue(Reader.Number(num));
    AssertTrue(num = 6);

    Reader.Advance;

    AssertTrue(Reader.List);

    Reader.Advance;

    AssertTrue(Reader.Number(num));
    AssertTRue(num = 7);

    AssertTrue(Reader.Advance = jnListEnd);
    AssertTrue(Reader.Advance = jnListEnd);
    AssertTrue(Reader.Advance = jnDictEnd);
    AssertTrue(Reader.Advance = jnEOF);

  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// More practical example
(*
procedure Test4;
var
  Stream: TStream;
  Reader: TJsonReader;
const
  sample =
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
    ']';

  procedure ReadValue; forward;

  procedure ReadList;
  begin
    WriteLn('List Begin');
    while Reader.Advance <> jnListEnd do
      ReadValue;               
    WriteLn('List End');
  end;

  procedure ReadDict;
  var
    Key: String;
  begin               
    WriteLn('Dict Begin');
    while Reader.Advance <> jnDictEnd do
    begin
      if Reader.Key(Key) then
      begin
        WriteLn('Key: ', Key);
        ReadValue;
      end
      else
        WriteLn('Parse error');
    end;
    WriteLn('Dict End');
  end;

  procedure ReadValue;
  var
    Num: integer;
    Str: string;
  begin
    if Reader.Number(Num) then
      WriteLn('Number: ', Num)
    else if Reader.Str(Str) then
      WriteLn('String: ', Str)
    else if Reader.List then
      ReadList
    else if Reader.Dict then
      ReadDict
    else
      WriteLn('Parse Error');
  end;

begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(sample);
    Reader := TJsonReader.Create(Stream);

    ReadValue;

  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;
*)

// Test error recovery
procedure TestErrorRecovery;
var
  Stream: TStream;
  Reader: TJsonReader;
  str: string;
const
  // Malformed JSON
  sample = '[{"a":"b"}{"c":"d","e"}{"f":"g"]}';
  //                  ^           ^^       ^^
  //                  1           23       45
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(sample);
    Reader := TJsonReader.Create(Stream);

    AssertTrue(Reader.List);

    Reader.Advance;

    AssertTrue(Reader.Dict);

    Reader.Advance;

    AssertTrue(Reader.Key(str));
    AssertTrue(str = 'a');

    AssertTrue(Reader.Str(str));
    AssertTrue(str = 'b');

    Reader.Advance;

    AssertTrue(Reader.State = jnDictEnd);

    Reader.Advance;

    // 1st error

    AssertTrue(Reader.State = jnError);

    Reader.Proceed;
    Reader.Advance;

    AssertTrue(Reader.Dict);

    Reader.Advance;

    AssertTrue(Reader.Key(str));
    AssertTrue(str = 'c');

    AssertTrue(Reader.Str(str));
    AssertTrue(str = 'd');

    Reader.Advance;

    AssertTrue(Reader.Key(str));
    AssertTrue(str = 'e');

    // 2nd error

    AssertTrue(Reader.Error);

    Reader.Proceed;

    AssertTrue(Reader.State = jnNull);

    AssertTrue(Reader.Advance = jnDictEnd);

    // 3rd error

    Reader.Advance;
    AssertTrue(Reader.Error);

    Reader.Proceed;
    Reader.Advance;

    AssertTrue(Reader.Dict);

    Reader.Advance;

    AssertTrue(Reader.Key(str));
    AssertTrue(str = 'f');

    AssertTrue(Reader.Str(str));
    AssertTrue(str = 'g');

    // 4th error

    Reader.Advance;
    AssertTrue(Reader.Error);

    Reader.Proceed;

    AssertTrue(Reader.Advance = jnDictEnd);
    AssertTrue(Reader.Advance = jnListEnd);

    // 5th error

    Reader.Advance;
    AssertTrue(Reader.Error);

    Reader.Proceed;

    AssertTrue(Reader.Advance = jnEOF);

  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// Test basic skip functionality
procedure TestSkip;
var
  Stream: TStream;
  Reader: TJsonReader;
  num:    integer;
const
  sample = '[1,[2,[3,4],[5]],6]';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(sample);
    Reader := TJsonReader.Create(Stream);

    AssertTrue(Reader.List);

    Reader.Advance;

    AssertTrue(Reader.Number(num));
    AssertTrue(num = 1);

    Reader.Advance;

    AssertTrue(Reader.List);

    Reader.Skip;

    Reader.Advance;    

    AssertTrue(Reader.Number(num));
    AssertTrue(num = 6);

    AssertTrue(Reader.Advance = jnListEnd);
    AssertTrue(Reader.Advance = jnEOF);
  finally   
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// Test skip with errors
procedure TestSkipWithErrors;
var
  Stream: TStream;
  Reader: TJsonReader;
  num:    integer;
  i:      integer;
const
  sample = '[1,{2,"a":"b"},3]';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(sample);
    Reader := TJsonReader.Create(Stream);

    AssertTrue(Reader.List);

    Reader.Advance;
    AssertTrue(Reader.Number(num));
    AssertTrue(num = 1);

    Reader.Advance;

    AssertTrue(Reader.Dict);

    Reader.Skip;  

    AssertTrue(Reader.Advance = jnError);

    AssertTrue(Reader.Proceed);
    AssertTrue(Reader.Proceed);

    AssertTrue(Reader.Number(num));
    AssertTrue(num = 3);

    AssertTrue(Reader.Advance = jnListEnd);
    AssertTrue(Reader.Advance = jnEOF);
  finally   
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;


// Test booleans
procedure TestBoolean;
var
  Stream: TStream;
  Reader: TJsonReader;
  b:      Boolean;
const
  sample = '[true,false,true]';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(sample);
    Reader := TJsonReader.Create(Stream);

    AssertTrue(Reader.List);

    Reader.Advance;

    AssertTrue(Reader.Bool(b));
    AssertTrue(b);

    Reader.Advance;

    AssertTrue(Reader.Bool(b));
    AssertTrue(not b);

    Reader.Advance;

    AssertTrue(Reader.Bool(b));
    AssertTrue(b);

    AssertTrue(Reader.Advance = jnListEnd);
    AssertTrue(Reader.Advance = jnEOF);
  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// Test booleans in dict
procedure TestBoolsInDict;
var
  Stream: TStream;
  Reader: TJsonReader;
  b:      Boolean;
  k:      string;
const
  sample = '{"foo":true,"bar":false}';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(sample);
    Reader := TJsonReader.Create(Stream);

    AssertTrue(Reader.Dict);

    Reader.Advance;

    AssertTrue(Reader.Key(k));
    AssertTrue(k = 'foo');

    AssertTrue(Reader.Bool(b));
    AssertTrue(b);

    Reader.Advance;

    AssertTrue(Reader.Key(k));
    AssertTrue(k = 'bar');

    AssertTrue(Reader.Bool(b));
    AssertTrue(not b);

    AssertTrue(Reader.Advance = jnDictEnd);
    AssertTrue(Reader.Advance = jnEOF);
  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// Test numbers
procedure TestNumbers;
var
  Stream: TStream;
  Reader: TJsonReader;

  dbl: double;
  int: integer;
  u64: uint64;
const
  sample = '[3.14,-42,1.024e3,9223372036854775808]';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(sample);
    Reader := TJsonReader.Create(Stream);

    AssertTrue(Reader.List);

    Reader.Advance;

    AssertTrue(not Reader.Number(int));
    AssertTrue(Reader.Number(dbl));
    AssertTrue(dbl = double(3.14));

    Reader.Advance;

    AssertTrue(Reader.Number(int));
    AssertTrue(int = -42);

    Reader.Advance;

    AssertTrue(Reader.Number(dbl));
    AssertTrue(dbl = 1024);

    Reader.Advance;

    AssertTrue(not Reader.Number(int));
    AssertTrue(Reader.Number(u64));
    AssertTrue(u64 = uint64(9223372036854775808));

    AssertTrue(Reader.Advance = jnListEnd);
    AssertTrue(Reader.Advance = jnEOF);
  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// Test escape sequences
procedure TestEscapeSequences;
var
  Stream: TStream;
  Reader: TJsonReader;

  str: string;
const
  sample = '"Hello \u0041 World\tTab\r\nNewLine"';
  expected = 'Hello A World'#9'Tab'#13#10'NewLine';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(sample);
    Reader := TJsonReader.Create(Stream);

    AssertTrue(Reader.Str(str));
    AssertTrue(str = expected);

    AssertTrue(Reader.Advance = jnEOF);
  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// Test erroneous escape sequences
procedure TestInvalidEscapeSequences;
var
  Stream: TStream;
  Reader: TJsonReader;

  str: string;
const
  sample = '"a \u41 b\x"';
  expected = 'a A b\x';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(sample);
    Reader := TJsonReader.Create(Stream);

    AssertTrue(not Reader.Str(str));
    Reader.Proceed;

    AssertTrue(not Reader.Str(str));
    Reader.Proceed;

    AssertTrue(Reader.Str(str));
    AssertTrue(str = expected);

    AssertTrue(Reader.Advance = jnEOF);
  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// Test StrBuf
procedure TestStrBuf;
var
  Stream: TStream;
  Reader: TJsonReader;
  buf: string;
  n: SizeInt;
const
  sample = '["Hello World", "Hello \u0041 World", "\u0041\u0042\u0043\u0044\r\n\u0045\u0046", "", "Hell\u00f6 W\u00f6rld"]';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(sample);
    Reader := TJsonReader.Create(Stream);

    AssertTrue(Reader.List);

    AssertTrue(Reader.Advance = jnString);

    buf := '';
    SetLength(buf, 5);

    // "Hello World"
    n := Reader.StrBuf(buf[1], 5);
    AssertTrue((n = 5) and (Copy(buf, 1, n) = 'Hello'));
    n := Reader.StrBuf(buf[1], 5);
    AssertTrue((n = 5) and (Copy(buf, 1, n) = ' Worl'));
    n := Reader.StrBuf(buf[1], 5);
    AssertTrue((n = 1) and (Copy(buf, 1, n) = 'd'));
    n := Reader.StrBuf(buf[1], 5);
    AssertTrue((n = 0));

    AssertTrue(Reader.Advance = jnString);

    // Hello A World
    n := Reader.StrBuf(buf[1], 5);
    AssertTrue((n = 5) and (Copy(buf, 1, n) = 'Hello'));
    n := Reader.StrBuf(buf[1], 5);
    AssertTrue((n = 5) and (Copy(buf, 1, n) = ' A Wo'));
    n := Reader.StrBuf(buf[1], 5);
    AssertTrue((n = 3) and (Copy(buf, 1, n) = 'rld'));
    n := Reader.StrBuf(buf[1], 5);
    AssertTrue((n = 0));

    AssertTrue(Reader.Advance = jnString);

    // ABCD\n\rEF
    n := Reader.StrBuf(buf[1], 5);
    AssertTrue((n = 5) and (Copy(buf, 1, n) = 'ABCD'#13));
    n := Reader.StrBuf(buf[1], 5);
    AssertTrue((n = 3) and (Copy(buf, 1, n) = #10'EF'));
    n := Reader.StrBuf(buf[1], 5);
    AssertTrue((n = 0));

    AssertTrue(Reader.Advance = jnString);

    // ""
    n := Reader.StrBuf(buf[1], 5);
    AssertTrue(n = 0);

    AssertTrue(Reader.Advance = jnString);

    // Hellö Wörld
    n := Reader.StrBuf(buf[1], 5);
    AssertTrue((n = 5) and (Copy(buf, 1, n) = 'Hell'#$c3));
    n := Reader.StrBuf(buf[1], 5);
    AssertTrue((n = 5) and(Copy(buf, 1, n) = #$b6' W'#$c3#$b6));
    n := Reader.StrBuf(buf[1], 5);
    AssertTrue((n = 3) and (Copy(buf, 1, n) = 'rld'));
    n := Reader.StrBuf(buf[1], 5);
    AssertTrue((n = 0));

    AssertTrue(Reader.Advance = jnListEnd);
  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// Test KeyBuf
procedure TestKeyBuf;
var
  Stream: TStream;
  Reader: TJsonReader;
  buf: string;
  n: SizeInt;
  int: integer;
const
  sample = '{"Hello World": 1, "Hello \u0041 World": 2, "\u0041\u0042\u0043\u0044\r\n\u0045\u0046":3, "":4, "Hell\u00f6 W\u00f6rld":5}';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(sample);
    Reader := TJsonReader.Create(Stream);

    AssertTrue(Reader.Dict);

    AssertTrue(Reader.Advance = jnKey);

    buf := '';
    SetLength(buf, 5);

    // "Hello World"
    n := Reader.KeyBuf(buf[1], 5);
    AssertTrue((n = 5) and (Copy(buf, 1, n) = 'Hello'));
    n := Reader.KeyBuf(buf[1], 5);
    AssertTrue((n = 5) and (Copy(buf, 1, n) = ' Worl'));
    n := Reader.KeyBuf(buf[1], 5);
    AssertTrue((n = 1) and (Copy(buf, 1, n) = 'd'));
    n := Reader.KeyBuf(buf[1], 5);
    AssertTrue((n = 0));

    AssertTrue(Reader.Number(int));
    AssertTrue(int = 1);

    AssertTrue(Reader.Advance = jnKey);

    // Hello A World
    n := Reader.KeyBuf(buf[1], 5);
    AssertTrue((n = 5) and (Copy(buf, 1, n) = 'Hello'));
    n := Reader.KeyBuf(buf[1], 5);
    AssertTrue((n = 5) and (Copy(buf, 1, n) = ' A Wo'));
    n := Reader.KeyBuf(buf[1], 5);
    AssertTrue((n = 3) and (Copy(buf, 1, n) = 'rld'));
    n := Reader.KeyBuf(buf[1], 5);
    AssertTrue((n = 0));

    AssertTrue(Reader.Number(int));
    AssertTrue(int = 2);

    AssertTrue(Reader.Advance = jnKey);

    // ABCD\n\rEF
    n := Reader.KeyBuf(buf[1], 5);
    AssertTrue((n = 5) and (Copy(buf, 1, n) = 'ABCD'#13));
    n := Reader.KeyBuf(buf[1], 5);
    AssertTrue((n = 3) and (Copy(buf, 1, n) = #10'EF'));
    n := Reader.KeyBuf(buf[1], 5);
    AssertTrue((n = 0));

    AssertTrue(Reader.Number(int));
    AssertTrue(int = 3);

    AssertTrue(Reader.Advance = jnKey);

    // ""
    n := Reader.KeyBuf(buf[1], 5);
    AssertTrue(n = 0);

    AssertTrue(Reader.Number(int));
    AssertTrue(int = 4);

    AssertTrue(Reader.Advance = jnKey);

    // Hellö Wörld
    n := Reader.KeyBuf(buf[1], 5);
    AssertTrue((n = 5) and (Copy(buf, 1, n) = 'Hell'#$c3));
    n := Reader.KeyBuf(buf[1], 5);
    AssertTrue((n = 5) and (Copy(buf, 1, n) = #$b6' W'#$c3#$b6));
    n := Reader.KeyBuf(buf[1], 5);
    AssertTrue((n = 3) and (Copy(buf, 1, n) = 'rld'));
    n := Reader.KeyBuf(buf[1], 5);
    Assert(n = 0);

    AssertTrue(Reader.Number(int));
    AssertTrue(int = 5);

    AssertTrue(Reader.Advance = jnDictEnd);
  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

begin
  SetMultiByteConversionCodePage(CP_UTF8);

  TestList;
  TestDict;
  TestDictsListsMix;
  TestErrorRecovery;
  TestSkip;
  TestSkipWithErrors;
  TestBoolean;
  TestBoolsInDict;
  TestNumbers;
  TestEscapeSequences;
  TestInvalidEscapeSequences;
  TestStrBuf;
  TestKeyBuf;
end.

