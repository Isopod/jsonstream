# JsonStream

## Description
JsonStream is a library providing a low-level streaming API for reading and
writing JSON markup. No automatic serialization or deserialization takes place
and no objects are created in memory. As a result, there is very little overhead
and you can even handle JSON markup too large to fit into memory. The parser is
also fault tolerant and can report and recover from certain errors like
incorrect nesting or a missing comma. It is easy to use and adapt to your own
use cases.

## What makes this library different?
Other JSON libraries do a lot of things at once. When parsing JSON, they not
only parse, but also turn the markup into an object tree, or even use
Reflection/RTTI to automatically map between your own objects and their JSON
representation. The parser in JsonStream on the other hand is *just* a parser.
What you do with the data is entirely up to you. This also means that your
classes/structs/records don't have to be a 1:1 representation of the JSON, which
can be very useful when working with existing JSON APIs.

Whereas other JSON libraries force you to define the JSON structure
declaratively, in JsonStream the structure is defined as code, which makes it a
lot more flexible and expressive. For example, if there is a value that may be
either `null` or an integer, you can simply test for it, rather than having to
declare a special `Nullable<int>` type with a bunch of overloaded methods. As
your JSON spec becomes more complex, the declarative approach taken by other
libraries becomes difficult to read and maintain, and results in a lot of
boilerplate code. You end up writing turing-complete code using template syntax,
which is not what you want. JsonStream on the other hand just lets you use the
turing-complete language already at your disposal.

## Example

Reading:
```pascal
var
  s: string;
  i: integer;
  ...
begin
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
end;
```

Writing:
```pascal
begin
  Stream := TIOStream.Create(iosOutput);
  Writer := TJsonWriter.Create(Stream,[],true);
  Writer.Dict;
    Writer.Key('Hello');
    Writer.Str('World');
    Writer.Key('Flag');
    Writer.Bool(true);
    Writer.Key('Numbers');
    Writer.List;
      Writer.Number(1);
      Writer.Number(2);
      Writer.Number(3);
    Writer.ListEnd;
  Writer.DictEnd;
end;
```

=>

```json
{
  "Hello": "World",
  "Flag": true,
  "Numbers": [
    1,
    2,
    3
  ]
}
```

Find more examples [here](pascal/example).

## Features

This library can read and write the following standards:
  - [JSON](https://www.json.org/json-en.html)
  - [JSON5](https://json5.org/) (needs to be enabled explicitly)

It adheres closely to the standards and can be used to validate or sanitize JSON
markup. It can even continue parsing after an error, if desired. See an example
for such a usage in [pascal/example/jsonecho](pascal/example/jsonecho).

The library can process arbitrary inputs with predictable runtime
characteristics. Strings and object keys can be processed chunk-by-chunk using
the methods `StrBuf` and `KeyBuf`, and thus don't have to be reside in memory in
their entirety. The semantics of these functions are similar to the `read`
syscall on Posix systems.

The time required to parse a JSON file is bounded by O(n + e\*k), where n is the
length in bytes, e is the number of corrected errors and k is the maximum
nesting depth. For most use cases, aborting on the first error is fine (it is
also the default), in which case the runtime becomes O(n). The memory usage is
bounded by O(k). You can specify a maximum allowable nesting depth during
initialization. The parser will then abort once this limit is reached.

Output can be pretty-printed if desired or use a compact representation with no
extra whitespace.

## Files
This repository has subfolders for the various language implementations of the
library.  Currently, the only implementation is written in Pascal, but other
implementations (e.g. C) are planned.

Subfolders:

| Folder           | Description                         |
| ---------------- | ----------------------------------- |
| [pascal](pascal) | Pascal implementation of JsonStream |


## License
This project is licensed under the MIT license.

```
Copyright 2021 Philip Zander

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```
