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

program helloworld;

uses
  classes, jsonstream;

var
  Stream: TStream;
  Reader: TJsonReader;
  Writer: TJsonWriter;
  s: String;
  i: integer;
  d: Double;
begin
  // 1. Read a string
  WriteLn('Example 1');
  Stream := TStringStream.Create('"Hello World"');
  Reader := TJsonReader.Create(Stream);
  if (Reader.Str(s)) then
    WriteLn(s);
  Reader.Free;
  Stream.Free;

  // 2. Read a number
  WriteLn;
  WriteLn('Example 2');
  Stream := TStringStream.Create('42');
  Reader := TJsonReader.Create(Stream);
  if (Reader.Number(i)) then
    WriteLn(i);
  Reader.Free;
  Stream.Free;

  // 3. Read a list of strings and numbers
  WriteLn;
  WriteLn('Example 3');
  Stream := TStringStream.Create('["Hello", "World", 42]');
  Reader := TJsonReader.Create(Stream);
  if Reader.List then
    while Reader.Advance <> jsListEnd do
    begin
      if Reader.Str(s) then
        WriteLn(s)
      else if Reader.Number(i) then
        WriteLn(i)
    end;

  // 4. Read a dict
  WriteLn;
  WriteLn('Example 4');
  Stream := TStringStream.Create('{"hello": "world", "number": 3.14}');
  Reader := TJsonReader.Create(Stream);
  if Reader.Dict then
    while Reader.Advance <> jsDictEnd do
    begin
      // Note: In the real world you should check the return value of
      // Key(), because it can return false in case of a parse error.
      Reader.Key(s);
      WriteLn('Key: ', s);

      if Reader.Str(s) then
        WriteLn('Value: ', s)
      else if Reader.Number(d) then
        WriteLn('Value: ', d);
    end;   
  Reader.Free;
  Stream.Free;

  // 5. Create formatted JSON output
  WriteLn;
  WriteLn('Example 5');
  Stream := TStringStream.Create('');
  Writer := TJsonWriter.Create(Stream,[],true);
  Writer.List;
    Writer.Str('Foo');
    Writer.Str('Bar');
    Writer.Dict;
      Writer.Key('Baz');
      Writer.Number(42);
      Writer.Key('Flag');
      Writer.Bool(true);
      Writer.Key('Numbers');
      Writer.List;
        Writer.Number(1);
        Writer.Number(2);
        Writer.Number(3);
      Writer.ListEnd;
    Writer.DictEnd;
    Writer.Number(43);
  Writer.ListEnd;
  WriteLn(TStringStream(Stream).DataString);
end.

