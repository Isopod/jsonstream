// Copyright 2021 Philip Zander
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
// the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

program jsontest;

uses
  SysUtils, Classes, jsonstream;

procedure Check(Cond: Boolean; const Msg: string=''); inline;
begin
  if not Cond then
    raise EAssertionFailed.Create(Msg);
end;

// Test basic list
procedure TestList;
var
  Stream: TStream;
  Reader: TJsonReader;
  Num:    Integer;
  i:      Integer;
const
  Sample = '[1,2,3]';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(Sample);
    Reader := TJsonReader.Create(Stream);

    Check(Reader.List);

    for i := 1 to 3 do
    begin
      Reader.Advance;
      Check(Reader.Number(Num));
      assert(Num = i);
    end;

    Check(Reader.Advance = jsListEnd);
    Check(Reader.Advance = jsEOF);
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

  Num:    Integer;
  Str:    string;

  i:      Integer;
const
  Sample = '{"abc":1,"def":2,"ghi":3}';
  Keys: array [1..3] of string = ('abc', 'def', 'ghi');
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(Sample);
    Reader := TJsonReader.Create(Stream);

    Check(Reader.Dict);

    for i := 1 to 3 do
    begin
      Reader.Advance;
      Check(Reader.Key(Str));
      Check(Str = Keys[i]);
      Check(Reader.Number(Num));
      Check(Num = i);
    end;

    Check(Reader.Advance = jsDictEnd);
    Check(Reader.Advance = jsEOF);

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
  Num:    Integer;
  Str:    string;
  i:      Integer;
const
  Sample =
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
    Stream := TStringStream.Create(Sample);
    Reader := TJsonReader.Create(Stream);

    Check(Reader.Dict);

    Reader.Advance;

    Check(Reader.Key(Str));
    Check(Str = 'abc');

    Check(Reader.List);

    Reader.Advance;

    Check(Reader.Dict);

    Reader.Advance;

    Check(Reader.Key(Str));
    Check(Str = 'nest');

    Check(Reader.Dict);

    Reader.Advance;

    Check(Reader.Key(Str));
    Check(Str = 'nest2');

    Check(Reader.List);

    for i := 1 to 3 do
    begin
      Reader.Advance;
      Check(Reader.Number(Num));
      Check(Num = i);
    end;

    Check(Reader.Advance = jsListEnd);
    Check(Reader.Advance = jsDictEnd);
    Check(Reader.Advance = jsDictEnd);
    Check(Reader.Advance = jsListEnd);

    Reader.Advance;

    Check(Reader.Key(Str));
    Check(Str = 'def');

    Check(Reader.List);

    Reader.Advance;

    Check(Reader.List);

    Reader.Advance;

    Check(Reader.Number(Num));
    Check(Num = 1);

    Reader.Advance;

    Check(Reader.Number(Num));
    Check(Num = 2);

    Check(Reader.Advance = jsListEnd);

    Reader.Advance;

    Check(Reader.List);

    Reader.Advance;

    Check(Reader.List);

    Reader.Advance;

    Check(Reader.Number(Num));
    Check(Num = 4);

    Check(Reader.Advance = jsListEnd);

    Reader.Advance;

    Check(Reader.Number(Num));

    assert(Num = 5);

    Check(Reader.Advance = jsListEnd);

    Reader.Advance;

    Check(Reader.Number(Num));
    Check(Num = 6);

    Reader.Advance;

    Check(Reader.List);

    Reader.Advance;

    Check(Reader.Number(Num));
    Check(Num = 7);

    Check(Reader.Advance = jsListEnd);
    Check(Reader.Advance = jsListEnd);
    Check(Reader.Advance = jsDictEnd);
    Check(Reader.Advance = jsEOF);

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
  Str:    string;
const
  // Malformed JSON
  Sample = '[{"a":"b"}{"c":"d","e"}{"f":"g"]}';
  //                  ^           ^^       ^^
  //                  1           23       45
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(Sample);
    Reader := TJsonReader.Create(Stream);

    Check(Reader.List);

    Reader.Advance;

    Check(Reader.Dict);

    Reader.Advance;

    Check(Reader.Key(Str));
    Check(Str = 'a');

    Check(Reader.Str(Str));
    Check(Str = 'b');

    Reader.Advance;

    Check(Reader.State = jsDictEnd);

    Reader.Advance;

    // 1st error

    Check(Reader.State = jsError);

    Reader.Proceed;
    Reader.Advance;

    Check(Reader.Dict);

    Reader.Advance;

    Check(Reader.Key(Str));
    Check(Str = 'c');

    Check(Reader.Str(Str));
    Check(Str = 'd');

    Reader.Advance;

    Check(Reader.Key(Str));
    Check(Str = 'e');

    // 2nd error

    Check(Reader.Error);

    Reader.Proceed;

    Check(Reader.State = jsNull);

    Check(Reader.Advance = jsDictEnd);

    // 3rd error

    Reader.Advance;
    Check(Reader.Error);

    Reader.Proceed;
    Reader.Advance;

    Check(Reader.Dict);

    Reader.Advance;

    Check(Reader.Key(Str));
    Check(Str = 'f');

    Check(Reader.Str(Str));
    Check(Str = 'g');

    // 4th error

    Reader.Advance;
    Check(Reader.Error);

    Reader.Proceed;

    Check(Reader.Advance = jsDictEnd);
    Check(Reader.Advance = jsListEnd);

    // 5th error

    Reader.Advance;
    Check(Reader.Error);

    Reader.Proceed;

    Check(Reader.Advance = jsEOF);

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
  Num:    Integer;
const
  Sample = '[1,[2,[3,4],[5]],6]';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(Sample);
    Reader := TJsonReader.Create(Stream);

    Check(Reader.List);

    Reader.Advance;

    Check(Reader.Number(Num));
    Check(Num = 1);

    Reader.Advance;

    Check(Reader.List);

    Reader.Skip;

    Reader.Advance;

    Check(Reader.Number(Num));
    Check(Num = 6);

    Check(Reader.Advance = jsListEnd);
    Check(Reader.Advance = jsEOF);
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
  Num:    Integer;
const
  Sample = '[1,{2,"a":"b"},3]';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(Sample);
    Reader := TJsonReader.Create(Stream);

    Check(Reader.List);

    Reader.Advance;
    Check(Reader.Number(Num));
    Check(Num = 1);

    Reader.Advance;

    Check(Reader.Dict);

    Reader.Skip;

    Check(Reader.Advance = jsError);

    Check(Reader.Proceed);
    Check(Reader.Proceed);

    Check(Reader.Number(Num));
    Check(Num = 3);

    Check(Reader.Advance = jsListEnd);
    Check(Reader.Advance = jsEOF);
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
  Sample = '[true,false,true]';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(Sample);
    Reader := TJsonReader.Create(Stream);

    Check(Reader.List);

    Reader.Advance;

    Check(Reader.Bool(b));
    Check(b);

    Reader.Advance;

    Check(Reader.Bool(b));
    Check(not b);

    Reader.Advance;

    Check(Reader.Bool(b));
    Check(b);

    Check(Reader.Advance = jsListEnd);
    Check(Reader.Advance = jsEOF);
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
  Sample = '{"foo":true,"bar":false}';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(Sample);
    Reader := TJsonReader.Create(Stream);

    Check(Reader.Dict);

    Reader.Advance;

    Check(Reader.Key(k));
    Check(k = 'foo');

    Check(Reader.Bool(b));
    Check(b);

    Reader.Advance;

    Check(Reader.Key(k));
    Check(k = 'bar');

    Check(Reader.Bool(b));
    Check(not b);

    Check(Reader.Advance = jsDictEnd);
    Check(Reader.Advance = jsEOF);
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

  Dbl:    double;
  Int:    Integer;
  U64:    UInt64;
const
  Sample = '[3.14,-42,1.024e3,9223372036854775808]';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(Sample);
    Reader := TJsonReader.Create(Stream);

    Check(Reader.List);

    Reader.Advance;

    Check(not Reader.Number(Int));
    Check(Reader.Number(Dbl));
    Check(Dbl = double(3.14));

    Reader.Advance;

    Check(Reader.Number(Int));
    Check(Int = -42);

    Reader.Advance;

    Check(Reader.Number(Dbl));
    Check(Dbl = 1024);

    Reader.Advance;

    Check(not Reader.Number(Int));
    Check(Reader.Number(U64));
    Check(U64 = uint64(9223372036854775808));

    Check(Reader.Advance = jsListEnd);
    Check(Reader.Advance = jsEOF);
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
  Str:    string;
const
  Sample   = '"Hello \u0041 World\tTab\r\nNewLine"';
  Expected = 'Hello A World'#9'Tab'#13#10'NewLine';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(Sample);
    Reader := TJsonReader.Create(Stream);

    Check(Reader.Str(Str));
    Check(Str = Expected);

    Check(Reader.Advance = jsEOF);
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
  Str:    string;
const
  Sample   = '"a \u41 b\x"';
  Expected = 'a A b\x';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(Sample);
    Reader := TJsonReader.Create(Stream);

    Check(not Reader.Str(Str));
    Reader.Proceed;

    Check(not Reader.Str(Str));
    Reader.Proceed;

    Check(Reader.Str(Str));
    Check(Str = Expected);

    Check(Reader.Advance = jsEOF);
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
  Buf:    string;
  n:      SizeInt;
const
  Sample = '["Hello World", "Hello \u0041 World", "\u0041\u0042\u0043\u0044\r\n\u0045\u0046", "", "Hell\u00f6 W\u00f6rld"]';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(Sample);
    Reader := TJsonReader.Create(Stream);

    Check(Reader.List);

    Check(Reader.Advance = jsString);

    Buf := '';
    SetLength(Buf, 5);

    // "Hello World"
    n := Reader.StrBuf(Buf[1], 5);
    Check((n = 5) and (Copy(Buf, 1, n) = 'Hello'));
    n := Reader.StrBuf(Buf[1], 5);
    Check((n = 5) and (Copy(Buf, 1, n) = ' Worl'));
    n := Reader.StrBuf(Buf[1], 5);
    Check((n = 1) and (Copy(Buf, 1, n) = 'd'));
    n := Reader.StrBuf(Buf[1], 5);
    Check((n = 0));

    Check(Reader.Advance = jsString);

    // Hello A World
    n := Reader.StrBuf(Buf[1], 5);
    Check((n = 5) and (Copy(Buf, 1, n) = 'Hello'));
    n := Reader.StrBuf(Buf[1], 5);
    Check((n = 5) and (Copy(Buf, 1, n) = ' A Wo'));
    n := Reader.StrBuf(Buf[1], 5);
    Check((n = 3) and (Copy(Buf, 1, n) = 'rld'));
    n := Reader.StrBuf(Buf[1], 5);
    Check((n = 0));

    Check(Reader.Advance = jsString);

    // ABCD\n\rEF
    n := Reader.StrBuf(Buf[1], 5);
    Check((n = 5) and (Copy(Buf, 1, n) = 'ABCD'#13));
    n := Reader.StrBuf(Buf[1], 5);
    Check((n = 3) and (Copy(Buf, 1, n) = #10'EF'));
    n := Reader.StrBuf(Buf[1], 5);
    Check((n = 0));

    Check(Reader.Advance = jsString);

    // ""
    n := Reader.StrBuf(Buf[1], 5);
    Check(n = 0);

    Check(Reader.Advance = jsString);

    // Hellö Wörld
    n := Reader.StrBuf(Buf[1], 5);
    Check((n = 5) and (Copy(Buf, 1, n) = 'Hell'#$c3));
    n := Reader.StrBuf(Buf[1], 5);
    Check((n = 5) and(Copy(Buf, 1, n) = #$b6' W'#$c3#$b6));
    n := Reader.StrBuf(Buf[1], 5);
    Check((n = 3) and (Copy(Buf, 1, n) = 'rld'));
    n := Reader.StrBuf(Buf[1], 5);
    Check((n = 0));

    Check(Reader.Advance = jsListEnd);
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
  Buf:    string;
  n:      SizeInt;
  Int:    Integer;
const
  Sample = '{"Hello World": 1, "Hello \u0041 World": 2, "\u0041\u0042\u0043\u0044\r\n\u0045\u0046":3, "":4, "Hell\u00f6 W\u00f6rld":5}';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(Sample);
    Reader := TJsonReader.Create(Stream);

    Check(Reader.Dict);

    Check(Reader.Advance = jsKey);

    Buf := '';
    SetLength(Buf, 5);

    // "Hello World"
    n := Reader.KeyBuf(Buf[1], 5);
    Check((n = 5) and (Copy(Buf, 1, n) = 'Hello'));
    n := Reader.KeyBuf(Buf[1], 5);
    Check((n = 5) and (Copy(Buf, 1, n) = ' Worl'));
    n := Reader.KeyBuf(Buf[1], 5);
    Check((n = 1) and (Copy(Buf, 1, n) = 'd'));
    n := Reader.KeyBuf(Buf[1], 5);
    Check((n = 0));

    Check(Reader.Number(Int));
    Check(Int = 1);

    Check(Reader.Advance = jsKey);

    // Hello A World
    n := Reader.KeyBuf(Buf[1], 5);
    Check((n = 5) and (Copy(Buf, 1, n) = 'Hello'));
    n := Reader.KeyBuf(Buf[1], 5);
    Check((n = 5) and (Copy(Buf, 1, n) = ' A Wo'));
    n := Reader.KeyBuf(Buf[1], 5);
    Check((n = 3) and (Copy(Buf, 1, n) = 'rld'));
    n := Reader.KeyBuf(Buf[1], 5);
    Check((n = 0));

    Check(Reader.Number(Int));
    Check(Int = 2);

    Check(Reader.Advance = jsKey);

    // ABCD\n\rEF
    n := Reader.KeyBuf(Buf[1], 5);
    Check((n = 5) and (Copy(Buf, 1, n) = 'ABCD'#13));
    n := Reader.KeyBuf(Buf[1], 5);
    Check((n = 3) and (Copy(Buf, 1, n) = #10'EF'));
    n := Reader.KeyBuf(Buf[1], 5);
    Check((n = 0));

    Check(Reader.Number(Int));
    Check(Int = 3);

    Check(Reader.Advance = jsKey);

    // ""
    n := Reader.KeyBuf(Buf[1], 5);
    Check(n = 0);

    Check(Reader.Number(Int));
    Check(Int = 4);

    Check(Reader.Advance = jsKey);

    // Hellö Wörld
    n := Reader.KeyBuf(Buf[1], 5);
    Check((n = 5) and (Copy(Buf, 1, n) = 'Hell'#$c3));
    n := Reader.KeyBuf(Buf[1], 5);
    Check((n = 5) and (Copy(Buf, 1, n) = #$b6' W'#$c3#$b6));
    n := Reader.KeyBuf(Buf[1], 5);
    Check((n = 3) and (Copy(Buf, 1, n) = 'rld'));
    n := Reader.KeyBuf(Buf[1], 5);
    Assert(n = 0);

    Check(Reader.Number(Int));
    Check(Int = 5);

    Check(Reader.Advance = jsDictEnd);
  finally
    FreeAndNil(Stream);
    FreeAndNil(Reader);
  end;
end;


procedure TestIntRanges;
var          
  Stream: TStream;
  Reader: TJsonReader;
  i32:    Int32;
  u32:    UInt32;
  i64:    Int64;
  u64:    UInt64;
  dbl:    Double;
const
  sample = '[7795000000, 2147483648, 9223372036854775808, 18446744073709551616]';
begin
  Stream := nil;
  Reader := nil;
  try
    Stream := TStringStream.Create(sample);
    Reader := TJsonReader.Create(Stream);

    Reader.List; 
    Reader.Advance;

    Check(not Reader.Number(i32));
    Check(not Reader.Number(u32));
    Check(Reader.Number(i64));
    Check(i64 = 7795000000);

    Reader.Advance;

    Check(not Reader.Number(i32));
    Check(Reader.Number(u32));
    Check(u32 = 2147483648);

    Reader.Advance;

    Check(not Reader.Number(i32));
    Check(not Reader.Number(u32));
    Check(not Reader.Number(i64));
    Check(Reader.Number(u64));
    Check(u64 = 9223372036854775808);

    Reader.Advance;

    Check(not Reader.Number(i32));
    Check(not Reader.Number(u32));
    Check(not Reader.Number(i64));
    Check(not Reader.Number(u64));
    Check(Reader.Number(dbl));
    Check(dbl = 18446744073709551616.0);
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
  const Input:    string;
  const Expected: string;
  Features:       TJsonFeatures;
  Errors:         array of TExpectedError;
  Stubborn:       Boolean = true
);
var
  InStream, OutStream: TStream;
  Reader: TJsonReader;
  Writer: TJsonWriter;
  Actual: String;
  ErrIdx: Integer;

  function ReadValue: Boolean; forward;

  procedure CheckError;
  begin
    if ErrIdx > High(Errors) then
      Check(false,
        Format(
          'Unexpected error: %d (%s) at %d.', [
            Integer(Reader.LastError), Reader.LastErrorMessage, Reader.LastErrorPosition
          ]
        )
      )
    else
      Check(
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
    while Reader.Advance <> jsListEnd do
      ReadValue;
    Writer.ListEnd;
  end;

  procedure ReadDict;
  var
    Key: String;
  begin
    Writer.Dict;

    while Reader.Advance <> jsDictEnd do
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
    i64:  Int64;
    u64:  UInt64;
    dbl:  Double;
    Str:  string;
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
  InStream  := nil;
  OutStream := nil;
  Reader    := nil;
  Writer    := nil;
  ErrIdx    := 0;
  try
    InStream := TStringStream.Create(Input);
    OutStream := TMemoryStream.Create;
    Reader := TJsonReader.Create(InStream, Features);
    Writer := TJsonWriter.Create(OutStream, Features);

    ReadValue;

    SetString(
      Actual, TMemoryStream(OutStream).Memory, TMemoryStream(OutStream).Size
    );
    Check(
      Actual = Expected,
      Format(
        LineEnding + 'Expected: %s' +
        LineEnding + 'Got:      %s',
        [Expected, Actual]
      )
    );

    if ErrIdx < Length(Errors) then
    begin
      Check(
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
  const Input:    string;
  const Expected: string;
  Features:       TJsonFeatures;
  Errors:         array of TExpectedError
);
begin
  if Length(Errors) > 0 then
    _TestSample(Input, Expected, Features, [Errors[0]], false)
  else
    _TestSample(Input, Expected, Features, [], false);

  _TestSample(Input, Expected, Features, Errors, true);
end;

procedure TestSample2(
  const Input:            string;
  const Expected:         string;
  const ExpectedStubborn: string;
  Features:               TJsonFeatures;
  Errors:                 array of TExpectedError
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
  try
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
    TestIntRanges;
    TestSamples;

    WriteLn('All tests succeeded.');
    ExitCode := 0;
  except
    on E: Exception do
    begin
      WriteLn('A test FAILED!');
      DumpExceptionBackTrace(Output);
      ExitCode := -1;
    end;
  end;
end.




