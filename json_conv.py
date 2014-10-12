# -*- coding: utf-8 -*-  
r"""Command-line tool to validate and pretty-print JSON

Usage::

    $ echo '{"json":"obj"}' | python -m json.tool
    {
        "json": "obj"
    }
    $ echo '{ 1.2:3.4}' | python -m json.tool
    Expecting property name enclosed in double quotes: line 1 column 3 (char 2)

"""
import sys
import json
import io
def main():
    if len(sys.argv) == 1:
        infile = sys.stdin
        outfile = sys.stdout
    elif len(sys.argv) == 2:
        infile = open(sys.argv[1], 'r', encoding='utf8')
        outfile = sys.stdout
    elif len(sys.argv) == 3:
        infile = io.open(sys.argv[1], 'r', encoding='utf8')
        outfile = io.open(sys.argv[2], 'w', encoding='utf8')
    else:
        raise SystemExit(sys.argv[0] + " [infile [outfile]]")
    with infile:
        try:
            obj = json.load(infile)
        except ValueError as e:
            raise SystemExit(e)
    with outfile:
        json_string = json.dumps(obj, ensure_ascii = False , sort_keys=True,
                  indent=4, separators=(',', ': '))
        outfile.write(json_string)


if __name__ == '__main__':
    main()
