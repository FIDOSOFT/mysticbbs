program test0;

uses
  crt;

var ch : char;

begin
  repeat
    ch := readkey;

    if ch = #0 then
        writeln('Extended: ', ord(ch))
          else
              writeln('Got: ' + ch + ' ', ord(ch));
              until ch = #27;
end.
