program jsontest;

uses
  sysutils, classes, json;

// Test basic list
procedure Test1;
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

    if not Reader.List then
      assert(false);

    for i := 1 to 3 do
    begin
      Reader.Advance;
      if not Reader.Number(num) then
        assert(false);
      WriteLn(num);
      assert(num = i);
    end;

    if Reader.Advance <> jnListEnd then
      assert(false);

    if Reader.Advance <> jnEOF then
      assert(false);

  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// Test basic dict
procedure Test2;
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

    if not Reader.Dict then
      assert(false);

    for i := 1 to 3 do
    begin
      Reader.Advance;
      if not Reader.Key(str) then
        assert(false);
      assert(str = keys[i]);
      if not Reader.Number(num) then
        assert(false);
      WriteLn(str, '=', num);
      assert(num = i);
    end;

    if Reader.Advance <> jnDictEnd then
      assert(false);

    if Reader.Advance <> jnEOF then
      assert(false);

  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// Test complex mixture of dicts and lists
procedure Test3;
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

    if not Reader.Dict then
      assert(false);

    Reader.Advance;
    if not Reader.Key(str) then
      assert(false);
    assert(str = 'abc');

    if not Reader.List then
      assert(false);

    Reader.Advance;

    if not Reader.Dict then
      assert(false);

    Reader.Advance;

    if not Reader.Key(str) then
      assert(false);

    assert(str = 'nest');

    if not Reader.Dict then
      assert(false);

    Reader.Advance;

    if not Reader.Key(str) then
      assert(false);

    assert(str = 'nest2');

    if not Reader.List then
      assert(false);

    for i := 1 to 3 do
    begin
      Reader.Advance;
      if not Reader.Number(num) then
        assert(false);
      assert(num = i);
    end;

    if Reader.Advance <> jnListEnd then
      assert(false);

    if Reader.Advance <> jnDictEnd then
      assert(false);

    if Reader.Advance <> jnDictEnd then
      assert(false);

    if Reader.Advance <> jnListEnd then
      assert(false);

    Reader.Advance;

    if not Reader.Key(str) then
      assert(false);

    assert(str = 'def');

    if not Reader.List then
      assert(false);

    Reader.Advance;

    if not Reader.List then
      assert(false);

    Reader.Advance;

    if not Reader.Number(num) then
      assert(false);

    assert(num = 1);

    Reader.Advance;

    if not Reader.Number(num) then
      assert(false);

    assert(num = 2);

    if Reader.Advance <> jnListEnd then
      assert(false);

    Reader.Advance;

    if not Reader.List then
      assert(false);

    Reader.Advance;

    if not Reader.List then
      assert(false);

    Reader.Advance;

    if not Reader.Number(num) then
      assert(false);

    assert(num = 4);

    if Reader.Advance <> jnListEnd then
      assert(false);

    Reader.Advance;

    if not Reader.Number(num) then
      assert(false);

    assert(num = 5);

    if Reader.Advance <> jnListEnd then
      assert(false);

    Reader.Advance;

    if not Reader.Number(num) then
      assert(false);

    assert(num = 6);

    Reader.Advance;

    if not Reader.List then
      assert(false);

    Reader.Advance;

    if not Reader.Number(num) then
      assert(false);

    assert(num = 7);

    if Reader.Advance <> jnListEnd then
      assert(false);

    if Reader.Advance <> jnListEnd then
      assert(false);

    if Reader.Advance <> jnDictEnd then
      assert(false);

    if Reader.Advance <> jnEOF then
      assert(false);

  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// More practical example
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

// Test error recovery
procedure Test5;
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

    if not Reader.List then
      assert(false);

    Reader.Advance;

    if not Reader.Dict then
      assert(false);

    Reader.Advance;

    if not Reader.Key(str) then
      assert(false);

    assert(str = 'a');

    if not Reader.Str(str) then
      assert(false);

    assert(str = 'b');

    Reader.Advance;

    if Reader.State <> jnDictEnd then
      assert(false);

    Reader.Advance;

    // 1st error

    if Reader.State <> jnError then
      assert(false);

    Reader.Proceed;
    Reader.Advance;

    if not Reader.Dict then
      assert(false);

    Reader.Advance;

    if not Reader.Key(str) then
      assert(false);

    assert(str = 'c');

    if not Reader.Str(str) then
      assert(false);

    assert(str = 'd');

    Reader.Advance;

    if not Reader.Key(str) then
      assert(false);

    assert(str = 'e');

    // 2nd error

    if Reader.State <> jnError then
      assert(false);

    Reader.Proceed;

    if Reader.State <> jnNull then
      assert(false);

    Reader.Advance;

    if Reader.State <> jnDictEnd then
      assert(false);

    Reader.Advance;

    // 3rd error

    if Reader.State <> jnError then
      assert(false);

    Reader.Proceed;
    Reader.Advance;

    if not Reader.Dict then
      assert(false);

    Reader.Advance;

    if not Reader.Key(str) then
      assert(false);

    assert(str = 'f');

    if not Reader.Str(str) then
      assert(false);

    assert(str = 'g');

    Reader.Advance;

    // 4th error
    if Reader.State <> jnError then
      assert(false);

    Reader.Proceed;
    Reader.Advance;

    if Reader.State <> jnDictEnd then
      assert(false);

    Reader.Advance;

    if Reader.State <> jnListEnd then
      assert(false);

    Reader.Advance;

    // 5th error
    if Reader.State <> jnError then
      assert(false);

    Reader.Proceed;
    Reader.Advance;

    if Reader.State <> jnEOF then
      assert(false);

  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// Test basic skip functionality
procedure Test6;
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

    if not Reader.List then
      assert(false);

    Reader.Advance;

    if not Reader.Number(num) then
      assert(false);

    assert(num = 1);

    Reader.Advance;

    if not Reader.List then
      assert(false);

    Reader.Skip;

    Reader.Advance;    

    if not Reader.Number(num) then
      assert(false);

    assert(num = 6);

    Reader.Advance;

    if Reader.State <> jnListEnd then
      assert(false);

    Reader.Advance;

    if Reader.State <> jnEOF then
      assert(false);

  finally   
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// Test skip with errors
procedure Test7;
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

    if not Reader.List then
      assert(false);

    Reader.Advance;

    if not Reader.Number(num) then
      assert(false);

    assert(num = 1);

    Reader.Advance;

    if not Reader.Dict then
      assert(false);

    Reader.Skip;  
    Reader.Advance;

    if Reader.State <> jnError then
      assert(false);
    if not Reader.Proceed then
      assert(false);
    if not Reader.Proceed then
      assert(false);

    if not Reader.Number(num) then
      assert(false);

    assert(num = 3);

    Reader.Advance;

    if Reader.State <> jnListEnd then
      assert(false);

    Reader.Advance;

    if Reader.State <> jnEOF then
      assert(false);

  finally   
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;


// Test booleans
procedure Test8;
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

    if not Reader.List then
      assert(false);

    Reader.Advance;

    if not Reader.Bool(b) then
      assert(false);

    assert(b);

    Reader.Advance;

    if not Reader.Bool(b) then
      assert(false);

    assert(not b);

    Reader.Advance;

    if not Reader.Bool(b) then
      assert(false);

    assert(b);

    Reader.Advance;

    if Reader.State <> jnListEnd then
      assert(false);

    Reader.Advance;

    if Reader.State <> jnEOF then
      assert(false);

  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// Test booleans in dict
procedure Test9;
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

    if not Reader.Dict then
      assert(false);

    Reader.Advance;

    if not Reader.key(k) then
      assert(false);

    assert(k = 'foo');

    if not Reader.Bool(b) then
      assert(false);

    assert(b);

    Reader.Advance;

    if not Reader.key(k) then
      assert(false);

    assert(k = 'bar');

    if not Reader.Bool(b) then
      assert(false);

    assert(not b);

    Reader.Advance;

    if Reader.State <> jnDictEnd then
      assert(false);

    Reader.Advance;

    if Reader.State <> jnEOF then
      assert(false);

  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// Test numbers
procedure Test10;
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

    if not Reader.List then
      assert(false);

    Reader.Advance;
    if Reader.Number(int) then
      assert(false);
    if not Reader.Number(dbl) then
      assert(false);
    assert(dbl = double(3.14));

    Reader.Advance;
    if not Reader.Number(int) then
      assert(false);
    assert(int = -42);

    Reader.Advance;
    if not Reader.Number(dbl) then
      assert(false);
    assert(dbl = 1024);

    Reader.Advance;
    if Reader.Number(int) then
      assert(false);
    if not Reader.Number(u64) then
      assert(false);
    assert(u64 = uint64(9223372036854775808));

    if Reader.Advance <> jnListEnd then
      assert(false);

    if Reader.Advance <> jnEOF then
      assert(false);

  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// Test escape sequences
procedure Test11;
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

    if not Reader.Str(str) then
      assert(false);

    assert(str = expected);

    if Reader.Advance <> jnEOF then
      assert(false);
  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

// Test erroneous escape sequences
procedure Test12;
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

    if Reader.Str(str) then
      assert(false);
    Reader.Proceed;
    if Reader.Str(str) then
      assert(false);
    Reader.Proceed;

    if not Reader.Str(str) then
      assert(false);

    assert(str = expected);

    if Reader.Advance <> jnEOF then
      assert(false);
  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;

begin
  Test1;
  Test2;
  Test3;
  Test4;
  Test5;
  Test6;
  Test7;
  Test8;
  Test9;
  Test10;
  Test11;
  Test12;
end.

