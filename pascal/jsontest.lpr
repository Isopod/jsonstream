program jsontest;

uses
  sysutils, classes, jsonstream;

procedure AssertTrue(Cond: Boolean; const msg: string=''); inline;
begin
  if not Cond then
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

type
  TExpectedError = record
    Pos: integer;
    Err: TJsonError;
  end;

procedure _TestSample(
  const Input: string;
  const Expected: string;
  Features: TJsonFeatures;
  Errors: array of TExpectedError;
  Stubborn: Boolean = true
);
var
  InStream, OutStream: TStream;
  Reader: TJsonReader;
  Writer: TJsonWriter;
  Actual: String;
  ErrIdx: integer;

  function ReadValue: Boolean; forward;

  procedure CheckError;
  begin
    if ErrIdx > High(Errors) then
      AssertTrue(false,
        Format(
          'Unexpected error: %d (%s) at %d.', [
            Integer(Reader.LastError), Reader.LastErrorMessage, Reader.LastErrorPosition
          ]
        )
      )
    else
      AssertTrue(
        (Reader.LastError = Errors[ErrIdx].Err) and
        (Reader.LastErrorPosition = Errors[ErrIdx].Pos),
        Format(
          'Expected %d at %d, but got %d at %d (%s). ', [
            Errors[ErrIdx].Err, Errors[ErrIdx].Pos ,
            Integer(Reader.LastError), Reader.LastErrorPosition, Reader.LastErrorMessage
          ]
        )
      );

    Inc(ErrIdx);
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
          if not ReadValue then
            Writer.Null;
        end
        else if Reader.Error then
        begin
          CheckError;
          if Stubborn and Reader.Proceed then
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
        CheckError;
        if Stubborn and Reader.Proceed then
          continue;
      end
      else
        assert(false);
      break;
    until false;
  end;
begin
  InStream := nil;
  OutStream := nil;
  Reader := nil;
  Writer := nil;
  ErrIdx := 0;
  try
    InStream := TStringStream.Create(Input);
    OutStream := TMemoryStream.Create;
    Reader := TJsonReader.Create(InStream, Features);
    Writer := TJsonWriter.Create(OutStream, Features);

    ReadValue;

    SetString(
      Actual, TMemoryStream(OutStream).Memory, TMemoryStream(OutStream).Size
    );
    AssertTrue(
      Actual = Expected,
      Format(
        LineEnding + 'Expected: %s' +
        LineEnding + 'Got:      %s',
        [Expected, Actual]
      )
    );

    if ErrIdx < Length(Errors) then
    begin
      AssertTrue(
        false,
        Format(
          'Expected %d errors, got only %d. First missing error: %d at %d.',
          [
            Length(Errors), ErrIdx, Errors[High(Errors)].Err, Errors[High(Errors)].Pos
          ]
        )
      );
    end;
  finally
    FreeAndNil(InStream);
    FreeAndNil(OutStream);
    FreeAndNil(Reader);
    FreeAndNil(Writer);
  end;
end;

procedure TestSample(
  const Input: string;
  const Expected: string;
  Features: TJsonFeatures;
  Errors: array of TExpectedError
);
begin
  if Length(Errors) > 0 then
    _TestSample(Input, Expected, Features, [Errors[0]], false)
  else
    _TestSample(Input, Expected, Features, [], false);

  _TestSample(Input, Expected, Features, Errors, true);
end;

procedure TestSample2(
  const Input: string;
  const Expected: string;
  const ExpectedStubborn: string;
  Features: TJsonFeatures;
  Errors: array of TExpectedError
);
begin
  if Length(Errors) > 0 then
    _TestSample(Input, Expected, Features, [Errors[0]], false)
  else
    _TestSample(Input, Expected, Features, [], false);

  _TestSample(Input, ExpectedStubborn, Features, Errors, true);
end;

procedure TestSamples;
  function E(Pos: integer; Err: TJsonError): TExpectedError;
  begin
    Result.Pos := Pos;
    Result.Err := Err;
  end;
begin
  TestSample(
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
    ']',
    '[' +
      '{' +
        '"name":"Alan Turing",' +
        '"profession":"computer scientist",' +
        '"born":1912,' +
        '"died":1954,' +
        '"tags":["turing machine","cryptography","enigma","computability"]' +
      '},' +
      '{' +
        '"name":"Kurt Gödel",' +
        '"profession":"mathematician",' +
        '"born":1906,' +
        '"died":1978,' +
        '"tags":["incompleteness theorem","set theory","logic","philosophy"]' +
      '},' +
      '{' +
        '"name":"Bobby \"\\\"\" Tables",' +
        '"profession":"troll",' +
        '"born":1970,'+
        '"died":2038,'+
        '"tags":["escape sequence","input validation","sql injection"]' +
      '}' +
    ']',
    [], []
  );

  TestSample(
    '["Hello", "World"}',
    '["Hello","World"]',
    [], [E(17, jeUnexpectedToken), E(18, jeUnexpectedEOF)]
  );
  TestSample(
    '[}',
    '[]',
    [], [E(1, jeUnexpectedToken), E(2, jeUnexpectedEOF)]
  );
  TestSample2(
    '{[], "Foo": "Bar"}',
    '{}',
    '{"Foo":"Bar"}',
    [], [E(1, jeUnexpectedToken)]
  );
  TestSample2(
    '{"garbage": 03.14, "foo": "bar"}',
    '{"garbage":null}',
    '{"garbage":3.14,"foo":"bar"}',
    [], [E(13, jeInvalidNumber)]
  );
  TestSample2(
    '[03.14,3.14]',
    '[]',
    '[3.14,3.14]',
    [], [E(2, jeInvalidNumber)]
  );
  TestSample2(
    '[1 2]',
    '[1]',
    '[1,2]',
    [], [E(3, jeUnexpectedToken) ]
  );
  TestSample2(
    '{"abc" "123"}',
    '{"abc":null}',
    '{"abc":null,"123":null}',
    [], [
      E(7,  jeUnexpectedToken) { Expected colon },
      E(7,  jeUnexpectedToken) { Expected comma },
      E(12, jeUnexpectedToken) { Expected colon }
    ]
  );
  TestSample2(
    '{"abc" 123}',
    '{"abc":null}',
    '{"abc":null,"123":null}',
    [], [
      E(7,  jeUnexpectedToken) { Expected colon },
      E(7,  jeUnexpectedToken) { Expected comma },
      E(7,  jeUnexpectedToken) { Expected key },
      E(10, jeUnexpectedToken) { Expected colon }
    ]
  );
  TestSample2(
    '{"abc" 123 "a" : "b"}',
    '{"abc":null}',
    '{"abc":null,"123":null,"a":"b"}',
    [], [
      E(7,  jeUnexpectedToken) { Expected colon },
      E(7,  jeUnexpectedToken) { Expected comma },
      E(7,  jeUnexpectedToken) { Expected key },
      E(11, jeUnexpectedToken) { Expected colon },
      E(11, jeUnexpectedToken) { Expected comma }
    ]
  );
  TestSample2(
    '{123:123,  "a" : "b"}',
    '{}',
    '{"123":123,"a":"b"}',
    [], [
      E(1,  jeUnexpectedToken) { Expected key }
    ]
  );
  TestSample2(
    '{123:123,  23 : "b"}',
    '{}',
    '{"123":123,"23":"b"}',
    [], [
      E(1,  jeUnexpectedToken) { Expected key },
      E(11, jeUnexpectedToken) { Expected key }
    ]
  );
  TestSample2(
    '{abc123 : "bcd"}',
    '{}',
    '{"abc123":"bcd"}',
    [], [
      E(1,  jeInvalidToken) { Expected key }
    ]
  );
  TestSample2(
    '{123:[123,  23 : "b"}',
    '{}',
    '{"123":[123,23,"b"]}',
    [], [
      E(1,  jeUnexpectedToken) { Expected key },
      E(15, jeUnexpectedToken) { Expected comma },
      E(17, jeUnexpectedToken) { Expected comma },
      E(20, jeUnexpectedToken) { Expected list end }
    ]
  );
  TestSample2(
    '{123:[123,  23 : "b"]}',
    '{}',
    '{"123":[123,23,"b"]}',
    [], [
      E(1,  jeUnexpectedToken) { Expected key },
      E(15, jeUnexpectedToken) { Expected comma },
      E(17, jeUnexpectedToken) { Expected comma }
    ]
  );
  TestSample2(
    '{"a":123abc, "c":"d"}',
    '{"a":null}',
    '{"a":null,"c":"d"}',
    [], [E(8, jeInvalidToken)]
  );
  TestSample2(
    '{"123a":, "c":"d"}',
    '{"123a":null}',
    '{"123a":null,"c":"d"}',
    [], [E(8, jeUnexpectedToken)]
  );
  TestSample2(
    '{"123a" "c" "d" }',
    '{"123a":null}',
    '{"123a":null,"c":null,"d":null}',
    [], [
      E(8,  jeUnexpectedToken) { Expected colon },
      E(8,  jeUnexpectedToken) { Expected comma },
      E(12, jeUnexpectedToken) { Expected colon },
      E(12, jeUnexpectedToken) { Expected comma },
      E(16, jeUnexpectedToken) { Expected colon }
    ]
  );
  TestSample(
    '{"a" ',
    '{"a":null}',
    [], [
      E(5,  jeUnexpectedEOF) { Expected colon },
      E(5,  jeUnexpectedEOF) { Expected dict-end }
    ]
  );
  TestSample2(
    '{"a", {"b" ',
    '{"a":null}',
    '{"a":null}',
    [], [
      E(4,  jeUnexpectedToken) { Expected colon },  
      E(6,  jeUnexpectedToken) { Expected key },
      E(11, jeUnexpectedEOF)   { Expected colon },
      E(11, jeUnexpectedEOF)   { Expected dict-end }
    ]
  );
  TestSample2(
    '{"a", {"b": ',
    '{"a":null}',
    '{"a":null}',
    [], [
      E(4,  jeUnexpectedToken) { Expected colon },
      E(6,  jeUnexpectedToken) { Expected key },
      E(12, jeUnexpectedEOF)   { Expected value },
      E(12, jeUnexpectedEOF)   { Expected dict-end }
    ]
  );
  TestSample(
    '{"a", ["b" ',
    '{"a":null}',
    [], [
      E(4,  jeUnexpectedToken) { Expected colon },
      E(6,  jeUnexpectedToken) { Expected key },
      E(11, jeUnexpectedEOF)   { Expected list-end }
    ]
  );
  TestSample(
    '{[ ',
    '{}',
    [], [
      E(1,  jeUnexpectedToken) { Expected key },
      E(3,  jeUnexpectedEOF)   { Expected list-end }
    ]
  );
  TestSample2(
    '{{} "c":123',
    '{}',
    '{"c":123}',
    [], [
      E(1,  jeUnexpectedToken) { Expected key },   
      E(4,  jeUnexpectedToken) { Expected comma },
      E(11, jeUnexpectedEOF)   { Expected dict-end }
    ]
  );
  TestSample2(
    '{["a"], "c":123',
    '{}',
    '{"c":123}',
    [], [
      E(1,  jeUnexpectedToken) { Expected key },
      E(15, jeUnexpectedEOF)   { Expected dict-end }
    ]
  );
  TestSample2(
    '{["a",], "c":123',
    '{}',
    '{"c":123}',
    [], [
      E(1,  jeUnexpectedToken) { Expected key },
      E(6,  jeTrailingComma),
      E(16, jeUnexpectedEOF)   { Expected dict-end }
    ]
  );
  TestSample2(
    '{{"b":"a",} "c":123',
    '{}',
    '{"c":123}',
    [], [
      E(1,  jeUnexpectedToken) { Expected key } ,
      E(10, jeTrailingComma),
      E(12, jeUnexpectedToken) { Expected comma },
      E(19, jeUnexpectedEOF)   { Expected dict-end }
    ]
  );
  TestSample2(
    '{"a", {"b",} "c":123',
    '{"a":null}',
    '{"a":null,"c":123}',
    [], [
      E(4,  jeUnexpectedToken) { Expected colon },
      E(6,  jeUnexpectedToken) { Expected key },
      E(10, jeUnexpectedToken) { Expected colon },
      E(11, jeTrailingComma),
      E(13, jeUnexpectedToken) { Expected comma },
      E(20, jeUnexpectedEOF)   { Expected dict-end }
    ]
  );
  TestSample(
    '[0]',
    '[0]',
    [], []
  );
  TestSample(
    '{"a":2b3}',
    '{"a":null}',
    [], [E(6, jeInvalidToken)]
  );
  TestSample2(
    '{"',
    '{}',
    '{"":null}',
    [], [
      E(2,  jeUnexpectedEOF) { Expected string-end },
      E(2,  jeUnexpectedEOF) { Expected colon },
      E(2,  jeUnexpectedEOF) { Expected value }
    ]
  );
  TestSample2(
    '{"a":23ueuiaeia232, "b": truefalse, "c": "}',
    '{"a":null}',
    '{"a":null,"b":"truefalse","c":"}"}',
    [], [
      E(7,  jeInvalidToken),
      E(25, jeInvalidToken)  { Expected value },
      E(43, jeUnexpectedEOF) { Expected string-end },
      E(43, jeUnexpectedEOF) { Expected dict-end }
    ]
  );
  TestSample(
    '{"a": "b",}',
    '{"a":"b"}',
    [], [E(10, jeTrailingComma)]
  );
  TestSample(
    '["a",]',
    '["a"]',
    [], [E(5, jeTrailingComma)]
  );
  TestSample(
    '[]',
    '[]',
    [], []
  );
  TestSample2(
    '{"n": 003.14}',
    '{"n":null}',
    '{"n":3.14}',
    [], [E(8, jeInvalidNumber)]
  );
  TestSample2(
    '{{123: 321} "c":42}',
    '{}',
    '{"c":42}',
    [], [
      E(1,  jeUnexpectedToken) { Expected key },
      E(2,  jeUnexpectedToken) { Expected key },
      E(12, jeUnexpectedToken) { Expected comma }
    ]
  );
  TestSample(
    '{"text": "cote \r\naiu e [/code" }',
    '{"text":"cote \r\naiu e [/code"}',
    [], []
  );
  TestSample2(
    '["a]',
    '[]',
    '["a]"]',
    [], [
      E(4, jeUnexpectedEOF) { Expected string end },
      E(4, jeUnexpectedEOF) { Expected list end }
    ]
  );
  TestSample(
    '["\u0041"]',
    '["A"]',
    [], []
  );
  TestSample2(
    '["\u41"]',
    '[]',
    '["A"]',
    [], [E(2, jeInvalidEscapeSequence)]
  );
  TestSample2(
    '"a'#13#10'b"',
    '',
    '"a\r\nb"',
    [], [E(2, jeInvalidEscapeSequence),E(3, jeInvalidEscapeSequence)]
  );
  TestSample(
    '['#1']',
    '[]',
    [], [E(1,  jeInvalidToken)]
  );
  TestSample2(
    '[a'#10'b]',
    '[]',
    '["a","b"]',
    [], [E(1, jeInvalidToken), E(3, jeInvalidToken)]
  );
  TestSample2(
    '["abc\'#13#10'def\'#10'ghi"]',
    '[]',
    '["abc\\\r\ndef\\\nghi"]',
    [], [
      E(5, jeInvalidEscapeSequence), E(7, jeInvalidEscapeSequence),
      E(11, jeInvalidEscapeSequence)
    ]
  );
  TestSample2(
    '[''a'', /*hello'#10'*w/orld*/123.5//this is a number]',
    '[]',
    '["a","/*hello","*w/orld*/123.5//this","is","a","number"]',
    [], [
      E(1,  jeInvalidToken) { ' instead of " },
      E(6,  jeInvalidToken) { /* },
      E(14, jeInvalidToken) { */ },
      E(35, jeInvalidToken) { is },
      E(38, jeInvalidToken) { a },
      E(40, jeInvalidToken) { number }
    ]
  );
  TestSample(
    '[''a'', /*hello'#10'*w/orld*/123.5//this is a number]',
    '["a",123.5]',
    [jfJson5], [
      E(47, jeUnexpectedEOF) { expected list end }
    ]
  );
  TestSample2(
    '[-Infinity, 42]',
    '[]',
    '[null,42]',
    [], [E(2, jeInvalidToken)]
  );

  TestSample2(
    '{"a":-Infinity, "b":42}',
    '{"a":null}',
    '{"a":null,"b":42}',
    [], [E(6, jeInvalidToken)]
  );

  TestSample(
    '[0xcafe, .123, 123., ''a"b\''c'', "a\'#13#10'b", {key: "value",},]',
    '[51966,0.123,123,"a\"b''c","a\r\nb",{"key":"value"}]',
    [jfJson5], []
  );

  TestSample(
    '{NaN: NaN, Infinity: Infinity, "+Infinity": +Infinity, "-Infinity": -Infinity}',
    '{"NaN":NaN,"Infinity":Infinity,"+Infinity":Infinity,"-Infinity":-Infinity}',
    [jfJson5], []
  );
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
  TestSamples;
end.




